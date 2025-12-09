import { Canvas, CanvasRenderingContext2D } from '@kit.ArkGraphics2D';

export interface WaveformData {
  peaks: number[];
  duration: number;
  sampleRate: number;
}

export interface WaveformSelection {
  startTime: number;
  endTime: number;
  startX: number;
  endX: number;
}

@Component
export struct WaveformComponent {
  @State waveformData: WaveformData | null = null;
  @State currentTime: number = 0;
  @State selection: WaveformSelection | null = null;
  @State isSelecting: boolean = false;
  @State zoomLevel: number = 1;
  @State offsetX: number = 0;
  @State canvasWidth: number = 0;
  @State canvasHeight: number = 120;

  private canvasId: string = 'waveformCanvas';
  private ctx: CanvasRenderingContext2D | null = null;
  private animationId: number = -1;
  private isDragging: boolean = false;
  private lastPanX: number = 0;

  // 回调函数
  onSelectionChange: (selection: WaveformSelection | null) => void = () => {};
  onTimeChange: (time: number) => void = () => {};

  build() {
    Column() {
      // 时间轴
      Row() {
        Text(this.formatTime(0))
          .fontSize(12)
          .fontColor('#9CA3AF')

        Blank()

        if (this.waveformData) {
          Text(this.formatTime(this.waveformData.duration))
            .fontSize(12)
            .fontColor('#9CA3AF')
        }
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 波形画布
      Stack() {
        Canvas(this.canvasId)
          .width('100%')
          .height(this.canvasHeight)
          .backgroundColor('#F8FAFC')
          .borderRadius(8)
          .onReady(() => {
            this.initCanvas();
          })
          .onAreaChange((oldValue, newValue) => {
            this.canvasWidth = newValue.width as number;
            this.drawWaveform();
          })
          .gesture(
            GestureGroup(GestureMode.Parallel,
              // 点击/选择手势
              TapGesture({ count: 1 })
                .onAction((event) => {
                  this.handleTap(event.fingerList[0].localX);
                }),
              
              // 拖拽选择手势
              PanGesture({ fingers: 1, distance: 5 })
                .onActionStart((event) => {
                  this.handlePanStart(event.fingerList[0].localX);
                })
                .onActionUpdate((event) => {
                  this.handlePanUpdate(event.fingerList[0].localX);
                })
                .onActionEnd(() => {
                  this.handlePanEnd();
                }),
              
              // 缩放手势
              PinchGesture({ fingers: 2, distance: 3 })
                .onActionStart(() => {
                  this.handlePinchStart();
                })
                .onActionUpdate((event) => {
                  this.handlePinchUpdate(event.scale);
                })
                .onActionEnd(() => {
                  this.handlePinchEnd();
                })
            )
          )

        // 播放进度指示器
        if (this.waveformData && this.currentTime > 0) {
          Column()
            .width(2)
            .height('100%')
            .backgroundColor('#EF4444')
            .margin({ left: this.timeToX(this.currentTime) })
        }
      }
      .width('100%')
      .height(this.canvasHeight)

      // 选择信息显示
      if (this.selection) {
        Row() {
          Text(`选择: ${this.formatTime(this.selection.startTime * 1000)} - ${this.formatTime(this.selection.endTime * 1000)}`)
            .fontSize(12)
            .fontColor('#6B7280')

          Blank()

          Text(`时长: ${this.formatTime((this.selection.endTime - this.selection.startTime) * 1000)}`)
            .fontSize(12)
            .fontColor('#6B7280')
        }
        .width('100%')
        .margin({ top: 8 })
      }
    }
    .width('100%')
  }

  // 初始化画布
  private initCanvas() {
    const canvas = this.getUIContext().getCanvasById(this.canvasId);
    if (canvas) {
      this.ctx = canvas.getContext('2d') as CanvasRenderingContext2D;
      this.drawWaveform();
    }
  }

  // 绘制波形
  private drawWaveform() {
    if (!this.ctx || !this.waveformData || this.canvasWidth === 0) return;

    const { peaks, duration } = this.waveformData;
    const ctx = this.ctx;
    const width = this.canvasWidth;
    const height = this.canvasHeight;

    // 清空画布
    ctx.clearRect(0, 0, width, height);

    // 计算可见区域
    const visibleDuration = duration / this.zoomLevel;
    const startTime = this.offsetX / this.zoomLevel;
    const endTime = startTime + visibleDuration;

    const startIndex = Math.floor((startTime / duration) * peaks.length);
    const endIndex = Math.ceil((endTime / duration) * peaks.length);
    const visiblePeaks = peaks.slice(startIndex, endIndex);

    if (visiblePeaks.length === 0) return;

    // 绘制背景波形
    this.drawWaveformPeaks(ctx, visiblePeaks, 0, width, height, '#E5E7EB', 1);

    // 绘制选择区域高亮
    if (this.selection) {
      const selectionStartX = this.timeToX(this.selection.startTime * 1000);
      const selectionEndX = this.timeToX(this.selection.endTime * 1000);
      const selectionWidth = selectionEndX - selectionStartX;

      if (selectionWidth > 0 && selectionStartX < width && selectionEndX > 0) {
        // 绘制选择区域背景
        ctx.fillStyle = 'rgba(99, 102, 241, 0.2)';
        ctx.fillRect(Math.max(0, selectionStartX), 0, Math.min(width, selectionWidth), height);

        // 重新绘制选择区域内的波形（高亮）
        const clipStartX = Math.max(0, selectionStartX);
        const clipEndX = Math.min(width, selectionEndX);
        const clipWidth = clipEndX - clipStartX;

        if (clipWidth > 0) {
          ctx.save();
          ctx.beginPath();
          ctx.rect(clipStartX, 0, clipWidth, height);
          ctx.clip();

          this.drawWaveformPeaks(ctx, visiblePeaks, 0, width, height, '#6366F1', 1);
          ctx.restore();
        }

        // 绘制选择区域边框
        ctx.strokeStyle = '#6366F1';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(selectionStartX, 0);
        ctx.lineTo(selectionStartX, height);
        ctx.moveTo(selectionEndX, 0);
        ctx.lineTo(selectionEndX, height);
        ctx.stroke();
      }
    }
  }

  // 绘制波形峰值
  private drawWaveformPeaks(ctx: CanvasRenderingContext2D, peaks: number[], x: number, width: number, height: number, color: string, alpha: number) {
    const barWidth = width / peaks.length;
    const centerY = height / 2;

    ctx.fillStyle = color;
    ctx.globalAlpha = alpha;

    for (let i = 0; i < peaks.length; i++) {
      const barHeight = Math.abs(peaks[i]) * centerY;
      const barX = x + i * barWidth;
      const barY = centerY - barHeight / 2;

      ctx.fillRect(barX, barY, Math.max(1, barWidth - 1), barHeight);
    }

    ctx.globalAlpha = 1;
  }

  // 时间转换为X坐标
  private timeToX(timeMs: number): number {
    if (!this.waveformData) return 0;
    
    const timeSeconds = timeMs / 1000;
    const relativeTime = (timeSeconds - this.offsetX / this.zoomLevel) / (this.waveformData.duration / this.zoomLevel);
    return relativeTime * this.canvasWidth;
  }

  // X坐标转换为时间
  private xToTime(x: number): number {
    if (!this.waveformData) return 0;
    
    const relativeX = x / this.canvasWidth;
    const timeSeconds = (this.offsetX / this.zoomLevel) + (relativeX * this.waveformData.duration / this.zoomLevel);
    return Math.max(0, Math.min(this.waveformData.duration, timeSeconds));
  }

  // 处理点击
  private handleTap(x: number) {
    const time = this.xToTime(x);
    this.currentTime = time * 1000;
    this.onTimeChange(this.currentTime);
    this.drawWaveform();
  }

  // 处理拖拽开始
  private handlePanStart(x: number) {
    if (this.zoomLevel > 1) {
      this.isDragging = true;
      this.lastPanX = x;
    } else {
      this.isSelecting = true;
      const time = this.xToTime(x);
      this.selection = {
        startTime: time,
        endTime: time,
        startX: x,
        endX: x
      };
    }
  }

  // 处理拖拽更新
  private handlePanUpdate(x: number) {
    if (this.isDragging && this.zoomLevel > 1) {
      // 平移波形
      const deltaX = x - this.lastPanX;
      const deltaTime = (deltaX / this.canvasWidth) * (this.waveformData?.duration || 0) / this.zoomLevel;
      this.offsetX = Math.max(0, Math.min(this.offsetX - deltaTime * this.zoomLevel, 
        (this.waveformData?.duration || 0) * (this.zoomLevel - 1)));
      this.lastPanX = x;
      this.drawWaveform();
    } else if (this.isSelecting && this.selection) {
      // 更新选择区域
      const endTime = this.xToTime(x);
      this.selection = {
        ...this.selection,
        endTime: Math.max(this.selection.startTime, endTime),
        endX: x
      };
      this.drawWaveform();
    }
  }

  // 处理拖拽结束
  private handlePanEnd() {
    this.isDragging = false;
    
    if (this.isSelecting) {
      this.isSelecting = false;
      if (this.selection && Math.abs(this.selection.endTime - this.selection.startTime) < 0.1) {
        // 如果选择区域太小，清除选择
        this.selection = null;
      }
      this.onSelectionChange(this.selection);
      this.drawWaveform();
    }
  }

  // 处理缩放开始
  private handlePinchStart() {
    // 缩放开始时的处理
  }

  // 处理缩放更新
  private handlePinchUpdate(scale: number) {
    const newZoomLevel = Math.max(1, Math.min(10, this.zoomLevel * scale));
    
    if (newZoomLevel !== this.zoomLevel) {
      this.zoomLevel = newZoomLevel;
      
      // 调整偏移以保持中心点
      if (this.waveformData) {
        const maxOffset = this.waveformData.duration * (this.zoomLevel - 1);
        this.offsetX = Math.max(0, Math.min(this.offsetX, maxOffset));
      }
      
      this.drawWaveform();
    }
  }

  // 处理缩放结束
  private handlePinchEnd() {
    // 缩放结束时的处理
  }

  // 格式化时间显示
  private formatTime(milliseconds: number): string {
    const totalSeconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  // 公共方法：设置波形数据
  setWaveformData(data: WaveformData) {
    this.waveformData = data;
    this.currentTime = 0;
    this.selection = null;
    this.zoomLevel = 1;
    this.offsetX = 0;
    this.drawWaveform();
  }

  // 公共方法：更新播放时间
  updateCurrentTime(timeMs: number) {
    this.currentTime = timeMs;
    this.drawWaveform();
  }

  // 公共方法：获取选择区域
  getSelection(): WaveformSelection | null {
    return this.selection;
  }

  // 公共方法：清除选择
  clearSelection() {
    this.selection = null;
    this.onSelectionChange(null);
    this.drawWaveform();
  }

  // 公共方法：重置视图
  resetView() {
    this.zoomLevel = 1;
    this.offsetX = 0;
    this.currentTime = 0;
    this.drawWaveform();
  }
}