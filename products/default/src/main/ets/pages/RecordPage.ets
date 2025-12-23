import { AudioManager } from '../manager/AudioManager';
import { FileManager } from '../manager/FileManager';
import { UserManager } from '../manager/UserManager';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';

@Component
export struct RecordPage {
  @State isRecording: boolean = false;
  @State recordDuration: string = '00:00';
  @State audioLevel: number = 0;
  @State isPlaying: boolean = false;
  @State showActions: boolean = false;
  @State currentRecordingPath: string = '';
  @State errorMessage: string = '';
  @State isDarkMode: boolean = false;

  private audioManager: AudioManager | null = null;
  private fileManager: FileManager | null = null;
  private userManager: UserManager | null = null;
  private context: common.UIAbilityContext | null = null;
  private recordTimer: number = -1;
  private recordStartTime: number = 0;

  aboutToAppear() {
    this.initializeManagers();
    this.loadThemePreference();
  }

  aboutToDisappear() {
    this.cleanup();
  }

  // 加载主题偏好
  private loadThemePreference() {
    this.isDarkMode = AppStorage.get<boolean>('dark_mode') || false;
    
    // 监听主题变化
    AppStorage.setAndLink('dark_mode', this.isDarkMode);
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

  // 检查并请求权限
  private async checkPermissions(): Promise<boolean> {
    try {
      if (!this.context) return false;

      const atManager = abilityAccessCtrl.createAtManager();
      
      // 检查麦克风权限
      const micPermission = await atManager.checkAccessToken(
        this.context.applicationInfo.accessTokenId,
        'ohos.permission.MICROPHONE'
      );

      if (micPermission !== abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        // 请求权限
        const result = await atManager.requestPermissionsFromUser(
          this.context,
          ['ohos.permission.MICROPHONE', 'ohos.permission.READ_MEDIA', 'ohos.permission.WRITE_MEDIA']
        );
        
        return result.authResults.every(result => result === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
      }
      
      return true;
    } catch (error) {
      console.error('Permission check failed:', error);
      return false;
    }
  }

  // 开始录音
  private async startRecording() {
    try {
      if (!this.audioManager) {
        this.errorMessage = 'Audio manager not initialized';
        return;
      }

      // 检查权限
      const hasPermission = await this.checkPermissions();
      if (!hasPermission) {
        this.errorMessage = '请授予麦克风权限';
        return;
      }

      this.currentRecordingPath = await this.audioManager.startRecording();
      this.isRecording = true;
      this.recordStartTime = new Date().getTime();
      this.showActions = false;
      this.errorMessage = '';
      
      // 开始计时
      this.recordTimer = setInterval(() => {
        const elapsed = new Date().getTime() - this.recordStartTime;
        this.recordDuration = this.formatDuration(elapsed);
      }, 100);

    } catch (error) {
      console.error('Failed to start recording:', error);
      this.errorMessage = '录音启动失败';
      this.isRecording = false;
    }
  }

  // 停止录音
  private async stopRecording() {
    try {
      if (!this.audioManager) return;

      const filePath = await this.audioManager.stopRecording();
      this.isRecording = false;
      
      // 停止计时器
      if (this.recordTimer !== -1) {
        clearInterval(this.recordTimer);
        this.recordTimer = -1;
      }

      if (filePath && this.recordDuration !== '00:00') {
        this.showActions = true;
        this.currentRecordingPath = filePath;
      }

    } catch (error) {
      console.error('Failed to stop recording:', error);
      this.errorMessage = '停止录音失败';
    }
  }

  // 播放录音
  private async playRecording() {
    try {
      if (!this.audioManager || !this.currentRecordingPath) return;

      if (this.isPlaying) {
        await this.audioManager.pausePlaying();
        this.isPlaying = false;
      } else {
        await this.audioManager.playAudio(this.currentRecordingPath);
        this.isPlaying = true;
      }
    } catch (error) {
      console.error('Failed to play recording:', error);
      this.errorMessage = '播放失败';
    }
  }

  // 逆转播放
  private async reversePlay() {
    try {
      if (!this.audioManager || !this.currentRecordingPath) return;

      this.errorMessage = '正在生成逆转音频...';
      
      const reversedPath = await this.audioManager.reverseAudio(this.currentRecordingPath);
      await this.audioManager.playAudio(reversedPath);
      
      this.errorMessage = '';
    } catch (error) {
      console.error('Failed to reverse play:', error);
      this.errorMessage = '逆转播放失败';
    }
  }

  // 保存录音
  private async saveRecording() {
    try {
      if (!this.fileManager || !this.currentRecordingPath) return;

      const fileName = `录音_${new Date().toLocaleTimeString()}`;
      await this.fileManager.saveAudioFile(this.currentRecordingPath, fileName, 'original');
      
      this.errorMessage = '录音已保存';
      setTimeout(() => {
        this.resetRecording();
      }, 1000);

    } catch (error) {
      console.error('Failed to save recording:', error);
      this.errorMessage = '保存失败';
    }
  }

  // 重新录音
  private resetRecording() {
    this.currentRecordingPath = '';
    this.recordDuration = '00:00';
    this.showActions = false;
    this.isPlaying = false;
    this.errorMessage = '';
  }

  // 格式化时长显示
  private formatDuration(milliseconds: number): string {
    const totalSeconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  // 清理资源
  private async cleanup() {
    if (this.recordTimer !== -1) {
      clearInterval(this.recordTimer);
    }
    
    if (this.audioManager) {
      await this.audioManager.release();
    }
  }

  build() {
    Column() {
      // 标题
      Text('录音')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .margin({ top: 60, bottom: 40 })

      // 错误消息显示
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor('#EF4444')
          .margin({ bottom: 20 })
      }

      // 录音时长显示
      Text(this.recordDuration)
        .fontSize(48)
        .fontWeight(FontWeight.Medium)
        .fontColor('#374151')
        .margin({ bottom: 20 })

      // 波形显示区域
      Column() {
        Row() {
          ForEach(Array(20).fill(0).map((_: number, i: number) => i), (item: number) => {
            Column()
              .width(3)
              .height(this.isRecording ? Math.random() * 60 + 10 : 20)
              .backgroundColor(this.isRecording ? '#6366F1' : '#E5E7EB')
              .margin({ left: 2, right: 2 })
              .animation({
                duration: 300,
                curve: Curve.Linear,
                iterations: this.isRecording ? -1 : 1
              })
          })
        }
        .justifyContent(FlexAlign.Center)
        .height(80)
        .width('100%')
      }
      .width('90%')
      .height(120)
      .backgroundColor('#F8FAFC')
      .borderRadius(16)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 60 })

      // 录音按钮
      Column() {
        Button() {
          Image(this.isRecording ? $r('app.media.ic_stop') : $r('app.media.ic_mic'))
            .width(32)
            .height(32)
            .fillColor(Color.White)
        }
        .width(80)
        .height(80)
        .borderRadius(40)
        .backgroundColor(this.isRecording ? '#EF4444' : '#6366F1')
        .onClick(async () => {
          if (this.isRecording) {
            await this.stopRecording();
          } else {
            await this.startRecording();
          }
        })

        Text(this.isRecording ? '停止录音' : '开始录音')
          .fontSize(16)
          .fontColor('#6B7280')
          .margin({ top: 12 })
      }
      .margin({ bottom: 40 })

      // 操作按钮区域（录音完成后显示）
      if (this.showActions) {
        Row() {
          Button('保存')
            .width(80)
            .height(40)
            .backgroundColor('#10B981')
            .borderRadius(20)
            .fontSize(14)
            .onClick(async () => {
              await this.saveRecording();
            })

          Button(this.isPlaying ? '暂停' : '播放')
            .width(80)
            .height(40)
            .backgroundColor('#3B82F6')
            .borderRadius(20)
            .fontSize(14)
            .margin({ left: 20 })
            .onClick(async () => {
              await this.playRecording();
            })

          Button('逆转播放')
            .width(100)
            .height(40)
            .backgroundColor('#8B5CF6')
            .borderRadius(20)
            .fontSize(14)
            .margin({ left: 20 })
            .onClick(async () => {
              await this.reversePlay();
            })

          Button('重录')
            .width(80)
            .height(40)
            .backgroundColor('#F59E0B')
            .borderRadius(20)
            .fontSize(14)
            .margin({ left: 20 })
            .onClick(() => {
              this.resetRecording();
            })
        }
        .justifyContent(FlexAlign.Center)
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.isDarkMode ? '#1F2937' : '#FFFFFF')
    .alignItems(HorizontalAlign.Center)
  }
  @Builder
  buildActionButtons() {
    Column() {
      // 第一行按钮
      Row() {
        Button('保存')
          .width(120)
          .height(44)
          .backgroundColor('#10B981')
          .borderRadius(22)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .onClick(async () => {
            await this.saveRecording();
          })

        Button(this.isPlaying ? '暂停' : '播放')
          .width(120)
          .height(44)
          .backgroundColor('#3B82F6')
          .borderRadius(22)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .margin({ left: 20 })
          .onClick(async () => {
            await this.playRecording();
          })
      }
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 16 })

      // 第二行按钮
      Row() {
        Button('逆转播放')
          .width(120)
          .height(44)
          .backgroundColor('#8B5CF6')
          .borderRadius(22)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .onClick(async () => {
            await this.reversePlay();
          })

        Button('重录')
          .width(120)
          .height(44)
          .backgroundColor('#F59E0B')
          .borderRadius(22)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .margin({ left: 20 })
          .onClick(() => {
            this.resetRecording();
          })
      }
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding({ left: 20, right: 20 })
  }
}