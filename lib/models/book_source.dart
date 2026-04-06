/// 书源配置模型
class BookSource {
  int? id;
  String sourceName;
  String websiteUrl;
  String websiteEncoding;
  String? searchUrl;
  String searchType;
  String? searchList;
  String? searchName;
  String? searchAuthor;
  String? searchCover;
  String? searchDesc;
  String? searchChapter;
  String? searchUrlPattern;
  String? exploreUrl;
  String? exploreList;
  String? exploreName;
  String? exploreAuthor;
  String? exploreCover;
  String? exploreDesc;
  String? exploreChapter;
  String? bookUrlPattern;
  String? tocUrlPattern;
  String? chapterUrlPattern;
  
  // 与原应用兼容的字段别名
  String? get bookInfoUrl => bookUrlPattern;
  set bookInfoUrl(String? value) => bookUrlPattern = value;
  
  String? get directoryUrl => tocUrlPattern;
  set directoryUrl(String? value) => tocUrlPattern = value;
  
  String? get chapterUrl => chapterUrlPattern;
  set chapterUrl(String? value) => chapterUrlPattern = value;
  
  String? get categoryRank => exploreUrl;
  set categoryRank(String? value) => exploreUrl = value;
  String? tocList;
  String? tocName;
  String? tocUrl;
  String? contentUrlPattern;
  String? contentRule;
  String? nextPageRule;
  String? prevPageRule;
  String? coverRule;
  String? descRule;
  String? authorRule;
  String? bookNameRule;
  String? latestChapterRule;
  int? chapterOrder;
  bool isEnabled;
  int? searchStatus;
  int? exploreStatus;
  DateTime? createdAt;
  DateTime? updatedAt;

  BookSource({
    this.id,
    this.sourceName = '',
    this.websiteUrl = '',
    this.websiteEncoding = 'UTF-8',
    this.searchUrl,
    this.searchType = 'GET',
    this.searchList,
    this.searchName,
    this.searchAuthor,
    this.searchCover,
    this.searchDesc,
    this.searchChapter,
    this.searchUrlPattern,
    this.exploreUrl,
    this.exploreList,
    this.exploreName,
    this.exploreAuthor,
    this.exploreCover,
    this.exploreDesc,
    this.exploreChapter,
    this.bookUrlPattern,
    this.tocUrlPattern,
    this.chapterUrlPattern,
    this.tocList,
    this.tocName,
    this.tocUrl,
    this.contentUrlPattern,
    this.contentRule,
    this.nextPageRule,
    this.prevPageRule,
    this.coverRule,
    this.descRule,
    this.authorRule,
    this.bookNameRule,
    this.latestChapterRule,
    this.chapterOrder = 0,
    this.isEnabled = true,
    this.searchStatus,
    this.exploreStatus,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sourceName': sourceName,
      'websiteUrl': websiteUrl,
      'websiteEncoding': websiteEncoding,
      'searchUrl': searchUrl,
      'searchType': searchType,
      'searchList': searchList,
      'searchName': searchName,
      'searchAuthor': searchAuthor,
      'searchCover': searchCover,
      'searchDesc': searchDesc,
      'searchChapter': searchChapter,
      'searchUrlPattern': searchUrlPattern,
      'exploreUrl': exploreUrl,
      'exploreList': exploreList,
      'exploreName': exploreName,
      'exploreAuthor': exploreAuthor,
      'exploreCover': exploreCover,
      'exploreDesc': exploreDesc,
      'exploreChapter': exploreChapter,
      'bookUrlPattern': bookUrlPattern,
      'tocUrlPattern': tocUrlPattern,
      'chapterUrlPattern': chapterUrlPattern,
      'tocList': tocList,
      'tocName': tocName,
      'tocUrl': tocUrl,
      'contentUrlPattern': contentUrlPattern,
      'contentRule': contentRule,
      'nextPageRule': nextPageRule,
      'prevPageRule': prevPageRule,
      'coverRule': coverRule,
      'descRule': descRule,
      'authorRule': authorRule,
      'bookNameRule': bookNameRule,
      'latestChapterRule': latestChapterRule,
      'chapterOrder': chapterOrder,
      'isEnabled': isEnabled ? 1 : 0,
      'searchStatus': searchStatus,
      'exploreStatus': exploreStatus,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory BookSource.fromMap(Map<String, dynamic> map) {
    return BookSource(
      id: map['id'],
      sourceName: map['sourceName'] ?? '',
      websiteUrl: map['websiteUrl'] ?? '',
      websiteEncoding: map['websiteEncoding'] ?? 'UTF-8',
      searchUrl: map['searchUrl'],
      searchType: map['searchType'] ?? 'GET',
      searchList: map['searchList'],
      searchName: map['searchName'],
      searchAuthor: map['searchAuthor'],
      searchCover: map['searchCover'],
      searchDesc: map['searchDesc'],
      searchChapter: map['searchChapter'],
      searchUrlPattern: map['searchUrlPattern'],
      exploreUrl: map['exploreUrl'],
      exploreList: map['exploreList'],
      exploreName: map['exploreName'],
      exploreAuthor: map['exploreAuthor'],
      exploreCover: map['exploreCover'],
      exploreDesc: map['exploreDesc'],
      exploreChapter: map['exploreChapter'],
      bookUrlPattern: map['bookUrlPattern'],
      tocUrlPattern: map['tocUrlPattern'],
      chapterUrlPattern: map['chapterUrlPattern'],
      tocList: map['tocList'],
      tocName: map['tocName'],
      tocUrl: map['tocUrl'],
      contentUrlPattern: map['contentUrlPattern'],
      contentRule: map['contentRule'],
      nextPageRule: map['nextPageRule'],
      prevPageRule: map['prevPageRule'],
      coverRule: map['coverRule'],
      descRule: map['descRule'],
      authorRule: map['authorRule'],
      bookNameRule: map['bookNameRule'],
      latestChapterRule: map['latestChapterRule'],
      chapterOrder: map['chapterOrder'] ?? 0,
      isEnabled: map['isEnabled'] != 0,
      searchStatus: map['searchStatus'],
      exploreStatus: map['exploreStatus'],
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
    );
  }

  BookSource copyWith({
    int? id,
    String? sourceName,
    String? websiteUrl,
    String? websiteEncoding,
    String? searchUrl,
    String? searchType,
    String? searchList,
    String? searchName,
    String? searchAuthor,
    String? searchCover,
    String? searchDesc,
    String? searchChapter,
    String? searchUrlPattern,
    String? exploreUrl,
    String? exploreList,
    String? exploreName,
    String? exploreAuthor,
    String? exploreCover,
    String? exploreDesc,
    String? exploreChapter,
    String? bookUrlPattern,
    String? tocUrlPattern,
    String? chapterUrlPattern,
    String? tocList,
    String? tocName,
    String? tocUrl,
    String? contentUrlPattern,
    String? contentRule,
    String? nextPageRule,
    String? prevPageRule,
    String? coverRule,
    String? descRule,
    String? authorRule,
    String? bookNameRule,
    String? latestChapterRule,
    int? chapterOrder,
    bool? isEnabled,
    int? searchStatus,
    int? exploreStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookSource(
      id: id ?? this.id,
      sourceName: sourceName ?? this.sourceName,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      websiteEncoding: websiteEncoding ?? this.websiteEncoding,
      searchUrl: searchUrl ?? this.searchUrl,
      searchType: searchType ?? this.searchType,
      searchList: searchList ?? this.searchList,
      searchName: searchName ?? this.searchName,
      searchAuthor: searchAuthor ?? this.searchAuthor,
      searchCover: searchCover ?? this.searchCover,
      searchDesc: searchDesc ?? this.searchDesc,
      searchChapter: searchChapter ?? this.searchChapter,
      searchUrlPattern: searchUrlPattern ?? this.searchUrlPattern,
      exploreUrl: exploreUrl ?? this.exploreUrl,
      exploreList: exploreList ?? this.exploreList,
      exploreName: exploreName ?? this.exploreName,
      exploreAuthor: exploreAuthor ?? this.exploreAuthor,
      exploreCover: exploreCover ?? this.exploreCover,
      exploreDesc: exploreDesc ?? this.exploreDesc,
      exploreChapter: exploreChapter ?? this.exploreChapter,
      bookUrlPattern: bookUrlPattern ?? this.bookUrlPattern,
      tocUrlPattern: tocUrlPattern ?? this.tocUrlPattern,
      chapterUrlPattern: chapterUrlPattern ?? this.chapterUrlPattern,
      tocList: tocList ?? this.tocList,
      tocName: tocName ?? this.tocName,
      tocUrl: tocUrl ?? this.tocUrl,
      contentUrlPattern: contentUrlPattern ?? this.contentUrlPattern,
      contentRule: contentRule ?? this.contentRule,
      nextPageRule: nextPageRule ?? this.nextPageRule,
      prevPageRule: prevPageRule ?? this.prevPageRule,
      coverRule: coverRule ?? this.coverRule,
      descRule: descRule ?? this.descRule,
      authorRule: authorRule ?? this.authorRule,
      bookNameRule: bookNameRule ?? this.bookNameRule,
      latestChapterRule: latestChapterRule ?? this.latestChapterRule,
      chapterOrder: chapterOrder ?? this.chapterOrder,
      isEnabled: isEnabled ?? this.isEnabled,
      searchStatus: searchStatus ?? this.searchStatus,
      exploreStatus: exploreStatus ?? this.exploreStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 创建默认书源
  static BookSource createDefault() {
    return BookSource(
      sourceName: '示例书源',
      websiteUrl: 'https://example.com',
      websiteEncoding: 'UTF-8',
      searchType: 'GET',
      isEnabled: true,
    );
  }

  /// 转换为书源文本格式
  String toSourceText() {
    final buffer = StringBuffer();
    buffer.writeln('网站名称=$sourceName');
    buffer.writeln('网站网址=$websiteUrl');
    buffer.writeln('网站编码=$websiteEncoding');
    if (searchUrl != null) buffer.writeln('搜索网址=$searchUrl');
    if (searchType != 'GET') buffer.writeln('搜索类型=$searchType');
    if (searchList != null) buffer.writeln('搜索列表=$searchList');
    if (searchName != null) buffer.writeln('搜索书名=$searchName');
    if (searchAuthor != null) buffer.writeln('搜索作者=$searchAuthor');
    if (exploreUrl != null) buffer.writeln('分类排行=$exploreUrl');
    if (bookUrlPattern != null) buffer.writeln('简介页网址=$bookUrlPattern');
    if (tocUrlPattern != null) buffer.writeln('目录页网址=$tocUrlPattern');
    if (chapterUrlPattern != null) buffer.writeln('章节页网址=$chapterUrlPattern');
    if (tocList != null) buffer.writeln('目录章节列表=$tocList');
    if (tocName != null) buffer.writeln('目录章节名称=$tocName');
    if (tocUrl != null) buffer.writeln('目录章节网址=$tocUrl');
    if (contentRule != null) buffer.writeln('章节内容=$contentRule');
    if (chapterOrder != null) buffer.writeln('目录章节排序方式=${chapterOrder == 0 ? "正序" : "倒序"}');
    return buffer.toString();
  }

  /// 从书源文本解析
  static BookSource fromSourceText(String text) {
    final source = BookSource.createDefault();
    final lines = text.split('\n');
    
    for (final line in lines) {
      final parts = line.split('=');
      if (parts.length != 2) continue;
      
      final key = parts[0].trim();
      final value = parts[1].trim();
      
      switch (key) {
        case '网站名称':
          source.sourceName = value;
          break;
        case '网站网址':
          source.websiteUrl = value;
          break;
        case '网站编码':
          source.websiteEncoding = value;
          break;
        case '搜索网址':
          source.searchUrl = value;
          break;
        case '搜索类型':
          source.searchType = value;
          break;
        case '搜索列表':
          source.searchList = value;
          break;
        case '搜索书名':
          source.searchName = value;
          break;
        case '搜索作者':
          source.searchAuthor = value;
          break;
        case '分类排行':
          source.exploreUrl = value;
          break;
        case '简介页网址':
          source.bookUrlPattern = value;
          break;
        case '目录页网址':
          source.tocUrlPattern = value;
          break;
        case '章节页网址':
          source.chapterUrlPattern = value;
          break;
        case '目录章节列表':
          source.tocList = value;
          break;
        case '目录章节名称':
          source.tocName = value;
          break;
        case '目录章节网址':
          source.tocUrl = value;
          break;
        case '章节内容':
          source.contentRule = value;
          break;
        case '目录章节排序方式':
          source.chapterOrder = value == '正序' ? 0 : 1;
          break;
      }
    }
    
    return source;
  }
}
