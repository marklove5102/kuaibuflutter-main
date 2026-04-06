import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'storage_service.dart';

/// 阅读进度模型
class ReadingProgress {
  String bookName;
  String bookUrl;
  String chapterTitle;
  String chapterUrl;
  int chapterIndex;
  double scrollPosition;
  DateTime? lastReadTime;

  ReadingProgress({
    required this.bookName,
    required this.bookUrl,
    required this.chapterTitle,
    required this.chapterUrl,
    this.chapterIndex = 0,
    this.scrollPosition = 0.0,
    this.lastReadTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'book': {
        'name': bookName,
        'url': bookUrl,
      },
      'chapter': {
        'title': chapterTitle,
        'url': chapterUrl,
        'index': chapterIndex,
      },
      'scroll_position': scrollPosition,
      'last_read_time': lastReadTime?.toIso8601String(),
    };
  }

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    final book = map['book'] ?? {};
    final chapter = map['chapter'] ?? {};
    
    return ReadingProgress(
      bookName: book['name'] ?? '',
      bookUrl: book['url'] ?? '',
      chapterTitle: chapter['title'] ?? '',
      chapterUrl: chapter['url'] ?? '',
      chapterIndex: chapter['index'] ?? 0,
      scrollPosition: (map['scroll_position'] ?? 0).toDouble(),
      lastReadTime: map['last_read_time'] != null
          ? DateTime.tryParse(map['last_read_time'])
          : null,
    );
  }
}

/// 书签模型
class Bookmark {
  String bookTitle;
  String chapterTitle;
  int chapterIndex;
  double scrollPosition;
  String bookmarkName;
  DateTime createTime;

  Bookmark({
    required this.bookTitle,
    required this.chapterTitle,
    this.chapterIndex = 0,
    this.scrollPosition = 0.0,
    required this.bookmarkName,
    DateTime? createTime,
  }) : createTime = createTime ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'book_title': bookTitle,
      'chapter_title': chapterTitle,
      'chapter_index': chapterIndex,
      'scroll_position': scrollPosition,
      'bookmark_name': bookmarkName,
      'create_time': createTime.toIso8601String(),
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      bookTitle: map['book_title'] ?? '',
      chapterTitle: map['chapter_title'] ?? '',
      chapterIndex: map['chapter_index'] ?? 0,
      scrollPosition: (map['scroll_position'] ?? 0).toDouble(),
      bookmarkName: map['bookmark_name'] ?? '',
      createTime: map['create_time'] != null
          ? DateTime.tryParse(map['create_time'])
          : DateTime.now(),
    );
  }
}

/// 阅读进度管理器
class ReadingProgressManager {
  static final ReadingProgressManager _instance = ReadingProgressManager._internal();
  factory ReadingProgressManager() => _instance;
  ReadingProgressManager._internal();

  Map<String, dynamic> _data = {
    'progress': [],
    'bookmarks': [],
  };
  bool _initialized = false;
  String? _cachedFilePath;

  /// 获取进度文件路径
  Future<String> get _progressFilePath async {
    if (_cachedFilePath != null) {
      return _cachedFilePath!;
    }
    final appDir = await StorageService().getAppDirectory();
    _cachedFilePath = path.join(appDir.path, 'reading_progress.json');
    return _cachedFilePath!;
  }

  /// 初始化
  Future<void> init() async {
    if (_initialized) {
      return;
    }
    
    await _loadData();
    _initialized = true;
  }

  /// 重新加载数据（用于进度文件被外部修改后刷新）
  Future<void> reload() async {
    _initialized = false;
    await init();
  }

  /// 加载数据
  Future<void> _loadData() async {
    try {
      final filePath = await _progressFilePath;
      final file = File(filePath);
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        
        if (data is List) {
          _data = {
            'progress': data,
            'bookmarks': [],
          };
        } else {
          _data = {
            'progress': data['progress'] ?? [],
            'bookmarks': data['bookmarks'] ?? [],
          };
        }
      } else {
        _data = {
          'progress': [],
          'bookmarks': [],
        };
      }
    } catch (e) {
      _data = {
        'progress': [],
        'bookmarks': [],
      };
    }
  }

  /// 保存数据
  Future<void> _saveData() async {
    try {
      final filePath = await _progressFilePath;
      final file = File(filePath);
      final jsonContent = jsonEncode(_data);
      await file.writeAsString(jsonContent);
    } catch (e) {
      // 忽略保存错误
    }
  }

  /// 保存阅读进度
  Future<void> saveProgress(ReadingProgress progress) async {
    await init();
    
    final progressList = _data['progress'] as List;
    
    int existingIndex = -1;
    for (int i = 0; i < progressList.length; i++) {
      final p = progressList[i];
      if (p['book']?['name'] == progress.bookName &&
          p['book']?['url'] == progress.bookUrl) {
        existingIndex = i;
        break;
      }
    }
    
    final progressMap = progress.toMap();
    progressMap['last_read_time'] = DateTime.now().toIso8601String();
    
    if (existingIndex >= 0) {
      progressList[existingIndex] = progressMap;
    } else {
      progressList.add(progressMap);
    }
    
    await _saveData();
  }

  /// 同步保存阅读进度（用于dispose时调用）
  void saveProgressSync(ReadingProgress progress) {
    if (_cachedFilePath == null) {
      final appDir = StorageService().getAppDirectorySync();
      if (appDir != null) {
        _cachedFilePath = path.join(appDir.path, 'reading_progress.json');
      }
    }

    if (_cachedFilePath == null) {
      return;
    }

    try {
      final progressList = _data['progress'] as List;
      
      int existingIndex = -1;
      for (int i = 0; i < progressList.length; i++) {
        final p = progressList[i];
        if (p['book']?['name'] == progress.bookName &&
            p['book']?['url'] == progress.bookUrl) {
          existingIndex = i;
          break;
        }
      }
      
      final progressMap = progress.toMap();
      progressMap['last_read_time'] = DateTime.now().toIso8601String();
      
      if (existingIndex >= 0) {
        progressList[existingIndex] = progressMap;
      } else {
        progressList.add(progressMap);
      }
      
      final file = File(_cachedFilePath!);
      final jsonContent = jsonEncode(_data);
      file.writeAsStringSync(jsonContent);
    } catch (e) {
      // 忽略同步保存错误
    }
  }

  /// 获取阅读进度
  Future<ReadingProgress?> getProgress(String bookName, String bookUrl) async {
    await init();
    
    final progressList = _data['progress'] as List;
    
    for (final p in progressList) {
      if (p['book']?['name'] == bookName && p['book']?['url'] == bookUrl) {
        return ReadingProgress.fromMap(p);
      }
    }
    
    return null;
  }

  /// 删除阅读进度
  Future<void> deleteProgress(String bookName, String bookUrl) async {
    await init();
    
    final progressList = _data['progress'] as List;
    progressList.removeWhere((p) =>
        p['book']?['name'] == bookName && p['book']?['url'] == bookUrl);
    
    await _saveData();
  }

  /// 获取所有阅读进度
  Future<List<ReadingProgress>> getAllProgress() async {
    await init();
    
    final progressList = _data['progress'] as List;
    return progressList.map((p) => ReadingProgress.fromMap(p)).toList();
  }

  /// 保存书签
  Future<void> saveBookmark(Bookmark bookmark) async {
    await init();
    
    final bookmarkList = _data['bookmarks'] as List;
    bookmarkList.add(bookmark.toMap());
    
    await _saveData();
  }

  /// 获取书籍的所有书签
  Future<List<Bookmark>> getBookmarks(String bookTitle) async {
    await init();
    
    final bookmarkList = _data['bookmarks'] as List;
    return bookmarkList
        .where((b) => b['book_title'] == bookTitle)
        .map((b) => Bookmark.fromMap(b))
        .toList();
  }

  /// 删除书签
  Future<void> deleteBookmark(String bookTitle, DateTime createTime) async {
    await init();
    
    final bookmarkList = _data['bookmarks'] as List;
    bookmarkList.removeWhere((b) =>
        b['book_title'] == bookTitle &&
        b['create_time'] == createTime.toIso8601String());
    
    await _saveData();
  }

  /// 删除书籍的所有书签
  Future<void> deleteAllBookmarks(String bookTitle) async {
    await init();
    
    final bookmarkList = _data['bookmarks'] as List;
    bookmarkList.removeWhere((b) => b['book_title'] == bookTitle);
    
    await _saveData();
  }

  /// 获取所有书签
  Future<List<Bookmark>> getAllBookmarks() async {
    await init();
    
    final bookmarkList = _data['bookmarks'] as List;
    return bookmarkList.map((b) => Bookmark.fromMap(b)).toList();
  }

  /// 清除所有数据
  Future<void> clearAll() async {
    _data = {
      'progress': [],
      'bookmarks': [],
    };
    await _saveData();
  }
}
