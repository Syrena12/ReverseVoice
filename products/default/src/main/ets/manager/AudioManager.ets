import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export interface AudioRecorderConfig {
  audioEncoderMime: string;
  audioEncodingBitRate: number;
  audioSampleRate: number;
  numberOfChannels: number;
  outputFormat: string;
  uri: string;
}

export interface AudioPlayerConfig {
  src: string;
}

export class AudioManager {
  private audioRecorder: media.AVRecorder | null = null;
  private audioPlayer: media.AVPlayer | null = null;
  private context: common.UIAbilityContext;
  private currentRecordingPath: string = '';
  private isRecording: boolean = false;
  private isPlaying: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  // 初始化录音器
  async initRecorder(): Promise<void> {
    try {
      this.audioRecorder = await media.createAVRecorder();
      
      this.audioRecorder.on('stateChange', (state, reason) => {
        console.info(`AudioRecorder state changed to ${state}, reason: ${reason}`);
      });

      this.audioRecorder.on('error', (err) => {
        console.error(`AudioRecorder error: ${err.message}`);
      });

    } catch (error) {
      console.error('Failed to init audio recorder:', error);
      throw error;
    }
  }

  // 初始化播放器
  async initPlayer(): Promise<void> {
    try {
      this.audioPlayer = await media.createAVPlayer();

      this.audioPlayer.on('stateChange', (state, reason) => {
        console.info(`AudioPlayer state changed to ${state}, reason: ${reason}`);
        if (state === 'completed') {
          this.isPlaying = false;
        }
      });

      this.audioPlayer.on('error', (err) => {
        console.error(`AudioPlayer error: ${err.message}`);
      });

    } catch (error) {
      console.error('Failed to init audio player:', error);
      throw error;
    }
  }

  // 开始录音
  async startRecording(): Promise<string> {
    try {
      if (!this.audioRecorder) {
        await this.initRecorder();
      }

      // 生成录音文件路径
      const timestamp = new Date().getTime();
      const fileName = `record_${timestamp}.wav`;
      const filesDir = this.context.filesDir;
      this.currentRecordingPath = `${filesDir}/${fileName}`;

      // 录音配置
      const config: AudioRecorderConfig = {
        audioEncoderMime: 'audio/wav',
        audioEncodingBitRate: 128000,
        audioSampleRate: 44100,
        numberOfChannels: 2,
        outputFormat: 'wav',
        uri: `file://${this.currentRecordingPath}`
      };

      await this.audioRecorder!.prepare(config);
      await this.audioRecorder!.start();
      this.isRecording = true;

      console.info(`Recording started: ${this.currentRecordingPath}`);
      return this.currentRecordingPath;
    } catch (error) {
      console.error('Failed to start recording:', error);
      throw error;
    }
  }

  // 停止录音
  async stopRecording(): Promise<string> {
    try {
      if (this.audioRecorder && this.isRecording) {
        await this.audioRecorder.stop();
        await this.audioRecorder.release();
        this.audioRecorder = null;
        this.isRecording = false;
        
        console.info(`Recording stopped: ${this.currentRecordingPath}`);
        return this.currentRecordingPath;
      }
      return '';
    } catch (error) {
      console.error('Failed to stop recording:', error);
      throw error;
    }
  }

  // 播放音频
  async playAudio(filePath: string): Promise<void> {
    try {
      if (!this.audioPlayer) {
        await this.initPlayer();
      }

      if (this.isPlaying) {
        await this.stopPlaying();
      }

      this.audioPlayer!.url = `file://${filePath}`;
      await this.audioPlayer!.prepare();
      await this.audioPlayer!.play();
      this.isPlaying = true;

      console.info(`Playing audio: ${filePath}`);
    } catch (error) {
      console.error('Failed to play audio:', error);
      throw error;
    }
  }

  // 停止播放
  async stopPlaying(): Promise<void> {
    try {
      if (this.audioPlayer && this.isPlaying) {
        await this.audioPlayer.stop();
        this.isPlaying = false;
      }
    } catch (error) {
      console.error('Failed to stop playing:', error);
      throw error;
    }
  }

  // 暂停播放
  async pausePlaying(): Promise<void> {
    try {
      if (this.audioPlayer && this.isPlaying) {
        await this.audioPlayer.pause();
        this.isPlaying = false;
      }
    } catch (error) {
      console.error('Failed to pause playing:', error);
      throw error;
    }
  }

  // 恢复播放
  async resumePlaying(): Promise<void> {
    try {
      if (this.audioPlayer) {
        await this.audioPlayer.play();
        this.isPlaying = true;
      }
    } catch (error) {
      console.error('Failed to resume playing:', error);
      throw error;
    }
  }

  // 音频逆转核心算法
  async reverseAudio(inputPath: string): Promise<string> {
    try {
      console.info(`Starting audio reverse for: ${inputPath}`);

      // 读取原始音频文件
      const audioData = await this.readAudioFile(inputPath);
      
      // 逆转音频数据
      const reversedData = this.reverseAudioData(audioData);
      
      // 生成逆转后的文件路径
      const timestamp = new Date().getTime();
      const fileName = `reversed_${timestamp}.wav`;
      const filesDir = this.context.filesDir;
      const outputPath = `${filesDir}/${fileName}`;
      
      // 保存逆转后的音频
      await this.writeAudioFile(outputPath, reversedData);
      
      console.info(`Audio reversed successfully: ${outputPath}`);
      return outputPath;
      
    } catch (error) {
      console.error('Failed to reverse audio:', error);
      throw error;
    }
  }

  // 读取音频文件数据
  private async readAudioFile(filePath: string): Promise<ArrayBuffer> {
    try {
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(filePath);
      const buffer = new ArrayBuffer(stat.size);
      await fileIo.read(file.fd, buffer);
      fileIo.closeSync(file);
      return buffer;
    } catch (error) {
      console.error('Failed to read audio file:', error);
      throw error;
    }
  }

  // 逆转音频数据
  private reverseAudioData(audioData: ArrayBuffer): ArrayBuffer {
    try {
      // 简化的WAV文件处理 - 实际应用中需要解析WAV文件头
      const dataView = new DataView(audioData);
      const headerSize = 44; // 标准WAV文件头大小
      
      // 创建新的ArrayBuffer用于存储逆转后的数据
      const reversedBuffer = new ArrayBuffer(audioData.byteLength);
      const reversedView = new DataView(reversedBuffer);
      
      // 复制文件头
      for (let i = 0; i < headerSize; i++) {
        reversedView.setUint8(i, dataView.getUint8(i));
      }
      
      // 逆转音频数据部分（16位样本）
      const sampleSize = 2; // 16位 = 2字节
      const audioDataSize = audioData.byteLength - headerSize;
      const numSamples = audioDataSize / sampleSize;
      
      for (let i = 0; i < numSamples; i++) {
        const originalIndex = headerSize + i * sampleSize;
        const reversedIndex = headerSize + (numSamples - 1 - i) * sampleSize;
        const sample = dataView.getInt16(originalIndex, true); // little-endian
        reversedView.setInt16(reversedIndex, sample, true);
      }
      
      return reversedBuffer;
    } catch (error) {
      console.error('Failed to reverse audio data:', error);
      throw error;
    }
  }

  // 写入音频文件
  private async writeAudioFile(filePath: string, audioData: ArrayBuffer): Promise<void> {
    try {
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      await fileIo.write(file.fd, audioData);
      fileIo.closeSync(file);
    } catch (error) {
      console.error('Failed to write audio file:', error);
      throw error;
    }
  }

  // 获取音频时长
  async getAudioDuration(filePath: string): Promise<number> {
    try {
      if (!this.audioPlayer) {
        await this.initPlayer();
      }

      this.audioPlayer!.url = `file://${filePath}`;
      await this.audioPlayer!.prepare();
      
      const duration = this.audioPlayer!.duration;
      console.info(`Audio duration: ${duration}ms`);
      return duration;
    } catch (error) {
      console.error('Failed to get audio duration:', error);
      return 0;
    }
  }

  // 获取录音状态
  getRecordingStatus(): boolean {
    return this.isRecording;
  }

  // 获取播放状态
  getPlayingStatus(): boolean {
    return this.isPlaying;
  }

  // 释放资源
  async release(): Promise<void> {
    try {
      if (this.audioRecorder) {
        if (this.isRecording) {
          await this.stopRecording();
        }
        await this.audioRecorder.release();
        this.audioRecorder = null;
      }

      if (this.audioPlayer) {
        if (this.isPlaying) {
          await this.stopPlaying();
        }
        await this.audioPlayer.release();
        this.audioPlayer = null;
      }
    } catch (error) {
      console.error('Failed to release audio manager:', error);
    }
  }
}