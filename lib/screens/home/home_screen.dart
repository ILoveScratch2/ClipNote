import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../../services/diary_service.dart';

/// 主界面
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DiaryService _diaryService = DiaryService();
  final TextEditingController _contentController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  List<DateTime> _diaryDates = [];
  bool _isEditMode = false; // 默认预览模式
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadDiaryDates();
    _loadDiary(_selectedDate);
  }
  
  @override
  void dispose() {
    _contentController.dispose();
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
    
    final content = await _diaryService.getDiary(date);
    _contentController.text = content ?? '';
    
    setState(() {
      _isLoading = false;
      _isEditMode = false; // 加载后默认预览模式
    });
  }
  
  /// 保存当前日记
  Future<void> _saveDiary() async {
    if (_contentController.text.trim().isEmpty) {
      return;
    }
    
    await _diaryService.saveDiary(_selectedDate, _contentController.text);
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
      _contentController.clear();
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
    if (_contentController.text.trim().isNotEmpty && _isEditMode) {
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
            '还没有日记\n开始写第一篇吧',
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
              if (!_isEditMode && _contentController.text.trim().isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    setState(() => _isEditMode = true);
                  },
                  tooltip: '编辑',
                ),
              if (_isEditMode) ...[
                IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  onPressed: () {
                    setState(() => _isEditMode = false);
                  },
                  tooltip: '预览',
                ),
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  onPressed: _saveDiary,
                  tooltip: '保存',
                ),
              ],
              if (_contentController.text.trim().isNotEmpty)
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
                    // Markdown工具栏
                    if (_isEditMode) _buildToolbar(),
                    
                    if (_isEditMode)
                      Divider(height: 1, color: colorScheme.outlineVariant),
                    
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
  
  /// Markdown工具栏
  Widget _buildToolbar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _toolButton(Icons.format_bold, '粗体', () => _insertMarkdown('**', '**')),
            _toolButton(Icons.format_italic, '斜体', () => _insertMarkdown('*', '*')),
            _toolButton(Icons.format_strikethrough, '删除线', () => _insertMarkdown('~~', '~~')),
            _toolButton(Icons.format_underline, '下划线', () => _insertMarkdown('<u>', '</u>')),
            const SizedBox(width: 8),
            _toolButton(Icons.title, '大标题', () => _insertMarkdown('# ', '')),
            _toolButton(Icons.format_size, '中标题', () => _insertMarkdown('## ', '')),
            _toolButton(Icons.text_fields, '小标题', () => _insertMarkdown('### ', '')),
            const SizedBox(width: 8),
            _toolButton(Icons.format_list_bulleted, '无序列表', () => _insertMarkdown('- ', '')),
            _toolButton(Icons.format_list_numbered, '有序列表', () => _insertMarkdown('1. ', '')),
            _toolButton(Icons.checklist, '任务列表', () => _insertMarkdown('- [ ] ', '')),
            const SizedBox(width: 8),
            _toolButton(Icons.link, '链接', () => _insertMarkdown('[', '](url)')),
            _toolButton(Icons.image_outlined, '图片', () => _insertMarkdown('![', '](url)')),
            _toolButton(Icons.code, '内联代码', () => _insertMarkdown('`', '`')),
            _toolButton(Icons.code_outlined, '代码块', () => _insertMarkdown('\n```\n', '\n```\n')),
            _toolButton(Icons.format_quote, '引用', () => _insertMarkdown('> ', '')),
            const SizedBox(width: 8),
            _toolButton(Icons.table_chart, '表格', () => _insertMarkdown('\n| 列1 | 列2 |\n|-----|-----|\n| ', ' |  |\n')),
            _toolButton(Icons.horizontal_rule, '分割线', () => _insertMarkdown('\n---\n', '')),
            _toolButton(Icons.bookmark_outline, '引用日记', () => _insertDiaryLink()),
          ],
        ),
      ),
    );
  }
  
  /// 工具栏按钮
  Widget _toolButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
    );
  }
  
  /// 插入Markdown语法
  void _insertMarkdown(String before, String after) {
    final selection = _contentController.selection;
    final text = _contentController.text;
    
    if (selection.isValid) {
      final selectedText = selection.textInside(text);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$before$selectedText$after',
      );
      
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: selection.start + before.length + selectedText.length + after.length,
        ),
      );
    } else {
      // 没有选中文本，直接插入
      final newText = text + before + after;
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length - after.length),
      );
    }
  }
  
  /// 插入日记链接
  void _insertDiaryLink() async {
    // 显示日期选择器
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('zh', 'CN'),
    );
    
    if (picked != null) {
      final link = 'clipnote-note://${DateFormat('yyyy-MM-dd').format(picked)}';
      _insertMarkdown('[${DateFormat('yyyy年MM月dd日').format(picked)}]($link)', '');
    }
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
    _insertMarkdown('[$dateStr]($link)', '');
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
  
  /// 编辑器 - 带有基础Markdown语法视觉提示
  Widget _buildEditor() {
    final theme = Theme.of(context);
    return TextField(
      controller: _contentController,
      maxLines: null,
      expands: true,
      autofocus: true,
      textAlignVertical: TextAlignVertical.top,
      style: TextStyle(
        fontSize: 16,
        height: 1.8,
        color: theme.colorScheme.onSurface,
        fontFamily: 'monospace', // 使用等宽字体方便编辑Markdown
      ),
      decoration: InputDecoration(
        hintText: '开始写日记...\n\n支持Markdown语法！',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          fontSize: 14,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(24),
      ),
    );
  }
  
  /// 预览 - 点击切换为编辑模式
  Widget _buildPreview() {
    final theme = Theme.of(context);
    
    if (_contentController.text.trim().isEmpty) {
      return GestureDetector(
        onTap: () {
          setState(() => _isEditMode = true);
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
    
    return Markdown(
      data: _contentController.text,
      selectable: true,
      padding: const EdgeInsets.all(24),
      onTapLink: (text, href, title) {
        if (href != null && href.startsWith('clipnote-note://')) {
          // 处理日记链接
          final dateStr = href.substring('clipnote-note://'.length);
          try {
            final date = DateFormat('yyyy-MM-dd').parse(dateStr);
            _switchToDate(date);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('无效的日记链接: $href'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 16,
          height: 1.8,
          color: theme.colorScheme.onSurface,
        ),
        h1: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        h2: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        h3: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
        blockquote: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
        code: TextStyle(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
