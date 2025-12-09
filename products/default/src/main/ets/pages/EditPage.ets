import { WaveformComponent, WaveformSelection } from '../components/WaveformComponent';
import { AudioAnalyzer, AudioAnalysisResult } from '../utils/AudioAnalyzer';
import { AudioManager } from '../manager/AudioManager';
import { FileManager, AudioFileInfo } from '../manager/FileManager';
import { common } from '@kit.AbilityKit';

@Component
export struct EditPage {
  @State selectedFile: AudioFileInfo | null = null;
  @State currentTime: number = 0;
  @State totalTime: number = 0;
  @State isPlaying: boolean = false;
  @State selection: WaveformSelection | null = null;
  @State audioAnalysis: AudioAnalysisResult | null = null;
  @State isLoading: boolean = false;
  @State errorMessage: string = '';
  @State recentFiles: AudioFileInfo[] = [];
  @State showFileSelector: boolean = false;

  private audioManager: AudioManager | null = null;
  private fileManager: FileManager | null = null;
  private context: common.UIAbilityContext | null = null;
  private waveformComponent: WaveformComponent | null = null;
  private playTimer: number = -1;

  aboutToAppear() {
    this.initializeManagers();
    this.loadRecentFiles();
  }

  aboutToDisappear() {
    this.cleanup();
  }

  // 初始化管理器
  private async initializeManagers() {
    try {
      this.context = getContext() as common.UIAbilityContext;
      if (this.context) {
        this.audioManager = new AudioManager(this.context);
        this.fileManager = new FileManager(this.context);
      }
    } catch (error) {
      console.error('Failed to initialize managers:', error);
      this.errorMessage = '初始化失败';
    }
  }

  // 加载最近的文件
  private async loadRecentFiles() {
    try {
      if (!this.fileManager) return;
      this.recentFiles = await this.fileManager.getRecentRecordings(10);
    } catch (error) {
      console.error('Failed to load recent files:', error);
    }
  }

  // 选择音频文件
  private async selectAudioFile(file: AudioFileInfo) {
    try {
      this.isLoading = true;
      this.errorMessage = '';
      this.selectedFile = file;

      // 分析音频文件
      this.audioAnalysis = await AudioAnalyzer.analyzeAudioFile(file.filePath);
      this.totalTime = this.audioAnalysis.duration * 1000; // 转换为毫秒

      // 设置波形数据
      if (this.waveformComponent) {
        this.waveformComponent.setWaveformData(this.audioAnalysis.waveformData);
      }

      this.showFileSelector = false;

    } catch (error) {
      console.error('Failed to analyze audio file:', error);
      this.errorMessage = '文件分析失败';
    } finally {
      this.isLoading = false;
    }
  }

  // 播放/暂停音频
  private async togglePlayback() {
    try {
      if (!this.audioManager || !this.selectedFile) return;

      if (this.isPlaying) {
        await this.audioManager.pausePlaying();
        this.isPlaying = false;
        this.stopPlaybackTimer();
      } else {
        const startTime = this.selection ? this.selection.startTime * 1000 : this.currentTime;
        await this.audioManager.playAudio(this.selectedFile.filePath);
        this.isPlaying = true;
        this.currentTime = startTime;
        this.startPlaybackTimer();
      }
    } catch (error) {
      console.error('Failed to toggle playback:', error);
      this.errorMessage = '播放失败';
    }
  }

  // 开始播放计时器
  private startPlaybackTimer() {
    this.playTimer = setInterval(() => {
      this.currentTime += 100;
      
      // 更新波形组件的当前时间
      if (this.waveformComponent) {
        this.waveformComponent.updateCurrentTime(this.currentTime);
      }

      // 如果有选择区域，检查是否播放结束
      if (this.selection && this.currentTime >= this.selection.endTime * 1000) {
        this.stopPlayback();
      } else if (this.currentTime >= this.totalTime) {
        this.stopPlayback();
      }
    }, 100);
  }

  // 停止播放计时器
  private stopPlaybackTimer() {
    if (this.playTimer !== -1) {
      clearInterval(this.playTimer);
      this.playTimer = -1;
    }
  }

  // 停止播放
  private async stopPlayback() {
    try {
      if (this.audioManager) {
        await this.audioManager.stopPlaying();
      }
      this.isPlaying = false;
      this.stopPlaybackTimer();
    } catch (error) {
      console.error('Failed to stop playback:', error);
    }
  }

  // 逆转预览
  private async reversePreview() {
    try {
      if (!this.audioManager || !this.selectedFile) return;

      this.errorMessage = '正在生成逆转预览...';
      
      let audioToReverse = this.selectedFile.filePath;
      
      // 如果有选择区域，先截取片段
      if (this.selection) {
        audioToReverse = await this.extractSegment();
      }

      const reversedPath = await this.audioManager.reverseAudio(audioToReverse);
      await this.audioManager.playAudio(reversedPath);
      
      this.errorMessage = '';
    } catch (error) {
      console.error('Failed to reverse preview:', error);
      this.errorMessage = '逆转预览失败';
    }
  }

  // 提取音频片段
  private async extractSegment(): Promise<string> {
    if (!this.audioManager || !this.selectedFile || !this.selection) {
      throw new Error('Invalid state for segment extraction');
    }

    // 这里应该实现音频片段提取逻辑
    // 简化实现：直接返回原文件路径
    return this.selectedFile.filePath;
  }

  // 保存片段
  private async saveSegment() {
    try {
      if (!this.fileManager || !this.selectedFile || !this.selection) return;

      this.errorMessage = '正在保存片段...';
      
      // 生成片段文件名
      const startTime = Math.floor(this.selection.startTime);
      const endTime = Math.floor(this.selection.endTime);
      const segmentName = `${this.selectedFile.name}_片段_${startTime}s-${endTime}s`;

      // 提取并保存片段
      const segmentPath = await this.extractSegment();
      await this.fileManager.saveAudioFile(segmentPath, segmentName, 'edited');
      
      this.errorMessage = '片段已保存';
      setTimeout(() => {
        this.errorMessage = '';
      }, 2000);

    } catch (error) {
      console.error('Failed to save segment:', error);
      this.errorMessage = '保存片段失败';
    }
  }

  // 处理波形选择变化
  private onSelectionChange = (selection: WaveformSelection | null) => {
    this.selection = selection;
  };

  // 处理时间变化
  private onTimeChange = (time: number) => {
    this.currentTime = time;
    
    // 如果正在播放，更新播放位置
    if (this.isPlaying && this.audioManager) {
      // 这里可以实现精确的播放位置控制
    }
  };

  // 清理资源
  private async cleanup() {
    this.stopPlaybackTimer();
    if (this.audioManager) {
      await this.audioManager.release();
    }
  }

  // 格式化时间显示
  private formatTime(milliseconds: number): string {
    const totalSeconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      // 标题
      Text('编辑')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .margin({ top: 60, bottom: 20 })

      // 错误消息
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor(this.errorMessage.includes('失败') ? '#EF4444' : '#10B981')
          .margin({ bottom: 16 })
      }

      // 文件选择区域
      if (!this.selectedFile) {
        Column() {
          Image($r('app.media.ic_folder'))
            .width(48)
            .height(48)
            .fillColor('#9CA3AF')
            .margin({ bottom: 16 })

          Text('选择音频文件')
            .fontSize(16)
            .fontColor('#6B7280')
            .margin({ bottom: 8 })

          Text('从录音文件或历史记录中选择')
            .fontSize(12)
            .fontColor('#9CA3AF')

          Button('选择文件')
            .width(120)
            .height(40)
            .backgroundColor('#6366F1')
            .borderRadius(20)
            .fontSize(14)
            .margin({ top: 20 })
            .onClick(() => {
              this.showFileSelector = true;
            })
        }
        .width('90%')
        .height(200)
        .backgroundColor('#F8FAFC')
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .border({ width: 2, color: '#E5E7EB', style: BorderStyle.Dashed })
        .margin({ bottom: 20 })
      } else {
        // 音频编辑界面
        Column() {
          // 文件信息
          Row() {
            Text(this.selectedFile.name)
              .fontSize(16)
              .fontColor('#374151')
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)

            Button('更换文件')
              .width(80)
              .height(32)
              .backgroundColor('#F3F4F6')
              .fontColor('#6B7280')
              .borderRadius(16)
              .fontSize(12)
              .onClick(() => {
                this.selectedFile = null;
                this.audioAnalysis = null;
                this.selection = null;
                this.currentTime = 0;
                this.stopPlayback();
              })
          }
          .width('100%')
          .margin({ bottom: 20 })

          // 波形可视化区域
          if (this.isLoading) {
            Column() {
              Text('分析音频文件中...')
                .fontSize(14)
                .fontColor('#6B7280')
            }
            .width('100%')
            .height(160)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#F8FAFC')
            .borderRadius(12)
            .margin({ bottom: 20 })
          } else if (this.audioAnalysis) {
            Column() {
              WaveformComponent({
                onSelectionChange: this.onSelectionChange,
                onTimeChange: this.onTimeChange
              })
            }
            .width('100%')
            .padding({ horizontal: 16, vertical: 16 })
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 20 })
          }

          // 控制按钮
          Row() {
            Button() {
              Image(this.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
                .width(20)
                .height(20)
                .fillColor(Color.White)
            }
            .width(50)
            .height(50)
            .borderRadius(25)
            .backgroundColor('#6366F1')
            .onClick(() => this.togglePlayback())

            if (this.selection) {
              Button('逆转预览')
                .width(100)
                .height(40)
                .backgroundColor('#8B5CF6')
                .borderRadius(20)
                .fontSize(14)
                .margin({ left: 20 })
                .onClick(() => this.reversePreview())

              Button('保存片段')
                .width(100)
                .height(40)
                .backgroundColor('#10B981')
                .borderRadius(20)
                .fontSize(14)
                .margin({ left: 20 })
                .onClick(() => this.saveSegment())
            } else {
              Button('全部逆转')
                .width(100)
                .height(40)
                .backgroundColor('#8B5CF6')
                .borderRadius(20)
                .fontSize(14)
                .margin({ left: 20 })
                .onClick(() => this.reversePreview())
            }
          }
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 20 })

        }
        .width('90%')
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F9')
    .alignItems(HorizontalAlign.Center)
    .padding({ horizontal: 20 })
    .bindContentCover($$this.showFileSelector, this.fileSelectorDialog())
  }

  @Builder
  fileSelectorDialog() {
    Column() {
      Text('选择音频文件')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 20 })

      if (this.recentFiles.length > 0) {
        List({ space: 12 }) {
          ForEach(this.recentFiles, (file: AudioFileInfo) => {
            ListItem() {
              Row() {
                Image($r('app.media.ic_audio'))
                  .width(24)
                  .height(24)
                  .fillColor('#6366F1')
                  .margin({ right: 12 })

                Column() {
                  Text(file.name)
                    .fontSize(14)
                    .fontColor('#1F2937')
                    .alignSelf(ItemAlign.Start)

                  Text(FileManager.formatFileSize(file.size))
                    .fontSize(12)
                    .fontColor('#6B7280')
                    .margin({ top: 2 })
                    .alignSelf(ItemAlign.Start)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ horizontal: 16, vertical: 12 })
              .backgroundColor('#F8FAFC')
              .borderRadius(8)
              .onClick(() => this.selectAudioFile(file))
            }
          })
        }
        .width('100%')
        .height(300)
      } else {
        Text('暂无音频文件')
          .fontSize(14)
          .fontColor('#9CA3AF')
          .margin({ vertical: 40 })
      }

      Button('取消')
        .width(100)
        .height(40)
        .backgroundColor('#F3F4F6')
        .fontColor('#6B7280')
        .margin({ top: 20 })
        .onClick(() => {
          this.showFileSelector = false;
        })
    }
    .width(320)
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}