/// URL 工具类 - 提供统一的 URL 处理方法
class UrlUtils {
  /// 将相对URL转换为绝对URL
  static String convertToAbsoluteUrl(String link, String baseUrl) {
    if (link.startsWith('http://') || link.startsWith('https://')) {
      return link;
    }

    final uri = Uri.parse(baseUrl);

    if (link.startsWith('//')) {
      return '${uri.scheme}:$link';
    } else if (link.startsWith('/')) {
      return '${uri.scheme}://${uri.host}$link';
    } else {
      final basePath = baseUrl.substring(0, baseUrl.lastIndexOf('/') + 1);
      return '$basePath$link';
    }
  }

  /// 将书源配置中的URL模式转换为正则表达式
  static String convertPatternToRegex(String pattern) {
    var regex = pattern;

    // 替换简化格式
    regex = regex.replaceAll('(书类)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(书号)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(章号)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(记一)', '([a-zA-Z0-9_-]+)');
    regex = regex.replaceAll('(记二)', '([a-zA-Z0-9_-]+)');

    // 转义特殊字符
    regex = regex.replaceAll('.', r'\.');
    regex = regex.replaceAll('?', r'\?');

    return regex;
  }

  /// 验证URL是否匹配模式
  static bool validateUrl(String url, String? pattern) {
    if (pattern == null || pattern.isEmpty) {
      return true;
    }

    final regex = convertPatternToRegex(pattern);

    try {
      final regExp = RegExp(regex, caseSensitive: false);

      // 首先尝试全地址匹配
      if (regex.startsWith('http')) {
        if (regExp.hasMatch(url)) {
          return true;
        }
      }

      // 尝试提取URL的路径部分进行匹配
      final uri = Uri.parse(url);
      final path = uri.path;

      return regExp.hasMatch(path) || regExp.hasMatch(url);
    } catch (e) {
      return true;
    }
  }

  /// 从URL中提取参数
  static Map<String, String> extractUrlParams(String url, String pattern) {
    final regex = convertPatternToRegex(pattern);
    final regExp = RegExp(regex);
    final match = regExp.firstMatch(url);

    if (match == null) {
      return {};
    }

    final params = <String, String>{};
    final groupNames = ['书类', '书号', '章号', '记一', '记二'];

    for (int i = 1; i <= match.groupCount && i <= groupNames.length; i++) {
      final value = match.group(i);
      if (value != null) {
        params[groupNames[i - 1]] = value;
      }
    }

    return params;
  }

  /// 替换URL模板中的变量
  static String replaceUrlTemplate(String template, Map<String, String> params) {
    var result = template;
    params.forEach((key, value) {
      result = result.replaceAll('($key)', value);
    });
    return result;
  }

  /// 检查两个URL是否属于同一章节（用于分页检测）
  static bool isSameChapter(String currentUrl, String? nextPageUrl) {
    if (nextPageUrl == null || nextPageUrl.isEmpty) {
      return false;
    }

    try {
      final currentBase = currentUrl.replaceAll(RegExp(r'_\d+\.html$'), '').replaceAll(RegExp(r'\.html$'), '');
      final nextBase = nextPageUrl.replaceAll(RegExp(r'_\d+\.html$'), '').replaceAll(RegExp(r'\.html$'), '');

      if (currentBase == nextBase) {
        return true;
      }

      if (nextBase.startsWith(currentBase + '_') || nextBase.startsWith(currentBase + '-')) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// 解析URL为绝对路径（支持相对路径）
  static String resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    try {
      final baseUri = Uri.parse(baseUrl);

      if (url.startsWith('/')) {
        return '${baseUri.scheme}://${baseUri.host}$url';
      } else if (url.startsWith('./')) {
        final basePath = baseUri.path;
        final lastSlashIndex = basePath.lastIndexOf('/');
        final baseDir = lastSlashIndex >= 0 ? basePath.substring(0, lastSlashIndex + 1) : '/';
        return '${baseUri.scheme}://${baseUri.host}$baseDir${url.substring(2)}';
      } else if (url.startsWith('../')) {
        return baseUri.resolve(url).toString();
      } else {
        final basePath = baseUri.path;
        final lastSlashIndex = basePath.lastIndexOf('/');
        final baseDir = lastSlashIndex >= 0 ? basePath.substring(0, lastSlashIndex + 1) : '/';
        return '${baseUri.scheme}://${baseUri.host}$baseDir$url';
      }
    } catch (e) {
      return url;
    }
  }
}
