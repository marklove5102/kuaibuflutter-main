import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../services/source_manager.dart';
import '../services/bookshelf_manager.dart';
import '../services/network_service.dart';
import '../services/search_service.dart';
import '../services/catalog_parser.dart';
import '../utils/url_utils.dart';
import 'book_detail_page.dart';
import 'bookshelf_page.dart';

/// 书源分类数据
class _SourceCategories {
  final BookSource source;
  final List<Map<String, String>> categories;
  bool isExpanded;

  _SourceCategories({
    required this.source,
    required this.categories,
    this.isExpanded = false,
  });
}

/// 网上搜书页面
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final SourceManager _sourceManager = SourceManager();
  final BookshelfManager _bookshelfManager = BookshelfManager();
  final NetworkService _networkService = NetworkService();
  final SearchService _searchService = SearchService();
  final CatalogParser _catalogParser = CatalogParser();

  List<BookSource> _bookSources = [];
  List<_SourceCategories> _sourceCategoriesList = [];
  List<SearchResult> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isLeftPanelCollapsed = false;
  bool _isRightPanelCollapsed = false;
  String _statusMessage = '就绪';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategoryUrl;
  BookSource? _selectedCategorySource;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _sourceManager.init();
    await _bookshelfManager.init();
    _loadBookSources();
  }

  Future<void> _loadBookSources() async {
    setState(() => _isLoading = true);
    _bookSources = _sourceManager.enabledSources;

    // 为每个书源加载分类
    _sourceCategoriesList = [];
    for (final source in _bookSources) {
      final categories = _parseCategories(source);
      if (categories.isNotEmpty) {
        _sourceCategoriesList.add(_SourceCategories(
          source: source,
          categories: categories,
          isExpanded: false,
        ));
      }
    }

    setState(() => _isLoading = false);
  }

  /// 解析书源的分类
  List<Map<String, String>> _parseCategories(BookSource source) {
    final categories = <Map<String, String>>[];

    if (source.exploreUrl != null && source.exploreUrl!.isNotEmpty) {
      final exploreUrl = source.exploreUrl!;

      // 支持多种格式：
      // 1. &&分隔格式: 玄幻::http://...&&武侠::http://...
      // 2. 多行格式: 玄幻::http://...\n武侠::http://...
      // 3. 带分类的JSON格式: [{"name":"玄幻","url":"..."}]
      // 4. 简单URL: http://example.com/sort/ (不显示分类)

      if (exploreUrl.contains('::')) {
        // 先尝试用&&分隔，如果没有&&则尝试用换行符分隔
        List<String> groups;
        if (exploreUrl.contains('&&')) {
          groups = exploreUrl.split('&&');
        } else {
          groups = exploreUrl.split('\n');
        }

        for (final group in groups) {
          final trimmedGroup = group.trim();
          if (trimmedGroup.contains('::')) {
            final parts = trimmedGroup.split('::');
            if (parts.length >= 2) {
              categories.add({
                'name': parts[0].trim(),
                'url': parts[1].trim(),
              });
            }
          }
        }
      }
    }

    return categories;
  }

  /// 点击分类进行搜索 - 类似于书源调试的分类排行效果
  Future<void> _onCategoryTap(BookSource source, String url, String categoryName) async {
    setState(() {
      _selectedCategoryUrl = url;
      _selectedCategorySource = source;
      _isSearching = true;
      _searchResults = [];
    });

    try {
      // 多页加载，最多10页
      final allResults = <Map<String, String>>[];
      const maxPages = 10;
      int actualPages = 0;

      for (int page = 1; page <= maxPages; page++) {
        // 更新状态
        setState(() {
          _statusMessage = '正在获取 ${source.sourceName} 站点 $categoryName 分类排行... 第${page}页';
        });

        // 构建请求URL，替换页码参数
        final requestUrl = url.replaceAll('{page}', page.toString());

        final html = await _networkService.get(
          requestUrl,
          encoding: source.websiteEncoding,
        );

        if (html.isEmpty) {
          continue;
        }

        // 使用搜索解析逻辑（与普通搜索一致，不使用关键词过滤）
        final pageResults = _searchService.parseSearchResults(html, source, '');
        if (pageResults.isEmpty) {
          continue;
        }

        allResults.addAll(pageResults);
        actualPages++;
      }

      // 过滤掉网址中含有/author/的结果
      final filteredResults = allResults.where((result) {
        final resultUrl = result['url'] ?? '';
        return !resultUrl.contains('/author/');
      }).toList();

      // 限制为前600条
      final results = filteredResults.take(600).toList();

      // 更新状态
      setState(() {
        _searchResults = results.map((book) => SearchResult(
          title: book['name'] ?? '',
          author: book['author'] ?? '',
          bookUrl: book['url'] ?? '',
          sourceName: book['source'] ?? source.sourceName,
          sourceUrl: source.websiteUrl,
          latestChapter: book['latest_chapter'],
        )).toList();
        _statusMessage = '已获取 $actualPages 页，共 ${results.length} 条 $categoryName 分类结果';
      });
    } catch (e, stackTrace) {
      setState(() {
        _statusMessage = '获取分类排行失败';
      });
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _isSearching = true);
    _searchResults = [];

    final enabledSources = _sourceManager.enabledSources;

    // 使用SearchService进行搜索（与书源调试一致）
    final searchResults = await _searchService.searchMultipleSources(
      enabledSources,
      keyword,
    );

    // 转换为SearchResult对象
    for (final result in searchResults) {
      _searchResults.add(SearchResult(
        title: result['name'] ?? '',
        author: result['author'] ?? '',
        bookUrl: result['url'] ?? '',
        sourceName: result['source'] ?? '',
        sourceUrl: '',
        latestChapter: result['latestChapter'],
      ));
    }

    setState(() => _isSearching = false);
  }

  void _openBookDetail(SearchResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookDetailPage(
          searchResult: result,
        ),
      ),
    );
  }

  /// 处理搜索结果双击事件 - 加入书架
  void _onSearchResultDoubleTapped(SearchResult result) {
    _showAddToBookshelfDialog(result);
  }

  /// 显示加入书架对话框（先解析目录获取章节数）
  Future<void> _showAddToBookshelfDialog(SearchResult result) async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在获取章节列表...'),
          ],
        ),
      ),
    );

    try {
      // 获取书源信息
      final source = _sourceManager.getSourceByName(result.sourceName);
      if (source == null) {
        Navigator.pop(context);
        _showErrorMessage('找不到书源: ${result.sourceName}');
        return;
      }

      // 解析简介页URL获取目录页URL
      final introUrl = result.bookUrl;
      final directoryUrl = _generateDirectoryUrl(introUrl, source);

      if (directoryUrl.isEmpty) {
        Navigator.pop(context);
        _showErrorMessage('无法生成目录页URL');
        return;
      }

      // 解析目录获取章节列表
      final chapters = await _catalogParser.parseCatalog(directoryUrl, source);

      // 关闭加载对话框
      Navigator.pop(context);

      if (chapters.isEmpty) {
        _showErrorMessage('未获取到章节列表，请检查书源配置');
        return;
      }

      // 显示确认对话框（显示书名和章节数量）
      final editedNameController = TextEditingController(text: result.title);
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('确认加入书架'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('书名:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextField(
                controller: editedNameController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 12),
              if (result.author.isNotEmpty)
                Text('作者: ${result.author}'),
              const SizedBox(height: 8),
              Text('来源: ${result.sourceName}'),
              const SizedBox(height: 8),
              Text(
                '章节: ${chapters.length} 章',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 8),
              Text(
                '目录URL:',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                directoryUrl,
                style: const TextStyle(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                result.title = editedNameController.text.trim();
                _addToBookshelfWithChapters(result, directoryUrl, chapters);
              },
              child: const Text('确认'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      _showErrorMessage('获取章节列表失败: $e');
    }
  }

  /// 添加书籍到书架
  Future<void> _addToBookshelf(SearchResult result) async {
    try {
      // 获取书源信息
      final source = _sourceManager.getSourceByName(result.sourceName);

      if (source == null) {
        _showErrorMessage('找不到书源: ${result.sourceName}');
        return;
      }

      // 解析简介页URL获取目录页URL
      final introUrl = result.bookUrl;
      final directoryUrl = _generateDirectoryUrl(introUrl, source);

      if (directoryUrl.isEmpty) {
        _showErrorMessage('无法生成目录页URL');
        return;
      }

      // 解析简介页URL获取目录页URL检查书籍是否已存在
      final existingBooks = _bookshelfManager.books.where((b) =>
        b.title == result.title && b.sourceUrl == directoryUrl
      );

      if (existingBooks.isNotEmpty) {
        _showErrorMessage('《${result.title}》已存在于书架');
        return;
      }

      // 创建Book对象
      final newBook = Book(
        title: result.title,
        author: result.author,
        sourceUrl: directoryUrl,
        sourceName: result.sourceName,
        lastReadChapter: result.latestChapter,
        coverUrl: 'cover/default.jpg',
        addedTime: DateTime.now(),
      );

      // 添加到书架
      await _bookshelfManager.addBook(newBook);

      // 刷新书架
      BookshelfPage.refreshIfExists();

      // 解析目录页获取章节列表并保存（支持分页）
      await _parseAndSaveChapters(directoryUrl, source);

      if (mounted) {
        // 获取保存后的章节数量
        final savedChapters = await _bookshelfManager.getChapters(directoryUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('《${result.title}》已添加到书架，共 ${savedChapters.length} 章')),
        );
      }
    } catch (e) {
      _showErrorMessage('添加书架失败: $e');
    }
  }

  /// 添加书籍到书架（使用已获取的章节列表）
  Future<void> _addToBookshelfWithChapters(
    SearchResult result,
    String directoryUrl,
    List<Map<String, dynamic>> chapters,
  ) async {
    try {
      // 检查书籍是否已存在
      final existingBooks = _bookshelfManager.books.where((b) =>
        b.title == result.title && b.sourceUrl == directoryUrl
      );

      if (existingBooks.isNotEmpty) {
        _showErrorMessage('《${result.title}》已存在于书架');
        return;
      }

      // 下载封面
      String coverUrl = 'cover/default.jpg';
      final introUrl = result.bookUrl;
      final source = _sourceManager.getSourceByName(result.sourceName);
      if (source != null && introUrl.isNotEmpty) {
        final existingPath = await BookshelfPage.getCoverPath(result.title);
        coverUrl = existingPath ?? await BookshelfPage.downloadCoverIfNeeded(introUrl, source.websiteEncoding, result.title);
      }

      // 创建Book对象
      final newBook = Book(
        title: result.title,
        author: result.author,
        sourceUrl: directoryUrl,
        sourceName: result.sourceName,
        lastReadChapter: result.latestChapter,
        coverUrl: coverUrl,
        addedTime: DateTime.now(),
      );

      // 添加到书架
      await _bookshelfManager.addBook(newBook);

      // 刷新书架
      BookshelfPage.refreshIfExists();

      // 保存章节列表
      await _bookshelfManager.saveChapters(directoryUrl, chapters);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('《${result.title}》已添加到书架，共 ${chapters.length} 章')),
        );
      }
    } catch (e) {
      _showErrorMessage('添加书架失败: $e');
    }
  }

  /// 根据简介页URL和书源配置生成目录页URL
  /// 参考 source_edit.dart 中的 _generateDirectoryUrl 方法
  String _generateDirectoryUrl(String introUrl, BookSource source) {
    if (introUrl.isEmpty) return '';

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
        final result = '$cleanUrl/all.html';
        return result;
      }
      // 无法转换，返回空字符串表示失败
      return '';
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
    final result = '$baseUrl$directoryUrl';
    return result;
  }

  /// 从URL中提取组件（如书类、书号、章号等）
  /// 参考 source_edit.dart 中的 _extractUrlComponents 方法
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
      RegExp(r'(?<!\\)/'),
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
      }
    } catch (e, stackTrace) {
    }

    return null;
  }

  /// 解析目录页并保存章节列表（支持分页）
  Future<void> _parseAndSaveChapters(String directoryUrl, BookSource source) async {
    try {
      // 使用CatalogParser解析所有章节（包括分页）
      final chapters = await _catalogParser.parseCatalog(directoryUrl, source);

      if (chapters.isNotEmpty) {
        // 保存章节到数据库
        await _bookshelfManager.saveChapters(directoryUrl, chapters);
      }
    } catch (e) {
    }
  }

  /// 显示错误消息
  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
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
        // 左侧分类排行面板（可折叠）
        if (!_isLeftPanelCollapsed)
          SizedBox(
            width: leftPanelWidth,
            child: _buildCategoryPanel(),
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
        // 右侧搜索区域
        Expanded(
          child: Column(
            children: [
              // 搜索栏
              _buildSearchBar(),
              // 搜索结果
              Expanded(
                child: _isSearching
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              _statusMessage,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? _buildEmptyView()
                        : _buildResultTable(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建左侧分类面板 - 卷帘菜单样式
  Widget _buildCategoryPanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
        color: Colors.grey[50],
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sourceCategoriesList.isEmpty
              ? _buildNoSourceView()
              : _buildCategoryExpansionList(),
    );
  }

  /// 构建无书源视图
  Widget _buildNoSourceView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            '暂无分类排行',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 构建分类卷帘菜单列表
  Widget _buildCategoryExpansionList() {
    return ListView.builder(
      itemCount: _sourceCategoriesList.length + 1,
      itemBuilder: (context, index) {
        // 第一个位置显示表头
        if (index == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const Row(
              children: [
                Text(
                  '分类排行',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        final sourceCategories = _sourceCategoriesList[index - 1];
        final source = sourceCategories.source;
        final categories = sourceCategories.categories;

        // 如果没有分类，显示书源名称（不可展开）
        if (categories.isEmpty) {
          return ListTile(
            dense: true,
            title: Text(
              source.sourceName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        // 有分类的书源，显示为可展开的卷帘菜单
        return ExpansionTile(
          initiallyExpanded: sourceCategories.isExpanded,
          onExpansionChanged: (expanded) {
            setState(() {
              sourceCategories.isExpanded = expanded;
            });
          },
          title: Text(
            source.sourceName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: categories.map((category) {
            final categoryName = category['name'] ?? '';
            final categoryUrl = category['url'] ?? '';
            final isSelected = _selectedCategoryUrl == categoryUrl &&
                              _selectedCategorySource?.id == source.id;

            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 24, right: 16),
              selected: isSelected,
              title: Text(
                categoryName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                _onCategoryTap(source, categoryUrl, categoryName);
              },
            );
          }).toList(),
        );
      },
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
    return Icon(icon, color: color, size: 14);
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Text(
            '搜索书名:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入书名或作者...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isSearching ? null : _search,
            icon: _isSearching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.search, size: 18),
            label: const Text('搜索'),
          ),
        ],
      ),
    );
  }

  /// 构建空视图
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '输入关键词开始搜索\n或点击左侧分类浏览',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// 构建结果表格
  Widget _buildResultTable() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Column(
      children: [
        // 表头（仅宽屏显示）
        if (isWideScreen)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('书名', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('作者', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('最新章节', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('书源', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        // 结果列表
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final result = _searchResults[index];
              return GestureDetector(
                onDoubleTap: () => _onSearchResultDoubleTapped(result),
                child: InkWell(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWideScreen ? 16 : 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: isWideScreen
                        ? _buildResultRowWide(result)
                        : _buildResultRowNarrow(result),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 宽屏结果行
  Widget _buildResultRowWide(SearchResult result) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            result.title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            result.author,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            result.latestChapter ?? '',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            result.sourceName,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 窄屏结果行
  Widget _buildResultRowNarrow(SearchResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                result.title,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                result.sourceName,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (result.author.isNotEmpty)
              Text(
                result.author,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (result.latestChapter != null && result.latestChapter!.isNotEmpty) ...[
              if (result.author.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.latestChapter!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
