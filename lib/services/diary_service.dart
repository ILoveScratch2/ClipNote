import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'storage_service.dart';

/// 日记服务
class DiaryService {
  final StorageService _storage = StorageService();
  
  /// 获取日记文件路径 - YYYY-MM-DD.md
  Future<String> _getFilePath(DateTime date) async {
    final directory = await _storage.getNotebookPath();
    if (directory == null) {
      throw Exception('数据目录未设置');
    }
    
    // 日记放在diary （主目录我打算放点别的）
    final diaryDir = path.join(directory, 'diary');
    await Directory(diaryDir).create(recursive: true);
    
    final fileName = DateFormat('yyyy-MM-dd').format(date);
    return path.join(diaryDir, '$fileName.md');
  }
  
  /// 读取日记内容
  Future<String?> getDiary(DateTime date) async {
    try {
      final filePath = await _getFilePath(date);
      final file = File(filePath);
      
      if (!await file.exists()) {
        return null;
      }
      
      return await file.readAsString();
    } catch (e) {
      return null;
    }
  }
  
  /// 保存日记内容
  Future<void> saveDiary(DateTime date, String content) async {
    final filePath = await _getFilePath(date);
    final file = File(filePath);
    
    // 确保目录存在
    await file.parent.create(recursive: true);
    
    // 写！
    await file.writeAsString(content);
  }
  
  /// 删除日记
  Future<void> deleteDiary(DateTime date) async {
    final filePath = await _getFilePath(date);
    final file = File(filePath);
    
    if (await file.exists()) {
      await file.delete();
    }
  }
  
  /// 获取所有日记日期列表
  Future<List<DateTime>> getAllDiaryDates() async {
    final directory = await _storage.getNotebookPath();
    if (directory == null) {
      return [];
    }
    
    // 扫描diary子目录
    final diaryDir = path.join(directory, 'diary');
    final dir = Directory(diaryDir);
    if (!await dir.exists()) {
      return [];
    }
    
    final dates = <DateTime>[];
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.md')) {
        final fileName = path.basenameWithoutExtension(entity.path);
        try {
          final date = dateFormat.parse(fileName);
          dates.add(date);
        } catch (e) {
          // 忽略不符合格式的文件
        }
      }
    }
    
    // 按日期倒序排列
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }
  
  /// 检查某日期是否有日记
  Future<bool> hasDiary(DateTime date) async {
    final filePath = await _getFilePath(date);
    return await File(filePath).exists();
  }
}
