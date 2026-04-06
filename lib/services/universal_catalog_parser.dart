import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' show Element;
import '../utils/url_utils.dart';
import '../utils/chapter_utils.dart';
import '../utils/text_utils.dart';
import 'network_service.dart';

/// 通用目录解析器 - 无需书源配置，自动解析目录页
class UniversalCatalogParser {
  final NetworkService _networkService = NetworkService();

  /// 标准URL信息（用于过滤）
  String? _standardUrl;
  String? _urlPathPrefix;
  String? _standardExtension;
  bool _isFirstPage = true;

  /// 解析目录页获取所有章节（包括分页）
  /// 
  /// [directoryUrl] 目录页URL
  /// [encoding] 页面编码，默认为UTF-8
  /// [onProgress] 进度回调
  Future<List<Map<String, dynamic>>> parseCatalog(
    String directoryUrl, {
    String encoding = 'UTF-8',
    Function(int current, int total)? onProgress,
  }) async {

    // 重置状态
    _standardUrl = null;
    _urlPathPrefix = null;
    _standardExtension = null;
    _isFirstPage = true;

    final processedUrls = <String>{directoryUrl};
    final allResults = <Map<String, dynamic>>[];
    var currentUrl = directoryUrl;
    var pageCount = 0;
    const maxPages = 999;

    while (currentUrl.isNotEmpty && pageCount < maxPages) {

      final html = await _networkService.get(
        currentUrl,
        encoding: encoding,
      );

      if (html.isEmpty) {
        break;
      }


      // 解析章节
      var results = _parseTocResults(html, currentUrl);

      // 第一页时选择标准URL
      if (_isFirstPage && results.isNotEmpty) {
        final standardInfo = ChapterUtils.selectStandardUrl(results);
        if (standardInfo != null) {
          _standardUrl = standardInfo['standardUrl'];
          _urlPathPrefix = standardInfo['urlPathPrefix'];
          _standardExtension = standardInfo['standardExtension'];
        }
        _isFirstPage = false;
      }

      // 过滤章节
      if (results.length > 2) {
        results = ChapterUtils.filterChapters(
          results,
          standardUrl: _standardUrl,
          urlPathPrefix: _urlPathPrefix,
          standardExtension: _standardExtension,
        );
      }

      for (final result in results) {
        if (!allResults.any((r) => r['url'] == result['url'])) {
          allResults.add(result);
        }
      }

      if (onProgress != null) {
        onProgress(allResults.length, allResults.length + 50);
      }

      final nextPageUrl = _findNextPageUrl(html, currentUrl);
      if (nextPageUrl != null && !processedUrls.contains(nextPageUrl)) {
        processedUrls.add(nextPageUrl);
        currentUrl = nextPageUrl;
        pageCount++;

        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        break;
      }
    }

    // 章节去重
    final deduplicated = ChapterUtils.deduplicateChapters(allResults);

    return deduplicated;
  }

  /// 解析目录页HTML，提取章节列表
  List<Map<String, dynamic>> _parseTocResults(
    String html,
    String baseUrl,
  ) {
    final results = <Map<String, dynamic>>[];
    final document = parse(html);

    // 1. 首先尝试通用正则表达式提取章节链接
    final chapterPattern = RegExp(
      'href\\s*=["\']*([\\w/:\\\-\\.\\?&=]+)["\'\\s]*.*?>(.*?)<',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = chapterPattern.allMatches(html);

    for (final match in matches) {
      final href = match.group(1)?.trim() ?? '';
      var title = match.group(2)?.trim() ?? '';

      // 清理标题
      title = _cleanTitle(title);
      if (title.isEmpty) continue;

      // 排除导航链接
      if (_isNavLink(title)) continue;

      // 处理URL
      final fullUrl = UrlUtils.resolveUrl(href, baseUrl);
      if (fullUrl.isEmpty) continue;

      results.add({
        'title': title,
        'url': fullUrl,
      });
    }

    // 2. 如果正则没有提取到，尝试DOM解析
    if (results.isEmpty) {
      _parseFromDom(document, baseUrl, results);
    }

    return results;
  }

  /// 从DOM解析章节
  void _parseFromDom(
    dynamic document,
    String baseUrl,
    List<Map<String, dynamic>> results,
  ) {
    // 查找包含最多a标签的div（目录列表通常包含大量章节链接）
    final divs = document.querySelectorAll('div');
    Element? targetDiv;
    int maxLinks = 0;

    for (final div in divs) {
      final links = div.querySelectorAll('a');
      if (links.length > maxLinks && links.length > 5) {
        maxLinks = links.length;
        targetDiv = div;
      }
    }

    // 如果找到目标div，提取其中的链接
    if (targetDiv != null) {
      final links = targetDiv.querySelectorAll('a');
      for (final link in links) {
        final href = link.attributes['href']?.trim() ?? '';
        var title = link.text.trim();

        title = _cleanTitle(title);
        if (title.isEmpty) continue;
        if (_isNavLink(title)) continue;

        final fullUrl = UrlUtils.resolveUrl(href, baseUrl);
        if (fullUrl.isEmpty) continue;

        if (!results.any((r) => r['url'] == fullUrl)) {
          results.add({
            'title': title,
            'url': fullUrl,
          });
        }
      }
    }

    // 3. 如果还是没找到，尝试常见的目录容器ID
    if (results.isEmpty) {
      final listSelectors = [
        '#list',
        '#chapterlist',
        '.catalog-list',
        '.chapter-list',
        '#catalog',
        '#mlist',
        '#dir',
      ];

      for (final selector in listSelectors) {
        final container = document.querySelector(selector);
        if (container != null) {
          final links = container.querySelectorAll('a');
          for (final link in links) {
            final href = link.attributes['href']?.trim() ?? '';
            var title = link.text.trim();

            title = _cleanTitle(title);
            if (title.isEmpty) continue;
            if (_isNavLink(title)) continue;

            final fullUrl = UrlUtils.resolveUrl(href, baseUrl);
            if (fullUrl.isEmpty) continue;

            if (!results.any((r) => r['url'] == fullUrl)) {
              results.add({
                'title': title,
                'url': fullUrl,
              });
            }
          }
          if (results.isNotEmpty) break;
        }
      }
    }
  }

  /// 清理标题
  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 判断是否为导航链接
  bool _isNavLink(String title) {
    final navKeywords = {
      '上一页', '下一页', '首页', '尾页', '目录', '收藏',
      '返回', '返回首页', '开始阅读', '立即阅读', '我的书架', '阅读记录',
      '上一章', '下一章', '末页',
    };
    return navKeywords.any((kw) => title.contains(kw));
  }

  /// 查找下一页URL
  String? _findNextPageUrl(String html, String currentUrl) {
    final document = parse(html);

    // 1. 查找文本为"下一页"的链接
    final nextLinks = document.querySelectorAll('a');
    for (final link in nextLinks) {
      final text = link.text.trim();
      if (text.contains('下一页') ||
          text.contains('下页') ||
          text.contains('下一章') ||
          text.contains('查看更多章节')) {
        final href = link.attributes['href'];
        if (href != null && href.isNotEmpty) {
          return UrlUtils.resolveUrl(href, currentUrl);
        }
      }
    }

    // 2. 尝试数字分页
    final currentPage = _extractPageNumber(currentUrl);
    if (currentPage > 0) {
      // 查找数字链接，找到比当前页大1的链接
      for (final link in nextLinks) {
        final text = link.text.trim();
        final pageNum = int.tryParse(text);
        if (pageNum == currentPage + 1) {
          final href = link.attributes['href'];
          if (href != null && href.isNotEmpty) {
            return UrlUtils.resolveUrl(href, currentUrl);
          }
        }
      }
    }

    // 3. 尝试从URL模式推断下一页
    final nextUrl = _generateNextPageUrl(currentUrl);
    if (nextUrl != null && nextUrl != currentUrl) {
      return nextUrl;
    }

    return null;
  }

  /// 从URL中提取页码
  int _extractPageNumber(String url) {
    final patterns = [
      RegExp(r'index_(\d+)\.html'),
      RegExp(r'page-(\d+)'),
      RegExp(r'\?page=(\d+)'),
      RegExp(r'_(\d+)\.html$'),
      RegExp(r'-(\d+)\.html$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) {
        return int.tryParse(match.group(1) ?? '') ?? 0;
      }
    }
    return 0;
  }

  /// 生成下一页URL
  String? _generateNextPageUrl(String currentUrl) {
    final currentPage = _extractPageNumber(currentUrl);
    if (currentPage == 0) return null;

    final nextPage = currentPage + 1;

    if (currentUrl.contains('index_')) {
      return currentUrl.replaceFirst(
        RegExp(r'index_\d+\.html'),
        'index_$nextPage.html',
      );
    } else if (currentUrl.contains('page-')) {
      return currentUrl.replaceFirst(
        RegExp(r'page-\d+'),
        'page-$nextPage',
      );
    } else if (currentUrl.contains('?page=')) {
      return currentUrl.replaceFirst(
        RegExp(r'\?page=\d+'),
        '?page=$nextPage',
      );
    } else if (RegExp(r'_\d+\.html$').hasMatch(currentUrl)) {
      return currentUrl.replaceFirst(
        RegExp(r'_\d+\.html$'),
        '_$nextPage.html',
      );
    } else if (RegExp(r'-\d+\.html$').hasMatch(currentUrl)) {
      return currentUrl.replaceFirst(
        RegExp(r'-\d+\.html$'),
        '-$nextPage.html',
      );
    }

    return null;
  }

  /// 从HTML中提取书名
  String? extractBookTitle(String html) {
    final document = parse(html);

    // 1. 尝试title标签
    final titleElement = document.querySelector('title');
    if (titleElement != null) {
      final title = titleElement.text.trim();
      // 清理常见的后缀
      final cleaned = title
          .replaceAll(RegExp(r'[_-].*$'), '')
          .replaceAll(RegExp(r'最新章节.*$'), '')
          .replaceAll(RegExp(r'全文阅读.*$'), '')
          .trim();
      if (cleaned.isNotEmpty && cleaned.length < 50) {
        return cleaned;
      }
    }

    // 2. 尝试h1标签
    final h1Element = document.querySelector('h1');
    if (h1Element != null) {
      final title = h1Element.text.trim();
      if (title.isNotEmpty && title.length < 50) {
        return title;
      }
    }

    // 3. 尝试常见的书名class/id
    final selectors = [
      '.book-name',
      '.book-title',
      '#book-name',
      '#book-title',
      '.novel-name',
      '.novel-title',
    ];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        final title = element.text.trim();
        if (title.isNotEmpty && title.length < 50) {
          return title;
        }
      }
    }

    return null;
  }

  /// 从HTML中提取作者
  String? extractAuthor(String html) {
    final document = parse(html);

    // 尝试常见的作者选择器
    final selectors = [
      '.author',
      '.book-author',
      '#author',
      '.novel-author',
      '[class*="author"]',
    ];

    for (final selector in selectors) {
      final elements = document.querySelectorAll(selector);
      for (final element in elements) {
        final text = element.text.trim();
        // 匹配"作者：xxx"或"xxx 著"等格式
        final authorMatch = RegExp(r'作者[：:]\s*(\S+)').firstMatch(text);
        if (authorMatch != null) {
          final author = authorMatch.group(1);
          if (author != null && author.isNotEmpty && author.length < 20) {
            return TextUtils.cleanAuthor(author);
          }
        }
      }
    }

    return null;
  }
}
