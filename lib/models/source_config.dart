import 'package:flutter/material.dart';

// 搜索类型枚举
enum SearchType {
  GET('GET'),
  POST('POST');

  final String value;
  const SearchType(this.value);

  static SearchType fromString(String value) {
    return SearchType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SearchType.GET,
    );
  }
}

// 排序类型枚举
enum SortType {
  ASC('正序'),
  DESC('倒序');

  final String value;
  const SortType(this.value);

  static SortType fromString(String value) {
    return SortType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SortType.ASC,
    );
  }
}

// 书源状态枚举
enum SourceStatus {
  UNKNOWN(2, '未知'),
  VALID(1, '有效'),
  INVALID(0, '失效');

  final int value;
  final String label;
  const SourceStatus(this.value, this.label);

  static SourceStatus fromInt(int value) {
    return SourceStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SourceStatus.UNKNOWN,
    );
  }
}

// 书源配置类
class SourceConfig {
  String sourceName;           // 网站名称
  String websiteUrl;           // 网站网址
  String websiteEncoding;      // 网站编码
  String bookUrlPattern;       // 简介页网址规则
  String tocUrlPattern;        // 目录页网址规则
  String chapterUrlPattern;    // 章节页网址规则
  SortType sortType;           // 目录章节排序方式
  String searchUrl;            // 搜索网址
  SearchType searchType;       // 搜索类型
  String categoryRank;         // 分类排行
  int searchStatus;            // 搜索状态 0=失效 1=有效 2=未知
  int categoryStatus;          // 分类状态 0=失效 1=有效 2=未知

  // 兼容性属性
  String get sourceUrl => websiteUrl;
  String get encoding => websiteEncoding;

  SourceConfig({
    this.sourceName = '',
    this.websiteUrl = '',
    this.websiteEncoding = 'UTF-8',
    this.bookUrlPattern = '',
    this.tocUrlPattern = '',
    this.chapterUrlPattern = '',
    this.sortType = SortType.ASC,
    this.searchUrl = '',
    this.searchType = SearchType.GET,
    this.categoryRank = '',
    this.searchStatus = 2,
    this.categoryStatus = 2,
  });

  // 从Map创建
  factory SourceConfig.fromMap(Map<String, dynamic> map) {
    return SourceConfig(
      sourceName: map['sourceName'] ?? '',
      websiteUrl: map['websiteUrl'] ?? '',
      websiteEncoding: map['websiteEncoding'] ?? 'UTF-8',
      bookUrlPattern: map['bookUrlPattern'] ?? '',
      tocUrlPattern: map['tocUrlPattern'] ?? '',
      chapterUrlPattern: map['chapterUrlPattern'] ?? '',
      sortType: SortType.fromString(map['sortType'] ?? '正序'),
      searchUrl: map['searchUrl'] ?? '',
      searchType: SearchType.fromString(map['searchType'] ?? 'GET'),
      categoryRank: map['categoryRank'] ?? '',
      searchStatus: map['searchStatus'] ?? 2,
      categoryStatus: map['categoryStatus'] ?? 2,
    );
  }

  // 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'sourceName': sourceName,
      'websiteUrl': websiteUrl,
      'websiteEncoding': websiteEncoding,
      'bookUrlPattern': bookUrlPattern,
      'tocUrlPattern': tocUrlPattern,
      'chapterUrlPattern': chapterUrlPattern,
      'sortType': sortType.value,
      'searchUrl': searchUrl,
      'searchType': searchType.value,
      'categoryRank': categoryRank,
      'searchStatus': searchStatus,
      'categoryStatus': categoryStatus,
    };
  }

  // 从文本内容解析
  static SourceConfig fromText(String content) {
    final source = SourceConfig();
    final lines = content.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.contains('=')) {
        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();

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
            case '简介页网址规则':
              source.bookUrlPattern = value;
              break;
            case '目录页网址规则':
              source.tocUrlPattern = value;
              break;
            case '章节页网址规则':
              source.chapterUrlPattern = value;
              break;
            case '目录章节排序方式':
              source.sortType = SortType.fromString(value);
              break;
            case '搜索网址':
              source.searchUrl = value;
              break;
            case '搜索类型':
              source.searchType = SearchType.fromString(value);
              break;
            case '分类排行':
              source.categoryRank = value;
              break;
            case '搜索状态':
              source.searchStatus = int.tryParse(value) ?? 2;
              break;
            case '分类状态':
              source.categoryStatus = int.tryParse(value) ?? 2;
              break;
          }
        }
      }
    }

    return source;
  }

  // 转换为文本格式
  String toText() {
    final lines = [
      '网站名称=$sourceName',
      '网站网址=$websiteUrl',
      '网站编码=$websiteEncoding',
      '简介页网址规则=$bookUrlPattern',
      '目录页网址规则=$tocUrlPattern',
      '章节页网址规则=$chapterUrlPattern',
      '目录章节排序方式=${sortType.value}',
      '搜索网址=$searchUrl',
      '搜索类型=${searchType.value}',
      '分类排行=$categoryRank',
      '搜索状态=$searchStatus',
      '分类状态=$categoryStatus',
    ];
    return lines.join('\n');
  }

  // 创建默认书源
  static SourceConfig createDefault() {
    return SourceConfig(
      sourceName: '新网站',
      websiteUrl: 'http://www.example.com',
      websiteEncoding: 'UTF-8',
      searchUrl: 'http://www.example.com/search?keyword={key}&page={page}',
      searchType: SearchType.GET,
      bookUrlPattern: 'http://www.example.com/bookid',
      tocUrlPattern: 'http://www.example.com/bookid',
      chapterUrlPattern: 'http://www.example.com/bookid/chapterid.html',
    );
  }

  // 复制
  SourceConfig copy() {
    return SourceConfig.fromMap(toMap());
  }
}

// 分类排行项
class CategoryRankItem {
  final String name;
  final String url;

  CategoryRankItem({required this.name, required this.url});

  // 从字符串解析 (格式: 分类名::网址)
  static CategoryRankItem? fromString(String str) {
    final parts = str.split('::');
    if (parts.length == 2) {
      return CategoryRankItem(
        name: parts[0].trim(),
        url: parts[1].trim(),
      );
    }
    return null;
  }

  @override
  String toString() => '$name::$url';
}

// 解析分类排行字符串
List<CategoryRankItem> parseCategoryRank(String categoryRank) {
  final items = <CategoryRankItem>[];
  if (categoryRank.isEmpty) return items;

  final parts = categoryRank.split('&&');
  for (final part in parts) {
    final item = CategoryRankItem.fromString(part);
    if (item != null) {
      items.add(item);
    }
  }
  return items;
}

// 将分类排行列表转换为字符串
String categoryRankToString(List<CategoryRankItem> items) {
  return items.map((e) => e.toString()).join('&&');
}
