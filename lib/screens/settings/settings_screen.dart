import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../../services/storage_service.dart';

/// 设置页面
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('设置'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '数据 & 安全'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DataSecurityTab(),
          ],
        ),
      ),
    );
  }
}

/// 数据 & 安全 Tab
class DataSecurityTab extends StatefulWidget {
  const DataSecurityTab({super.key});

  @override
  State<DataSecurityTab> createState() => _DataSecurityTabState();
}

class _DataSecurityTabState extends State<DataSecurityTab> {
  final _storageService = StorageService();
  String? _currentDirectory;

  @override
  void initState() {
    super.initState();
    _loadCurrentDirectory();
  }

  Future<void> _loadCurrentDirectory() async {
    final path = await _storageService.getNotebookPath();
    if (mounted) {
      setState(() {
        _currentDirectory = path;
      });
    }
  }

  Future<void> _showChangeDirectoryDialog() async {
    String? selectedPath;
    String? errorMessage;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('更改数据目录'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('当前目录：'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentDirectory ?? '未设置',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              if (selectedPath != null) ...[
                const Text('新目录：'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    selectedPath!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (errorMessage != null) ...[
                Text(
                  errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: () async {
                  setDialogState(() {
                    errorMessage = null;
                  });

                  try {
                    final result = await FilePicker.platform.getDirectoryPath();
                    
                    if (result == null) return;

                    // 验证目录
                    final directory = Directory(result);
                    
                    if (!await directory.exists()) {
                      setDialogState(() {
                        errorMessage = '目录不存在';
                      });
                      return;
                    }

                    // 检查权限
                    try {
                      final testFile = File(path.join(directory.path, '.clipnote_test'));
                      await testFile.writeAsString('test');
                      await testFile.delete();
                    } catch (e) {
                      setDialogState(() {
                        errorMessage = '没有写入权限';
                      });
                      return;
                    }

                    setDialogState(() {
                      selectedPath = result;
                      errorMessage = null;
                    });
                  } catch (e) {
                    setDialogState(() {
                      errorMessage = '选择目录失败: $e';
                    });
                  }
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('选择目录'),
              ),
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
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '更改目录后，不会自动迁移数据',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: selectedPath == null
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('确认更改'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedPath != null) {
      await _storageService.setNotebookPath(selectedPath!);
      await _loadCurrentDirectory();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据目录已更改')),
        );
      }
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final hasPassword = await _storageService.hasPassword();
    
    if (!mounted) return;

    if (!hasPassword) {
      // 没有密码，直接设置新密码
      _showSetNewPasswordDialog(requireOldPassword: false);
      return;
    }

    // 有密码，需要验证旧密码
    _showSetNewPasswordDialog(requireOldPassword: true);
  }

  Future<void> _showSetNewPasswordDialog({required bool requireOldPassword}) async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(requireOldPassword ? '重置密码' : '设置密码'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (requireOldPassword) ...[
                TextFormField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '当前密码',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入当前密码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新密码',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入新密码';
                  }
                  if (value.length < 4) {
                    return '密码至少4个字符';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '确认新密码',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != newPasswordController.text) {
                    return '密码不一致';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              // 验证旧密码
              if (requireOldPassword) {
                final isValid = await _storageService.verifyPassword(oldPasswordController.text);
                if (!isValid) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('当前密码错误')),
                    );
                  }
                  return;
                }
              }

              // 设置新密码
              await _storageService.setPassword(newPasswordController.text);
              
              if (context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已更新')),
      );
    }
  }

  Future<void> _showClearDataDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有数据'),
        content: const Text(
          '此操作将清空所有设置和数据，包括密码。此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _storageService.clearAllData();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/welcome',
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const ListTile(
          title: Text(
            '安全',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.lock_reset),
          title: const Text('重置密码'),
          subtitle: const Text('更改你的密码'),
          onTap: _showResetPasswordDialog,
        ),
        const Divider(),
        const ListTile(
          title: Text(
            '数据管理',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('数据目录'),
          subtitle: Text(_currentDirectory ?? '未设置'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _showChangeDirectoryDialog,
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            '清空所有数据',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          subtitle: const Text('删除所有设置和数据'),
          onTap: _showClearDataDialog,
        ),
      ],
    );
  }
}
