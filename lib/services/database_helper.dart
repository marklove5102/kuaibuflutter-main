import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<DatabaseFactory> _getDatabaseFactory() async {
  if (Platform.isAndroid) {
    return databaseFactory;
  } else {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
}

/// 数据库帮助类
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _bookshelfDb;
  Database? _replaceDb;

  /// 获取程序基础目录
  Future<String> getBaseDir() async {
    if (Platform.isAndroid) {
      // 使用外部存储的 kuaibu 目录，防止更新丢失数据
      final kuaibuDir = Directory('/storage/emulated/0/kuaibu');
      try {
        if (!await kuaibuDir.exists()) {
          await kuaibuDir.create(recursive: true);
        }
        // 测试写入权限
        final testFile = File('${kuaibuDir.path}/.test');
        await testFile.writeAsString('test');
        await testFile.delete();
        return kuaibuDir.path;
      } catch (e) {
        final docDir = await getApplicationDocumentsDirectory();
        return docDir.path;
      }
    }
    final executable = Platform.resolvedExecutable;
    final exeDir = path.dirname(executable);
    if (exeDir.contains('flutter') || exeDir.contains('build')) {
      return Directory.current.path;
    }
    return exeDir;
  }

  /// 初始化数据库
  Future<void> init() async {
    final dbFactory = await _getDatabaseFactory();

    await _initBookshelfDb(dbFactory);
    await _initReplaceDb(dbFactory);
  }

  /// 初始化书架数据库
  Future<void> _initBookshelfDb(DatabaseFactory dbFactory) async {
    final baseDir = await getBaseDir();
    final dbPath = path.join(baseDir, 'bookshelf.db');

    _bookshelfDb = await dbFactory.openDatabase(dbPath);
    
    // 创建书架表
    await _bookshelfDb!.execute('''
      CREATE TABLE IF NOT EXISTS bookshelf (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        website_name TEXT NOT NULL,
        book_name TEXT NOT NULL,
        directory_url TEXT NOT NULL,
        chapter_name TEXT,
        chapter_url TEXT,
        cover_path TEXT DEFAULT 'cover/default.jpg',
        `order` INTEGER DEFAULT 0,
        last_read_time TEXT
      )
    ''');
    
    // 检查并添加 last_read_time 列（兼容旧数据库）
    try {
      await _bookshelfDb!.execute('ALTER TABLE bookshelf ADD COLUMN last_read_time TEXT');
    } catch (e) {
      // 列已存在，忽略错误
    }
    
    // 创建章节表
    await _bookshelfDb!.execute('''
      CREATE TABLE IF NOT EXISTS chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        directory_url TEXT NOT NULL,
        chapter_title TEXT NOT NULL,
        chapter_url TEXT NOT NULL,
        chapter_order INTEGER NOT NULL
      )
    ''');
    
    // 创建索引
    await _bookshelfDb!.execute(
      'CREATE INDEX IF NOT EXISTS idx_chapters_directory_url ON chapters(directory_url)'
    );
  }

  /// 初始化替换规则数据库
  Future<void> _initReplaceDb(DatabaseFactory dbFactory) async {
    final baseDir = await getBaseDir();
    final dbPath = path.join(baseDir, 'replace.db');

    _replaceDb = await dbFactory.openDatabase(dbPath);
    
    // 创建替换规则表
    await _replaceDb!.execute('''
      CREATE TABLE IF NOT EXISTS replace_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        enabled INTEGER DEFAULT 1,
        scope TEXT DEFAULT 'all_sites',
        scope_value TEXT DEFAULT '',
        book_scope TEXT DEFAULT 'all_books',
        book_name TEXT DEFAULT '',
        replace_type TEXT DEFAULT 'normal',
        find_text TEXT NOT NULL,
        replace_text TEXT DEFAULT ''
      )
    ''');
  }

  /// 获取书架数据库
  Database get bookshelfDb {
    if (_bookshelfDb == null) {
      throw Exception('数据库未初始化');
    }
    return _bookshelfDb!;
  }

  /// 获取替换规则数据库
  Database get replaceDb {
    if (_replaceDb == null) {
      throw Exception('数据库未初始化');
    }
    return _replaceDb!;
  }

  /// 关闭数据库
  Future<void> close() async {
    await _bookshelfDb?.close();
    await _replaceDb?.close();
    _bookshelfDb = null;
    _replaceDb = null;
  }
}
