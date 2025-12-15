import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../services/storage_service.dart';

/// 目录选择页面
class DirectorySetupScreen extends StatefulWidget {
  const DirectorySetupScreen({super.key});

  @override
  State<DirectorySetupScreen> createState() => _DirectorySetupScreenState();
}

class _DirectorySetupScreenState extends State<DirectorySetupScreen> {
  final _storageService = StorageService();
  String? _selectedPath;
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _pickDirectory() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.getDirectoryPath();
      
      if (result == null) {
        // 用户取消选择
        return;
      }

      // 验证目录
      final directory = Directory(result);
      
      if (!await directory.exists()) {
        setState(() {
          _errorMessage = '目录不存在';
        });
        return;
      }

      // 检查权限（尝试创建测试文件）
      try {
        final testFile = File(path.join(directory.path, '.clipnote_test'));
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        setState(() {
          _errorMessage = '没有写入权限';
        });
        return;
      }

      setState(() {
        _selectedPath = result;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '选择目录失败: $e';
      });
    }
  }

  Future<void> _useDefaultDirectory() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final clipnoteDir = Directory(path.join(appDir.path, 'ClipNote'));
      
      // 创建目录如果不存在
      if (!await clipnoteDir.exists()) {
        await clipnoteDir.create(recursive: true);
      }

      // 验证权限
      try {
        final testFile = File(path.join(clipnoteDir.path, '.clipnote_test'));
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        setState(() {
          _errorMessage = '默认目录没有写入权限';
          _isLoading = false;
        });
        return;
      }

      // 直接保存并继续
      await _storageService.setNotebookPath(clipnoteDir.path);
      await _storageService.setFirstLaunchComplete();
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '使用默认目录失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (_selectedPath == null) {
      setState(() {
        _errorMessage = '请先选择一个目录';
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _storageService.setNotebookPath(_selectedPath!);
      await _storageService.setFirstLaunchComplete();
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = '保存设置失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.folder_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '选择笔记存储位置',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '选择一个目录来存储你的笔记',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: InkWell(
                  onTap: _isLoading ? null : _pickDirectory,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _selectedPath == null
                              ? Icons.create_new_folder_outlined
                              : Icons.folder_open,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedPath ?? '点击选择目录',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: _selectedPath == null
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_selectedPath != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '已选择',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _useDefaultDirectory,
                  icon: const Icon(Icons.folder_special),
                  label: const Text('使用默认目录'),
                ),
                const SizedBox(height: 12),
              FilledButton(
                onPressed: _isLoading || _selectedPath == null ? null : _handleContinue,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('继续'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
