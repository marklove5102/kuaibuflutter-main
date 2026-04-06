import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/book.dart';
import 'database_helper.dart';
import 'storage_service.dart';

/// 书架管理器
class BookshelfManager {
  static final BookshelfManager _instance = BookshelfManager._internal();
  factory BookshelfManager() => _instance;
  BookshelfManager._internal();

  final List<Book> _books = [];
  bool _initialized = false;

  /// 获取所有书籍
  List<Book> get books => List.unmodifiable(_books);

  /// 初始化
  Future<void> init() async {
    if (_initialized) return;

    try {
      await DatabaseHelper().init();
      await StorageService().getCoverDirPath();
      await loadBooks();
      _initialized = true;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  /// 加载书架
  Future<void> loadBooks() async {
    final db = DatabaseHelper().bookshelfDb;

    final List<Map<String, dynamic>> maps = await db.query(
      'bookshelf',
      orderBy: 'last_read_time DESC',
    );

    _books.clear();
    _books.addAll(maps.map((map) => Book.fromDbMap(map)));
  }

  /// 添加书籍
  Future<void> addBook(Book book) async {
    final db = DatabaseHelper().bookshelfDb;

    // 检查是否已存在
    final existing = await db.query(
      'bookshelf',
      where: 'book_name = ? AND directory_url = ?',
      whereArgs: [book.title, book.sourceUrl],
    );

    if (existing.isNotEmpty) {
      throw Exception('该书籍已存在');
    }

    // 获取当前最大order
    final maxOrderResult = await db.rawQuery('SELECT MAX(`order`) as max_order FROM bookshelf');
    final maxOrder = maxOrderResult.first['max_order'] as int? ?? 0;

    await db.insert('bookshelf', {
      'website_name': book.sourceName,
      'book_name': book.title,
      'directory_url': book.sourceUrl,
      'chapter_name': book.lastReadChapter,
      'chapter_url': book.lastReadChapterUrl,
      'cover_path': book.coverUrl ?? 'cover/default.jpg',
      'order': maxOrder + 1,
      'last_read_time': DateTime.now().toIso8601String(),
    });

    await loadBooks();
  }

  /// 更新书籍
  Future<void> updateBook(Book book) async {
    if (book.id == null) return;

    final db = DatabaseHelper().bookshelfDb;

    await db.update(
      'bookshelf',
      {
        'website_name': book.sourceName,
        'book_name': book.title,
        'chapter_name': book.lastReadChapter,
        'chapter_url': book.lastReadChapterUrl,
        'cover_path': book.coverUrl ?? 'cover/default.jpg',
        'last_read_time': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [book.id],
    );

    await loadBooks();
  }

  /// 删除书籍
  Future<void> deleteBook(int id) async {
    final db = DatabaseHelper().bookshelfDb;

    // 获取书籍信息
    final book = await db.query(
      'bookshelf',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (book.isNotEmpty) {
      final directoryUrl = book.first['directory_url'] as String;

      // 删除封面文件
      final coverPath = book.first['cover_path'] as String?;
      if (coverPath != null && coverPath != 'cover/default.jpg') {
        try {
          final appDir = await StorageService().getAppDirectory();
          final file = File(path.join(appDir.path, coverPath));
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // 忽略删除错误
        }
      }

      // 删除书籍
      await db.delete(
        'bookshelf',
        where: 'id = ?',
        whereArgs: [id],
      );

      // 删除章节
      await db.delete(
        'chapters',
        where: 'directory_url = ?',
        whereArgs: [directoryUrl],
      );
    }

    await loadBooks();
  }

  /// 根据ID获取书籍
  Book? getBookById(int id) {
    try {
      return _books.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 搜索书籍
  List<Book> searchBooks(String keyword) {
    if (keyword.isEmpty) return _books;

    final lowerKeyword = keyword.toLowerCase();
    return _books.where((b) =>
      b.title.toLowerCase().contains(lowerKeyword) ||
      (b.sourceName?.toLowerCase().contains(lowerKeyword) ?? false)
    ).toList();
  }

  /// 移动书籍到指定位置
  Future<void> moveBookToOrder(int bookId, int newOrder) async {
    final db = DatabaseHelper().bookshelfDb;

    await db.transaction((txn) async {
      // 获取当前order
      final current = await txn.query(
        'bookshelf',
        columns: ['`order`'],
        where: 'id = ?',
        whereArgs: [bookId],
      );

      if (current.isEmpty) return;

      final currentOrder = current.first['order'] as int;

      if (newOrder < currentOrder) {
        // 向上移动
        await txn.rawUpdate(
          'UPDATE bookshelf SET `order` = `order` + 1 WHERE `order` >= ? AND `order` < ?',
          [newOrder, currentOrder],
        );
      } else if (newOrder > currentOrder) {
        // 向下移动
        await txn.rawUpdate(
          'UPDATE bookshelf SET `order` = `order` - 1 WHERE `order` > ? AND `order` <= ?',
          [currentOrder, newOrder],
        );
      }

      // 更新当前书籍order
      await txn.update(
        'bookshelf',
        {'order': newOrder},
        where: 'id = ?',
        whereArgs: [bookId],
      );
    });

    await loadBooks();
  }

  /// 保存章节列表
  Future<void> saveChapters(String directoryUrl, List<Map<String, dynamic>> chapters) async {
    final db = DatabaseHelper().bookshelfDb;

    await db.transaction((txn) async {
      // 删除旧章节
      await txn.delete(
        'chapters',
        where: 'directory_url = ?',
        whereArgs: [directoryUrl],
      );

      // 插入新章节
      for (int i = 0; i < chapters.length; i++) {
        await txn.insert('chapters', {
          'directory_url': directoryUrl,
          'chapter_title': chapters[i]['title'],
          'chapter_url': chapters[i]['url'],
          'chapter_order': i,
        });
      }
    });
  }

  /// 获取章节列表
  Future<List<Map<String, dynamic>>> getChapters(String directoryUrl) async {
    final db = DatabaseHelper().bookshelfDb;

    final List<Map<String, dynamic>> maps = await db.query(
      'chapters',
      where: 'directory_url = ?',
      whereArgs: [directoryUrl],
      orderBy: 'chapter_order ASC',
    );

    return maps.map((map) => {
      'title': map['chapter_title']?.toString() ?? '',
      'url': map['chapter_url']?.toString() ?? '',
    }).toList();
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(int bookId) async {
    // 原应用没有收藏功能，这里可以扩展
  }

  /// 获取收藏的书籍
  List<Book> getFavoriteBooks() {
    return [];
  }

  /// 获取最近阅读的书籍
  List<Book> getRecentBooks({int limit = 10}) {
    return _books.take(limit).toList();
  }

  /// 获取下载路径
  Future<String> getBookDownloadPath(String bookTitle) async {
    return StorageService().getBookDownloadPath(bookTitle);
  }

  /// 保存章节内容到文件
  Future<void> saveChapterContent(String bookTitle, int chapterIndex, String content) async {
    final filePath = await StorageService().getChapterFilePath(bookTitle, chapterIndex);
    final file = File(filePath);
    await file.writeAsString(content);
  }

  /// 读取章节内容
  Future<String?> readChapterContent(String bookTitle, int chapterIndex) async {
    try {
      final filePath = await StorageService().getChapterFilePath(bookTitle, chapterIndex);
      final file = File(filePath);

      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      // 忽略读取错误
    }
    return null;
  }
}
