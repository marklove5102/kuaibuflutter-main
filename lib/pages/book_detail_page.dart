import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../services/bookshelf_manager.dart';
import '../services/network_service.dart';
import '../services/source_manager.dart';
import '../services/catalog_parser.dart';
import '../services/storage_service.dart';
import '../utils/text_utils.dart';
import 'reader_tab_page.dart';

/// 书籍详情页面
class BookDetailPage extends StatefulWidget {
  final SearchResult searchResult;

  const BookDetailPage({super.key, required this.searchResult});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final BookshelfManager _bookshelfManager = BookshelfManager();
  final NetworkService _networkService = NetworkService();
  
  bool _isLoading = true;
  String _title = '';
  String _author = '';
  String _description = '';
  String _coverUrl = '';
  List<Map<String, String>> _chapters = [];
  int _currentChapterIndex = 0;

  @override
  void initState() {
    super.initState();
    _title = widget.searchResult.title;
    _loadBookDetail();
  }

  Future<void> _loadBookDetail() async {
    setState(() => _isLoading = true);

    try {
      // 获取书籍详情页面
      final html = await _networkService.get(widget.searchResult.bookUrl);

      // 解析书籍信息（简化实现）
      // 实际应该根据书源规则解析
      _description = '暂无简介';
      _author = '未知作者';

      // 尝试提取描述
      final descMatch = RegExp('<meta[^>]*description[^>]*content=(["\'"])([^"\'"]+)\1', caseSensitive: false)
          .firstMatch(html);
      if (descMatch != null) {
        _description = descMatch.group(2) ?? _description;
      }

      // 尝试提取作者
      final authorMatch = RegExp('<meta[^>]*author[^>]*content=(["\'"])([^"\'"]+)\1', caseSensitive: false)
          .firstMatch(html);
      if (authorMatch != null) {
        _author = TextUtils.cleanAuthor(authorMatch.group(2) ?? '');
      }

      // 尝试提取封面图片
      await _extractAndDownloadCover(html);

      // 解析章节列表
      await _loadChapters(html);

    } catch (e) {
      _description = '加载失败';
    }

    setState(() => _isLoading = false);
  }

  /// 从HTML中提取封面图片并下载保存
  Future<void> _extractAndDownloadCover(String html) async {
    try {
      // 尝试多种方式提取封面图片URL
      String? coverImageUrl;

      // 1. 尝试提取og:image
      final ogImageMatch = RegExp('<meta[^>]*property=["\'"]og:image["\'"][^>]*content=["\'"]([^"\'"]+)["\'"]', caseSensitive: false)
          .firstMatch(html);
      if (ogImageMatch != null) {
        coverImageUrl = ogImageMatch.group(1);
      }

      // 2. 尝试提取img标签中的封面图
      if (coverImageUrl == null) {
        final imgMatches = RegExp('<img[^>]*src=["\'"]([^"\'"]+\.(?:jpg|jpeg|png|webp))["\'"][^>]*>', caseSensitive: false)
            .allMatches(html);
        for (final match in imgMatches) {
          final url = match.group(1);
          if (url != null && (url.contains('cover') || url.contains('img') || url.contains('pic'))) {
            coverImageUrl = url;
            break;
          }
        }
      }

      // 3. 如果没有找到特定的封面图，取第一个较大的图片
      if (coverImageUrl == null) {
        final imgMatch = RegExp('<img[^>]*src=["\'"]([^"\'"]+\.(?:jpg|jpeg|png|webp))["\'"]', caseSensitive: false)
            .firstMatch(html);
        if (imgMatch != null) {
          coverImageUrl = imgMatch.group(1);
        }
      }

      if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
        // 转换为绝对URL
        final absoluteUrl = _networkService.convertToAbsoluteUrl(coverImageUrl, widget.searchResult.bookUrl);

        // 下载并保存封面
        final localPath = await _downloadCover(absoluteUrl);
        if (localPath != null) {
          _coverUrl = localPath;
        }
      }
    } catch (e) {
    }
  }

  /// 下载封面图片并保存到cover目录
  Future<String?> _downloadCover(String imageUrl) async {
    try {
      final coverDir = await StorageService().getCoverDirectory();

      if (!await coverDir.exists()) {
        await coverDir.create(recursive: true);
      }

      final safeTitle = _title.replaceAll(RegExp(r'[<>"/\\|?*]'), '_').trim();
      final fileName = '$safeTitle.jpg';
      final filePath = '${coverDir.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        return filePath;
      }

      final response = await _networkService.getBytes(imageUrl);
      if (response != null && response.isNotEmpty) {
        await file.writeAsBytes(response);
        return filePath;
      }
    } catch (e) {
    }
    return null;
  }

  Future<void> _loadChapters(String html) async {
    _chapters = [];
    
    try {
      // 获取书源信息
      final sourceManager = SourceManager();
      final source = sourceManager.getSourceByName(widget.searchResult.sourceName);
      
      if (source != null) {
        // 将简介页URL转换为目录页URL
        final directoryUrl = _generateDirectoryUrl(widget.searchResult.bookUrl, source);
        
        if (directoryUrl.isNotEmpty) {
          // 使用CatalogParser解析目录页获取完整章节列表
          final catalogParser = CatalogParser();
          final chapters = await catalogParser.parseCatalog(directoryUrl, source);
          
          for (final chapter in chapters) {
            _chapters.add({
              'title': chapter['title'] ?? '',
              'url': chapter['url'] ?? '',
            });
          }
        }
      }
      
      // 如果通过目录页没有获取到章节，回退到从详情页解析
      if (_chapters.isEmpty) {
        final chapterPattern = RegExp(
          '<a[^>]*href=(["\'"])([^"\'"]+)\1[^>]*>([^<]*第[一二三四五六七八九十百千零0-9]+章[^<]*)</a>',
          caseSensitive: false,
        );
        
        final matches = chapterPattern.allMatches(html);
        
        for (final match in matches) {
          final url = match.group(2) ?? '';
          final title = match.group(3) ?? '';
          
          if (url.isNotEmpty && title.isNotEmpty) {
            _chapters.add({
              'title': title,
              'url': _networkService.convertToAbsoluteUrl(url, widget.searchResult.bookUrl),
            });
          }
        }
      }
    } catch (e) {
    }
    
    // 如果没有找到章节，添加一个默认章节
    if (_chapters.isEmpty) {
      _chapters.add({
        'title': '第一章',
        'url': widget.searchResult.bookUrl,
      });
    }
  }
  
  /// 根据简介页URL和书源配置生成目录页URL
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
        return '$cleanUrl/all.html';
      }
      return '';
    }
    
    // 构建目录页URL
    var directoryUrl = source.tocUrlPattern ?? '';
    
    // 替换组件
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
    
    String regex = pattern;
    final componentNames = <String>[];
    final componentPattern = RegExp(r'\((书类|书号|章号|记一|记二)\)');
    for (final match in componentPattern.allMatches(pattern)) {
      componentNames.add(match.group(1)!);
    }
    
    regex = regex.replaceAll('(书类)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(书号)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(章号)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(记一)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(记二)', '([a-zA-Z0-9_-]+)');
    
    regex = regex.replaceAllMapped(
      RegExp(r'(?<!\\)\.),'),
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
    } catch (e) {
    }
    
    return null;
  }

  Future<void> _addToBookshelf() async {
    try {
      // 获取书源信息并生成目录页URL
      final sourceManager = SourceManager();
      final source = sourceManager.getSourceByName(widget.searchResult.sourceName);
      String directoryUrl = widget.searchResult.bookUrl;
      
      if (source != null) {
        final generatedUrl = _generateDirectoryUrl(widget.searchResult.bookUrl, source);
        if (generatedUrl.isNotEmpty) {
          directoryUrl = generatedUrl;
        }
      }
      
      final book = Book(
        title: _title,
        author: _author,
        description: _description,
        coverUrl: _coverUrl,
        sourceUrl: directoryUrl,
        sourceName: widget.searchResult.sourceName,
        totalChapters: _chapters.length,
      );
      
      await _bookshelfManager.addBook(book);
      
      // 保存章节列表到数据库
      final chaptersToSave = _chapters.map((chapter) => {
        'title': chapter['title'] ?? '',
        'url': chapter['url'] ?? '',
        'status': '未下载',
      }).toList();
      await _bookshelfManager.saveChapters(directoryUrl, chaptersToSave);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('《$_title》已添加到书架，共 ${_chapters.length} 章')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }

  void _startReading() {
    final book = Book(
      id: DateTime.now().millisecondsSinceEpoch,
      title: _title,
      author: _author,
      description: _description,
      coverUrl: _coverUrl,
      sourceUrl: widget.searchResult.bookUrl,
      sourceName: widget.searchResult.sourceName,
      totalChapters: _chapters.length,
      lastReadChapterIndex: _currentChapterIndex,
      lastReadChapter: _chapters.isNotEmpty ? _chapters[_currentChapterIndex]['title'] : null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderTabPage(book: book),
      ),
    );
  }

  void _openChapter(int index) {
    setState(() => _currentChapterIndex = index);
    _startReading();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: _addToBookshelf,
            tooltip: '加入书架',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // 书籍信息
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面
              Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('作者: $_author'),
                    const SizedBox(height: 4),
                    Text('书源: ${widget.searchResult.sourceName}'),
                    const SizedBox(height: 4),
                    Text('章节数: ${_chapters.length}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _startReading,
                          icon: const Icon(Icons.read_more, size: 18),
                          label: const Text('开始阅读'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _addToBookshelf,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('加入书架'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 简介
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '简介',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        // 章节列表
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: const Text(
            '章节目录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // 章节列表
        Expanded(
          child: _chapters.isEmpty
              ? const Center(child: Text('暂无章节'))
              : ListView.builder(
                  itemCount: _chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = _chapters[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        chapter['title'] ?? '第${index + 1}章',
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () => _openChapter(index),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
