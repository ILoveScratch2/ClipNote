import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'dart:convert';
import '../../services/diary_service.dart';

/// 主界面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DiaryService _diaryService = DiaryService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late quill.QuillController _quillController;
  
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  List<DateTime> _diaryDates = [];
  bool _isEditMode = false; // 默认预览模式
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController(
      document: quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _loadDiaryDates();
    _loadDiary(_selectedDate);
  }
  
  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }
  
  /// 加载所有日记日期
  Future<void> _loadDiaryDates() async {
    final dates = await _diaryService.getAllDiaryDates();
    setState(() {
      _diaryDates = dates;
    });
  }
  
  /// 加载指定日期的日记
  Future<void> _loadDiary(DateTime date) async {
    setState(() => _isLoading = true);
    
    final deltaJson = await _diaryService.getDiary(date);
    
    if (deltaJson != null && deltaJson.isNotEmpty) {
      try {
        final deltaData = jsonDecode(deltaJson);
        _quillController.document = quill.Document.fromJson(deltaData);
      } catch (e) {
        _quillController.document = quill.Document();
      }
    } else {
      _quillController.document = quill.Document();
    }
    
    _quillController.moveCursorToStart();
    
    setState(() {
      _isLoading = false;
      _isEditMode = false; // 加载后默认预览模式
      _quillController.readOnly = true;
    });
  }
  
  /// 保存当前日记
  Future<void> _saveDiary() async {
    final delta = _quillController.document.toDelta();
    final deltaJson = jsonEncode(delta.toJson());
    
    await _diaryService.saveDiary(_selectedDate, deltaJson);
    await _loadDiaryDates();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已保存'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  /// 删除当前日记
  Future<void> _deleteDiary() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日记'),
        content: const Text('确定要删除这篇日记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _diaryService.deleteDiary(_selectedDate);
      _quillController.document = quill.Document();
      await _loadDiaryDates();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已删除'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  /// 切换到指定日期
  Future<void> _switchToDate(DateTime date) async {
    // 保存当前编辑的内容
    if (_isEditMode && _quillController.document.toPlainText().trim().isNotEmpty) {
      await _saveDiary();
    }
    
    setState(() {
      _selectedDate = date;
      _focusedDate = date;
    });
    
    await _loadDiary(date);
  }
  
  /// 构建日历日期单元格（支持右键菜单）
  Widget _buildCalendarDay(
    BuildContext context,
    DateTime day,
    DateTime focusedDay,
    ColorScheme colorScheme, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final hasEvent = _diaryDates.any((d) => isSameDay(d, day));
    
    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showDiaryContextMenu(context, day, details.globalPosition);
      },
      onLongPressStart: (details) {
        _showDiaryContextMenu(context, day, details.globalPosition);
      },
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : isToday
                  ? colorScheme.secondaryContainer
                  : null,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : isToday
                          ? colorScheme.onSecondaryContainer
                          : colorScheme.onSurface,
                  fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (hasEvent)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.onPrimary : colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// 构建按年月分组的日记列表
  Widget _buildDiaryList() {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (_diaryDates.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '还没有日记\n开始写第一篇吧！',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    
    // 按年月分组
    final Map<String, List<DateTime>> groupedDates = {};
    for (final date in _diaryDates) {
      final yearKey = DateFormat('yyyy').format(date);
      final monthKey = '$yearKey-${DateFormat('MM').format(date)}';
      
      groupedDates.putIfAbsent(monthKey, () => []).add(date);
    }
    
    // 构建列表
    final sortedKeys = groupedDates.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    
    return ListView.builder(
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final key = sortedKeys[index];
        final dates = groupedDates[key]!;
        final firstDate = dates.first;
        final year = DateFormat('yyyy').format(firstDate);
        final month = DateFormat('M月').format(firstDate);
        
        // 检查是否需要显示年份标题
        final showYear = index == 0 || 
            year != DateFormat('yyyy').format(groupedDates[sortedKeys[index - 1]]!.first);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 年份标题
            if (showYear)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  year,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            
            // 月份标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                month,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            
            // 该月的日记列表
            ...dates.map((date) {
              final isSelected = isSameDay(date, _selectedDate);
              
              return GestureDetector(
                onSecondaryTapDown: (details) {
                  _showDiaryContextMenu(context, date, details.globalPosition);
                },
                onLongPressStart: (details) {
                  _showDiaryContextMenu(context, date, details.globalPosition);
                },
                child: ListTile(
                  selected: isSelected,
                  selectedTileColor: colorScheme.secondaryContainer,
                  leading: Icon(
                    Icons.article_outlined,
                    color: isSelected 
                        ? colorScheme.onSecondaryContainer 
                        : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  title: Text(
                    DateFormat('dd日 EEEE', 'zh_CN').format(date),
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected 
                          ? colorScheme.onSecondaryContainer 
                          : colorScheme.onSurface,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  onTap: () async {
                    await _switchToDate(date);
                  },
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // 响应式布局：宽度小于800时使用Drawer
        final useDrawer = constraints.maxWidth < 800;
        
        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            leading: useDrawer
                ? IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                    tooltip: '目录',
                  )
                : null,
            title: Text(
              DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_selectedDate),
              style: theme.textTheme.titleLarge,
            ),
            actions: [
              if (!_isEditMode && _quillController.document.toPlainText().trim().isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    setState(() {
                      _isEditMode = true;
                      _quillController.readOnly = false;
                    });
                  },
                  tooltip: '编辑',
                ),
              if (_isEditMode) ...[
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () {
                    setState(() {
                      _isEditMode = false;
                      _quillController.readOnly = true;
                    });
                  },
                  tooltip: '预览',
                ),
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _saveDiary,
                  tooltip: '保存',
                ),
              ],
              if (_quillController.document.toPlainText().trim().isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteDiary,
                  tooltip: '删除',
                ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.of(context).pushNamed('/settings');
                },
                tooltip: '设置',
              ),
            ],
          ),
          drawer: useDrawer ? Drawer(
            child: Column(
              children: [
                // 日历区域
                TableCalendar(
                  firstDay: DateTime(2000),
                  lastDay: DateTime(2100),
                  focusedDay: _focusedDate,
                  selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                  calendarFormat: CalendarFormat.month,
                  locale: 'zh_CN',
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    markerDecoration: BoxDecoration(
                      color: colorScheme.tertiary,
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(color: colorScheme.error),
                  ),
                  eventLoader: (day) {
                    return _diaryDates.any((d) => isSameDay(d, day)) ? [day] : [];
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(context, day, focusedDay, colorScheme);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(context, day, focusedDay, colorScheme, isToday: true);
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(context, day, focusedDay, colorScheme, isSelected: true);
                    },
                  ),
                  onDaySelected: (selectedDay, focusedDay) async {
                    await _switchToDate(selectedDay);
                    Navigator.pop(context); // 关闭Drawer
                  },
                  onPageChanged: (focusedDay) {
                    setState(() => _focusedDate = focusedDay);
                  },
                ),
                
                Divider(height: 1, color: colorScheme.outlineVariant),
                
                Expanded(child: _buildDiaryList()),
              ],
            ),
          ) : null,
          body: Row(
            children: [
              // 左侧边栏
              if (!useDrawer)
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    border: Border(
                      right: BorderSide(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // 日历
                      TableCalendar(
                        firstDay: DateTime(2000),
                        lastDay: DateTime(2100),
                        focusedDay: _focusedDate,
                        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                        calendarFormat: CalendarFormat.month,
                        locale: 'zh_CN',
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    markerDecoration: BoxDecoration(
                      color: colorScheme.tertiary,
                      shape: BoxShape.circle,
                    ),
                    weekendTextStyle: TextStyle(color: colorScheme.error),
                  ),
                  eventLoader: (day) {
                    return _diaryDates.any((d) => isSameDay(d, day)) ? [day] : [];
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(context, day, focusedDay, colorScheme);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(context, day, focusedDay, colorScheme, isToday: true);
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return _buildCalendarDay(context, day, focusedDay, colorScheme, isSelected: true);
                    },
                  ),
                  onDaySelected: (selectedDay, focusedDay) async {
                    await _switchToDate(selectedDay);
                  },
                      onPageChanged: (focusedDay) {
                        setState(() => _focusedDate = focusedDay);
                      },
                    ),
                    
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    
                    // 日记列表
                    Expanded(
                      child: _buildDiaryList(),
                    ),
                  ],
                ),
              ),
              
              // 主内容区
              Expanded(
                child: Column(
                  children: [
                    // 编辑/预览区域
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _isEditMode
                              ? _buildEditor()
                              : _buildPreview(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// 生成指定日期的链接
  String _getDiaryLink(DateTime date) {
    return 'clipnote-note://${DateFormat('yyyy-MM-dd').format(date)}';
  }
  
  /// 复制日记链接到剪贴板
  void _copyDiaryLink(DateTime date) async {
    final link = _getDiaryLink(date);
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已复制链接: $link'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  /// 引用日记到当前编辑
  void _referenceDiary(DateTime date) {
    if (!_isEditMode) {
      setState(() => _isEditMode = true);
    }
    final link = _getDiaryLink(date);
    final dateStr = DateFormat('yyyy年MM月dd日').format(date);
    final index = _quillController.selection.baseOffset;
    _quillController.replaceText(index, 0, dateStr, null);
    _quillController.formatText(index, dateStr.length, quill.LinkAttribute(link));
  }
  
  /// 显示日记右键菜单
  void _showDiaryContextMenu(BuildContext context, DateTime date, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.copy),
            title: Text('复制链接'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          onTap: () => _copyDiaryLink(date),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.bookmark_add),
            title: Text('引用到当前日记'),
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          onTap: () => _referenceDiary(date),
        ),
      ],
    );
  }
  
  /// 编辑器 - Quill
  Widget _buildEditor() {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: quill.QuillSimpleToolbar(
              controller: _quillController,
              config: quill.QuillSimpleToolbarConfig(
                showAlignmentButtons: true,
                showBackgroundColorButton: false,
                showBoldButton: true,
                showCenterAlignment: false,
                showClearFormat: true,
                showCodeBlock: true,
                showColorButton: false,
                showFontFamily: false,
                showFontSize: false,
                showHeaderStyle: true,
                showInlineCode: true,
                showItalicButton: true,
                showJustifyAlignment: false,
                showLeftAlignment: false,
                showLink: true,
                showListBullets: true,
                showListCheck: true,
                showListNumbers: true,
                showQuote: true,
                showRightAlignment: false,
                showStrikeThrough: true,
                showUnderLineButton: true,
                embedButtons: FlutterQuillEmbeds.toolbarButtons(
                  videoButtonOptions: null,
                  cameraButtonOptions: null,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: quill.QuillEditor.basic(
                controller: _quillController,
                config: quill.QuillEditorConfig(
                  embedBuilders: [...FlutterQuillEmbeds.editorBuilders()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 预览 - 只读 Quill
  Widget _buildPreview() {
    final theme = Theme.of(context);
    
    if (_quillController.document.toPlainText().trim().isEmpty) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _isEditMode = true;
            _quillController.readOnly = false;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_note,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '点击开始写作',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(24),
      child: quill.QuillEditor.basic(
        controller: _quillController,
        config: quill.QuillEditorConfig(
          embedBuilders: [...FlutterQuillEmbeds.editorBuilders()],
          onLaunchUrl: (url) async {
            String actualUrl = url;
            if (url.startsWith('https://clipnote-note://')) {
              actualUrl = url.substring('https://'.length);
            } else if (url.startsWith('http://clipnote-note://')) {
              actualUrl = url.substring('http://'.length);
            }
            
            if (actualUrl.startsWith('clipnote-note://')) {
              final dateStr = actualUrl.substring('clipnote-note://'.length);
              
              try {
                final date = DateFormat('yyyy-MM-dd').parse(dateStr);
                await _switchToDate(date);
                return;
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('无效的日记链接: $url'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
            }
          },
        ),
      ),
    );
  }
}
