import { FileManager } from '../manager/FileManager';
import { common } from '@kit.AbilityKit';

enum AudioFormat {
  WAV = 'WAV',
  MP3 = 'MP3',  
  AAC = 'AAC'
}

interface AudioFormatInfo {
  id: string;
  name: string;
  extension: string;
  quality: string;
}

enum WaveformStyle {
  LINE = 'LINE',
  BAR = 'BAR',
  CURVE = 'CURVE'
}

interface WaveformStyleInfo {
  id: string;
  name: string;
  colors: string[];
}

interface SettingItem {
  title: string;
  subtitle?: string;
  hasArrow: boolean;
  hasSwitch?: boolean;
  isEnabled?: boolean;
  type?: string;
}

interface UserInfo {
  name: string;
  phone: string;
  avatar?: string;
}

@Component
export struct MePage {
  @State isDarkMode: boolean = false;
  @State userInfo: UserInfo = {
    name: 'Syrena',
    phone: '133****1212'
  };
  @State totalFileSize: string = '0 B';
  @State fileCount: number = 0;
  @State showUserDialog: boolean = false;
  @State newUserName: string = '';
  
  // Login related states
  @State loginDialog: boolean = false;
  @State loginPhone: string = '';
  @State loginCode: string = '';
  @State countdown: number = 0;
  @State isSendingCode: boolean = false;
  
  // Audio format states
  @State audioFormatDialog: boolean = false;
  @State currentAudioFormat: AudioFormat = AudioFormat.WAV;
  @State audioFormats: AudioFormatInfo[] = [
    { id: 'WAV', name: 'WAV', extension: '.wav', quality: 'high' },
    { id: 'MP3', name: 'MP3', extension: '.mp3', quality: 'medium' },
    { id: 'AAC', name: 'AAC', extension: '.aac', quality: 'high' }
  ];
  
  // Waveform style states  
  @State showWaveformDialog: boolean = false;
  @State currentWaveformStyle: WaveformStyle = WaveformStyle.LINE;
  @State waveformStyles: WaveformStyleInfo[] = [
    { id: 'LINE', name: '线条', colors: ['#3B82F6'] },
    { id: 'BAR', name: '柱状图', colors: ['#10B981'] },
    { id: 'CURVE', name: '曲线', colors: ['#F59E0B'] }
  ];

  private fileManager: FileManager | null = null;
  private context: common.UIAbilityContext | null = null;

  @State settings: SettingItem[] = [
    { title: '账号管理', hasArrow: true, type: 'user' },
    { title: '主题模式', subtitle: '跟随系统', hasArrow: true, hasSwitch: true, isEnabled: false, type: 'theme' },
    { title: '控制中心', hasArrow: true, type: 'control' },
    { title: '共享反声', hasArrow: true, type: 'share' }
  ];

  aboutToAppear() {
    this.initializeData();
    this.loadUserPreferences();
    this.loadStorageInfo();
  }

  // 初始化数据
  private async initializeData() {
    try {
      this.context = getContext() as common.UIAbilityContext;
      if (this.context) {
        this.fileManager = new FileManager(this.context);
      }
    } catch (error) {
      console.error('Failed to initialize:', error);
    }
  }

  // 加载用户偏好设置
  private loadUserPreferences() {
    try {
      // 从本地存储加载用户设置
      const darkModePreference = AppStorage.get<boolean>('dark_mode') || false;
      const userInfoPreference = AppStorage.get<string>('user_info');
      
      this.isDarkMode = darkModePreference;
      
      if (userInfoPreference) {
        const storedUserInfo = JSON.parse(userInfoPreference) as UserInfo;
        this.userInfo = storedUserInfo;
      }

      // 更新设置列表中的主题模式状态
      this.updateThemeSetting();
    } catch (error) {
      console.error('Failed to load user preferences:', error);
    }
  }

  // 更新主题设置状态
  private updateThemeSetting() {
    const themeIndex = this.settings.findIndex(item => item.type === 'theme');
    if (themeIndex !== -1) {
      this.settings[themeIndex].isEnabled = this.isDarkMode;
      this.settings[themeIndex].subtitle = this.isDarkMode ? '暗色' : '亮色';
    }
  }

  // 加载存储信息
  private async loadStorageInfo() {
    try {
      if (!this.fileManager) return;

      const allFiles = await this.fileManager.getAllAudioFiles();
      this.fileCount = allFiles.length;
      
      const totalSize = await this.fileManager.getTotalAudioSize();
      this.totalFileSize = FileManager.formatFileSize(totalSize);
    } catch (error) {
      console.error('Failed to load storage info:', error);
    }
  }

  // 切换主题模式
  private toggleThemeMode(enabled: boolean) {
    this.isDarkMode = enabled;
    this.updateThemeSetting();
    
    // 保存到本地存储
    AppStorage.setOrCreate('dark_mode', enabled);
    
    // 这里可以实现实际的主题切换逻辑
    console.info(`主题模式切换为: ${enabled ? '暗色' : '亮色'}`);
  }

  // 清除缓存
  private async clearCache() {
    try {
      if (!this.fileManager) return;

      // 清理临时文件
      await this.fileManager.cleanupTempFiles();
      
      // 重新加载存储信息
      await this.loadStorageInfo();
      
      console.info('缓存清理完成');
    } catch (error) {
      console.error('Failed to clear cache:', error);
    }
  }

  // 更新用户信息
  private updateUserInfo() {
    if (this.newUserName.trim()) {
      this.userInfo.name = this.newUserName.trim();
      
      // 保存到本地存储
      AppStorage.setOrCreate('user_info', JSON.stringify(this.userInfo));
      
      this.showUserDialog = false;
      this.newUserName = '';
    }
  }

  // 处理设置项点击
  private handleSettingClick(item: SettingItem) {
    switch (item.type) {
      case 'user':
        this.newUserName = this.userInfo.name;
        this.showUserDialog = true;
        break;
      case 'theme':
        // 主题切换通过Switch控制，这里不需要处理
        break;
      case 'control':
        console.info('打开控制中心');
        break;
      case 'share':
        console.info('打开分享功能');
        break;
      default:
        console.info(`点击了设置项: ${item.title}`);
    }
  }

  build() {
    Column() {
      // 标题
      Text('我的')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1F2937')
        .margin({ top: 60, bottom: 40 })
        .alignSelf(ItemAlign.Start)
        .margin({ left: 20 })

      // 用户信息卡片
      Row() {
        // 用户头像
        Stack() {
          Image(this.userInfo.avatar || $r('app.media.avatar'))
            .width(60)
            .height(60)
            .borderRadius('30vp')
            .backgroundColor('#E5E7EB')

          // 头像边框
          Circle({ width: 60, height: 60 })
            .fill(Color.Transparent)
            .stroke('#E5E7EB')
            .strokeWidth(1)
        }
        .margin({ right: 16 })

        // 用户信息
        Column() {
          Text(this.userInfo.name)
            .fontSize(20)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)

          Text(this.userInfo.phone)
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ top: 4 })
            .alignSelf(ItemAlign.Start)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 编辑按钮
        Button() {
          Image($r('app.media.ic_edit'))
            .width(20)
            .height(20)
            .fillColor('#6B7280')
        }
        .width(36)
        .height(36)
        .backgroundColor('#F3F4F6')
        .borderRadius(18)
        .onClick(() => this.handleSettingClick({ title: '账号管理', hasArrow: true, type: 'user' }))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 20 })
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .margin({ left: 20, right: 20, bottom: 24 })
      .alignItems(VerticalAlign.Center)

      // 存储信息卡片
      Row() {
        Column() {
          Text('文件总数')
            .fontSize(12)
            .fontColor('#9CA3AF')
            .margin({ bottom: 4 })

          Text(this.fileCount.toString())
            .fontSize(18)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)
        }
        .alignItems(HorizontalAlign.Center)

        Column()
          .width(1)
          .height(40)
          .backgroundColor('#E5E7EB')
          .margin({ left: 20, right: 20 })

        Column() {
          Text('占用空间')
            .fontSize(12)
            .fontColor('#9CA3AF')
            .margin({ bottom: 4 })

          Text(this.totalFileSize)
            .fontSize(18)
            .fontColor('#1F2937')
            .fontWeight(FontWeight.Medium)
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .margin({ left: 20, right: 20, bottom: 24 })
      .justifyContent(FlexAlign.Center)

      // 设置选项列表
      Column() {
        ForEach(this.settings, (item: SettingItem, index: number) => {
          this.settingItemBuilder(item, index)
        })
      }
      .width('100%')
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .margin({ left: 20, right: 20, bottom: 20 })

      // 其他功能按钮
      Column() {
        Button('清除缓存')
          .width('100%')
          .height(50)
          .backgroundColor('#FFFFFF')
          .fontColor('#6B7280')
          .fontSize(16)
          .borderRadius(12)
          .margin({ bottom: 12 })
          .onClick(() => this.clearCache())

        Button('隐私政策')
          .width('100%')
          .height(50)
          .backgroundColor('#FFFFFF')
          .fontColor('#6B7280')
          .fontSize(16)
          .borderRadius(12)
          .margin({ bottom: 12 })
          .onClick(() => {
            console.info('打开隐私政策');
          })

        Button('关于我们')
          .width('100%')
          .height(50)
          .backgroundColor('#FFFFFF')
          .fontColor('#6B7280')
          .fontSize(16)
          .borderRadius(12)
          .onClick(() => {
            console.info('打开关于我们');
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F9')
    .bindContentCover($$this.showUserDialog, this.userEditDialog())
  }

  @Builder
  settingItemBuilder(item: SettingItem, index: number) {
    Row() {
      Column() {
        Text(item.title)
          .fontSize(16)
          .fontColor('#1F2937')
          .alignSelf(ItemAlign.Start)

        if (item.subtitle) {
          Text(item.subtitle)
            .fontSize(14)
            .fontColor('#6B7280')
            .margin({ top: 4 })
            .alignSelf(ItemAlign.Start)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (item.hasSwitch) {
        Toggle({ type: ToggleType.Switch, isOn: item.isEnabled || false })
          .selectedColor('#6366F1')
          .onChange((isOn: boolean) => {
            if (item.type === 'theme') {
              this.toggleThemeMode(isOn);
            }
          })
          .margin({ right: 8 })
      }

      if (item.hasArrow) {
        Image($r('app.media.ic_arrow_right'))
          .width(16)
          .height(16)
          .fillColor('#9CA3AF')
      }
    }
    .width('100%')
    .height(item.subtitle ? 60 : 50)
    .padding({ left: 20, right: 20, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.handleSettingClick(item))
    .borderColor('#F3F4F6')
    .borderWidth({ bottom: index < this.settings.length - 1 ? 1 : 0 })
  }

  @Builder
  buildLoginDialog() {
    Column() {
      Text('登录 / 注册')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2937')
        .margin({ bottom: 32 })

      // 手机号输入
      Column() {
        Text('手机号')
          .fontSize(14)
          .fontColor('#374151')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        TextInput({ placeholder: '请输入手机号', text: this.loginPhone })
          .width('100%')
          .height(44)
          .fontSize(16)
          .backgroundColor('#F9FAFB')
          .borderRadius(8)
          .border({ width: 1, color: '#E5E7EB' })
          .type(InputType.PhoneNumber)
          .onChange((value: string) => {
            this.loginPhone = value;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 20 })

      // 验证码输入
      Column() {
        Text('验证码')
          .fontSize(14)
          .fontColor('#374151')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        Row() {
          TextInput({ placeholder: '请输入验证码', text: this.loginCode })
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .backgroundColor('#F9FAFB')
            .borderRadius(8)
            .border({ width: 1, color: '#E5E7EB' })
            .type(InputType.Number)
            .onChange((value: string) => {
              this.loginCode = value;
            })

          Button(this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
            .width(100)
            .height(44)
            .backgroundColor(this.countdown > 0 || this.isSendingCode ? '#F3F4F6' : '#6366F1')
            .fontColor(this.countdown > 0 || this.isSendingCode ? '#9CA3AF' : '#FFFFFF')
            .fontSize(12)
            .borderRadius(8)
            .margin({ left: 12 })
            .enabled(this.countdown === 0 && !this.isSendingCode)
            .onClick(() => this.sendVerificationCode())
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 32 })

      // 操作按钮
      Row() {
        Button('取消')
          .width(80)
          .height(44)
          .backgroundColor('#F3F4F6')
          .fontColor('#6B7280')
          .borderRadius(8)
          .onClick(() => {
            this.loginDialog = false;
            this.resetLoginForm();
          })

        Button('登录')
          .width(120)
          .height(44)
          .backgroundColor('#6366F1')
          .borderRadius(8)
          .margin({ left: 16 })
          .enabled(this.loginPhone.trim() !== '' && this.loginCode.trim() !== '')
          .onClick(() => this.handleLogin())
      }
      .justifyContent(FlexAlign.End)
    }
    .width(320)
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  userEditDialog() {
    Column() {
      Text('编辑用户信息')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2937')
        .margin({ bottom: 20 })

      Column() {
        Text('用户名')
          .fontSize(14)
          .fontColor('#374151')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        TextInput({ placeholder: '请输入用户名', text: this.newUserName })
          .width('100%')
          .height(44)
          .fontSize(16)
          .backgroundColor('#F9FAFB')
          .borderRadius(8)
          .border({ width: 1, color: '#E5E7EB' })
          .onChange((value: string) => {
            this.newUserName = value;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 24 })

      Row() {
        Button('取消')
          .width(80)
          .height(40)
          .backgroundColor('#F3F4F6')
          .fontColor('#6B7280')
          .borderRadius(8)
          .onClick(() => {
            this.showUserDialog = false;
            this.newUserName = '';
          })

        Button('确定')
          .width(80)
          .height(40)
          .backgroundColor('#6366F1')
          .borderRadius(8)
          .margin({ left: 16 })
          .enabled(this.newUserName.trim() !== '' && this.newUserName.trim() !== this.userInfo?.name)
          .onClick(() => this.updateUserInfo())
      }
    }
    .width(300)
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  waveformStyleDialog() {
    Column() {
      Text('选择波形样式')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2937')
        .margin({ bottom: 24 })

      Column() {
        ForEach(this.waveformStyles, (style: WaveformStyleInfo, index: number) => {
          Row() {
            // 波形样式预览
            Row() {
              ForEach([1, 2, 3, 4, 5], (item: number) => {
                Column()
                  .width(4)
                  .height(Math.random() * 20 + 10)
                  .backgroundColor(style.colors[0])
                  .borderRadius('2vp')
                  .margin({ right: 2 })
              })
            }
            .width(60)
            .height(30)
            .padding(8)
            .backgroundColor('#F9FAFB')
            .borderRadius(8)
            .justifyContent(FlexAlign.Center)
            .alignItems(VerticalAlign.Center)
            .margin({ right: 12 })

            Text(style.name)
              .fontSize(16)
              .fontColor('#1F2937')
              .layoutWeight(1)

            if (this.currentWaveformStyle === style.id) {
              Image($r('app.media.ic_check'))
                .width(16)
                .height(16)
                .fillColor('#6366F1')
            }
          }
          .width('100%')
          .height(50)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.currentWaveformStyle === style.id ? '#F0F9FF' : Color.Transparent)
          .borderRadius(8)
          .alignItems(VerticalAlign.Center)
          .onClick(() => this.setWaveformStyle(style))

          if (index < this.waveformStyles.length - 1) {
            Divider()
              .color('#F3F4F6')
              .strokeWidth(1)
              .margin({ left: 16, right: 16 })
          }
        })
      }
      .width('100%')
      .height(300)

      Row() {
        Button('取消')
          .width(80)
          .height(40)
          .backgroundColor('#F3F4F6')
          .fontColor('#6B7280')
          .borderRadius(8)
          .onClick(() => {
            this.showWaveformDialog = false;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ top: 24 })
    }
    .width(320)
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  @Builder
  buildAudioFormatDialog() {
    Column() {
      Text('选择录音格式')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2937')
        .margin({ bottom: 24 })

      Column() {
        ForEach(this.audioFormats, (format: AudioFormatInfo, index: number) => {
          Row() {
            Column() {
              Text(format.name)
                .fontSize(16)
                .fontColor('#1F2937')
                .alignSelf(ItemAlign.Start)

              Text(`${format.extension.toUpperCase()} · ${this.getQualityText(format.quality)}`)
                .fontSize(12)
                .fontColor('#6B7280')
                .alignSelf(ItemAlign.Start)
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            if (this.currentAudioFormat === format.id) {
              Image($r('app.media.ic_check'))
                .width(16)
                .height(16)
                .fillColor('#6366F1')
            }
          }
          .width('100%')
          .height(60)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.currentAudioFormat === format.id ? '#F0F9FF' : Color.Transparent)
          .borderRadius(8)
          .alignItems(VerticalAlign.Center)
          .onClick(() => this.setAudioFormat(format))

          if (index < this.audioFormats.length - 1) {
            Divider()
              .color('#F3F4F6')
              .strokeWidth(1)
              .margin({ left: 16, right: 16 })
          }
        })
      }
      .width('100%')
      .height(300)

      Row() {
        Button('取消')
          .width(80)
          .height(40)
          .backgroundColor('#F3F4F6')
          .fontColor('#6B7280')
          .borderRadius(8)
          .onClick(() => {
            this.audioFormatDialog = false;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .margin({ top: 24 })
    }
    .width(320)
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }

  // 获取质量描述文本
  private getQualityText(quality: string): string {
    switch (quality) {
      case 'high':
        return '高质量';
      case 'medium':
        return '标准质量';
      case 'low':
        return '压缩质量';
      default:
        return '标准质量';
    }
  }

  // 发送验证码
  private sendVerificationCode() {
    if (!this.loginPhone || this.isSendingCode) return;
    
    this.isSendingCode = true;
    this.countdown = 60;
    
    // 模拟发送验证码
    const timer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        clearInterval(timer);
        this.isSendingCode = false;
      }
    }, 1000);
    
    console.info('发送验证码到:', this.loginPhone);
  }

  // 重置登录表单
  private resetLoginForm() {
    this.loginPhone = '';
    this.loginCode = '';
    this.countdown = 0;
    this.isSendingCode = false;
  }

  // 处理登录
  private handleLogin() {
    if (!this.loginPhone || !this.loginCode) {
      console.warn('手机号或验证码不能为空');
      return;
    }
    
    // 模拟登录逻辑
    console.info('登录:', { phone: this.loginPhone, code: this.loginCode });
    this.loginDialog = false;
    this.resetLoginForm();
  }

  // 设置波形样式
  private setWaveformStyle(style: WaveformStyleInfo) {
    this.currentWaveformStyle = style.id as WaveformStyle;
    this.showWaveformDialog = false;
    console.info('设置波形样式为:', style.name);
  }

  // 设置音频格式  
  private setAudioFormat(format: AudioFormatInfo) {
    this.currentAudioFormat = format.id as AudioFormat;
    this.audioFormatDialog = false;
    console.info('设置音频格式为:', format.name);
  }
}