import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/book.dart' as book_models;
import '../models/source_config.dart';
import '../utils/url_utils.dart';
import '../utils/text_utils.dart';
import 'network_service.dart';

/// 小说下载器
class NovelDownloader {
  static final NovelDownloader _instance = NovelDownloader._internal();
  factory NovelDownloader() => _instance;
  NovelDownloader._internal();

  final NetworkService _networkService = NetworkService();

  final String _defaultChapterRegex = 'href\\s*=\\s*["\'\\s]*([^"\'>\\s]+)\\s*["\']*\\s*[^>]*>([^<]+)<';

  /// 解析目录
  Future<List<book_models.Chapter>> parseDirectory(String url, SourceConfig source) async {
    final html = await _networkService.get(url, encoding: source.encoding);
    if (html == null) return [];

    final chapters = <book_models.Chapter>[];
    final document = parse(html);

    final divs = document.getElementsByTagName('div');
    Element? targetDiv;
    int maxLinks = 0;

    for (final div in divs) {
      final links = div.getElementsByTagName('a');
      if (links.length > maxLinks) {
        maxLinks = links.length;
        targetDiv = div;
      }
    }

    if (targetDiv != null) {
      final links = targetDiv.getElementsByTagName('a');
      for (final link in links) {
        final href = link.attributes['href'];
        final title = link.text.trim();

        if (href != null && title.isNotEmpty) {
          final absoluteUrl = UrlUtils.resolveUrl(href, url);
          chapters.add(book_models.Chapter(
            title: title,
            url: absoluteUrl,
            index: chapters.length,
          ));
        }
      }
    }

    if (chapters.isEmpty) {
      final regExp = RegExp(_defaultChapterRegex, caseSensitive: false, dotAll: true);
      final matches = regExp.allMatches(html);

      for (final match in matches) {
        final href = match.group(1)?.trim();
        final title = match.group(2)?.trim();

        if (href != null && title != null && title.isNotEmpty) {
          final absoluteUrl = UrlUtils.resolveUrl(href, url);
          chapters.add(book_models.Chapter(
            title: TextUtils.cleanTitle(title),
            url: absoluteUrl,
            index: chapters.length,
          ));
        }
      }
    }

    final uniqueChapters = <book_models.Chapter>[];
    final seenUrls = <String>{};
    for (final chapter in chapters) {
      if (!seenUrls.contains(chapter.url)) {
        seenUrls.add(chapter.url);
        uniqueChapters.add(chapter);
      }
    }

    if (source.sortType == SortType.DESC) {
      uniqueChapters.sort((a, b) => b.index.compareTo(a.index));
    }

    return uniqueChapters;
  }

  /// 解析章节内容
  Future<String?> parseChapter(String url, SourceConfig source) async {
    final html = await _networkService.get(url, encoding: source.encoding);
    if (html == null) return null;

    final document = parse(html);
    String? content;

    final articles = document.getElementsByTagName('article');
    if (articles.isNotEmpty) {
      content = _extractTextContent(articles.first);
    }

    if (content == null || content.isEmpty) {
      final contentDiv = document.querySelector('#content') ??
                         document.querySelector('.content') ??
                         document.querySelector('[class*="content"]') ??
                         document.querySelector('[id*="content"]');
      if (contentDiv != null) {
        content = _extractTextContent(contentDiv);
      }
    }

    if (content == null || content.isEmpty) {
      final divs = document.getElementsByTagName('div');
      String? bestContent;
      int maxLength = 0;

      for (final div in divs) {
        final text = _extractTextContent(div);
        if (text.length > maxLength && text.length > 100) {
          maxLength = text.length;
          bestContent = text;
        }
      }
      content = bestContent;
    }

    if (content == null || content.isEmpty) {
      final paragraphs = document.getElementsByTagName('p');
      if (paragraphs.length > 5) {
        content = paragraphs.map((p) => p.text.trim()).where((t) => t.isNotEmpty).join('\n\n');
      }
    }

    return TextUtils.cleanContent(content ?? '');
  }

  /// 搜索书籍
  Future<List<book_models.SearchResult>> searchBooks(String keyword, SourceConfig source) async {
    final results = <book_models.SearchResult>[];

    String? searchUrl;
    String? html;

    if (source.searchType == SearchType.GET) {
      searchUrl = source.searchUrl
          .replaceAll('{key}', Uri.encodeComponent(keyword))
          .replaceAll('{page}', '1');
      html = await _networkService.get(searchUrl, encoding: source.encoding);
    } else {
      final parts = source.searchUrl.split('?');
      if (parts.length == 2) {
        searchUrl = parts[0];
        final params = _parseQueryString(parts[1]);

        params.forEach((key, value) {
          params[key] = value.replaceAll('{key}', keyword).replaceAll('{page}', '1');
        });

        html = await _networkService.post(
          searchUrl,
          encoding: source.encoding,
          body: params,
        );
      }
    }

    if (html == null) return results;

    final document = parse(html);

    final links = document.getElementsByTagName('a');
    for (final link in links) {
      final href = link.attributes['href'];
      final title = link.text.trim();

      if (href != null && title.isNotEmpty && _isBookTitle(title)) {
        final parent = link.parent;
        String? latestChapter;

        if (parent != null) {
          final siblings = parent.children;
          for (final sibling in siblings) {
            final text = sibling.text.trim();
            if (text.contains('章') || text.contains('第')) {
              latestChapter = text;
              break;
            }
          }
        }

        final absoluteUrl = UrlUtils.resolveUrl(href, source.websiteUrl);
        results.add(book_models.SearchResult(
          title: title,
          author: '',
          bookUrl: absoluteUrl,
          sourceName: source.sourceName,
          sourceUrl: source.websiteUrl,
          latestChapter: latestChapter,
        ));
      }
    }

    final uniqueResults = <book_models.SearchResult>[];
    final seenNames = <String>{};
    for (final result in results) {
      if (!seenNames.contains(result.title)) {
        seenNames.add(result.title);
        uniqueResults.add(result);
      }
    }

    return uniqueResults;
  }

  /// 多源搜索
  Future<Map<String, List<book_models.SearchResult>>> searchBooksMultiSource(
    String keyword,
    List<SourceConfig> sources,
  ) async {
    final results = <String, List<book_models.SearchResult>>{};

    await Future.wait(
      sources.map((source) async {
        try {
          final sourceResults = await searchBooks(keyword, source);
          if (sourceResults.isNotEmpty) {
            results[source.sourceName] = sourceResults;
          }
        } catch (e) {
          // ignore
        }
      }),
    );

    return results;
  }

  /// 获取分类排行
  Future<List<book_models.SearchResult>> getCategoryRank(String categoryUrl, SourceConfig source) async {
    final html = await _networkService.get(categoryUrl, encoding: source.encoding);
    if (html == null) return [];

    final results = <book_models.SearchResult>[];
    final document = parse(html);

    final links = document.getElementsByTagName('a');
    for (final link in links) {
      final href = link.attributes['href'];
      final title = link.text.trim();

      if (href != null && title.isNotEmpty && _isBookTitle(title)) {
        final absoluteUrl = UrlUtils.resolveUrl(href, source.websiteUrl);
        results.add(book_models.SearchResult(
          title: title,
          author: '',
          bookUrl: absoluteUrl,
          sourceName: source.sourceName,
          sourceUrl: source.websiteUrl,
        ));
      }
    }

    return results;
  }

  /// 提取文本内容
  String _extractTextContent(Element element) {
    element.querySelectorAll('script, style').forEach((e) => e.remove());
    String text = element.text;
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// 判断是否为书籍标题
  bool _isBookTitle(String text) {
    if (text.length < 2 || text.length > 50) return false;
    if (text.contains('首页') || text.contains('下一页') || text.contains('上一页')) return false;
    if (text.contains('返回') || text.contains('登录') || text.contains('注册')) return false;
    return true;
  }

  /// 解析查询字符串
  Map<String, String> _parseQueryString(String query) {
    final params = <String, String>{};
    final pairs = query.split('&');

    for (final pair in pairs) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        params[parts[0]] = parts[1];
      }
    }

    return params;
  }
}
