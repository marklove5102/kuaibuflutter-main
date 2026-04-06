import 'package:html_unescape/html_unescape.dart';

/// 文本处理工具类
class TextUtils {
  static final HtmlUnescape _unescape = HtmlUnescape();

  /// 清理HTML内容
  static String cleanContent(String content) {
    var text = _unescape.convert(content);

    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

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
    ];

    for (final pattern in adPatterns) {
      text = text.replaceAll(RegExp(pattern), '');
    }

    text = text.replaceAll(RegExp(r'\n\s*\n'), '\n\n').trim();

    return text;
  }

  /// 清理标题
  static String cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 提取文本内容（去除script和style）
  static String extractTextContent(String html) {
    var cleaned = html
        .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');

    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    return cleaned;
  }

  /// 解码HTML实体
  static String decodeHtmlEntities(String text) {
    return _unescape.convert(text);
  }

  /// 判断是否为书名
  static bool isBookTitle(String text) {
    if (text.length < 2 || text.length > 50) return false;
    if (text.contains('首页') || text.contains('下一页') || text.contains('上一页')) return false;
    if (text.contains('返回') || text.contains('登录') || text.contains('注册')) return false;
    return true;
  }

  /// 清理作者名
  /// 去掉后面的"连载中"、"连载"、"完结"等状态
  /// 如果包含特殊符号"|"或"["，取左边部分
  static String cleanAuthor(String author) {
    var text = author.trim();
    
    // 如果包含 | 或 [，取左边部分
    if (text.contains('|')) {
      text = text.split('|')[0].trim();
    }
    if (text.contains('[')) {
      text = text.split('[')[0].trim();
    }
    
    // 去掉后面的连载状态
    final statusPatterns = [
      '连载中',
      '连载',
      '完结',
      '已完结',
      '完本',
    ];
    
    for (final pattern in statusPatterns) {
      if (text.endsWith(pattern)) {
        text = text.substring(0, text.length - pattern.length).trim();
      }
    }
    
    return text;
  }
}
