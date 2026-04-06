import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/book_source.dart';
import '../services/bookshelf_manager.dart';
import '../services/chapter_downloader.dart';
import '../services/universal_catalog_parser.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';
import 'main_tab_controller.dart';

// 我的书架页面
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  static final GlobalKey<State<BookshelfPage>> bookshelfKey = GlobalKey();

  static void refreshIfExists() {
    final state = bookshelfKey.currentState as _BookshelfPageState?;
    state?.loadBooks();
  }

  static String _getSafeFileName(String title) {
    return title.replaceAll(RegExp(r'[<>"/\\|?*]'), '_').trim();
  }

  static Future<String?> getCoverPath(String title) async {
    try {
      final coverDir = await StorageService().getCoverDirectory();
      final safeTitle = _getSafeFileName(title);
      final filePath = '${coverDir.path}/$safeTitle.jpg';
      final file = File(filePath);
      if (await file.exists()) {
        return filePath;
      }
    } catch (e) {
    }
    return null;
  }

  static Future<String> downloadCoverIfNeeded(String introUrl, String websiteEncoding, String title) async {
    final existingPath = await getCoverPath(title);
    if (existingPath != null) {
      return existingPath;
    }

    try {
      final coverDir = await StorageService().getCoverDirectory();
      if (!await coverDir.exists()) {
        await coverDir.create(recursive: true);
      }

      final safeTitle = _getSafeFileName(title);
      final filePath = '${coverDir.path}/$safeTitle.jpg';
      final file = File(filePath);

      final html = await NetworkService().get(introUrl, encoding: websiteEncoding, timeout: 30);
      String? coverImageUrl;

      final ogImageMatch = RegExp(
        '<meta[^>]*property=["\'"]og:image["\'"][^>]*content=["\'"]([^"\'"]+)["\'"]',
        caseSensitive: false,
      ).firstMatch(html);
      if (ogImageMatch != null) {
        coverImageUrl = ogImageMatch.group(1);
      }

      if (coverImageUrl == null) {
        final imgMatches = RegExp(
          '<img[^>]*src=["\'"]([^"\'"]+\\.(?:jpg|jpeg|png|webp))["\'][^>]*>',
          caseSensitive: false,
        ).allMatches(html);
        for (final match in imgMatches) {
          final url = match.group(1);
          if (url != null && (url.contains('cover') || url.contains('img') || url.contains('pic'))) {
            coverImageUrl = url;
            break;
          }
        }
      }

      if (coverImageUrl == null) {
        final imgMatch = RegExp(
          '<img[^>]*src=["\'"]([^"\'"]+\\.(?:jpg|jpeg|png|webp))["\']',
          caseSensitive: false,
        ).firstMatch(html);
        if (imgMatch != null) {
          coverImageUrl = imgMatch.group(1);
        }
      }

      if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
        final absoluteUrl = NetworkService().convertToAbsoluteUrl(coverImageUrl, introUrl);
        final response = await NetworkService().getBytes(absoluteUrl);
        if (response != null && response.isNotEmpty) {
          await file.writeAsBytes(response);
          return filePath;
        }
      }
    } catch (e) {
    }
    return 'cover/default.jpg';
  }

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> with WidgetsBindingObserver {
  final BookshelfManager _bookshelfManager = BookshelfManager();
  final UniversalCatalogParser _catalogParser = UniversalCatalogParser();
  List<Book> _books = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    loadBooks();
  }

  Future<void> loadBooks() async {
    setState(() => _isLoading = true);
    try {
      await _bookshelfManager.init();
      setState(() {
        _books = _bookshelfManager.books;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _books = [];
        _isLoading = false;
      });
    }
  }

  /// 打开书籍阅读
  void _openBook(Book book) {
    final controller = MainTabControllerProvider.of(context);
    if (controller != null) {
      controller.openBook(book);
    }
  }

  /// 显示目录解析对话框
  void _showAddByUrlDialog() {
    final urlController = TextEditingController();
    final encodingController = TextEditingController(text: 'UTF-8');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('目录解析'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '目录页URL',
                hintText: '请输入书籍目录页链接',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: encodingController,
              decoration: const InputDecoration(
                labelText: '页面编码',
                hintText: '默认UTF-8',
                prefixIcon: Icon(Icons.code),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addBookByUrl(urlController.text, encodingController.text);
            },
            child: const Text('解析'),
          ),
        ],
      ),
    );
  }

  /// 通过URL解析目录并添加书籍
  Future<void> _addBookByUrl(String url, String encoding) async {
    if (url.isEmpty) {
      _showMessage('请输入目录页URL', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {

      // 解析目录
      final chapters = await _catalogParser.parseCatalog(
        url,
        encoding: encoding,
      );

      if (chapters.isEmpty) {
        _showMessage('未解析到章节，请检查URL是否正确', isError: true);
        setState(() => _isLoading = false);
        return;
      }


      // 获取第一页HTML提取书名和作者
      final html = await NetworkService().get(url, encoding: encoding);
      String? bookTitle = _catalogParser.extractBookTitle(html);
      String? author = _catalogParser.extractAuthor(html);

      // 如果无法提取书名，使用URL作为书名
      bookTitle ??= '未知书名';


      // 检查书籍是否已存在
      final existingBooks = _bookshelfManager.books.where((b) =>
        b.title == bookTitle && b.sourceUrl == url
      );

      if (existingBooks.isNotEmpty) {
        _showMessage('《$bookTitle》已存在于书架', isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // 检查或下载封面
      final coverUrl = await BookshelfPage.getCoverPath(bookTitle);
      final finalCoverUrl = coverUrl ?? await BookshelfPage.downloadCoverIfNeeded(url, encoding, bookTitle);

      // 创建Book对象
      final newBook = Book(
        title: bookTitle,
        author: author ?? '',
        sourceUrl: url,
        sourceName: '目录解析',
        lastReadChapter: chapters.isNotEmpty ? chapters.first['title'] : null,
        coverUrl: finalCoverUrl,
        addedTime: DateTime.now(),
      );

      // 添加到书架
      await _bookshelfManager.addBook(newBook);

      // 保存章节列表
      await _bookshelfManager.saveChapters(url, chapters);

      // 刷新书架
      await loadBooks();

      _showMessage('《$bookTitle》已添加到书架，共 ${chapters.length} 章');
    } catch (e) {
      _showMessage('添加失败: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Spacer(),

              // 目录解析按钮
              ElevatedButton.icon(
                onPressed: _showAddByUrlDialog,
                icon: const Icon(Icons.add_link, size: 18),
                label: const Text('目录解析'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        // 书籍网格
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _books.isEmpty
                  ? _buildEmptyView()
                  : _buildBookGrid(),
        ),
      ],
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '书架为空',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildBookGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 140).floor().clamp(2, 10);

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.65,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: _books.length,
          itemBuilder: (context, index) {
            final book = _books[index];
            return _buildBookCard(book);
          },
        );
      },
    );
  }

  Widget _buildBookCard(Book book) {
    final coverPath = book.coverUrl;
    final hasCover = coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync();

    return GestureDetector(
      onTap: () {},
      onDoubleTap: () => _openBook(book),
      onLongPress: () => _showBookOptionsMenu(book),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          children: [
            // 封面
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: hasCover
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  image: hasCover
                      ? DecorationImage(
                          image: FileImage(File(coverPath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasCover
                    ? null
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            book.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // 书名
            Text(
              book.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            // 最新章节
            if (book.lastReadChapter != null)
              Text(
                book.lastReadChapter!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  /// 显示书籍选项菜单
  void _showBookOptionsMenu(Book book) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('下载'),
              onTap: () {
                Navigator.pop(context);
                _downloadBook(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('检查更新'),
              onTap: () {
                Navigator.pop(context);
                _checkForUpdates(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet),
              title: const Text('制作TXT'),
              onTap: () {
                Navigator.pop(context);
                _generateTxt(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('移出书架', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _removeFromBookshelf(book);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 下载书籍
  Future<void> _downloadBook(Book book) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开始下载...')),
      );

      final chapters = await _bookshelfManager.getChapters(book.sourceUrl ?? '');
      if (chapters.isEmpty) {
        _showMessage('无法获取章节列表', isError: true);
        return;
      }

      final source = BookSource(
        sourceName: book.sourceName ?? '未知',
        websiteEncoding: 'UTF-8',
      );

      final downloader = ChapterDownloader();
      final result = await downloader.downloadChapters(
        chapters: chapters.cast<Map<String, String>>(),
        bookTitle: book.title,
        source: source,
      );

      final success = result['success'] as int? ?? 0;
      final total = result['total'] as int? ?? 0;
      _showMessage('下载完成：$success/$total 章');
    } catch (e) {
      _showMessage('下载失败: $e', isError: true);
    }
  }

  /// 检查更新
  Future<void> _checkForUpdates(Book book) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在检查《${book.title}》更新...')),
      );

      final catalogParser = UniversalCatalogParser();
      final latestChapters = await catalogParser.parseCatalog(
        book.sourceUrl ?? '',
        encoding: 'UTF-8',
      );

      if (latestChapters.isEmpty) {
        _showMessage('检查更新失败', isError: true);
        return;
      }

      final currentChapters = await _bookshelfManager.getChapters(book.sourceUrl ?? '');
      final newCount = latestChapters.length - currentChapters.length;

      if (newCount > 0) {
        _showMessage('发现 $newCount 章新内容');
        await _bookshelfManager.saveChapters(book.sourceUrl ?? '', latestChapters);
        _showMessage('已更新目录');
      } else {
        _showMessage('已是最新版本');
      }
    } catch (e) {
      _showMessage('检查更新失败: $e', isError: true);
    }
  }

  /// 制作TXT
  Future<void> _generateTxt(Book book) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('正在生成《${book.title}》TXT...')),
      );

      final chapters = await _bookshelfManager.getChapters(book.sourceUrl ?? '');
      if (chapters.isEmpty) {
        _showMessage('无法获取章节列表', isError: true);
        return;
      }

      final downloadPath = await _bookshelfManager.getBookDownloadPath(book.title);
      final buffer = StringBuffer();
      buffer.writeln(book.title);
      buffer.writeln();
      buffer.writeln('=' * 50);
      buffer.writeln();

      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        final title = chapter['title'] ?? '第${i + 1}章';
        final content = await _bookshelfManager.readChapterContent(book.title, i);

        buffer.writeln(title);
        buffer.writeln();
        if (content != null && content.isNotEmpty) {
          buffer.writeln(content);
        } else {
          buffer.writeln('（未下载）');
        }
        buffer.writeln();
        buffer.writeln('-' * 50);
        buffer.writeln();
      }

      final file = File('$downloadPath/${book.title}.txt');
      await file.writeAsString(buffer.toString());
      _showMessage('TXT已生成: ${file.path}');
    } catch (e) {
      _showMessage('生成TXT失败: $e', isError: true);
    }
  }

  /// 移出书架
  void _removeFromBookshelf(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认移出'),
        content: Text('确定要将《${book.title}》移出书架吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _bookshelfManager.deleteBook(book.id ?? 0);
                await loadBooks();
                _showMessage('已移出书架');
              } catch (e) {
                _showMessage('移出失败: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('移出', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }
}
