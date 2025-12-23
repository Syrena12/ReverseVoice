import { common } from '@kit.AbilityKit';

export interface UserInfo {
  id?: string;
  name: string;
  phone: string;
  avatar?: string;
  isLoggedIn: boolean;
  loginTime?: number;
}

export interface LoginResult {
  success: boolean;
  message: string;
  userInfo?: UserInfo;
}

export interface VerificationResult {
  success: boolean;
  message: string;
}

export interface WaveformStyle {
  id: string;
  name: string;
  type: 'gradient' | 'solid' | 'neon';
  colors: string[];
}

export interface AudioFormat {
  id: string;
  name: string;
  extension: string;
  quality: 'low' | 'medium' | 'high';
}

export class UserManager {
  private static instance: UserManager | null = null;
  private context: common.UIAbilityContext;
  private currentUser: UserInfo | null = null;

  // 预定义的波形样式
  private readonly waveformStyles: WaveformStyle[] = [
    {
      id: 'gradient_blue_purple',
      name: '蓝紫渐变',
      type: 'gradient',
      colors: ['#6366F1', '#8B5CF6']
    },
    {
      id: 'gradient_pink_orange',
      name: '粉橙渐变',
      type: 'gradient',
      colors: ['#EC4899', '#F97316']
    },
    {
      id: 'solid_blue',
      name: '纯蓝色',
      type: 'solid',
      colors: ['#3B82F6']
    },
    {
      id: 'neon_green',
      name: '霓虹绿',
      type: 'neon',
      colors: ['#10B981', '#34D399']
    }
  ];

  // 预定义的音频格式
  private readonly audioFormats: AudioFormat[] = [
    {
      id: 'wav_high',
      name: 'WAV 高质量',
      extension: 'wav',
      quality: 'high'
    },
    {
      id: 'wav_medium',
      name: 'WAV 标准',
      extension: 'wav',
      quality: 'medium'
    },
    {
      id: 'mp3_high',
      name: 'MP3 高质量',
      extension: 'mp3',
      quality: 'high'
    },
    {
      id: 'mp3_medium',
      name: 'MP3 标准',
      extension: 'mp3',
      quality: 'medium'
    }
  ];

  private constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.loadUserInfo();
  }

  static getInstance(context?: common.UIAbilityContext): UserManager {
    if (!UserManager.instance && context) {
      UserManager.instance = new UserManager(context);
    }
    return UserManager.instance!;
  }

  // 发送验证码 (模拟实现)
  async sendVerificationCode(phone: string): Promise<VerificationResult> {
    try {
      // 验证手机号格式
      const phoneRegex: RegExp = /^1[3-9]\d{9}$/;
      if (!phoneRegex.test(phone)) {
        const result: VerificationResult = { success: false, message: '手机号格式不正确' };
        return result;
      }

      // 模拟发送验证码
      console.info(`向 ${phone} 发送验证码`);
      
      // 这里应该调用实际的短信服务API
      // 现在只是模拟延迟
      await new Promise<void>(resolve => setTimeout(resolve, 1000));

      const successResult: VerificationResult = { success: true, message: '验证码已发送' };
      return successResult;
    } catch (error) {
      console.error('发送验证码失败:', error);
      const errorResult: VerificationResult = { success: false, message: '发送验证码失败，请稍后重试' };
      return errorResult;
    }
  }

  // 验证码登录/注册
  async loginWithCode(phone: string, code: string): Promise<LoginResult> {
    try {
      // 模拟验证码验证 (实际应该调用后端API)
      if (code !== '123456' && code !== '888888') {
        const errorResult: LoginResult = { success: false, message: '验证码错误' };
        return errorResult;
      }

      // 生成用户信息
      const userInfo: UserInfo = {
        id: this.generateUserId(),
        name: `用户${phone.slice(-4)}`,
        phone: this.maskPhone(phone),
        isLoggedIn: true,
        loginTime: Date.now()
      };

      this.currentUser = userInfo;
      await this.saveUserInfo(userInfo);

      const successResult: LoginResult = {
        success: true,
        message: '登录成功',
        userInfo: userInfo
      };
      return successResult;
    } catch (error) {
      console.error('登录失败:', error);
      const finalErrorResult: LoginResult = { success: false, message: '登录失败，请稍后重试' };
      return finalErrorResult;
    }
  }

  // 退出登录
  async logout(): Promise<void> {
    try {
      this.currentUser = null;
      AppStorage.setOrCreate('user_info', '');
      AppStorage.setOrCreate('is_logged_in', false);
    } catch (error) {
      console.error('退出登录失败:', error);
    }
  }

  // 更新用户信息
  async updateUserInfo(updates: Partial<UserInfo>): Promise<boolean> {
    try {
      if (!this.currentUser) return false;

      const currentUserCopy: UserInfo = {
        id: this.currentUser.id,
        name: updates.name || this.currentUser.name,
        phone: updates.phone || this.currentUser.phone,
        avatar: updates.avatar || this.currentUser.avatar,
        isLoggedIn: updates.isLoggedIn !== undefined ? updates.isLoggedIn : this.currentUser.isLoggedIn,
        loginTime: updates.loginTime || this.currentUser.loginTime
      };
      this.currentUser = currentUserCopy;
      await this.saveUserInfo(this.currentUser);
      return true;
    } catch (error) {
      console.error('更新用户信息失败:', error);
      return false;
    }
  }

  // 获取当前用户信息
  getCurrentUser(): UserInfo | null {
    return this.currentUser;
  }

  // 检查是否已登录
  isLoggedIn(): boolean {
    return this.currentUser?.isLoggedIn === true;
  }

  // 获取波形样式列表
  getWaveformStyles(): WaveformStyle[] {
    return this.waveformStyles;
  }

  // 获取音频格式列表
  getAudioFormats(): AudioFormat[] {
    return this.audioFormats;
  }

  // 获取当前选择的波形样式
  getCurrentWaveformStyle(): WaveformStyle {
    const savedStyleId = AppStorage.get<string>('waveform_style') || 'gradient_blue_purple';
    const foundStyle = this.waveformStyles.find(style => style.id === savedStyleId);
    return foundStyle || this.waveformStyles[0];
  }

  // 设置波形样式
  setWaveformStyle(styleId: string): boolean {
    const style = this.waveformStyles.find(s => s.id === styleId);
    if (style) {
      AppStorage.setOrCreate('waveform_style', styleId);
      return true;
    }
    return false;
  }

  // 获取当前选择的音频格式
  getCurrentAudioFormat(): AudioFormat {
    const savedFormatId = AppStorage.get<string>('audio_format') || 'wav_high';
    const foundFormat = this.audioFormats.find(format => format.id === savedFormatId);
    return foundFormat || this.audioFormats[0];
  }

  // 设置音频格式
  setAudioFormat(formatId: string): boolean {
    const format = this.audioFormats.find(f => f.id === formatId);
    if (format) {
      AppStorage.setOrCreate('audio_format', formatId);
      return true;
    }
    return false;
  }

  // 私有方法：加载用户信息
  private loadUserInfo(): void {
    try {
      const userInfoString = AppStorage.get<string>('user_info');
      if (userInfoString) {
        const userInfo = JSON.parse(userInfoString) as UserInfo;
        const isLoggedIn = AppStorage.get<boolean>('is_logged_in') || false;
        
        if (isLoggedIn && userInfo.id) {
          const loggedInUser: UserInfo = {
            id: userInfo.id,
            name: userInfo.name,
            phone: userInfo.phone,
            avatar: userInfo.avatar,
            isLoggedIn: true,
            loginTime: userInfo.loginTime
          };
          this.currentUser = loggedInUser;
        }
      }
    } catch (error) {
      console.error('加载用户信息失败:', error);
    }
  }

  // 私有方法：保存用户信息
  private async saveUserInfo(userInfo: UserInfo): Promise<void> {
    try {
      AppStorage.setOrCreate('user_info', JSON.stringify(userInfo));
      AppStorage.setOrCreate('is_logged_in', userInfo.isLoggedIn);
    } catch (error) {
      console.error('保存用户信息失败:', error);
      throw new Error('保存用户信息失败');
    }
  }

  // 私有方法：生成用户ID
  private generateUserId(): string {
    return `user_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
  }

  // 私有方法：手机号脱敏
  private maskPhone(phone: string): string {
    if (phone.length === 11) {
      return `${phone.substring(0, 3)}****${phone.substring(7)}`;
    }
    return phone;
  }
}