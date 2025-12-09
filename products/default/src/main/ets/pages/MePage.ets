import { FileManager } from '../manager/FileManager';
import { common } from '@kit.AbilityKit';

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
    name: '徐磊',
    phone: '189****3459'
  };
  @State totalFileSize: string = '0 B';
  @State fileCount: number = 0;
  @State showUserDialog: boolean = false;
  @State newUserName: string = '';

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
        const storedUserInfo = JSON.parse(userInfoPreference);
        this.userInfo = { ...this.userInfo, ...storedUserInfo };
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
            .borderRadius(30)
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
      .padding({ horizontal: 20, vertical: 20 })
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .margin({ horizontal: 20, bottom: 24 })
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
          .margin({ horizontal: 20 })

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
      .padding({ horizontal: 20, vertical: 16 })
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .margin({ horizontal: 20, bottom: 24 })
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
      .margin({ horizontal: 20, bottom: 20 })

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
      .padding({ horizontal: 20 })

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
    .padding({ horizontal: 20, vertical: 8 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.handleSettingClick(item))
    .borderColor('#F3F4F6')
    .borderWidth({ bottom: index < this.settings.length - 1 ? 1 : 0 })
  }

  @Builder
  userEditDialog() {
    Column() {
      Text('编辑用户信息')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
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
          .onClick(() => {
            this.showUserDialog = false;
            this.newUserName = '';
          })

        Button('确定')
          .width(80)
          .height(40)
          .backgroundColor('#6366F1')
          .margin({ left: 16 })
          .enabled(this.newUserName.trim() !== '' && this.newUserName.trim() !== this.userInfo.name)
          .onClick(() => this.updateUserInfo())
      }
    }
    .width(300)
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
  }
}