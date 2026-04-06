import 'dart:io';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import '../models/book_source.dart';
import '../services/source_manager.dart';
import '../services/network_service.dart';
import '../services/search_service.dart';
import '../services/http_service.dart';

/// 目录页结果
class TocPageResult {
  final bool success;
  final String? tocUrl;
  final String? firstChapterUrl;
  final String? error;
  final String? html;
  final String? charset;

  TocPageResult({
    required this.success,
    this.tocUrl,
    this.firstChapterUrl,
    this.error,
    this.html,
    this.charset,
  });
}

/// 书源编辑页面
class SourceEditPage extends StatefulWidget {
  const SourceEditPage({super.key});

  @override
  State<SourceEditPage> createState() => _SourceEditPageState();
}

class _SourceEditPageState extends State<SourceEditPage> {
  final SourceManager _sourceManager = SourceManager();
  final List<BookSource> _sources = [];
  BookSource? _currentSource;
  int _currentTabIndex = 0;
  bool _isLoading = true;
  bool _isLeftPanelCollapsed = false;
  final HttpService _httpService = HttpService();

  // 表单控制器
  final _sourceNameController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _searchUrlController = TextEditingController();
  final _exploreUrlController = TextEditingController();
  final _bookUrlPatternController = TextEditingController();
  final _tocUrlPatternController = TextEditingController();
  final _chapterUrlPatternController = TextEditingController();
  final _tocListController = TextEditingController();
  final _tocNameController = TextEditingController();
  final _tocUrlController = TextEditingController();
  final _contentRuleController = TextEditingController();

  // 调试测试控制器
  final _testSearchKeywordController = TextEditingController();
  final _testTocUrlController = TextEditingController();
  final _testChapterUrlController = TextEditingController();

  // 调试测试结果
  List<Map<String, String>> _testSearchResults = [];
  List<Map<String, String>> _testTocResults = [];
  String _testChapterContent = '';
  bool _isTesting = false;

  // 分类排行列表
  List<String> _exploreCategories = [];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _sourceManager.init();
    _loadSources();
  }

  Future<void> _loadSources() async {
    setState(() => _isLoading = true);
    _sources.clear();
    _sources.addAll(_sourceManager.sources);
    
    if (_sources.isNotEmpty && _currentSource == null) {
      _selectSource(_sources.first);
    }
    
    setState(() => _isLoading = false);
  }

  void _selectSource(BookSource source) {
    setState(() {
      _currentSource = source;
      _updateControllers();
    });
  }

  void _updateControllers() {
    if (_currentSource == null) return;

    _sourceNameController.text = _currentSource!.sourceName;
    _websiteUrlController.text = _currentSource!.websiteUrl;
    _searchUrlController.text = _currentSource!.searchUrl ?? '';
    _exploreUrlController.text = _currentSource!.exploreUrl ?? '';
    _bookUrlPatternController.text = _currentSource!.bookUrlPattern ?? '';
    _tocUrlPatternController.text = _currentSource!.tocUrlPattern ?? '';
    _chapterUrlPatternController.text = _currentSource!.chapterUrlPattern ?? '';
    _tocListController.text = _currentSource!.tocList ?? '';
    _tocNameController.text = _currentSource!.tocName ?? '';
    _tocUrlController.text = _currentSource!.tocUrl ?? '';
    _contentRuleController.text = _currentSource!.contentRule ?? '';

    // 加载分类排行列表
    _loadExploreCategories();
  }

  /// 加载分类排行列表
  void _loadExploreCategories() {
    _exploreCategories = [];
    _selectedCategory = null;

    if (_currentSource?.exploreUrl != null && _currentSource!.exploreUrl!.isNotEmpty) {
      final exploreUrl = _currentSource!.exploreUrl!;

      if (exploreUrl.contains('::')) {
        final groups = exploreUrl.split('&&');
        for (final group in groups) {
          final trimmedGroup = group.trim();
          if (trimmedGroup.contains('::')) {
            final parts = trimmedGroup.split('::');
            if (parts.isNotEmpty) {
              _exploreCategories.add(parts[0].trim());
            }
          }
        }
      } else {
        _exploreCategories = ['默认分类'];
      }
    }
  }

  void _updateSourceFromControllers() {
    if (_currentSource == null) return;
    
    _currentSource!.sourceName = _sourceNameController.text;
    _currentSource!.websiteUrl = _websiteUrlController.text;
    _currentSource!.searchUrl = _searchUrlController.text.isEmpty ? null : _searchUrlController.text;
    _currentSource!.exploreUrl = _exploreUrlController.text.isEmpty ? null : _exploreUrlController.text;
    _currentSource!.bookUrlPattern = _bookUrlPatternController.text.isEmpty ? null : _bookUrlPatternController.text;
    _currentSource!.tocUrlPattern = _tocUrlPatternController.text.isEmpty ? null : _tocUrlPatternController.text;
    _currentSource!.chapterUrlPattern = _chapterUrlPatternController.text.isEmpty ? null : _chapterUrlPatternController.text;
    _currentSource!.tocList = _tocListController.text.isEmpty ? null : _tocListController.text;
    _currentSource!.tocName = _tocNameController.text.isEmpty ? null : _tocNameController.text;
    _currentSource!.tocUrl = _tocUrlController.text.isEmpty ? null : _tocUrlController.text;
    _currentSource!.contentRule = _contentRuleController.text.isEmpty ? null : _contentRuleController.text;
  }

  Future<void> _addSource() async {
    final newSource = _sourceManager.createDefaultSource();
    await _sourceManager.addSource(newSource);
    _loadSources();
    _selectSource(newSource);
  }

  Future<void> _addBlankSource() async {
    final newSource = _sourceManager.createBlankSource();
    await _sourceManager.addSource(newSource);
    _loadSources();
    _selectSource(newSource);
  }

  Future<void> _saveSource() async {
    if (_currentSource == null) return;
    
    _updateSourceFromControllers();
    
    if (_currentSource!.id == null) {
      await _sourceManager.addSource(_currentSource!);
    } else {
      await _sourceManager.updateSource(_currentSource!);
    }
    
    _loadSources();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存成功')),
      );
    }
  }

  Future<void> _deleteSource(BookSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除书源"${source.sourceName}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && source.sourceName.isNotEmpty) {
      await _sourceManager.deleteSource(source.sourceName);
      _currentSource = null;
      _loadSources();
    }
  }

  Future<void> _batchVerify() async {
    final sources = _sourceManager.sources;
    if (sources.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可用的书源')),
        );
      }
      return;
    }

    final total = sources.length;
    int currentProgress = 0;

    void Function(VoidCallback)? setDialogState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, internalSetDialogState) {
          setDialogState = internalSetDialogState;
          return AlertDialog(
            title: const Text('批量校验'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('正在校验书源 ($currentProgress/$total)...'),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: total > 0 ? currentProgress / total : 0),
              ],
            ),
          );
        },
      ),
    );

    const concurrency = 5;
    for (var i = 0; i < sources.length; i += concurrency) {
      final batch = sources.skip(i).take(concurrency).toList();
      final futures = batch.map((source) => _sourceManager.verifySource(source, timeout: 20));
      await Future.wait(futures);
      currentProgress += batch.length;
      if (setDialogState != null) {
        setDialogState!(() {});
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }

    _loadSources();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('批量校验完成')),
      );
    }
  }

  Future<void> _batchDelete() async {
    final deleted = await _sourceManager.batchDeleteFailed('all');
    _loadSources();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 $deleted 个失效书源')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final leftPanelWidth = isWideScreen ? 280.0 : screenWidth * 0.38;

    return Row(
      children: [
        // 左侧书源列表（可折叠）
        if (!_isLeftPanelCollapsed)
          SizedBox(
            width: leftPanelWidth,
            child: _buildSourceListPanel(),
          ),
        // 折叠/展开按钮
        Container(
          width: 24,
          color: Colors.grey[200],
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isLeftPanelCollapsed = !_isLeftPanelCollapsed;
              });
            },
            child: Center(
              child: Icon(
                _isLeftPanelCollapsed ? Icons.chevron_right : Icons.chevron_left,
                size: 20,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
        // 右侧编辑区域
        Expanded(
          child: Column(
            children: [
              // 顶部选项卡
              _buildTopTabs(),
              // 编辑内容
              Expanded(
                child: _currentSource == null
                    ? const Center(child: Text('请选择或创建一个书源'))
                    : _currentTabIndex == 0
                        ? _buildGeneralSettings()
                        : _currentTabIndex == 1
                            ? _buildSearchSettings()
                            : _currentTabIndex == 2
                                ? _buildUrlSettings()
                                : _buildTestSettings(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建左侧书源列表面板
  Widget _buildSourceListPanel() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // 按钮区域（紧凑排列）
          Container(
            padding: EdgeInsets.all(isWideScreen ? 8 : 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildCompactButton('增加', Icons.add, _addSource),
                _buildCompactButton('空白', Icons.note_add, _addBlankSource),
                _buildCompactButton('校验', Icons.verified, _batchVerify),
              ],
            ),
          ),
          // 批量删除区域
          Container(
            padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 8 : 4, vertical: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: 'all',
                        style: const TextStyle(fontSize: 11),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('删搜索分类均失效')),
                          DropdownMenuItem(value: 'search', child: Text('删搜索失效')),
                          DropdownMenuItem(value: 'explore', child: Text('删分类失效')),
                        ],
                        onChanged: (value) {},
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isWideScreen ? 8 : 4),
                _buildCompactButton('批量删', Icons.delete, _batchDelete, small: true),
              ],
            ),
          ),
          // 书源列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sources.isEmpty
                    ? _buildEmptySourceList()
                    : _buildSourceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactButton(String label, IconData icon, VoidCallback onPressed, {bool small = false}) {
    if (small) {
      return SizedBox(
        height: 28,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 14),
          label: Text(label, style: const TextStyle(fontSize: 11)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
        ),
      );
    }
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  /// 构建空书源列表
  Widget _buildEmptySourceList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.source, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            '暂无书源',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 构建书源列表
  Widget _buildSourceList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Column(
      children: [
        // 表头
        Container(
          padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 16 : 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              // 搜索状态说明 - 上下排列
              SizedBox(
                width: 32,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search, size: 14, color: Colors.grey[600]),
                    Text('搜索', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  ],
                ),
              ),
              // 发现状态说明 - 上下排列
              SizedBox(
                width: 32,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore, size: 14, color: Colors.grey[600]),
                    Text('发现', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  ],
                ),
              ),
              SizedBox(width: isWideScreen ? 16 : 8),
              Expanded(
                child: Text(
                  '书源名称',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
        // 书源列表
        Expanded(
          child: ListView.builder(
            itemCount: _sources.length,
            itemBuilder: (context, index) {
              final source = _sources[index];
              final isSelected = _currentSource?.id == source.id;
              
              return ListTile(
                dense: true,
                selected: isSelected,
                contentPadding: EdgeInsets.symmetric(horizontal: isWideScreen ? 16 : 8),
                leading: SizedBox(
                  width: 48,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 24, child: _buildStatusIcon(source.searchStatus)),
                      SizedBox(width: 24, child: _buildStatusIcon(source.exploreStatus)),
                    ],
                  ),
                ),
                title: Text(
                  source.sourceName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _selectSource(source),
                onLongPress: () => _deleteSource(source),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建状态图标
  Widget _buildStatusIcon(int? status) {
    IconData icon;
    Color color;
    switch (status) {
      case 1:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 0:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 16);
  }

  /// 构建顶部选项卡
  Widget _buildTopTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          _buildTabButton('常规', '设置', 0),
          _buildTabButton('搜索', '设置', 1),
          _buildTabButton('网址', '识别', 2),
          _buildTabButton('总结', '测试', 3),
          const Spacer(),
          // 保存按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: _saveSource,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('保存', style: TextStyle(fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建选项卡按钮
  Widget _buildTabButton(String title1, String title2, int index) {
    final isActive = _currentTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title1,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? Colors.blue : Colors.black87,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Text(
              title2,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? Colors.blue : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建常规设置
  Widget _buildGeneralSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('网站名称', _sourceNameController, '请输入网站名称'),
          const SizedBox(height: 12),
          _buildTextField('网站网址', _websiteUrlController, '请输入完整http开头域名'),
          const SizedBox(height: 12),
          _buildDropdownField(
            '网站编码',
            _currentSource?.websiteEncoding ?? 'UTF-8',
            ['UTF-8', 'GB2312'],
            (value) {
              if (_currentSource != null && value != null) {
                setState(() => _currentSource!.websiteEncoding = value);
              }
            },
          ),
          const SizedBox(height: 16),
          _buildInfoBox('''说明：
写书源照示例输入网站名称和完整http开头域名，
网站编码一般用默认UTF8即可
编码查看方法，一般在网页源码的head前几行找charset=xxx'''),
        ],
      ),
    );
  }

  /// 构建搜索设置
  Widget _buildSearchSettings() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWideScreen ? 16 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('搜索网址', _searchUrlController, '请输入搜索网址'),
          SizedBox(height: isWideScreen ? 12 : 8),
          _buildDropdownField(
            '搜索类型',
            _currentSource?.searchType ?? 'GET',
            ['GET', 'POST'],
            (value) {
              if (_currentSource != null && value != null) {
                setState(() => _currentSource!.searchType = value);
              }
            },
          ),
          SizedBox(height: isWideScreen ? 12 : 8),
          _buildTextField('分类排行', _exploreUrlController, '格式: 分类名1::网址1&&分类名2::网址2'),
          SizedBox(height: isWideScreen ? 12 : 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInsertButton('关键字', '{key}', _searchUrlController),
              _buildInsertButton('页码', '{page}', _searchUrlController),
            ],
          ),
          SizedBox(height: isWideScreen ? 16 : 12),
          // 分类排行辅助处理区域
          Container(
            padding: EdgeInsets.all(isWideScreen ? 12 : 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '分类排行辅助处理',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: isWideScreen ? 14 : 12),
                ),
                SizedBox(height: isWideScreen ? 12 : 8),
                Text(
                  'HTML源码:',
                  style: TextStyle(fontSize: isWideScreen ? 13 : 11),
                ),
                SizedBox(height: 4),
                TextField(
                  maxLines: isWideScreen ? 6 : 8,
                  decoration: InputDecoration(
                    hintText: '粘贴类似<a href="网址1">分类1</a> 格式的分类网页源码',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  style: TextStyle(fontSize: isWideScreen ? 13 : 11),
                ),
                SizedBox(height: isWideScreen ? 12 : 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: '被替换',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isWideScreen ? 8 : 6),
                        ),
                        style: TextStyle(fontSize: isWideScreen ? 13 : 11),
                      ),
                    ),
                    SizedBox(width: isWideScreen ? 8 : 4),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: '替换为',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isWideScreen ? 8 : 6),
                        ),
                        style: TextStyle(fontSize: isWideScreen ? 13 : 11),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isWideScreen ? 12 : 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    _buildSmallButton('替换处理↑', Icons.arrow_upward, () {}),
                    _buildSmallButton('替换处理↓', Icons.arrow_downward, () {}),
                    _buildSmallButton('分类处理↑', Icons.list_alt, () {}),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: isWideScreen ? 16 : 12),
          _buildInfoBox('''说明：
GET格式：有搜索关键字就替换为{key}，有页码就替换为{page}
POST格式：基础URL?参数1=值1&参数2=值2
或 基础URL,参数1=值1&参数2=值2'''),
        ],
      ),
    );
  }

  Widget _buildSmallButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 32,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  /// 构建网址识别
  Widget _buildUrlSettings() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWideScreen ? 16 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('简介页网址', _bookUrlPatternController, '请输入简介页网址'),
          SizedBox(height: isWideScreen ? 12 : 8),
          _buildTextField('目录页网址', _tocUrlPatternController, '请输入目录页网址'),
          SizedBox(height: isWideScreen ? 12 : 8),
          _buildTextField('章节页网址', _chapterUrlPatternController, '请输入章节页网址'),
          SizedBox(height: isWideScreen ? 16 : 12),
          _buildDropdownField(
            '目录章节排序方式',
            _currentSource?.chapterOrder == 0 ? '正序' : '倒序',
            ['正序', '倒序'],
            (value) {
              if (_currentSource != null && value != null) {
                setState(() => _currentSource!.chapterOrder = value == '正序' ? 0 : 1);
              }
            },
          ),
          SizedBox(height: isWideScreen ? 16 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInsertButton('书类', '(书类)', _bookUrlPatternController),
              _buildInsertButton('书号', '(书号)', _bookUrlPatternController),
              _buildInsertButton('章号', '(章号)', _chapterUrlPatternController),
              _buildInsertButton('记一', '(记一)', _bookUrlPatternController),
              _buildInsertButton('记二', '(记二)', _bookUrlPatternController),
            ],
          ),
          SizedBox(height: isWideScreen ? 16 : 12),
          _buildInfoBox('''说明：
搜索结果跳转的是简介页，从简介页可以跳转目录页
章节页带章号和书号，可能也带书类
网址标识基本就是以上3个：(书类)(书号)(章号)'''),
        ],
      ),
    );
  }

  /// 构建插入按钮
  Widget _buildInsertButton(String label, String value, TextEditingController controller) {
    return ElevatedButton(
      onPressed: () {
        final text = controller.text;
        final selection = controller.selection;
        final newText = text.substring(0, selection.start) +
            value +
            text.substring(selection.end);
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: selection.start + value.length);
      },
      child: Text('$label: $value'),
    );
  }

  /// 构建测试设置
  Widget _buildTestSettings() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const TabBar(
              tabs: [
                Tab(text: '搜索测试'),
                Tab(text: '目录测试'),
                Tab(text: '章节测试'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSearchTest(),
                _buildTocTest(),
                _buildContentTest(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建搜索测试
  Widget _buildSearchTest() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isWideScreen ? 12 : 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text('搜索:', style: TextStyle(fontSize: isWideScreen ? 14 : 12)),
                  SizedBox(width: isWideScreen ? 8 : 4),
                  Expanded(
                    child: TextField(
                      controller: _testSearchKeywordController,
                      decoration: InputDecoration(
                        hintText: '输入书名',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isWideScreen ? 8 : 6),
                        isDense: true,
                      ),
                      style: TextStyle(fontSize: isWideScreen ? 14 : 12),
                    ),
                  ),
                  SizedBox(width: isWideScreen ? 8 : 4),
                  ElevatedButton(
                    onPressed: _isTesting ? null : _performSearchTest,
                    child: _isTesting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('搜索'),
                  ),
                ],
              ),
              SizedBox(height: isWideScreen ? 12 : 8),
              Row(
                children: [
                  Text('分类:', style: TextStyle(fontSize: isWideScreen ? 14 : 12)),
                  SizedBox(width: isWideScreen ? 8 : 4),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      hint: const Text('请选择'),
                      isDense: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isWideScreen ? 8 : 6),
                      ),
                      items: _exploreCategories.map((category) {
                        return DropdownMenuItem(value: category, child: Text(category, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: isWideScreen ? 13 : 11)));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                        if (value != null) {
                          _performCategorySearch(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _testSearchResults.isEmpty
              ? const Center(child: Text('输入书名点击搜索'))
              : Column(
                  children: [
                    // 表头
                    if (isWideScreen)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: Text('书名', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 3, child: Text('简介/目录页网址', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 2, child: Text('最新章节', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 1, child: Text('书源', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                    // 表格内容
                    Expanded(
                      child: ListView.builder(
                        itemCount: _testSearchResults.length,
                        itemBuilder: (context, index) {
                          final result = _testSearchResults[index];
                          return InkWell(
                            onTap: () {
                              final source = _currentSource;
                              if (source != null) {
                                final directoryUrl = _generateDirectoryUrl(result['url'] ?? '', source);
                                _testTocUrlController.text = directoryUrl;
                              } else {
                                _testTocUrlController.text = result['url'] ?? '';
                              }
                              DefaultTabController.of(context).animateTo(1);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 16 : 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                              ),
                              child: isWideScreen
                                  ? _buildSearchResultRowWide(result)
                                  : _buildSearchResultRowNarrow(result),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _testSearchResults.isEmpty ? null : () {
              if (_testSearchResults.isNotEmpty) {
                // 将详情页URL转换为目录页URL
                final source = _currentSource;
                if (source != null) {
                  final directoryUrl = _generateDirectoryUrl(_testSearchResults[0]['url'] ?? '', source);
                  _testTocUrlController.text = directoryUrl;
                } else {
                  _testTocUrlController.text = _testSearchResults[0]['url'] ?? '';
                }
                DefaultTabController.of(context).animateTo(1);
              }
            },
            child: const Text('尝试分析目录'),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultRowWide(Map<String, String> result) {
    return Row(
      children: [
        Expanded(flex: 2, child: Text(result['name'] ?? '', overflow: TextOverflow.ellipsis)),
        Expanded(flex: 3, child: Text(result['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 2, child: Text(result['latest_chapter'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
        Expanded(flex: 1, child: Text(result['source'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  Widget _buildSearchResultRowNarrow(Map<String, String> result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result['name'] ?? '',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          result['url'] ?? '',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (result['latest_chapter'] != null && result['latest_chapter']!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            result['latest_chapter']!,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// 执行搜索测试
  Future<void> _performSearchTest() async {
    if (_currentSource == null) return;
    final keyword = _testSearchKeywordController.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _isTesting = true);
    _testSearchResults = [];

    try {
      final source = _currentSource!;


      // 使用搜索服务执行搜索
      final searchService = SearchService();
      final result = await searchService.performSearch(
        searchUrl: source.searchUrl!,
        keyword: keyword,
        source: source,
      );

      if (result['success'] == true) {
        final List<dynamic> results = result['results'] as List<dynamic>;
        for (int i = 0; i < results.length && i < 3; i++) {
        }

        // 转换为内部格式
        final convertedResults = results.map((book) => <String, String>{
          'name': (book['name'] ?? '').toString(),
          'url': (book['url'] ?? '').toString(),
          'latest_chapter': (book['latest_chapter'] ?? '').toString(),
          'source': source.sourceName,
        }).toList();

        setState(() => _testSearchResults = convertedResults);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('搜索完成，找到 ${results.length} 个结果')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('搜索失败: ${result['error']}')),
          );
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      setState(() => _isTesting = false);
    }
  }

  /// 执行分类排行搜索
  Future<void> _performCategorySearch(String category) async {
    if (_currentSource == null) return;


    setState(() => _isTesting = true);
    _testSearchResults = [];

    try {
      // 1. 获取分类对应的URL
      final categoryUrl = _getCategoryUrl(category);
      if (categoryUrl == null || categoryUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到该分类的URL')),
          );
        }
        return;
      }


      // 2. 访问分类URL获取HTML
      final networkService = NetworkService();
      final html = await networkService.get(
        categoryUrl,
        encoding: _currentSource!.websiteEncoding,
      );


      // 3. 解析HTML获取书籍列表（分类搜索不使用关键词过滤）
      final results = _parseCategoryResults(html, _currentSource!, category);


      setState(() => _testSearchResults = results);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分类"$category"找到 ${results.length} 本书')),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分类搜索失败: $e')),
        );
      }
    } finally {
      setState(() => _isTesting = false);
    }
  }

  /// 解析分类页面结果 - 与搜索结果解析类似，但不使用关键词过滤
  List<Map<String, String>> _parseCategoryResults(String html, BookSource source, String category) {

    final results = <Map<String, String>>[];
    final processedUrls = <String>{};

    // 使用正则表达式提取所有a标签
    final aTagPattern = RegExp(
      '<a\\s+[^>]*href\\s*=\\s*["\']?([^"\'>\\s]+)["\']?[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final aTagMatches = aTagPattern.allMatches(html);

    for (final match in aTagMatches) {
      final href = match.group(1) ?? '';
      final aTagContent = match.group(2) ?? '';

      if (href.isEmpty) continue;

      // 构建完整URL
      String fullUrl = href;
      if (!href.startsWith('http')) {
        fullUrl = NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
      }

      // 去重
      if (processedUrls.contains(fullUrl)) continue;

      // 验证URL是否符合书源的简介页网址规则
      final isValid = _validateUrl(fullUrl, source.bookUrlPattern);
      if (!isValid) continue;

      processedUrls.add(fullUrl);

      // 提取书名和最新章节
      String bookName = '';
      String latestChapter = '';

      // 提取所有文本节点 >(内容)<
      final textPattern = RegExp('>([^<]*?)<', caseSensitive: false, dotAll: true);
      final textMatches = textPattern.allMatches(aTagContent);

      // 收集所有非空文本节点
      final allTexts = <String>[];
      for (final textMatch in textMatches) {
        final text = textMatch.group(1)?.trim() ?? '';
        if (text.isNotEmpty) {
          allTexts.add(text);
        }
      }

      // 提取书名（通常是第一个较短的文本）
      for (final text in allTexts) {
        if (text.length >= 2 && text.length <= 50 && !text.contains('|')) {
          bookName = text;
          break;
        }
      }

      // 提取最新章节（包含"更新"或"最新"的文本）
      for (final text in allTexts) {
        if (text.contains('更新') || text.contains('最新')) {
          latestChapter = text;
          break;
        }
      }

      // 确保书名不为空
      if (bookName.isEmpty) continue;

      results.add({
        'name': bookName,
        'url': fullUrl,
        'latest_chapter': latestChapter,
        'source': source.sourceName,
      });

      if (results.length >= 50) break; // 限制结果数量
    }

    return results;
  }

  /// 根据分类名称获取对应的URL
  String? _getCategoryUrl(String category) {
    if (_currentSource?.exploreUrl == null) return null;

    final exploreUrl = _currentSource!.exploreUrl!;

    if (exploreUrl.contains('::')) {
      final groups = exploreUrl.split('&&');
      for (final group in groups) {
        final trimmedGroup = group.trim();
        if (trimmedGroup.contains('::')) {
          final parts = trimmedGroup.split('::');
          if (parts.length >= 2 && parts[0].trim() == category) {
            var url = parts[1].trim();
            url = url.replaceAll('{page}', '1');
            return url;
          }
        }
      }
    }

    if (category == '默认分类') {
      var url = exploreUrl.trim();
      url = url.replaceAll('{page}', '1');
      return url;
    }

    return null;
  }

  /// 解析搜索结果 - 参考kuaibu_core.py实现
  List<Map<String, String>> _parseSearchResults(String html, BookSource source, String keyword) {

    final results = <Map<String, String>>[];
    final processedUrls = <String>{};

    // 方法1：使用正则表达式提取所有a标签，然后验证URL
    // 匹配a标签：支持多种href格式
    final aTagPattern = RegExp(
      '<a\\s+[^>]*href\\s*=\\s*["\']?([^"\'>\\s]+)["\']?[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final aTagMatches = aTagPattern.allMatches(html);

    int method1Checked = 0;
    int method1ValidUrl = 0;
    int method1PassedKeyword = 0;

    for (final match in aTagMatches) {
      final href = match.group(1) ?? '';
      final aTagContent = match.group(2) ?? '';

      if (href.isEmpty) continue;
      method1Checked++;

      // 构建完整URL
      String fullUrl = href;
      if (!href.startsWith('http')) {
        fullUrl = NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
      }

      // 去重
      if (processedUrls.contains(fullUrl)) continue;

      // 验证URL是否符合书源的简介页网址规则
      final isValid = _validateUrl(fullUrl, source.bookUrlPattern);
      if (!isValid) continue;

      method1ValidUrl++;
      processedUrls.add(fullUrl);

      // 提取书名和最新章节 - 通用方法：提取a标签内所有文本节点，按内容特征分类
      String bookName = '';
      String latestChapter = '';
      
      // 提取所有文本节点 >(内容)<
      final textPattern = RegExp('>([^<]*?)<', caseSensitive: false, dotAll: true);
      final textMatches = textPattern.allMatches(aTagContent);
      
      // 收集所有非空文本节点
      final allTexts = <String>[];
      for (final textMatch in textMatches) {
        final text = textMatch.group(1)?.trim() ?? '';
        if (text.isNotEmpty) {
          allTexts.add(text);
        }
      }
      
      // 第一遍：提取特征明显的（最新章节、作者）
      final remainingTexts = <String>[];
      for (final text in allTexts) {
        // 检查是否是最新章节
        if (text.contains('更新：') || text.contains('最新')) {
          if (text.contains('更新：')) {
            final parts = text.split('更新：');
            if (parts.length > 1) {
              latestChapter = parts[1].trim();
            }
          } else if (text.contains('最新')) {
            final parts = text.split('最新');
            if (parts.length > 1) {
              latestChapter = parts[1].trim().replaceFirst(RegExp('^[：:]'), '');
            }
          }
          // 已分类，不加入剩余列表
          continue;
        }
        
        // 检查是否是作者信息（特征：包含"作者："）
        if (text.contains('作者：')) {
          // 已分类，不加入剩余列表
          continue;
        }
        
        // 其他文本加入剩余列表待处理
        remainingTexts.add(text);
      }
      
      // 第二遍：从剩余文本中提取书名
      for (final text in remainingTexts) {
        // 书名通常是较短的文本（2-30字符），且不包含|
        if (text.length >= 2 && text.length <= 30 && !text.contains('|')) {
          if (keyword.isEmpty || text.toLowerCase().contains(keyword.toLowerCase())) {
            bookName = text;
            break;
          }
        }
      }
      
      // 如果还没找到书名，放宽条件
      if (bookName.isEmpty && keyword.isNotEmpty) {
        for (final text in remainingTexts) {
          // 只要包含关键词就认为是书名
          if (text.toLowerCase().contains(keyword.toLowerCase())) {
            bookName = text;
            break;
          }
        }
      }
      

      // 确保书名不为空且包含搜索关键字
      if (bookName.isEmpty) continue;
      if (keyword.isNotEmpty && !bookName.toLowerCase().contains(keyword.toLowerCase())) {
        continue;
      }

      method1PassedKeyword++;

      results.add({
        'name': bookName,
        'url': fullUrl,
        'latest_chapter': latestChapter,
        'source': source.sourceName,
      });

      if (results.length >= 20) break; // 限制结果数量
    }


    // 方法2：如果方法1没有找到结果，尝试更宽松的匹配
    if (results.isEmpty) {
      // 提取所有href
      final hrefPattern = RegExp('href=["\']([^"\']+)["\']', caseSensitive: false);
      final hrefMatches = hrefPattern.allMatches(html);

      for (final match in hrefMatches) {
        final href = match.group(1) ?? '';
        if (href.isEmpty) continue;

        // 构建完整URL
        String fullUrl = href;
        if (!href.startsWith('http')) {
          fullUrl = NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
        }

        // 去重
        if (processedUrls.contains(fullUrl)) continue;

        // 验证URL
        if (!_validateUrl(fullUrl, source.bookUrlPattern)) continue;

        processedUrls.add(fullUrl);

        // 查找包含该URL的a标签内容
        // 使用更宽松的模式匹配
        final pattern = RegExp(
          '<a[^>]*href=["\']?${RegExp.escape(href)}["\']?[^>]*>([\\s\\S]*?)</a>',
          caseSensitive: false,
        );
        final aMatch = pattern.firstMatch(html);

        if (aMatch != null) {
          String bookName = _extractTextFromHtml(aMatch.group(1) ?? '');

          if (bookName.isNotEmpty && keyword.isNotEmpty &&
              bookName.toLowerCase().contains(keyword.toLowerCase())) {
            results.add({
              'name': bookName,
              'url': fullUrl,
              'latest_chapter': '',
              'source': source.sourceName,
            });

            if (results.length >= 20) break;
          }
        }
      }
    }

    // 方法3：最后尝试，直接提取所有包含关键字的链接
    if (results.isEmpty && keyword.isNotEmpty) {
      final pattern = RegExp(
        '<a[^>]*href=["\']([^"\']*)["\'][^>]*>([^<]*${RegExp.escape(keyword)}[^<]*)</a>',
        caseSensitive: false,
      );
      final matches = pattern.allMatches(html);

      for (final match in matches.take(10)) {
        final url = match.group(1) ?? '';
        final title = (match.group(2) ?? '').trim();

        if (url.isNotEmpty && title.isNotEmpty) {
          String fullUrl = url.startsWith('http') ? url
              : NetworkService().convertToAbsoluteUrl(url, source.websiteUrl);

          if (!processedUrls.contains(fullUrl)) {
            processedUrls.add(fullUrl);
            results.add({
              'name': title,
              'url': fullUrl,
              'latest_chapter': '',
              'source': source.sourceName,
            });
          }
        }
      }
    }

    return results;
  }

  /// 从HTML内容中提取纯文本
  String _extractTextFromHtml(String html) {
    // 移除所有HTML标签
    var text = html.replaceAll(RegExp('<[^>]+>'), '');
    // 解码HTML实体
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&quot;', '"');
    // 清理空白字符
    text = text.replaceAll(RegExp('\\s+'), ' ').trim();
    return text;
  }

  /// 验证URL是否匹配给定的模式
  bool _validateUrl(String url, String? pattern) {

    if (pattern == null || pattern.isEmpty) {
      return true;
    }

    // 将模式转换为正则表达式
    String regex = pattern;
    regex = regex.replaceAll('(书类)', '[a-zA-Z0-9]+');
    regex = regex.replaceAll('(书号)', '[a-zA-Z0-9]+');
    regex = regex.replaceAll('(章号)', '[a-zA-Z0-9]+');
    regex = regex.replaceAll('(记一)', '[a-zA-Z0-9]+');
    regex = regex.replaceAll('(记二)', '[a-zA-Z0-9]+');


    try {
      final regExp = RegExp(regex, caseSensitive: false);
      final result = regExp.hasMatch(url);
      return result;
    } catch (e) {
      return true;
    }
  }

  /// 构建目录测试
  Widget _buildTocTest() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isWideScreen ? 12 : 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Text('目录:', style: TextStyle(fontSize: isWideScreen ? 14 : 12)),
              SizedBox(width: isWideScreen ? 8 : 4),
              Expanded(
                child: TextField(
                  controller: _testTocUrlController,
                  decoration: InputDecoration(
                    hintText: '输入目录页网址',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isWideScreen ? 8 : 6),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: isWideScreen ? 14 : 12),
                ),
              ),
              SizedBox(width: isWideScreen ? 8 : 4),
              ElevatedButton(
                onPressed: _isTesting ? null : _performTocTest,
                child: _isTesting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('分析'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _testTocResults.isEmpty
              ? const Center(child: Text('输入目录网址点击分析'))
              : Column(
                  children: [
                    // 表头
                    if (isWideScreen)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: Text('章节标题', style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 3, child: Text('章节地址', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                    // 表格内容
                    Expanded(
                      child: ListView.builder(
                        itemCount: _testTocResults.length,
                        itemBuilder: (context, index) {
                          final result = _testTocResults[index];
                          return InkWell(
                            onTap: () {
                              _testChapterUrlController.text = result['url'] ?? '';
                              DefaultTabController.of(context).animateTo(2);
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 16 : 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                              ),
                              child: isWideScreen
                                  ? Row(
                                      children: [
                                        Expanded(flex: 2, child: Text(result['title'] ?? '', overflow: TextOverflow.ellipsis)),
                                        Expanded(flex: 3, child: Text(result['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                                      ],
                                    )
                                  : _buildTocResultRowNarrow(result),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _testTocResults.isEmpty ? null : () {
              if (_testTocResults.isNotEmpty) {
                _testChapterUrlController.text = _testTocResults[0]['url'] ?? '';
                DefaultTabController.of(context).animateTo(2);
              }
            },
            child: const Text('分析章节'),
          ),
        ),
      ],
    );
  }

  /// 执行目录测试
  Future<void> _performTocTest() async {
    if (_currentSource == null) return;
    var url = _testTocUrlController.text.trim();
    if (url.isEmpty) return;


    setState(() => _isTesting = true);
    _testTocResults = [];

    try {
      final networkService = NetworkService();
      final source = _currentSource!;


      // 将简介页URL转换为目录页URL
      url = _generateDirectoryUrl(url, source);

      // 用于存储目录页网址的数组，防止下一页循环
      final processedUrls = <String>{url};
      var allResults = <Map<String, String>>[];
      var currentUrl = url;
      var pageCount = 0;
      const maxPages = 5; // 最多解析5页
      bool hasMorePages = false;

      while (currentUrl.isNotEmpty && pageCount < maxPages) {

        final html = await networkService.get(
          currentUrl,
          encoding: source.websiteEncoding,
        );


        // 解析目录
        final results = _parseTocResults(html, source);

        // 添加到总结果
        for (final result in results) {
          if (!allResults.any((r) => r['url'] == result['url'])) {
            allResults.add(result);
          }
        }

        // 查找下一页
        final nextPageUrl = _findNextPageUrl(html, currentUrl, source);
        if (nextPageUrl != null && !processedUrls.contains(nextPageUrl)) {
          processedUrls.add(nextPageUrl);
          currentUrl = nextPageUrl;
          pageCount++;
          // 检查是否达到上限但还有下一页
          if (pageCount >= maxPages) {
            hasMorePages = true;
          }
        } else {
          break;
        }
      }

      for (int i = 0; i < allResults.length && i < 3; i++) {
      }

      setState(() => _testTocResults = allResults);

      if (mounted) {
        String message = '分析完成，找到 ${allResults.length} 个章节';
        if (hasMorePages) {
          message += '（目录分页超过$maxPages页，仅预览前$maxPages页）';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析目录失败: $e')),
        );
      }
    } finally {
      setState(() => _isTesting = false);
    }
  }

  /// 查找下一页URL - 使用html包（类似jsoup）
  String? _findNextPageUrl(String html, String currentUrl, BookSource source) {
    
    try {
      // 使用html包解析HTML（类似jsoup）
      final document = parse(html);
      
      // 1. 优先查找id="pt_next"或id="next"的a标签
      final nextLink = document.querySelector('a#pt_next, a#next');
      if (nextLink != null) {
        final href = nextLink.attributes['href'];
        if (href != null && href.isNotEmpty && !href.startsWith('javascript:') && !href.startsWith('#')) {
          return NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
        }
      }
      
      // 2. 查找class包含"next"、"down"、"page"的a标签
      final classLinks = document.querySelectorAll('a.next, a.js_page_down, a.Readpage_down, a.page-next, a[rel="next"]');
      for (final link in classLinks) {
        final href = link.attributes['href'];
        if (href != null && href.isNotEmpty && !href.startsWith('javascript:') && !href.startsWith('#')) {
          return NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
        }
      }
      
      // 3. 查找包含"下一页"、"下页"文本的a标签
      final allLinks = document.querySelectorAll('a');
      for (final link in allLinks) {
        final text = link.text.trim();
        if (text.contains('下一页') || text.contains('下页') || text.contains('下一章')) {
          final href = link.attributes['href'];
          if (href != null && href.isNotEmpty && !href.startsWith('javascript:') && !href.startsWith('#')) {
            return NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
          }
        }
      }
      
    } catch (e) {
    }

    // 4. 尝试从当前URL推断下一页（回退方案）
    // 匹配 index_1.html, page-2, ?page=3, _4.html 等格式
    if (currentUrl.contains('index_') || currentUrl.contains('page-') || 
        currentUrl.contains('?page=') || RegExp(r'_\d+\.html$').hasMatch(currentUrl)) {
      int? currentPage = 1;
      String nextUrl = currentUrl;
      
      if (currentUrl.contains('index_')) {
        final match = RegExp(r'index_(\d+)\.html').firstMatch(currentUrl);
        if (match != null) {
          currentPage = int.tryParse(match.group(1) ?? '1');
          nextUrl = currentUrl.replaceFirst(
            'index_${match.group(1)}.html', 
            'index_${(currentPage ?? 1) + 1}.html'
          );
        }
      } else if (currentUrl.contains('page-')) {
        final match = RegExp(r'page-(\d+)').firstMatch(currentUrl);
        if (match != null) {
          currentPage = int.tryParse(match.group(1) ?? '1');
          nextUrl = currentUrl.replaceFirst(
            'page-${match.group(1)}', 
            'page-${(currentPage ?? 1) + 1}'
          );
        }
      } else if (currentUrl.contains('?page=')) {
        final match = RegExp(r'\?page=(\d+)').firstMatch(currentUrl);
        if (match != null) {
          currentPage = int.tryParse(match.group(1) ?? '1');
          nextUrl = currentUrl.replaceFirst(
            '?page=${match.group(1)}', 
            '?page=${(currentPage ?? 1) + 1}'
          );
        }
      } else {
        final match = RegExp(r'_(\d+)\.html$').firstMatch(currentUrl);
        if (match != null) {
          currentPage = int.tryParse(match.group(1) ?? '1');
          nextUrl = currentUrl.replaceFirst(
            '_${match.group(1)}.html', 
            '_${(currentPage ?? 1) + 1}.html'
          );
        }
      }
      
      if (nextUrl != currentUrl) {
        return nextUrl;
      }
    }

    return null;
  }

  /// 根据简介页URL生成目录页URL
  String _generateDirectoryUrl(String introUrl, BookSource source) {
    // 如果目录页URL模式和简介页URL模式相同，则直接返回简介页URL
    if (source.tocUrlPattern == source.bookUrlPattern) {
      return introUrl;
    }

    // 尝试从简介页URL中提取组件
    final components = _extractUrlComponents(introUrl, source.bookUrlPattern);
    if (components == null) {
      // 如果无法提取组件，尝试直接检查目录页URL是否只是在简介页URL基础上添加内容
      if (source.tocUrlPattern?.endsWith('/all.html') == true &&
          source.bookUrlPattern?.endsWith('/') == true) {
        var cleanUrl = introUrl;
        while (cleanUrl.endsWith('/')) {
          cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
        }
        return '$cleanUrl/all.html';
      }
      return introUrl;
    }

    // 构建目录页URL
    var directoryUrl = source.tocUrlPattern ?? '';

    // 替换组件（只使用简化格式）
    components.forEach((key, value) {
      directoryUrl = directoryUrl.replaceAll('($key)', value);
    });

    // 如果目录页URL是完整URL，则直接返回
    if (directoryUrl.startsWith('http')) {
      return directoryUrl;
    }

    // 否则，拼接完整URL
    var baseUrl = source.websiteUrl;
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return '$baseUrl$directoryUrl';
  }

  /// 从URL中提取组件
  Map<String, String>? _extractUrlComponents(String url, String? pattern) {
    if (pattern == null || pattern.isEmpty) return null;

    // 将模式转换为正则表达式
    String regex = pattern;
    
    // 先保存组件名称和顺序
    final componentNames = <String>[];
    final componentPattern = RegExp(r'\((书类|书号|章号|记一|记二)\)');
    for (final match in componentPattern.allMatches(pattern)) {
      componentNames.add(match.group(1)!);
    }
    
    // 替换为捕获组
    regex = regex.replaceAll('(书类)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(书号)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(章号)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(记一)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(记二)', '([a-zA-Z0-9_-]+)');

    // 转义特殊字符（但不要转义已经转义的）
    regex = regex.replaceAllMapped(
      RegExp(r'(?<!\\)\.'),
      (match) => '\\.',
    );
    regex = regex.replaceAllMapped(
      RegExp(r'(?<!\\)\/'),
      (match) => '\\/',
    );


    try {
      final regExp = RegExp(regex, caseSensitive: false);
      final match = regExp.firstMatch(url);

      if (match != null) {
        final components = <String, String>{};
        for (var i = 0; i < componentNames.length && i < match.groupCount; i++) {
          final value = match.group(i + 1);
          if (value != null) {
            components[componentNames[i]] = value;
          }
        }
        return components.isNotEmpty ? components : null;
      } else {
      }
    } catch (e, stackTrace) {
    }

    return null;
  }

  /// 解析目录结果 - 参考kuaibu_core.py实现
  List<Map<String, String>> _parseTocResults(String html, BookSource source) {
    final results = <Map<String, String>>[];
    final processedUrls = <String>{};

    // 使用通用正则表达式提取章节链接和标题
    final chapterPattern = RegExp(
      'href\\s*=["\'\\s]*([\\w/:\\\-\\.\\?&=]+)["\'\\s]*[^>]*>(.*?)<',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = chapterPattern.allMatches(html);

    for (final match in matches) {
      final href = match.group(1) ?? '';
      var title = match.group(2) ?? '';

      // 清理标题
      title = title.replaceAll(RegExp('\\s+'), ' ').trim();
      if (title.isEmpty) continue;

      // 排除导航链接
      final navTexts = ['上一页', '下一页', '尾页', '首页', '返回', '目录', '末页', '上一章', '下一章'];
      if (navTexts.any((nav) => title.contains(nav))) continue;

      // 处理相对URL和绝对URL
      String fullUrl;
      if (href.startsWith('http')) {
        fullUrl = href;
      } else {
        fullUrl = NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
      }

      // 验证URL是否与章节页网址规则匹配
      if (!_validateUrl(fullUrl, source.chapterUrlPattern)) continue;

      // 去重
      if (processedUrls.contains(fullUrl)) continue;
      processedUrls.add(fullUrl);

      results.add({
        'title': title,
        'url': fullUrl,
        'status': '未下载',
      });
    }

    return results;
  }

  /// 构建章节测试
  Widget _buildContentTest() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isWideScreen ? 12 : 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Text('章节:', style: TextStyle(fontSize: isWideScreen ? 14 : 12)),
              SizedBox(width: isWideScreen ? 8 : 4),
              Expanded(
                child: TextField(
                  controller: _testChapterUrlController,
                  decoration: InputDecoration(
                    hintText: '输入章节页网址',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isWideScreen ? 8 : 6),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: isWideScreen ? 14 : 12),
                ),
              ),
              SizedBox(width: isWideScreen ? 8 : 4),
              ElevatedButton(
                onPressed: _isTesting ? null : _performContentTest,
                child: _isTesting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('分析'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _testChapterContent.isEmpty
              ? const Center(child: Text('输入章节网址点击分析'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isWideScreen ? 16 : 12),
                  child: Text(_testChapterContent, style: TextStyle(fontSize: isWideScreen ? 14 : 13)),
                ),
        ),
      ],
    );
  }

  Widget _buildTocResultRowNarrow(Map<String, String> result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result['title'] ?? '',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          result['url'] ?? '',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// 执行章节测试
  Future<void> _performContentTest() async {
    if (_currentSource == null) return;
    final url = _testChapterUrlController.text.trim();
    if (url.isEmpty) return;


    setState(() => _isTesting = true);
    _testChapterContent = '';

    try {
      final networkService = NetworkService();
      final source = _currentSource!;


      // 用于防止分页循环
      final processedUrls = <String>{url};
      var allContent = StringBuffer();
      var currentUrl = url;
      var pageCount = 0;
      const maxPages = 10; // 最多解析10页

      while (currentUrl.isNotEmpty && pageCount < maxPages) {

        // 非第一页时添加延迟，避免请求过快被服务器拒绝
        if (pageCount > 0) {
          await Future.delayed(const Duration(milliseconds: 500));
        }

        String html = '';
        int retryCount = 0;
        const maxRetries = 3;
        bool fetchSuccess = false;
        
        while (retryCount < maxRetries) {
          try {
            // 第一页不传递Referer，后续页传递前一页URL作为Referer
            final referer = pageCount > 0 ? processedUrls.last : null;
            html = await networkService.get(
              currentUrl,
              encoding: source.websiteEncoding,
              referer: referer,
            );
            fetchSuccess = true;
            break; // 成功获取，跳出重试循环
          } catch (e) {
            retryCount++;
            
            if (retryCount >= maxRetries) {
              // 重试次数用尽
              if (pageCount == 0) {
                rethrow; // 第一页失败，抛出错误
              }
              // 后续页失败，终止分页但保留已获取内容
              break;
            }
            
            // 等待后重试
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          }
        }
        
        // 如果获取失败，终止循环
        if (!fetchSuccess) {
          break;
        }


        // 解析章节内容和下一页URL
        final result = _parseChapterContentWithNextPage(html, source, currentUrl);
        final content = result['content'] ?? '';
        final nextPageUrl = result['nextPageUrl'];


        // 添加内容（去重检查）
        if (content.isNotEmpty) {
          if (allContent.isNotEmpty) {
            allContent.write('\n\n');
          }
          allContent.write(content);
        }

        // 检查是否有下一页
        if (nextPageUrl != null && 
            nextPageUrl.isNotEmpty && 
            !processedUrls.contains(nextPageUrl) &&
            nextPageUrl != currentUrl) {
          processedUrls.add(nextPageUrl);
          currentUrl = nextPageUrl;
          pageCount++;
        } else {
          break;
        }
      }

      final finalContent = allContent.toString();

      setState(() => _testChapterContent = finalContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('章节解析成功，共${pageCount + 1}页')),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析章节失败: $e')),
        );
      }
    } finally {
      setState(() => _isTesting = false);
    }
  }

  /// 解析章节内容 - 使用html包实现类似jsoup的解析
  /// 优先级：1.内置常用模板 → 2.p标签模式 → 3.最大中文块 → 4.body兜底
  String _parseChapterContent(String html, BookSource source, String chapterUrl) {
    
    try {
      // 使用html包解析HTML
      final document = parse(html);
      
      // ========== 第1步：尝试内置常用模板 ==========
      final commonSelectors = [
        '#content', '#nr1', '#htmlContent', '#chaptercontent', '#nr',
        '#booktxt', '#TextContent', '#article', '#acontent', '#BookText',
        '#ChapterContents', '#novelcontent', '#txt', '#content1', '#book_text',
        '#cont-body', '#text', '.content', '.read-content', '.con',
        '.readcontent', '.page-content', '.chapter', '.article',
        '.chapter_content',
      ];
      
      for (final selector in commonSelectors) {
        final element = document.querySelector(selector);
        if (element != null) {
          final content = element.text;
          if (content.isNotEmpty && content.length > 50) {
            return _cleanChapterContent(content);
          }
        }
      }
      
      // ========== 第2步：p标签模式 ==========
      final pElements = document.querySelectorAll('p');
      if (pElements.isNotEmpty) {
        final buffer = StringBuffer();
        for (final p in pElements) {
          final text = p.text.trim();
          if (text.isNotEmpty && text.length > 10) {
            buffer.writeln(text);
          }
        }
        final pContent = buffer.toString();
        if (pContent.isNotEmpty && pContent.length > 100) {
          return _cleanChapterContent(pContent);
        }
      }
      
      // ========== 第3步：最大中文块 ==========
      final allElements = document.querySelectorAll('*');
      String bestContent = '';
      int maxChineseLength = 0;
      
      for (final elem in allElements) {
        final text = elem.text;
        // 计算中文字符数量
        final chineseChars = RegExp(r'[\u4e00-\u9fa5]').allMatches(text).length;
        if (chineseChars > maxChineseLength && text.length > 200) {
          maxChineseLength = chineseChars;
          bestContent = text;
        }
      }
      
      if (bestContent.isNotEmpty) {
        return _cleanChapterContent(bestContent);
      }
      
      // ========== 第4步：body兜底 ==========
      final body = document.querySelector('body');
      if (body != null) {
        final bodyText = body.text;
        if (bodyText.isNotEmpty) {
          return _cleanChapterContent(bodyText);
        }
      }
      
      // 最后兜底：返回整个文档文本
      final docText = document.documentElement?.text ?? '';
      if (docText.isNotEmpty) {
        return _cleanChapterContent(docText);
      }
      
    } catch (e, stackTrace) {
    }

    // 如果html包解析失败，回退到智能提取方法
    return _smartExtractContent(html);
  }

  /// 解析章节内容和下一页URL - 使用html包（类似jsoup）
  Map<String, String?> _parseChapterContentWithNextPage(String html, BookSource source, String chapterUrl) {
    // 获取章节内容
    final content = _parseChapterContent(html, source, chapterUrl);
    
    // 查找下一页URL
    String? nextPageUrl;
    
    
    try {
      // 使用html包解析HTML（类似jsoup）
      final document = parse(html);
      
      // 1. 优先查找id="pt_next"的a标签（博仕书屋等网站使用）
      final ptNextLink = document.querySelector('a#pt_next');
      if (ptNextLink != null) {
        final href = ptNextLink.attributes['href'];
        if (href != null && href.isNotEmpty && !href.startsWith('javascript:') && !href.startsWith('#')) {
          nextPageUrl = NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
        }
      }
      
      // 2. 查找class包含"next"或"down"的a标签
      if (nextPageUrl == null) {
        final nextLinks = document.querySelectorAll('a.js_page_down, a.Readpage_down, a.next, a[rel="next"]');
        for (final link in nextLinks) {
          final href = link.attributes['href'];
          if (href != null && href.isNotEmpty && !href.startsWith('javascript:') && !href.startsWith('#')) {
            nextPageUrl = NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
            break;
          }
        }
      }
      
      // 3. 查找包含"下一页"、"下页"文本的a标签
      if (nextPageUrl == null) {
        final allLinks = document.querySelectorAll('a');
        for (final link in allLinks) {
          final text = link.text.trim();
          if (text.contains('下一页') || text.contains('下页') || text.contains('下一章')) {
            final href = link.attributes['href'];
            if (href != null && href.isNotEmpty && !href.startsWith('javascript:') && !href.startsWith('#')) {
              nextPageUrl = NetworkService().convertToAbsoluteUrl(href, source.websiteUrl);
              break;
            }
          }
        }
      }
      
    } catch (e) {
    }
    
    // 4. 尝试从当前URL推断下一页（章节内分页）
    if (nextPageUrl == null) {
      // 匹配 _1.html, _2.html 等格式
      if (RegExp(r'_\d+\.html$').hasMatch(chapterUrl)) {
        final match = RegExp(r'_(\d+)\.html$').firstMatch(chapterUrl);
        if (match != null) {
          final currentPage = int.tryParse(match.group(1) ?? '1') ?? 1;
          nextPageUrl = chapterUrl.replaceFirst(
            '_${match.group(1)}.html', 
            '_${currentPage + 1}.html'
          );
        }
      }
    }
    
    // 验证下一页URL是否与当前章节相关（避免跳到下一章）
    if (nextPageUrl != null) {
      // 提取当前URL的章节基础路径（不含分页号）
      final currentBase = chapterUrl.replaceAll(RegExp(r'_\d+\.html$'), '');
      final nextBase = nextPageUrl.replaceAll(RegExp(r'_\d+\.html$'), '');
      
      // 如果基础路径相同，认为是同一章的分页
      if (currentBase == nextBase || nextPageUrl.contains(chapterUrl.replaceAll('.html', ''))) {
      } else {
        nextPageUrl = null;
      }
    }
    
    return {
      'content': content,
      'nextPageUrl': nextPageUrl,
    };
  }

  /// 清理章节内容 - 改进排版处理
  String _cleanChapterContent(String content) {
    // 首先处理特殊标签的换行
    // 将<br>、<br/>、<br />标签转换为换行符
    content = content.replaceAll(RegExp('<br\\s*/?>', caseSensitive: false), '\n');
    
    // 将<div>标签转换为换行符（用于段落分隔）
    content = content.replaceAll(RegExp('<div[^>]*>', caseSensitive: false), '');
    content = content.replaceAll(RegExp('</div>', caseSensitive: false), '\n');

    // 将<p>标签处理：开始标签转空，结束标签转换行
    content = content.replaceAll(RegExp('<p[^>]*>', caseSensitive: false), '');
    content = content.replaceAll(RegExp('</p>', caseSensitive: false), '\n');

    // 移除所有其他HTML标签
    content = content.replaceAll(RegExp('<[^>]+>'), '');

    // 解码HTML实体
    content = content.replaceAll('&nbsp;', ' ');
    content = content.replaceAll('&lt;', '<');
    content = content.replaceAll('&gt;', '>');
    content = content.replaceAll('&amp;', '&');
    content = content.replaceAll('&quot;', '"');
    content = content.replaceAll('&apos;', "'");
    content = content.replaceAll('&#39;', "'");
    content = content.replaceAll('&#x27;', "'");
    content = content.replaceAll('&#x2F;', '/');
    content = content.replaceAll('&#47;', '/');

    // 移除开头的网站地址等广告信息
    if (content.contains('本站最新域名')) {
      content = content.split('本站最新域名')[1];
      if (content.contains('\n')) {
        content = content.substring(content.indexOf('\n') + 1);
      }
    }

    if (content.contains('天才一秒记住本站地址：')) {
      content = content.split('天才一秒记住本站地址：')[1];
      if (content.contains('https://')) {
        content = content.substring(content.indexOf('https://'));
        final slashIndex = content.indexOf('/');
        if (slashIndex > 0) {
          content = content.substring(slashIndex);
          final secondSlashIndex = content.indexOf('/', 1);
          if (secondSlashIndex > 0) {
            content = content.substring(secondSlashIndex);
          }
        }
      }
      content = content.replaceAll('最快更新！无广告！', '');
    }

    // 移除末尾的章节错误报送信息
    if (content.contains('章节错误,点此报送(免注册)')) {
      content = content.split('章节错误,点此报送(免注册)')[0];
    }

    // 处理连续空白字符
    // 将多个空格替换为单个空格
    content = content.replaceAll(RegExp(' {2,}'), ' ');
    // 将制表符替换为空格
    content = content.replaceAll('\t', ' ');
    
    // 清理多余空行（3个及以上换行符替换为2个）
    content = content.replaceAll(RegExp('\n{3,}'), '\n\n');
    
    // 移除每行开头和结尾的空白
    final lines = content.split('\n');
    final cleanedLines = lines.map((line) => line.trim()).where((line) => line.isNotEmpty);
    content = cleanedLines.join('\n');

    return content.trim();
  }

  /// 智能提取内容 - 参考kuaibu_core.py实现
  String _smartExtractContent(String html) {
    // 移除script、style、iframe标签
    html = html.replaceAll(RegExp('<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');
    html = html.replaceAll(RegExp('<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    html = html.replaceAll(RegExp('<iframe[^>]*>[\s\S]*?</iframe>', caseSensitive: false), '');

    // 计算整个页面的中文字符总数
    final chinesePattern = RegExp('[\u4e00-\u9fa5]');
    final totalChCount = chinesePattern.allMatches(html).length;
    
    if (totalChCount == 0) {
      return '页面中没有检测到中文内容';
    }

    // 移除广告相关标签
    html = html.replaceAll(RegExp('<[^>]*class=["\'][^"\']*(ad|advertisement|ad-container|ad-box|ads|banner)[^"\']*["\'][^>]*>[\s\S]*?</[^>]*>', caseSensitive: false), '');
    
    // 移除导航、菜单、侧边栏等非内容标签
    html = html.replaceAll(RegExp('<[^>]*class=["\'][^"\']*(nav|menu|sidebar|aside|header|footer|top|bottom|breadcrumbs|breadcrumb|title)[^"\']*["\'][^>]*>[\s\S]*?</[^>]*>', caseSensitive: false), '');

    // 按优先级顺序检查各个标签（article > section > span > div）
    final tagOrder = ['article', 'section', 'span', 'div'];
    for (final tagName in tagOrder) {
      final content = _extractFromTag(html, tagName, totalChCount);
      if (content.isNotEmpty) {
        final chCount = chinesePattern.allMatches(content).length;
        // 如果提取到的内容中文字符数少于总字数的80%，继续尝试下一个标签
        if (chCount < totalChCount * 0.8) {
          continue;
        }
        return _cleanChapterContent(content);
      }
    }

    // 如果以上标签都失败，合并所有p标签
    final pContent = _extractFromPTags(html);
    if (pContent.isNotEmpty) {
      final chCount = chinesePattern.allMatches(pContent).length;
      if (chCount > totalChCount / 2) {
        return _cleanChapterContent(pContent);
      }
    }

    // 兜底模式：直接取body所有中文
    final bodyPattern = RegExp('<body[^>]*>([\s\S]*?)</body>', caseSensitive: false);
    final bodyMatch = bodyPattern.firstMatch(html);
    if (bodyMatch != null) {
      final bodyContent = bodyMatch.group(1) ?? '';
      return _cleanChapterContent(bodyContent);
    }

    // 如果无法提取，返回提示
    return '无法自动提取章节内容，请检查书源规则配置。';
  }

  /// 从指定标签中提取内容，要求中文字符数超过总数的一半
  String _extractFromTag(String html, String tagName, int totalChCount) {
    final chinesePattern = RegExp('[\u4e00-\u9fa5]');
    final pattern = RegExp('<$tagName[^>]*>([\s\S]*?)</$tagName>', caseSensitive: false);
    final matches = pattern.allMatches(html);
    
    if (matches.isEmpty) {
      return '';
    }

    // 找到中文字符数最多的标签
    String bestContent = '';
    var maxChCount = 0;

    for (final match in matches) {
      var content = match.group(1) ?? '';
      // 移除a标签减少干扰
      content = content.replaceAll(RegExp('<a[^>]*>[\s\S]*?</a>', caseSensitive: false), '');
      
      final chCount = chinesePattern.allMatches(content).length;
      
      if (chCount > maxChCount) {
        maxChCount = chCount;
        bestContent = content;
      }
    }

    // 检查是否超过总数的一半
    if (bestContent.isNotEmpty && maxChCount > totalChCount / 2) {
      return bestContent;
    }

    return '';
  }

  /// 合并所有p标签内容
  String _extractFromPTags(String html) {
    final pattern = RegExp('<p[^>]*>([\s\S]*?)</p>', caseSensitive: false);
    final matches = pattern.allMatches(html);
    
    final contents = <String>[];
    for (final match in matches) {
      final content = match.group(1)?.trim() ?? '';
      if (content.isNotEmpty) {
        contents.add(content);
      }
    }
    
    if (contents.isEmpty) {
      return '';
    }
    
    // 段落之间用两个换行符分隔
    return contents.join('\n\n');
  }

  /// 构建文本输入框
  Widget _buildTextField(String label, TextEditingController controller, String hint) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;
    final labelWidth = isWideScreen ? 100.0 : 70.0;

    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text('$label:', style: TextStyle(fontSize: isWideScreen ? 14 : 12)),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isWideScreen ? 8 : 6),
              isDense: true,
            ),
            style: TextStyle(fontSize: isWideScreen ? 14 : 12),
          ),
        ),
      ],
    );
  }

  /// 构建下拉选择框
  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text('$label:'),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: value,
                items: items.map((item) {
                  return DropdownMenuItem(value: item, child: Text(item));
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建信息框
  Widget _buildInfoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
      ),
    );
  }

  @override
  void dispose() {
    _sourceNameController.dispose();
    _websiteUrlController.dispose();
    _searchUrlController.dispose();
    _exploreUrlController.dispose();
    _bookUrlPatternController.dispose();
    _tocUrlPatternController.dispose();
    _chapterUrlPatternController.dispose();
    _tocListController.dispose();
    _tocNameController.dispose();
    _tocUrlController.dispose();
    _contentRuleController.dispose();
    super.dispose();
  }
}
