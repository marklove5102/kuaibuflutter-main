import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' show Element;
import '../models/book_source.dart';
import '../utils/url_utils.dart';
import '../utils/chapter_utils.dart';
import 'network_service.dart';

/// 目录解析器 - 支持分页获取章节列表
class CatalogParser {
  final NetworkService _networkService = NetworkService();

  /// 标准URL信息（用于过滤）
  String? _standardUrl;
  String? _urlPathPrefix;
  String? _standardExtension;
  bool _isFirstPage = true;

  /// 解析目录页获取所有章节（包括分页）
  Future<List<Map<String, dynamic>>> parseCatalog(
    String directoryUrl,
    BookSource source, {
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
        encoding: source.websiteEncoding,
      );

      if (html.isEmpty) {
        break;
      }


      // 解析章节
      var results = _parseTocResults(html, currentUrl, source);

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

      final nextPageUrl = _findNextPageUrl(html, currentUrl, source);
      if (nextPageUrl != null && !processedUrls.contains(nextPageUrl)) {
        processedUrls.add(nextPageUrl);
        currentUrl = nextPageUrl;
        pageCount++;

        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        break;
      }
    }

    // 最终去重
    final deduplicatedResults = ChapterUtils.deduplicateChapters(allResults);

    // 根据书源配置排序
    if (source.chapterOrder == 1) {
      // 倒序
      return deduplicatedResults.reversed.toList();
    }

    return deduplicatedResults;
  }

  /// 解析目录结果
  List<Map<String, dynamic>> _parseTocResults(String html, String baseUrl, BookSource source) {
    final results = <Map<String, dynamic>>[];
    final processedUrls = <String>{};


    // 使用正则提取章节链接
    final chapterPattern = RegExp(
      'href\\s*=\\s*["\']?([^\\s"\'>]+)["\']?\\s*>\\s*([^<]+)<',
      caseSensitive: false,
      dotAll: true,
    );
    final matches = chapterPattern.allMatches(html);

    for (final match in matches) {
      final href = match.group(1) ?? '';
      var title = match.group(2) ?? '';

      // 清理标题
      title = ChapterUtils.cleanChapterTitle(title);
      if (title.isEmpty) continue;

      // 验证是否为有效章节标题
      if (!ChapterUtils.isValidBookTitle(title)) continue;

      // 构建完整URL
      String fullUrl;
      if (href.startsWith('http')) {
        fullUrl = href;
      } else {
        fullUrl = UrlUtils.convertToAbsoluteUrl(href, baseUrl);
      }

      // 验证URL是否符合书源规则
      if (source.chapterUrlPattern != null && source.chapterUrlPattern!.isNotEmpty) {
        if (!UrlUtils.validateUrl(fullUrl, source.chapterUrlPattern)) {
          continue;
        }
      }

      // URL去重
      if (processedUrls.contains(fullUrl)) continue;
      processedUrls.add(fullUrl);

      results.add({
        'title': title,
        'url': fullUrl,
        'status': '未下载',
      });
    }

    // 如果正则匹配结果太少，尝试使用HTML解析
    if (results.length < 10) {
      final htmlResults = _parseWithHtmlParser(html, baseUrl, source, processedUrls);
      results.addAll(htmlResults);
    }

    return results;
  }

  /// 使用HTML解析器提取章节
  List<Map<String, dynamic>> _parseWithHtmlParser(
    String html,
    String baseUrl,
    BookSource source,
    Set<String> processedUrls,
  ) {
    final results = <Map<String, dynamic>>[];

    try {
      final document = parse(html);

      // 查找包含最多链接的div
      final divs = document.querySelectorAll('div');
      Element? targetDiv;
      int maxLinks = 0;

      for (final div in divs) {
        final links = div.querySelectorAll('a');
        if (links.length > maxLinks) {
          maxLinks = links.length;
          targetDiv = div;
        }
      }

      if (targetDiv != null) {
        final links = targetDiv.querySelectorAll('a');
        for (final link in links) {
          final href = link.attributes['href'];
          var title = link.text.trim();

          // 清理标题
          title = ChapterUtils.cleanChapterTitle(title);
          if (title.isEmpty || !ChapterUtils.isValidBookTitle(title)) continue;

          if (href != null && href.isNotEmpty && !href.startsWith('javascript:')) {
            final fullUrl = UrlUtils.convertToAbsoluteUrl(href, baseUrl);

            if (!processedUrls.contains(fullUrl)) {
              processedUrls.add(fullUrl);
              results.add({
                'title': title,
                'url': fullUrl,
                'status': '未下载',
              });
            }
          }
        }
      }
    } catch (e) {
    }

    return results;
  }

  /// 查找下一页URL
  String? _findNextPageUrl(String html, String currentUrl, BookSource source) {

    try {
      final document = parse(html);

      // 查找特定ID的下一页链接
      final nextLink = document.querySelector('a#pt_next, a#next');
      if (nextLink != null) {
        final href = nextLink.attributes['href'];
        if (href != null && href.isNotEmpty && !href.startsWith('javascript:')) {
          return UrlUtils.convertToAbsoluteUrl(href, source.websiteUrl);
        }
      }

      // 查找特定class的下一页链接
      final classLinks = document.querySelectorAll(
        'a.next, a.js_page_down, a.Readpage_down, a.page-next, a[rel="next"]',
      );
      for (final link in classLinks) {
        final href = link.attributes['href'];
        if (href != null && href.isNotEmpty && !href.startsWith('javascript:')) {
          return UrlUtils.convertToAbsoluteUrl(href, source.websiteUrl);
        }
      }

      // 查找包含"下一页"文本的链接
      final allLinks = document.querySelectorAll('a');
      for (final link in allLinks) {
        final text = link.text.trim();
        if (text.contains('下一页') || text.contains('下页')) {
          // 排除"下一章"
          if (text.contains('下一章')) continue;

          final href = link.attributes['href'];
          if (href != null && href.isNotEmpty && !href.startsWith('javascript:')) {
            return UrlUtils.convertToAbsoluteUrl(href, source.websiteUrl);
          }
        }
      }
    } catch (e) {
    }

    // 从URL推断下一页
    final inferredUrl = _inferNextPageUrl(currentUrl);
    if (inferredUrl != null) {
      return inferredUrl;
    }

    return null;
  }

  /// 从当前URL推断下一页URL
  String? _inferNextPageUrl(String currentUrl) {
    // 检查常见的分页模式
    if (currentUrl.contains('index_')) {
      final match = RegExp(r'index_(\d+)\.html').firstMatch(currentUrl);
      if (match != null) {
        final currentPage = int.tryParse(match.group(1) ?? '1') ?? 1;
        return currentUrl.replaceFirst(
          'index_${match.group(1)}.html',
          'index_${currentPage + 1}.html',
        );
      }
    }

    if (currentUrl.contains('page-')) {
      final match = RegExp(r'page-(\d+)').firstMatch(currentUrl);
      if (match != null) {
        final currentPage = int.tryParse(match.group(1) ?? '1') ?? 1;
        return currentUrl.replaceFirst(
          'page-${match.group(1)}',
          'page-${currentPage + 1}',
        );
      }
    }

    if (currentUrl.contains('?page=')) {
      final match = RegExp(r'\?page=(\d+)').firstMatch(currentUrl);
      if (match != null) {
        final currentPage = int.tryParse(match.group(1) ?? '1') ?? 1;
        return currentUrl.replaceFirst(
          '?page=${match.group(1)}',
          '?page=${currentPage + 1}',
        );
      }
    }

    // 匹配 _数字.html 格式
    final underscoreMatch = RegExp(r'_(\d+)\.html$').firstMatch(currentUrl);
    if (underscoreMatch != null) {
      final currentPage = int.tryParse(underscoreMatch.group(1) ?? '1') ?? 1;
      return currentUrl.replaceFirst(
        '_${underscoreMatch.group(1)}.html',
        '_${currentPage + 1}.html',
      );
    }

    return null;
  }
}
