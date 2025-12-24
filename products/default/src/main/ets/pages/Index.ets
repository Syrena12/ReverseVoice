import { RecordPage } from '../pages/RecordPage';
import { EditPage } from '../pages/EditPage';
import { HistoryPage } from '../pages/HistoryPage';
import { MePage } from '../pages/MePage';

@Entry
@Component
struct Index {
  @State currentTabIndex: number = 0;
  @State isDarkMode: boolean = false;

  aboutToAppear() {
    this.loadThemePreference();
  }

  // 加载主题偏好
  private loadThemePreference() {
    this.isDarkMode = AppStorage.get<boolean>('dark_mode') || false;
    
    // 监听主题变化
    AppStorage.setAndLink('dark_mode', this.isDarkMode);
  }

  build() {
    Column() {
      // Tab内容区域
      Stack() {
        if (this.currentTabIndex === 0) {
          RecordPage()
        } else if (this.currentTabIndex === 1) {
          EditPage()
        } else if (this.currentTabIndex === 2) {
          HistoryPage()
        } else {
          MePage()
        }
      }
      .layoutWeight(1)

      // Tab导航栏
      Row() {
        this.tabBuilder(0, '录音', $r('app.media.ic_record'), $r('app.media.ic_record_selected'))
        this.tabBuilder(1, '编辑', $r('app.media.ic_edit_tab'), $r('app.media.ic_edit_tab_selected'))
        this.tabBuilder(2, '历史', $r('app.media.ic_history'), $r('app.media.ic_history_selected'))
        this.tabBuilder(3, '我的', $r('app.media.ic_profile'), $r('app.media.ic_profile_selected'))
      }
      .width('100%')
      .height(80)
      .backgroundColor('#FFFFFF')
      .borderColor('#E5E7EB')
      .borderWidth({ top: 1 })
      .padding({ top: 8, bottom: 8 })
      .justifyContent(FlexAlign.SpaceAround)
    }
    .height('100%')
    .width('100%')
    .backgroundColor(this.isDarkMode ? '#1F2937' : '#F5F5F9')
  }

  @Builder
  tabBuilder(index: number, name: string, icon: Resource, selectedIcon: Resource) {
    Column() {
      Image(this.currentTabIndex === index ? selectedIcon : icon)
        .width(24)
        .height(24)
        .fillColor(this.currentTabIndex === index ? '#6366F1' : (this.isDarkMode ? '#9CA3AF' : '#8F90A6'))
      Text(name)
        .fontColor(this.currentTabIndex === index ? '#6366F1' : (this.isDarkMode ? '#9CA3AF' : '#8F90A6'))
        .fontSize(12)
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.currentTabIndex = index;
    })
  }
}