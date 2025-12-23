
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

      // 波形画布 - 使用简单UI组件替代Canvas
      Stack() {
        // 使用Row组件模拟波形显示
        Row() {
          if (this.waveformData && this.waveformData.peaks.length > 0) {
            ForEach(this.waveformData.peaks.slice(0, 50), (peak: number, index: number) => {
              Column()
                .width(3)
                .height(Math.max(2, peak * this.canvasHeight))
                .backgroundColor('#E5E7EB')
                .margin({ right: 1 })
                .borderRadius(1)
            })
          } else {
            // 显示默认波形
            ForEach([0.3, 0.7, 0.4, 0.8, 0.5, 0.9, 0.6, 0.2, 0.7, 0.4, 
                    0.8, 0.3, 0.6, 0.9, 0.5, 0.7, 0.4, 0.8, 0.3, 0.6,
                    0.9, 0.5, 0.7, 0.4, 0.8, 0.3, 0.6, 0.9, 0.5, 0.7,
                    0.4, 0.8, 0.3, 0.6, 0.9, 0.5, 0.7, 0.4, 0.8, 0.3,
                    0.6, 0.9, 0.5, 0.7, 0.4, 0.8, 0.3, 0.6, 0.9, 0.5], (peak: number, index: number) => {
              Column()
                .width(3)
                .height(peak * this.canvasHeight * 0.8)
                .backgroundColor('#E5E7EB')
                .margin({ right: 1 })
                .borderRadius(1)
            })
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .alignItems(VerticalAlign.Bottom)

  }
      .width('100%')
      .height(this.canvasHeight)
      .backgroundColor('#F8FAFC')
      .borderRadius(8)
      .padding(8)

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

  // 初始化画布 - 简化版
  private initCanvas() {
    console.info('Waveform component initialized');
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
  }

  // 公共方法：更新播放时间
  updateCurrentTime(timeMs: number) {
    this.currentTime = timeMs;
  }

  // 公共方法：获取选择区域
  getSelection(): WaveformSelection | null {
    return this.selection;
  }

  // 公共方法：清除选择
  clearSelection() {
    this.selection = null;
    this.onSelectionChange(null);
  }

  // 公共方法：重置视图
  resetView() {
    this.zoomLevel = 1;
    this.offsetX = 0;
    this.currentTime = 0;
  }
}