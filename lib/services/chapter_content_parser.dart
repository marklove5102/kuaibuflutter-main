import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import 'package:html_unescape/html_unescape.dart';
import '../models/book_source.dart';
import '../utils/url_utils.dart';

/// 章节内容解析器
class ChapterContentParser {
  static final HtmlUnescape _unescape = HtmlUnescape();

  /// 解析章节内容（通用方式，不依赖书源规则）
  /// 
  /// [html] HTML内容
  /// [source] 书源配置（仅用于编码等基础信息）
  /// [extractionMode] 指定的提取模式，如果为null则自动检测
  /// 返回解析后的正文内容
  static String parseContent(String html, BookSource source, {String? extractionMode}) {

    // 如果指定了提取模式，直接使用该模式
    if (extractionMode != null && extractionMode.isNotEmpty) {
      final result = _extractWithMode(html, extractionMode);
      if (result.isNotEmpty) {
        return result;
      }
    }

    try {
      final document = parse(html);

      // 使用通用CSS选择器提取内容（不依赖书源的contentRule）
      final commonSelectors = [
        '#content', '#nr1', '#htmlContent', '#chaptercontent', '#nr',
        '#booktxt', '#TextContent', '#article', '#acontent', '#BookText',
        '#ChapterContents', '#novelcontent', '#txt', '#content1', '#book_text',
        '#cont-body', '#text', '.content', '.read-content', '.con',
        '.readcontent', '.page-content', '.chapter', '.article',
        '.chapter_content',
      ];

      for (final selector in commonSelectors) {
        final element = document.querySelector(selector);
        if (element != null) {
          // 保留原始HTML结构，让 _cleanContent 处理换行
          final content = element.innerHtml;
          if (content.isNotEmpty && content.length > 50) {
            return _cleanContent(content);
          }
        }
      }

      // 按优先级检查语义标签：article → section → span → div
      // 要求中文字符数超过页面总数的一半
      final bodyElement = document.querySelector('body');
      if (bodyElement != null) {
        final totalText = bodyElement.text;
        final totalChCount = RegExp(r'[\u4e00-\u9fa5]').allMatches(totalText).length;
        
        if (totalChCount > 0) {
          final tagOrder = ['article', 'section', 'span', 'div'];
          for (final tagName in tagOrder) {
            final result = _extractFromTag(document, tagName, totalChCount);
            if (result != null && result.isNotEmpty) {
              return result;
            }
          }
        }
      }

      // 合并所有p标签
      final pElements = document.querySelectorAll('p');
      if (pElements.isNotEmpty) {
        final buffer = StringBuffer();
        for (final p in pElements) {
          // 保留原始HTML结构
          final html = p.innerHtml;
          if (html.isNotEmpty && html.length > 10) {
            if (buffer.isNotEmpty) buffer.write('\n');
            buffer.write(html);
          }
        }
        final pContent = buffer.toString();
        if (pContent.isNotEmpty && pContent.length > 100) {
          return _cleanContent(pContent);
        }
      }

      if (bodyElement != null) {
        // 保留原始HTML结构
        final bodyHtml = bodyElement.innerHtml;
        if (bodyHtml.isNotEmpty) {
          return _cleanContent(bodyHtml);
        }
      }

      final docHtml = document.documentElement?.innerHtml ?? '';
      if (docHtml.isNotEmpty) {
        return _cleanContent(docHtml);
      }

    } catch (e, stackTrace) {
    }

    return _smartExtractContent(html);
  }

  /// 使用指定模式提取内容
  static String _extractWithMode(String html, String mode) {
    try {
      final document = parse(html);

      switch (mode) {
        case 'selector':
          // 使用通用CSS选择器
          final commonSelectors = [
            '#content', '#nr1', '#htmlContent', '#chaptercontent', '#nr',
            '#booktxt', '#TextContent', '#article', '#acontent', '#BookText',
            '#ChapterContents', '#novelcontent', '#txt', '#content1', '#book_text',
            '#cont-body', '#text', '.content', '.read-content', '.con',
            '.readcontent', '.page-content', '.chapter', '.article',
            '.chapter_content',
          ];
          for (final selector in commonSelectors) {
            final element = document.querySelector(selector);
            if (element != null) {
              // 保留原始HTML结构，让 _cleanContent 处理换行
              final content = element.innerHtml;
              if (content.isNotEmpty && content.length > 50) {
                return _cleanContent(content);
              }
            }
          }
          return '';

        case 'p':
          // 使用p标签
          final pElements = document.querySelectorAll('p');
          if (pElements.isNotEmpty) {
            final buffer = StringBuffer();
            for (final p in pElements) {
              // 保留原始HTML结构
              final html = p.innerHtml;
              if (html.isNotEmpty && html.length > 10) {
                if (buffer.isNotEmpty) buffer.write('\n');
                buffer.write(html);
              }
            }
            return _cleanContent(buffer.toString());
          }
          return '';

        case 'article':
        case 'section':
        case 'span':
        case 'div':
          // 使用指定标签提取
          final body = document.querySelector('body');
          if (body != null) {
            final totalText = body.text;
            final totalChCount = RegExp(r'[\u4e00-\u9fa5]').allMatches(totalText).length;
            final result = _extractFromTag(document, mode, totalChCount);
            if (result != null) return result;
          }
          return '';

        case 'body':
          // 使用body
          final body = document.querySelector('body');
          if (body != null) {
            return _cleanContent(body.innerHtml);
          }
          return '';

        default:
          return '';
      }
    } catch (e) {
      return '';
    }
  }

  /// 检测最佳提取模式（用于首页）
  /// 返回检测到的模式名称和提取的内容
  static Map<String, dynamic> detectExtractionMode(String html, BookSource source) {

    // 1. 尝试通用CSS选择器
    final selectorResult = _extractWithMode(html, 'selector');
    if (selectorResult.isNotEmpty && selectorResult.length > 100) {
      return {'mode': 'selector', 'content': selectorResult};
    }

    // 2. 按优先级检查语义标签：article → section → span → div
    // 要求中文字符数超过页面总数的一半
    final document = parse(html);
    final body = document.querySelector('body');
    if (body != null) {
      final totalText = body.text;
      final totalChCount = RegExp(r'[\u4e00-\u9fa5]').allMatches(totalText).length;
      
      if (totalChCount > 0) {
        final tagOrder = ['article', 'section', 'span', 'div'];
        for (final tagName in tagOrder) {
          final result = _extractFromTag(document, tagName, totalChCount);
          if (result != null && result.isNotEmpty) {
            return {'mode': tagName, 'content': result};
          }
        }
      }
    }

    // 3. 尝试p标签合并模式
    final pResult = _extractWithMode(html, 'p');
    if (pResult.isNotEmpty && pResult.length > 100) {
      return {'mode': 'p', 'content': pResult};
    }

    // 4. 兜底使用body
    final bodyResult = _extractWithMode(html, 'body');
    return {'mode': 'body', 'content': bodyResult};
  }

  /// 从指定标签中提取内容，要求中文字符数超过总数的一半
  static String? _extractFromTag(Document document, String tagName, int totalChCount) {
    final elements = document.querySelectorAll(tagName);
    if (elements.isEmpty) return null;

    // 找到中文字符数最多的标签
    Element? bestElement;
    var maxChCount = 0;

    for (final elem in elements) {
      final text = elem.text;
      final chCount = RegExp(r'[\u4e00-\u9fa5]').allMatches(text).length;
      if (chCount > maxChCount) {
        maxChCount = chCount;
        bestElement = elem;
      }
    }

    // 检查是否超过总数的一半
    if (bestElement != null && maxChCount > totalChCount / 2) {
      return _cleanContent(bestElement.innerHtml);
    }

    return null;
  }

  /// 使用书源规则解析
  static String _parseWithRule(Document document, String rule) {
    try {
      final element = document.querySelector(rule);
      if (element != null) {
        return element.text;
      }

      String? tag;
      String? id;
      String? className;

      final idMatch = RegExp(r'#([a-zA-Z0-9_-]+)').firstMatch(rule);
      if (idMatch != null) {
        id = idMatch.group(1);
      }

      final classMatch = RegExp(r'\.([a-zA-Z0-9_-]+)').firstMatch(rule);
      if (classMatch != null) {
        className = classMatch.group(1);
      }

      final tagMatch = RegExp(r'^([a-zA-Z]+)').firstMatch(rule);
      if (tagMatch != null) {
        tag = tagMatch.group(1);
      }

      String selector = '';
      if (tag != null) {
        selector = tag;
      }
      if (id != null) {
        selector += '#$id';
      }
      if (className != null) {
        selector += '.$className';
      }

      if (selector.isNotEmpty) {
        final elem = document.querySelector(selector);
        if (elem != null) {
          return elem.text;
        }
      }

      return '';
    } catch (e) {
      return '';
    }
  }

  /// 智能提取内容
  static String _smartExtractContent(String html) {
    var cleanedHtml = html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');

    final patterns = [
      '<div[^>]*id=["\x27]?content["\x27]?[^>]*>([\s\S]*?)</div>',
      '<div[^>]*class=["\x27]?content["\x27]?[^>]*>([\s\S]*?)</div>',
      '<div[^>]*id=["\x27]?chaptercontent["\x27]?[^>]*>([\s\S]*?)</div>',
      '<div[^>]*class=["\x27]?chaptercontent["\x27]?[^>]*>([\s\S]*?)</div>',
    ];

    for (final pattern in patterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(cleanedHtml);
      if (match != null) {
        final content = match.group(1) ?? '';
        if (content.length > 100) {
          return _cleanContent(content);
        }
      }
    }

    final text = cleanedHtml
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return text.length > 50 ? text : '无法解析章节内容';
  }

  /// 清理内容并优化排版
  static String _cleanContent(String content) {
    var text = _unescape.convert(content);
    
    // 1. 首先将<br>标签转换为换行符，保留段落结构
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    // 将</p>标签转换为换行符
    text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');
    // 移除<p>标签
    text = text.replaceAll(RegExp(r'<p\s*>', caseSensitive: false), '');
    
    // 2. 移除所有其他HTML标签
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    
    // 3. 移除&nbsp;等特殊字符
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&emsp;', '　');
    text = text.replaceAll('&ensp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    
    // 4. 处理页面标记
    text = text.replaceAllMapped(
      RegExp(r'第\((\d+)/(\d+)\)页'),
      (match) => '\n\n    第(${match.group(1)}/${match.group(2)})页\n\n',
    );

    // 5. 移除广告内容
    final adPatterns = [
      r'请记住本书首发域名：[^。]*。',
      r'手机版阅读网址：[^。]*。',
      r'笔趣阁[^。]*。',
      r'最新网址：[^。]*',
      r'请大家收藏：[^。]*',
      r'下载本书[^。]*',
      r'加入书签[^。]*',
      r'阅读网址：[^。]*',
      r'收藏网址：[^。]*',
      r'本站地址：[^。]*',
      r'天才一秒记住本站地址：[^。]*',
      r'章节错误,点此报送[^。]*',
    ];

    for (final pattern in adPatterns) {
      text = text.replaceAll(RegExp(pattern, caseSensitive: false), '');
    }

    // 6. 规范化空白字符：先将多个空格转为单个空格
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    
    // 7. 处理段落分隔 - 根据中文标点后的换行或空格进行分段
    final paragraphs = <String>[];
    var currentParagraph = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      currentParagraph.write(char);
      
      // 遇到句号、问号、感叹号、右引号等标点后，如果下一个字符是换行或空格，就作为段落分隔
      if (['。', '？', '！', '"', '"', '”'].contains(char) && i < text.length - 1) {
        final nextChar = text[i + 1];
        if ((nextChar == ' ' || nextChar == '\n') && currentParagraph.toString().trim().length > 20) {
          paragraphs.add(currentParagraph.toString().trim());
          currentParagraph = StringBuffer();
        }
      }
    }
    
    // 处理剩余内容
    if (currentParagraph.toString().trim().isNotEmpty) {
      paragraphs.add(currentParagraph.toString().trim());
    }
    
    // 8. 重新组合内容，添加段落缩进
    final formattedContent = StringBuffer();
    for (final para in paragraphs) {
      // 检查是否是页面标记
      if (para.startsWith('    第(')) {
        formattedContent.write(para);
        formattedContent.write('\n\n');
      } else {
        // 为普通段落添加缩进（两个全角空格）
        var indentedPara = '　　$para';
        // 处理引号前的空格：左引号前减少空格，右引号后增加空格
        indentedPara = indentedPara.replaceAll('　　"', ' "');
        indentedPara = indentedPara.replaceAll('　　"', ' "');
        indentedPara = indentedPara.replaceAll('"　　', '" ');
        formattedContent.write(indentedPara);
        formattedContent.write('\n\n');
      }
    }

    // 9. 规范化连续的换行符
    var result = formattedContent.toString();
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // 10. 移除开头和结尾的空白
    result = result.trim();
    
    return result;
  }

  /// 解析下一页URL
  static String? parseNextPageUrl(String html, String baseUrl) {
    String? nextPageUrl;

    try {
      final document = parse(html);

      final ptNextLink = document.querySelector('a#pt_next');
      if (ptNextLink != null) {
        final href = ptNextLink.attributes['href'];
        if (href != null && href.isNotEmpty) {
          nextPageUrl = UrlUtils.resolveUrl(href, baseUrl);
        }
      }

      if (nextPageUrl == null) {
        final allLinks = document.querySelectorAll('a');
        for (final link in allLinks) {
          final text = link.text.trim();
          final href = link.attributes['href'];

          if (href != null &&
              href.isNotEmpty &&
              !href.startsWith('javascript:') &&
              !href.startsWith('#')) {
            final nextPageKeywords = ['下一页', '下页', '后一页', '下一页→', '>下一页'];
            for (final keyword in nextPageKeywords) {
              if (text.contains(keyword)) {
                final chapterKeywords = ['下一章', '下一节', '下一回', '下一卷'];
                bool isChapterLink = false;
                for (final chapterKeyword in chapterKeywords) {
                  if (text.contains(chapterKeyword)) {
                    isChapterLink = true;
                    break;
                  }
                }
                if (!isChapterLink) {
                  nextPageUrl = UrlUtils.resolveUrl(href, baseUrl);
                  break;
                }
              }
            }
            if (nextPageUrl != null) break;
          }
        }
      }
    } catch (e) {
      return null;
    }

    if (nextPageUrl != null) {
      final currentBase = baseUrl.replaceAll(RegExp(r'_\d+\.html$'), '').replaceAll(RegExp(r'\.html$'), '');
      final nextBase = nextPageUrl.replaceAll(RegExp(r'_\d+\.html$'), '').replaceAll(RegExp(r'\.html$'), '');


      if (currentBase == nextBase) {
        return nextPageUrl;
      } else if (nextBase.startsWith(currentBase + '_') || nextBase.startsWith(currentBase + '-')) {
        return nextPageUrl;
      } else {
        return null;
      }
    }

    return null;
  }
}
