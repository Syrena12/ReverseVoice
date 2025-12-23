import { AudioFileInfo, FileManager } from '../manager/FileManager';
import { AudioManager } from '../manager/AudioManager';
import { common } from '@kit.AbilityKit';

@Component
export struct HistoryPage {
  @State audioFiles: AudioFileInfo[] = [];
  @State isLoading: boolean = true;
  @State selectedFiles: Set<string> = new Set();
  @State showDeleteDialog: boolean = false;
  @State showRenameDialog: boolean = false;
  @State renamingFile: AudioFileInfo | null = null;
  @State newFileName: string = '';
  @State currentPlayingId: string = '';
  @State errorMessage: string = '';
  @State isSelectMode: boolean = false;

  private fileManager: FileManager | null = null;
  private audioManager: AudioManager | null = null;
  private context: common.UIAbilityContext | null = null;

  aboutToAppear() {
    this.initializeManagers();
    this.loadAudioFiles();
  }

  aboutToDisappear() {
    this.cleanup();
  }

  // 初始化管理器
  private async initializeManagers() {
    try {
      this.context = getContext() as common.UIAbilityContext;
      if (this.context) {
        this.fileManager = new FileManager(this.context);
        this.audioManager = new AudioManager(this.context);
      }
    } catch (error) {
      console.error('Failed to initialize managers:', error);
      this.errorMessage = '初始化失败';
    }
  }

  // 加载音频文件列表
  private async loadAudioFiles() {
    try {
      this.isLoading = true;
      this.errorMessage = '';

      if (!this.fileManager) return;

      const files = await this.fileManager.getAllAudioFiles();
      this.audioFiles = files.sort((a, b) => b.createTime - a.createTime);
      
    } catch (error) {
      console.error('Failed to load audio files:', error);
      this.errorMessage = '加载文件失败';
    } finally {
      this.isLoading = false;
    }
  }

  // 播放音频
  private async playAudio(file: AudioFileInfo) {
    try {
      if (!this.audioManager) return;

      if (this.currentPlayingId === file.id) {
        await this.audioManager.stopPlaying();
        this.currentPlayingId = '';
      } else {
        if (this.currentPlayingId) {
          await this.audioManager.stopPlaying();
        }
        
        await this.audioManager.playAudio(file.filePath);
        this.currentPlayingId = file.id;
        
        // 监听播放完成
        setTimeout(() => {
          this.currentPlayingId = '';
        }, file.duration);
      }
    } catch (error) {
      console.error('Failed to play audio:', error);
      this.errorMessage = '播放失败';
    }
  }

  // 删除选中的文件
  private async deleteSelectedFiles() {
    try {
      if (!this.fileManager) return;

      for (const fileId of this.selectedFiles) {
        await this.fileManager.deleteAudioFile(fileId);
      }

      this.selectedFiles.clear();
      this.isSelectMode = false;
      await this.loadAudioFiles();
      this.showDeleteDialog = false;
      
    } catch (error) {
      console.error('Failed to delete files:', error);
      this.errorMessage = '删除失败';
    }
  }

  // 重命名文件
  private async renameFile() {
    try {
      if (!this.fileManager || !this.renamingFile) return;

      await this.fileManager.renameAudioFile(this.renamingFile.id, this.newFileName);
      await this.loadAudioFiles();
      this.showRenameDialog = false;
      this.renamingFile = null;
      this.newFileName = '';
      
    } catch (error) {
      console.error('Failed to rename file:', error);
      this.errorMessage = '重命名失败';
    }
  }

  // 切换选择模式
  private toggleSelectMode() {
    this.isSelectMode = !this.isSelectMode;
    if (!this.isSelectMode) {
      this.selectedFiles.clear();
    }
  }

  // 切换文件选择状态
  private toggleFileSelection(fileId: string) {
    if (this.selectedFiles.has(fileId)) {
      this.selectedFiles.delete(fileId);
    } else {
      this.selectedFiles.add(fileId);
    }
  }

  // 格式化时间显示
  private formatTime(timestamp: number): string {
    const now = new Date();
    const date = new Date(timestamp);
    const diffTime = now.getTime() - timestamp;
    const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays === 0) {
      return `今天 ${date.toTimeString().slice(0, 5)}`;
    } else if (diffDays === 1) {
      return `昨天 ${date.toTimeString().slice(0, 5)}`;
    } else {
      return `${date.getMonth() + 1}月${date.getDate()}日 ${date.toTimeString().slice(0, 5)}`;
    }
  }

  // 获取文件类型显示文本
  private getFileTypeText(type: string): string {
    switch (type) {
      case 'original': return '原始';
      case 'reversed': return '逆转';
      case 'edited': return '剪辑';
      default: return '未知';
    }
  }

  // 清理资源
  private async cleanup() {
    if (this.audioManager) {
      await this.audioManager.release();
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('历史')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2937')

        Blank()

        if (this.isSelectMode) {
          Row() {
            Text(`已选择 ${this.selectedFiles.size}`)
              .fontSize(14)
              .fontColor('#6B7280')
              .margin({ right: 12 })

            Button('取消')
              .width(50)
              .height(32)
              .backgroundColor('#F3F4F6')
              .fontColor('#6B7280')
              .borderRadius(16)
              .fontSize(12)
              .onClick(() => this.toggleSelectMode())
              .margin({ right: 8 })

            if (this.selectedFiles.size > 0) {
              Button('删除')
                .width(50)
                .height(32)
                .backgroundColor('#EF4444')
                .fontColor('#FFFFFF')
                .borderRadius(16)
                .fontSize(12)
                .onClick(() => {
                  this.showDeleteDialog = true;
                })
            }
          }
        } else {
          Button('管理')
            .width(60)
            .height(32)
            .backgroundColor('#F3F4F6')
            .fontColor('#6B7280')
            .borderRadius(16)
            .fontSize(12)
            .onClick(() => this.toggleSelectMode())
        }
      }
      .width('100%')
      .margin({ top: 60, bottom: 20 })
      .padding({ left: 20, right: 20 })

      // 错误消息
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor('#EF4444')
          .margin({ bottom: 16 })
          .padding({ left: 20, right: 20 })
      }

      // 文件列表
      if (this.isLoading) {
        Column() {
          Text('加载中...')
            .fontSize(16)
            .fontColor('#6B7280')
        }
        .width('100%')
        .height('50%')
        .justifyContent(FlexAlign.Center)
      } else if (this.audioFiles.length === 0) {
        Column() {
          Image($r('app.media.ic_empty'))
            .width(64)
            .height(64)
            .fillColor('#D1D5DB')
            .margin({ bottom: 16 })

          Text('暂无录音文件')
            .fontSize(16)
            .fontColor('#6B7280')
            .margin({ bottom: 8 })

          Text('去录制一段音频吧')
            .fontSize(14)
            .fontColor('#9CA3AF')
        }
        .width('100%')
        .height('50%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.audioFiles, (file: AudioFileInfo) => {
            ListItem() {
              this.fileItemBuilder(file)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F9')
    .bindContentCover($$this.showDeleteDialog, this.deleteConfirmDialog())
    .bindContentCover($$this.showRenameDialog, this.renameDialog())
  }

  @Builder
  fileItemBuilder(file: AudioFileInfo) {
    Row() {
      // 选择框（选择模式下显示）
      if (this.isSelectMode) {
        Checkbox({ name: file.id, group: 'fileSelection' })
          .select(this.selectedFiles.has(file.id))
          .onChange((isChecked: boolean) => {
            this.toggleFileSelection(file.id);
          })
          .margin({ right: 12 })
      }

      // 文件图标和类型标识
      Stack() {
        Column() {
          Image($r('app.media.ic_audio'))
            .width(24)
            .height(24)
            .fillColor('#6366F1')
        }
        .width(48)
        .height(48)
        .backgroundColor('#EEF2FF')
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        // 类型标签
        if (file.type !== 'original') {
          Text(file.type === 'reversed' ? 'R' : 'C')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .width(16)
            .height(16)
            .backgroundColor(file.type === 'reversed' ? '#8B5CF6' : '#10B981')
            .borderRadius(8)
            .textAlign(TextAlign.Center)
            .margin({ top: 30, left: 30 })
        }
      }
      .margin({ right: 12 })

      // 文件信息
      Column() {
        Row() {
          Text(file.name)
            .fontSize(16)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)
            .flexShrink(1)

          Blank()

          Text(FileManager.formatFileSize(file.size))
            .fontSize(12)
            .fontColor('#9CA3AF')
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Row() {
          Text(this.formatTime(file.createTime))
            .fontSize(14)
            .fontColor('#6B7280')

          Text(` • ${this.getFileTypeText(file.type)}`)
            .fontSize(14)
            .fontColor('#6B7280')
        }
        .margin({ top: 4 })
        .alignSelf(ItemAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 操作按钮
      if (!this.isSelectMode) {
        Row() {
          Button() {
            Image(this.currentPlayingId === file.id ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
              .width(16)
              .height(16)
              .fillColor('#6366F1')
          }
          .width(32)
          .height(32)
          .backgroundColor('#EEF2FF')
          .borderRadius(16)
          .onClick(() => this.playAudio(file))

          Button() {
            Image($r('app.media.ic_more'))
              .width(16)
              .height(16)
              .fillColor('#6B7280')
          }
          .width(32)
          .height(32)
          .backgroundColor('#F3F4F6')
          .borderRadius(16)
          .margin({ left: 8 })
          .onClick(() => {
            this.renamingFile = file;
            this.newFileName = file.name;
            this.showRenameDialog = true;
          })
        }
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  deleteConfirmDialog() {
    Column() {
      Text('确认删除')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      Text(`确定要删除选中的 ${this.selectedFiles.size} 个文件吗？`)
        .fontSize(14)
        .fontColor('#6B7280')
        .margin({ bottom: 24 })

      Row() {
        Button('取消')
          .width(80)
          .height(40)
          .backgroundColor('#F3F4F6')
          .fontColor('#6B7280')
          .onClick(() => {
            this.showDeleteDialog = false;
          })

        Button('删除')
          .width(80)
          .height(40)
          .backgroundColor('#EF4444')
          .margin({ left: 16 })
          .onClick(() => this.deleteSelectedFiles())
      }
    }
    .width(280)
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  renameDialog() {
    Column() {
      Text('重命名')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 16 })

      TextInput({ placeholder: '请输入新名称', text: this.newFileName })
        .width('100%')
        .height(40)
        .fontSize(16)
        .backgroundColor('#F3F4F6')
        .borderRadius(8)
        .margin({ bottom: 24 })
        .onChange((value: string) => {
          this.newFileName = value;
        })

      Row() {
        Button('取消')
          .width(80)
          .height(40)
          .backgroundColor('#F3F4F6')
          .fontColor('#6B7280')
          .onClick(() => {
            this.showRenameDialog = false;
            this.renamingFile = null;
            this.newFileName = '';
          })

        Button('确定')
          .width(80)
          .height(40)
          .backgroundColor('#6366F1')
          .margin({ left: 16 })
          .enabled(this.newFileName.trim() !== '')
          .onClick(() => this.renameFile())
      }
    }
    .width(280)
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}