import { fileIo } from '@kit.CoreFileKit';
import { WaveformData } from '../components/WaveformComponent';

export interface AudioAnalysisResult {
  waveformData: WaveformData;
  duration: number;
  sampleRate: number;
  channels: number;
  bitDepth: number;
}

export class AudioAnalyzer {
  
  // 从音频文件分析波形数据
  static async analyzeAudioFile(filePath: string, targetPeaks: number = 1000): Promise<AudioAnalysisResult> {
    try {
      const audioBuffer = await this.readAudioFile(filePath);
      const wavInfo = this.parseWaveHeader(audioBuffer);
      const audioData = this.extractAudioData(audioBuffer, wavInfo);
      const peaks = this.generatePeaks(audioData, targetPeaks, wavInfo.channels);
      
      const waveformData: WaveformData = {
        peaks,
        duration: wavInfo.duration,
        sampleRate: wavInfo.sampleRate
      };

      return {
        waveformData,
        duration: wavInfo.duration,
        sampleRate: wavInfo.sampleRate,
        channels: wavInfo.channels,
        bitDepth: wavInfo.bitDepth
      };
    } catch (error) {
      console.error('Failed to analyze audio file:', error);
      throw error;
    }
  }

  // 读取音频文件
  private static async readAudioFile(filePath: string): Promise<ArrayBuffer> {
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

  // 解析WAV文件头
  private static parseWaveHeader(buffer: ArrayBuffer): {
    sampleRate: number;
    channels: number;
    bitDepth: number;
    dataOffset: number;
    dataSize: number;
    duration: number;
  } {
    const view = new DataView(buffer);
    
    // 检查RIFF标识
    const riffId = String.fromCharCode(
      view.getUint8(0), view.getUint8(1), view.getUint8(2), view.getUint8(3)
    );
    if (riffId !== 'RIFF') {
      throw new Error('Invalid WAV file: missing RIFF header');
    }

    // 检查WAVE标识
    const waveId = String.fromCharCode(
      view.getUint8(8), view.getUint8(9), view.getUint8(10), view.getUint8(11)
    );
    if (waveId !== 'WAVE') {
      throw new Error('Invalid WAV file: missing WAVE header');
    }

    // 查找fmt chunk
    let offset = 12;
    while (offset < buffer.byteLength - 8) {
      const chunkId = String.fromCharCode(
        view.getUint8(offset), view.getUint8(offset + 1),
        view.getUint8(offset + 2), view.getUint8(offset + 3)
      );
      const chunkSize = view.getUint32(offset + 4, true);

      if (chunkId === 'fmt ') {
        const sampleRate = view.getUint32(offset + 12, true);
        const channels = view.getUint16(offset + 10, true);
        const bitDepth = view.getUint16(offset + 22, true);
        
        // 查找data chunk
        let dataOffset = offset + 8 + chunkSize;
        while (dataOffset < buffer.byteLength - 8) {
          const dataChunkId = String.fromCharCode(
            view.getUint8(dataOffset), view.getUint8(dataOffset + 1),
            view.getUint8(dataOffset + 2), view.getUint8(dataOffset + 3)
          );
          const dataChunkSize = view.getUint32(dataOffset + 4, true);

          if (dataChunkId === 'data') {
            const duration = (dataChunkSize / (sampleRate * channels * (bitDepth / 8)));
            
            return {
              sampleRate,
              channels,
              bitDepth,
              dataOffset: dataOffset + 8,
              dataSize: dataChunkSize,
              duration
            };
          }
          
          dataOffset += 8 + dataChunkSize;
        }
        
        throw new Error('Invalid WAV file: data chunk not found');
      }
      
      offset += 8 + chunkSize;
    }
    
    throw new Error('Invalid WAV file: fmt chunk not found');
  }

  // 提取音频数据
  private static extractAudioData(buffer: ArrayBuffer, wavInfo: {
    dataOffset: number;
    dataSize: number;
    bitDepth: number;
    channels: number;
  }): Float32Array {
    const view = new DataView(buffer, wavInfo.dataOffset, wavInfo.dataSize);
    const sampleCount = wavInfo.dataSize / (wavInfo.bitDepth / 8);
    const audioData = new Float32Array(sampleCount);

    if (wavInfo.bitDepth === 16) {
      // 16位音频数据
      for (let i = 0; i < sampleCount; i++) {
        const sample = view.getInt16(i * 2, true);
        audioData[i] = sample / 32768.0; // 归一化到 -1 到 1
      }
    } else if (wavInfo.bitDepth === 24) {
      // 24位音频数据
      for (let i = 0; i < sampleCount; i++) {
        const byte1 = view.getUint8(i * 3);
        const byte2 = view.getUint8(i * 3 + 1);
        const byte3 = view.getUint8(i * 3 + 2);
        
        let sample = (byte3 << 24) | (byte2 << 16) | (byte1 << 8);
        sample = sample >> 8; // 符号扩展
        audioData[i] = sample / 8388608.0; // 归一化到 -1 到 1
      }
    } else if (wavInfo.bitDepth === 32) {
      // 32位浮点音频数据
      for (let i = 0; i < sampleCount; i++) {
        audioData[i] = view.getFloat32(i * 4, true);
      }
    } else {
      throw new Error(`Unsupported bit depth: ${wavInfo.bitDepth}`);
    }

    return audioData;
  }

  // 生成波形峰值数据
  private static generatePeaks(audioData: Float32Array, targetPeaks: number, channels: number): number[] {
    const samplesPerPeak = Math.floor(audioData.length / targetPeaks / channels);
    const peaks: number[] = [];

    for (let i = 0; i < targetPeaks; i++) {
      let maxPeak = 0;
      
      // 处理每个峰值区间
      for (let j = 0; j < samplesPerPeak; j++) {
        const sampleIndex = i * samplesPerPeak * channels + j * channels;
        
        if (sampleIndex < audioData.length) {
          // 如果是多声道，取各声道的平均值
          let sample = 0;
          for (let ch = 0; ch < channels; ch++) {
            if (sampleIndex + ch < audioData.length) {
              sample += Math.abs(audioData[sampleIndex + ch]);
            }
          }
          sample /= channels;
          
          maxPeak = Math.max(maxPeak, sample);
        }
      }
      
      peaks.push(maxPeak);
    }

    return peaks;
  }

  // 生成实时波形数据（用于录音过程中的波形显示）
  static generateRealtimePeaks(audioData: Float32Array, channels: number = 1): number[] {
    const peakCount = 50; // 固定50个峰值点用于实时显示
    const samplesPerPeak = Math.floor(audioData.length / peakCount / channels);
    const peaks: number[] = [];

    for (let i = 0; i < peakCount; i++) {
      let maxPeak = 0;
      
      for (let j = 0; j < samplesPerPeak; j++) {
        const sampleIndex = i * samplesPerPeak * channels + j * channels;
        
        if (sampleIndex < audioData.length) {
          let sample = 0;
          for (let ch = 0; ch < channels; ch++) {
            if (sampleIndex + ch < audioData.length) {
              sample += Math.abs(audioData[sampleIndex + ch]);
            }
          }
          sample /= channels;
          maxPeak = Math.max(maxPeak, sample);
        }
      }
      
      peaks.push(maxPeak);
    }

    return peaks;
  }

  // 模拟音频数据（用于演示）
  static generateMockAudioData(duration: number = 4, sampleRate: number = 44100): WaveformData {
    const totalSamples = duration * sampleRate;
    const peakCount = 1000;
    const peaks: number[] = [];
    
    // 生成模拟的音频波形数据
    for (let i = 0; i < peakCount; i++) {
      const time = (i / peakCount) * duration;
      
      // 创建复合波形：基础正弦波 + 噪音 + 包络
      const baseFreq = 440; // A4音符
      const envelope = Math.exp(-time * 0.5); // 衰减包络
      const sine1 = Math.sin(2 * Math.PI * baseFreq * time) * envelope;
      const sine2 = Math.sin(2 * Math.PI * baseFreq * 2 * time) * envelope * 0.3;
      const noise = (Math.random() - 0.5) * 0.1;
      
      const amplitude = Math.abs(sine1 + sine2 + noise);
      peaks.push(Math.min(1, amplitude));
    }
    
    return {
      peaks,
      duration,
      sampleRate
    };
  }

  // 计算音频片段的峰值
  static calculateSegmentPeaks(peaks: number[], startTime: number, endTime: number, duration: number): number[] {
    const startIndex = Math.floor((startTime / duration) * peaks.length);
    const endIndex = Math.ceil((endTime / duration) * peaks.length);
    
    return peaks.slice(startIndex, endIndex);
  }

  // 获取音频的RMS（均方根）值
  static calculateRMS(audioData: Float32Array): number {
    let sum = 0;
    for (let i = 0; i < audioData.length; i++) {
      sum += audioData[i] * audioData[i];
    }
    return Math.sqrt(sum / audioData.length);
  }

  // 检测音频中的静音段
  static detectSilence(peaks: number[], threshold: number = 0.01): { start: number, end: number }[] {
    const silenceSegments: { start: number, end: number }[] = [];
    let silenceStart = -1;
    
    for (let i = 0; i < peaks.length; i++) {
      if (peaks[i] < threshold) {
        if (silenceStart === -1) {
          silenceStart = i;
        }
      } else {
        if (silenceStart !== -1) {
          silenceSegments.push({
            start: silenceStart / peaks.length,
            end: i / peaks.length
          });
          silenceStart = -1;
        }
      }
    }
    
    // 处理结尾的静音段
    if (silenceStart !== -1) {
      silenceSegments.push({
        start: silenceStart / peaks.length,
        end: 1
      });
    }
    
    return silenceSegments;
  }
}