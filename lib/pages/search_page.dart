import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../services/bookshelf_manager.dart';
import '../services/source_manager.dart';
import '../services/search_service.dart';
import '../services/catalog_parser.dart';
import 'bookshelf_page.dart';

// 网上搜书页面
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  List<BookSource> _sources = [];
  final SourceManager _sourceManager = SourceManager();
  final SearchService _searchService = SearchService();
  final BookshelfManager _bookshelfManager = BookshelfManager();
  final CatalogParser _catalogParser = CatalogParser();

  @override
  void initState() {
    super.initState();
    _loadSources();
    _bookshelfManager.init();
  }

  Future<void> _loadSources() async {
    await _sourceManager.init();
    setState(() {
      _sources = _sourceManager.sources;
    });
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
      _results.clear();
    });


    try {
      // 筛选有搜索网址的书源
      final sourcesToSearch = _sources.where((s) =>
        s.searchUrl != null && s.searchUrl!.isNotEmpty
      ).toList();


      // 使用搜索服务进行并发搜索
      final results = await _searchService.searchMultipleSources(
        sourcesToSearch,
        keyword,
      );

      _results.addAll(results);


      setState(() => _isSearching = false);
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  /// 处理搜索结果单击事件 - 加入书架
  void _onSearchResultTapped(Map<String, dynamic> book) {
    _showAddToBookshelfDialog(book);
  }

  /// 显示加入书架对话框（先解析目录获取章节数）
  Future<void> _showAddToBookshelfDialog(Map<String, dynamic> book) async {
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
      final sourceName = book['source']?.toString() ?? '';
      final source = _sourceManager.getSourceByName(sourceName);

      if (source == null) {
        Navigator.pop(context);
        _showErrorMessage('找不到书源: $sourceName');
        return;
      }

      // 解析简介页URL获取目录页URL
      final introUrl = book['url']?.toString() ?? '';
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
      final editedNameController = TextEditingController(text: book['name'] ?? '');
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
              if (book['author'] != null && book['author'].toString().isNotEmpty)
                Text('作者: ${book['author']}'),
              const SizedBox(height: 8),
              Text('来源: ${book['source'] ?? ''}'),
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
                _addToBookshelfWithChapters(book, directoryUrl, chapters);
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

  /// 添加书籍到书架（使用已获取的章节列表）
  Future<void> _addToBookshelfWithChapters(
    Map<String, dynamic> book,
    String directoryUrl,
    List<Map<String, dynamic>> chapters,
  ) async {

    try {
      // 检查书籍是否已存在
      final existingBooks = _bookshelfManager.books.where((b) =>
        b.title == book['name'] && b.sourceUrl == directoryUrl
      );

      if (existingBooks.isNotEmpty) {
        _showErrorMessage('《${book['name']}》已存在于书架');
        return;
      }

      // 检查或下载封面
      final title = book['name']?.toString() ?? '';
      final introUrl = book['url']?.toString() ?? '';
      final sourceName = book['source']?.toString() ?? '';
      final source = _sourceManager.getSourceByName(sourceName);
      String coverUrl = 'cover/default.jpg';
      if (source != null && introUrl.isNotEmpty) {
        final existingPath = await BookshelfPage.getCoverPath(title);
        coverUrl = existingPath ?? await BookshelfPage.downloadCoverIfNeeded(introUrl, source.websiteEncoding, title);
      }

      // 创建Book对象
      final newBook = Book(
        title: title,
        author: book['author']?.toString() ?? '',
        sourceUrl: directoryUrl,
        sourceName: book['source']?.toString() ?? '',
        lastReadChapter: book['latest_chapter']?.toString(),
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
          SnackBar(content: Text('《${book['name']}》已添加到书架，共 ${chapters.length} 章')),
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

  /// 验证URL是否匹配给定模式
  bool _validateUrl(String url, String pattern) {
    final regex = _convertPatternToRegex(pattern);
    return RegExp(regex).hasMatch(url);
  }

  /// 将书源配置中的URL模式转换为正则表达式
  String _convertPatternToRegex(String pattern) {
    String regex = pattern;

    // 替换简化格式
    regex = regex.replaceAll('(书类)', '([a-zA-Z0-9]+)');
    regex = regex.replaceAll('(书号)', '([a-zA-Z0-9]+)');
    regex = regex.replaceAll('(章号)', '([a-zA-Z0-9]+)');
    regex = regex.replaceAll('(记一)', '([a-zA-Z0-9]+)');
    regex = regex.replaceAll('(记二)', '([a-zA-Z0-9]+)');

    // 转义特殊字符
    regex = regex.replaceAll('.', r'\.');
    regex = regex.replaceAll('/', r'/');

    return regex;
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
      } else {
      }
    } catch (e, stackTrace) {
    }

    return null;
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
    return Column(
      children: [
        // 搜索栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '输入书名...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isSearching ? null : _search,
                icon: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('搜索'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? _buildEmptyView()
                  : _buildResultList(),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '输入关键词开始搜索',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final book = _results[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _onSearchResultTapped(book),
            leading: Container(
              width: 40,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  book['name']?.substring(0, 1) ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            title: Text(book['name'] ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('来源: ${book['source'] ?? ''}'),
                if (book['author'] != null && book['author'].toString().isNotEmpty)
                  Text('作者: ${book['author']}'),
                if (book['latest_chapter'] != null && book['latest_chapter'].toString().isNotEmpty)
                  Text('最新: ${book['latest_chapter']}', maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
            isThreeLine: book['author'] != null || book['latest_chapter'] != null,
          ),
        );
      },
    );
  }
}
