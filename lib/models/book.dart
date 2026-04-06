/// 书籍模型
class Book {
  int? id;
  String title;
  String author;
  String? coverUrl;
  String? description;
  String? lastReadChapter;
  int lastReadChapterIndex;
  int totalChapters;
  String? sourceUrl;
  String? sourceName;
  DateTime? lastReadTime;
  DateTime? addedTime;
  String? localPath;
  int readProgress;
  bool isFavorite;

  Book({
    this.id,
    required this.title,
    this.author = '',
    this.coverUrl,
    this.description,
    this.lastReadChapter,
    this.lastReadChapterIndex = 0,
    this.totalChapters = 0,
    this.sourceUrl,
    this.sourceName,
    this.lastReadTime,
    this.addedTime,
    this.localPath,
    this.readProgress = 0,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'description': description,
      'lastReadChapter': lastReadChapter,
      'lastReadChapterIndex': lastReadChapterIndex,
      'totalChapters': totalChapters,
      'sourceUrl': sourceUrl,
      'sourceName': sourceName,
      'lastReadTime': lastReadTime?.toIso8601String(),
      'addedTime': addedTime?.toIso8601String(),
      'localPath': localPath,
      'readProgress': readProgress,
      'isFavorite': isFavorite ? 1 : 0,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'] ?? '',
      author: map['author'] ?? '',
      coverUrl: map['coverUrl'],
      description: map['description'],
      lastReadChapter: map['lastReadChapter'],
      lastReadChapterIndex: map['lastReadChapterIndex'] ?? 0,
      totalChapters: map['totalChapters'] ?? 0,
      sourceUrl: map['sourceUrl'],
      sourceName: map['sourceName'],
      lastReadTime: map['lastReadTime'] != null
          ? DateTime.parse(map['lastReadTime'])
          : null,
      addedTime: map['addedTime'] != null
          ? DateTime.parse(map['addedTime'])
          : null,
      localPath: map['localPath'],
      readProgress: map['readProgress'] ?? 0,
      isFavorite: map['isFavorite'] == 1,
    );
  }

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? coverUrl,
    String? description,
    String? lastReadChapter,
    int? lastReadChapterIndex,
    int? totalChapters,
    String? sourceUrl,
    String? sourceName,
    DateTime? lastReadTime,
    DateTime? addedTime,
    String? localPath,
    int? readProgress,
    bool? isFavorite,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      description: description ?? this.description,
      lastReadChapter: lastReadChapter ?? this.lastReadChapter,
      lastReadChapterIndex: lastReadChapterIndex ?? this.lastReadChapterIndex,
      totalChapters: totalChapters ?? this.totalChapters,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceName: sourceName ?? this.sourceName,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      addedTime: addedTime ?? this.addedTime,
      localPath: localPath ?? this.localPath,
      readProgress: readProgress ?? this.readProgress,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  /// 从数据库映射创建Book
  factory Book.fromDbMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['book_name'] ?? '',
      author: '',
      coverUrl: map['cover_path'],
      description: null,
      lastReadChapter: map['chapter_name'],
      lastReadChapterIndex: 0,
      totalChapters: 0,
      sourceUrl: map['directory_url'],
      sourceName: map['website_name'],
      lastReadTime: map['last_read_time'] != null
          ? DateTime.tryParse(map['last_read_time'])
          : null,
      addedTime: null,
      localPath: null,
      readProgress: 0,
      isFavorite: false,
    );
  }

  /// 转换为数据库映射
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'website_name': sourceName,
      'book_name': title,
      'directory_url': sourceUrl,
      'chapter_name': lastReadChapter,
      'chapter_url': null,
      'cover_path': coverUrl ?? 'cover/default.jpg',
      'order': 0,
    };
  }

  /// 获取最后阅读章节的URL
  String? get lastReadChapterUrl => null;
}

/// 章节模型
class Chapter {
  String title;
  String url;
  int index;
  bool isDownloaded;
  String? content;

  Chapter({
    required this.title,
    required this.url,
    required this.index,
    this.isDownloaded = false,
    this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'index': index,
      'isDownloaded': isDownloaded ? 1 : 0,
      'content': content,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      index: map['index'] ?? 0,
      isDownloaded: map['isDownloaded'] == 1,
      content: map['content'],
    );
  }
}

/// 搜索结果模型
class SearchResult {
  String title;
  String author;
  String? coverUrl;
  String? description;
  String bookUrl;
  String sourceName;
  String sourceUrl;
  String? latestChapter;

  SearchResult({
    required this.title,
    required this.author,
    this.coverUrl,
    this.description,
    required this.bookUrl,
    required this.sourceName,
    required this.sourceUrl,
    this.latestChapter,
  });
}

/// 搜索类型枚举
enum SearchType {
  all,
  bookName,
  author,
}

/// 排序类型枚举
enum SortType {
  defaultSort,
  updateTime,
  wordCount,
}
