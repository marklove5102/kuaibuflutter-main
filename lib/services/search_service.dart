import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/book_source.dart';
import '../utils/url_utils.dart';
import '../utils/text_utils.dart';
import 'network_service.dart';

/// 搜索服务类 - 提供统一的搜索功能
class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final NetworkService _networkService = NetworkService();

  /// 执行搜索 - 返回字典结果
  Future<Map<String, dynamic>> performSearch({
    required String searchUrl,
    required String keyword,
    required BookSource source,
  }) async {
    final result = <String, dynamic>{
      'success': false,
      'results': <Map<String, String>>[],
      'error': '',
    };

    try {
      final html = await _fetchSearchHtml(searchUrl, keyword, source);
      final books = parseSearchResults(html, source, keyword);
      result['success'] = true;
      result['results'] = books;
    } catch (e) {
      result['error'] = e.toString();
    }

    return result;
  }

  /// 获取搜索页面的HTML
  Future<String> _fetchSearchHtml(String searchUrl, String keyword, BookSource source) async {
    if (source.searchType?.toUpperCase() == 'POST' && searchUrl.contains(',')) {
      String processedUrl = searchUrl.replaceAll('{key}', keyword);
      processedUrl = processedUrl.replaceAll('{page}', '1');

      final parts = processedUrl.split(',');
      final requestUrl = parts[0];
      Map<String, String>? postBody;

      if (parts.length > 1) {
        final params = parts[1].split('&');
        postBody = {};
        for (final param in params) {
          final kv = param.split('=');
          if (kv.length == 2) {
            final key = kv[0].replaceAll('{', '').replaceAll('}', '');
            var value = kv[1].replaceAll('{key}', keyword);
            value = value.replaceAll('{', '').replaceAll('}', '');
            postBody[key] = value;
          }
        }
      }

      return await _networkService.post(
        requestUrl,
        body: postBody,
        encoding: source.websiteEncoding,
      );
    } else {
      String processedUrl = searchUrl.replaceAll('{key}', Uri.encodeComponent(keyword));
      processedUrl = processedUrl.replaceAll('{page}', '1');

      return await _networkService.get(
        processedUrl,
        encoding: source.websiteEncoding,
      );
    }
  }

  /// 解析搜索结果
  List<Map<String, String>> parseSearchResults(String html, BookSource source, String keyword) {
    final results = <Map<String, String>>[];
    final processedContainers = <Element>{};

    final document = parse(html);
    final allLinks = document.querySelectorAll('a[href]');

    final validBookLinks = <_BookLinkInfo>[];

    for (final aTag in allLinks) {
      final href = aTag.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      String fullUrl = href;
      if (!href.startsWith('http')) {
        fullUrl = UrlUtils.convertToAbsoluteUrl(href, source.websiteUrl);
      }

      if (!UrlUtils.validateUrl(fullUrl, source.bookUrlPattern)) {
        continue;
      }

      validBookLinks.add(_BookLinkInfo(
        element: aTag,
        href: href,
        fullUrl: fullUrl,
      ));
    }

    for (final bookLink in validBookLinks) {
      Element? container = _findParentContainer(bookLink.element);

      if (container == null) {
        container = bookLink.element.parent;
      }

      if (container == null) continue;

      if (processedContainers.contains(container)) {
        continue;
      }
      processedContainers.add(container);

      final bookInfo = _extractBookInfoFromContainer(
        container,
        bookLink,
        source,
        keyword,
      );

      if (bookInfo != null) {
        results.add(bookInfo);
      }
    }

    if (results.isEmpty) {
      results.addAll(_parseByGlobalSearch(document, source, keyword));
    }

    return results;
  }

  /// 向上查找父容器
  Element? _findParentContainer(Element element) {
    final containerTags = ['div', 'li', 'tr', 'dl', 'dt'];

    Element? parent = element.parent;

    for (int i = 0; i < 3; i++) {
      if (parent == null) break;

      if (containerTags.contains(parent.localName?.toLowerCase())) {
        return parent;
      }

      parent = parent.parent;
    }

    return null;
  }

  /// 从容器内提取书籍信息
  Map<String, String>? _extractBookInfoFromContainer(
    Element container,
    _BookLinkInfo bookLink,
    BookSource source,
    String keyword,
  ) {
    String bookName = '';

    final pTag = bookLink.element.querySelector('p');
    if (pTag != null) {
      bookName = pTag.text.trim();
    }

    if (bookName.isEmpty) {
      bookName = bookLink.element.text.trim();
    }

    if (bookName.isEmpty) {
      return null;
    }
    if (keyword.isNotEmpty && !bookName.toLowerCase().contains(keyword.toLowerCase())) {
      return null;
    }

    final result = <String, String>{
      'name': bookName,
      'url': bookLink.fullUrl,
      'source': source.sourceName,
    };

    final author = _extractAuthorFromContainer(container, bookLink.element);
    if (author.isNotEmpty) {
      result['author'] = author;
    }

    final latestChapter = _extractLatestChapterFromContainer(
      container,
      bookLink,
      source,
      keyword,
    );
    if (latestChapter.isNotEmpty) {
      result['latest_chapter'] = latestChapter;
    }

    return result;
  }

  /// 从容器内提取作者信息
  String _extractAuthorFromContainer(Element container, Element bookATag) {
    final allText = container.text;
    final authorPattern = RegExp(r'作者[：:]\s*(.+?)(?:\||\n|$)', caseSensitive: false);
    final authorMatch = authorPattern.firstMatch(allText);
    if (authorMatch != null) {
      final author = authorMatch.group(1)?.trim() ?? '';
      if (author.isNotEmpty && author.length <= 30) {
        return TextUtils.cleanAuthor(author);
      }
    }

    final authorLinks = container.querySelectorAll('a[href*="author"]');
    for (final link in authorLinks) {
      if (link == bookATag) continue;
      final author = link.text.trim();
      if (author.isNotEmpty && author.length <= 30) {
        return TextUtils.cleanAuthor(author);
      }
    }

    return '';
  }

  /// 从容器内提取最新章节信息
  String _extractLatestChapterFromContainer(
    Element container,
    _BookLinkInfo bookLink,
    BookSource source,
    String keyword,
  ) {
    final allLinks = container.querySelectorAll('a[href]');

    for (final aTag in allLinks) {
      if (aTag == bookLink.element) continue;

      final href = aTag.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      String fullUrl = href;
      if (!href.startsWith('http')) {
        fullUrl = UrlUtils.convertToAbsoluteUrl(href, source.websiteUrl);
      }

      if (!UrlUtils.validateUrl(fullUrl, source.chapterUrlPattern)) {
        continue;
      }

      String chapterName = '';
      final pTag = aTag.querySelector('p');
      if (pTag != null) {
        chapterName = pTag.text.trim();
      } else {
        chapterName = aTag.text.trim();
      }

      if (chapterName.isNotEmpty &&
          (keyword.isEmpty || !chapterName.toLowerCase().contains(keyword.toLowerCase()))) {
        return chapterName;
      }
    }

    final allText = container.text;
    final latestPattern = RegExp(r'(?:最新|更新)[：:]\s*(.+?)(?:\||\n|$)', caseSensitive: false);
    final latestMatch = latestPattern.firstMatch(allText);
    if (latestMatch != null) {
      final chapterName = latestMatch.group(1)?.trim() ?? '';
      if (chapterName.isNotEmpty) {
        return chapterName;
      }
    }

    return '';
  }

  /// 全局搜索方法
  List<Map<String, String>> _parseByGlobalSearch(Document document, BookSource source, String keyword) {
    final results = <Map<String, String>>[];
    final processedUrls = <String>{};

    final allLinks = document.querySelectorAll('a[href]');

    for (final aTag in allLinks) {
      final href = aTag.attributes['href'] ?? '';
      if (href.isEmpty) continue;

      String fullUrl = href;
      if (!href.startsWith('http')) {
        fullUrl = UrlUtils.convertToAbsoluteUrl(href, source.websiteUrl);
      }

      if (!UrlUtils.validateUrl(fullUrl, source.bookUrlPattern)) {
        continue;
      }

      if (processedUrls.contains(fullUrl)) continue;
      processedUrls.add(fullUrl);

      String bookName = '';
      final pTag = aTag.querySelector('p');
      if (pTag != null) {
        bookName = pTag.text.trim();
      } else {
        bookName = aTag.text.trim();
      }

      if (bookName.isEmpty) continue;
      if (keyword.isNotEmpty && !bookName.toLowerCase().contains(keyword.toLowerCase())) {
        continue;
      }

      results.add({
        'name': bookName,
        'url': fullUrl,
        'source': source.sourceName,
      });

      if (results.length >= 20) break;
    }

    return results;
  }

  /// 从HTML内容中提取纯文本
  String extractTextFromHtml(String html) {
    final document = parse(html);
    return document.body?.text.trim() ?? '';
  }

  /// 并发搜索多个书源
  Future<List<Map<String, dynamic>>> searchMultipleSources(
    List<BookSource> sources,
    String keyword,
  ) async {
    final allResults = <Map<String, dynamic>>[];

    for (final source in sources) {
      if (source.searchUrl?.isEmpty ?? true) {
        continue;
      }

      try {
        final result = await performSearch(
          searchUrl: source.searchUrl!,
          keyword: keyword,
          source: source,
        );

        if (result['success'] == true) {
          final books = result['results'] as List<Map<String, String>>;

          for (final book in books) {
            allResults.add({
              'name': book['name'] ?? '',
              'url': book['url'] ?? '',
              'latestChapter': book['latest_chapter'] ?? '',
              'source': book['source'] ?? source.sourceName,
              'author': book['author'] ?? '',
            });
          }
        }
      } catch (e) {
        // 忽略单个书源的错误，继续搜索其他书源
      }
    }

    return allResults;
  }
}

/// 书籍链接信息
class _BookLinkInfo {
  final Element element;
  final String href;
  final String fullUrl;

  _BookLinkInfo({
    required this.element,
    required this.href,
    required this.fullUrl,
  });
}
