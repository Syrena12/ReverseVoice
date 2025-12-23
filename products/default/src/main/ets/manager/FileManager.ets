import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export interface AudioFileInfo {
  id: string;
  name: string;
  filePath: string;
  type: 'original' | 'reversed' | 'edited';
  duration: number;
  size: number;
  createTime: number;
  modifyTime: number;
}

export class FileManager {
  private context: common.UIAbilityContext;
  private audioFilesDir: string;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
    this.audioFilesDir = `${context.filesDir}/audio`;
    this.initializeDirectories();
  }

  // 初始化目录
  private async initializeDirectories(): Promise<void> {
    try {
      if (!fileIo.accessSync(this.audioFilesDir)) {
        fileIo.mkdirSync(this.audioFilesDir, true);
      }
    } catch (error) {
      console.error('Failed to initialize directories:', error);
    }
  }

  // 保存音频文件信息
  async saveAudioFile(sourceFilePath: string, name: string, type: 'original' | 'reversed' | 'edited'): Promise<AudioFileInfo> {
    try {
      const id = this.generateId();
      const timestamp = new Date().getTime();
      const extension = this.getFileExtension(sourceFilePath);
      const fileName = `${id}.${extension}`;
      const targetFilePath = `${this.audioFilesDir}/${fileName}`;

      // 复制文件到应用目录
      await this.copyFile(sourceFilePath, targetFilePath);

      // 获取文件信息
      const stat = fileIo.statSync(targetFilePath);
      
      const audioFileInfo: AudioFileInfo = {
        id,
        name,
        filePath: targetFilePath,
        type,
        duration: 0, // 需要通过AudioManager获取
        size: stat.size,
        createTime: timestamp,
        modifyTime: timestamp
      };

      // 保存文件信息到本地存储
      await this.saveFileInfoToStorage(audioFileInfo);

      return audioFileInfo;
    } catch (error) {
      console.error('Failed to save audio file:', error);
      throw new Error('Failed to save audio file');
    }
  }

  // 获取所有音频文件信息
  async getAllAudioFiles(): Promise<AudioFileInfo[]> {
    try {
      const storageKey = 'audio_files_info';
      const storedInfo = AppStorage.get<string>(storageKey);
      
      if (storedInfo) {
        const fileInfos: AudioFileInfo[] = JSON.parse(storedInfo);
        // 过滤掉已删除的文件
        const validFiles = fileInfos.filter(info => fileIo.accessSync(info.filePath));
        
        // 如果有文件被删除，更新存储
        if (validFiles.length !== fileInfos.length) {
          await this.updateFileInfoStorage(validFiles);
        }
        
        return validFiles;
      }
      
      return [];
    } catch (error) {
      console.error('Failed to get audio files:', error);
      return [];
    }
  }

  // 根据类型获取音频文件
  async getAudioFilesByType(type: 'original' | 'reversed' | 'edited'): Promise<AudioFileInfo[]> {
    const allFiles = await this.getAllAudioFiles();
    return allFiles.filter(file => file.type === type);
  }

  // 根据ID获取音频文件
  async getAudioFileById(id: string): Promise<AudioFileInfo | null> {
    const allFiles = await this.getAllAudioFiles();
    return allFiles.find(file => file.id === id) || null;
  }

  // 删除音频文件
  async deleteAudioFile(id: string): Promise<boolean> {
    try {
      const fileInfo = await this.getAudioFileById(id);
      if (!fileInfo) {
        return false;
      }

      // 删除物理文件
      if (fileIo.accessSync(fileInfo.filePath)) {
        fileIo.unlinkSync(fileInfo.filePath);
      }

      // 从存储中移除文件信息
      const allFiles = await this.getAllAudioFiles();
      const updatedFiles = allFiles.filter(file => file.id !== id);
      await this.updateFileInfoStorage(updatedFiles);

      return true;
    } catch (error) {
      console.error('Failed to delete audio file:', error);
      return false;
    }
  }

  // 重命名音频文件
  async renameAudioFile(id: string, newName: string): Promise<boolean> {
    try {
      const allFiles = await this.getAllAudioFiles();
      const fileIndex = allFiles.findIndex(file => file.id === id);
      
      if (fileIndex === -1) {
        return false;
      }

      allFiles[fileIndex].name = newName;
      allFiles[fileIndex].modifyTime = new Date().getTime();

      await this.updateFileInfoStorage(allFiles);
      return true;
    } catch (error) {
      console.error('Failed to rename audio file:', error);
      return false;
    }
  }

  // 获取最近的录音文件
  async getRecentRecordings(limit: number = 5): Promise<AudioFileInfo[]> {
    const originalFiles = await this.getAudioFilesByType('original');
    return originalFiles
      .sort((a, b) => b.createTime - a.createTime)
      .slice(0, limit);
  }

  // 清理临时文件
  async cleanupTempFiles(): Promise<void> {
    try {
      const tempDir = `${this.context.cacheDir}/temp_audio`;
      if (fileIo.accessSync(tempDir)) {
        const files = fileIo.listFileSync(tempDir);
        for (const file of files) {
          fileIo.unlinkSync(`${tempDir}/${file}`);
        }
      }
    } catch (error) {
      console.error('Failed to cleanup temp files:', error);
    }
  }

  // 获取应用音频文件总大小
  async getTotalAudioSize(): Promise<number> {
    try {
      const allFiles = await this.getAllAudioFiles();
      return allFiles.reduce((total, file) => total + file.size, 0);
    } catch (error) {
      console.error('Failed to get total audio size:', error);
      return 0;
    }
  }

  // 导出音频文件到外部存储
  async exportAudioFile(id: string, targetDir: string): Promise<string | null> {
    try {
      const fileInfo = await this.getAudioFileById(id);
      if (!fileInfo) {
        return null;
      }

      const extension = this.getFileExtension(fileInfo.filePath);
      const exportFileName = `${fileInfo.name}.${extension}`;
      const exportPath = `${targetDir}/${exportFileName}`;

      await this.copyFile(fileInfo.filePath, exportPath);
      return exportPath;
    } catch (error) {
      console.error('Failed to export audio file:', error);
      return null;
    }
  }

  // 私有方法：生成唯一ID
  private generateId(): string {
    return `audio_${new Date().getTime()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  // 私有方法：获取文件扩展名
  private getFileExtension(filePath: string): string {
    const lastDotIndex = filePath.lastIndexOf('.');
    return lastDotIndex > 0 ? filePath.substring(lastDotIndex + 1) : 'wav';
  }

  // 私有方法：复制文件
  private async copyFile(sourcePath: string, targetPath: string): Promise<void> {
    try {
      const sourceFile = fileIo.openSync(sourcePath, fileIo.OpenMode.READ_ONLY);
      const targetFile = fileIo.openSync(targetPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      
      const buffer = new ArrayBuffer(8192); // 8KB buffer
      let bytesRead = 0;
      
      do {
        bytesRead = await fileIo.read(sourceFile.fd, buffer);
        if (bytesRead > 0) {
          await fileIo.write(targetFile.fd, buffer.slice(0, bytesRead));
        }
      } while (bytesRead > 0);
      
      fileIo.closeSync(sourceFile);
      fileIo.closeSync(targetFile);
    } catch (error) {
      console.error('Failed to copy file:', error);
      throw new Error('Failed to copy file');
    }
  }

  // 私有方法：保存文件信息到本地存储
  private async saveFileInfoToStorage(fileInfo: AudioFileInfo): Promise<void> {
    try {
      const allFiles = await this.getAllAudioFiles();
      allFiles.push(fileInfo);
      await this.updateFileInfoStorage(allFiles);
    } catch (error) {
      console.error('Failed to save file info to storage:', error);
      throw new Error('Failed to save file info to storage');
    }
  }

  // 私有方法：更新文件信息存储
  private async updateFileInfoStorage(fileInfos: AudioFileInfo[]): Promise<void> {
    try {
      const storageKey = 'audio_files_info';
      const jsonData = JSON.stringify(fileInfos);
      AppStorage.setOrCreate(storageKey, jsonData);
    } catch (error) {
      console.error('Failed to update file info storage:', error);
      throw new Error('Failed to update file info storage');
    }
  }

  // 格式化文件大小
  static formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 B';
    
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  }

  // 格式化时长
  static formatDuration(milliseconds: number): string {
    const totalSeconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }
}