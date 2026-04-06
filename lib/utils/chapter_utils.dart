/// 章节处理工具类 - 提供章节去重、过滤等功能
class ChapterUtils {
  /// 章节去重：综合使用多种去重算法
  ///
  /// 1. 纯数字章号去重: 从URL中提取纯数字章号，保留最后出现的章节
  /// 2. URL去重: 去掉域名部分后比较URL路径，保留最后出现的章节
  /// 3. 章节名去重: 前后20章对比，去掉前面留后面
  static List<Map<String, dynamic>> deduplicateChapters(
    List<Map<String, dynamic>> chapters,
  ) {
    if (chapters.length <= 1) {
      return chapters;
    }

    List<Map<String, dynamic>> currentChapters = List.from(chapters);

    // 第一步：纯数字章号去重
    currentChapters = _deduplicateByNumericChapterNumber(currentChapters);

    // 第二步：URL去重
    currentChapters = _deduplicateByUrl(currentChapters);

    // 第三步：章节名去重（前后20章对比）
    currentChapters = _deduplicateByTitle(currentChapters);

    return currentChapters;
  }

  /// 纯数字章号去重算法
  static List<Map<String, dynamic>> _deduplicateByNumericChapterNumber(
    List<Map<String, dynamic>> chapters,
  ) {
    // 辅助函数：从URL中提取纯数字章号
    int? extractChapterNumber(String url) {
      if (url.isEmpty) return null;

      // 匹配以.html或.htm结尾的URL中的数字章号
      final match = RegExp(r'/([0-9]+)\.html?$').firstMatch(url);
      if (match != null) {
        final chapterNum = match.group(1);
        if (chapterNum != null) {
          return int.tryParse(chapterNum);
        }
      }
      return null;
    }

    // 为每个章节提取章号
    final chaptersWithNum = <MapEntry<int?, Map<String, dynamic>>>[];
    bool hasNumericChapters = false;

    for (final chapter in chapters) {
      final chapterNum = extractChapterNumber(chapter['url'] ?? '');
      chaptersWithNum.add(MapEntry(chapterNum, chapter));
      if (chapterNum != null) {
        hasNumericChapters = true;
      }
    }

    // 如果没有数字章号，跳过此步骤
    if (!hasNumericChapters) {
      return chapters;
    }

    // 分组：有章号的章节和无章号的章节
    final numericChapters = <int, Map<String, dynamic>>{};
    final nonNumericChapters = <Map<String, dynamic>>[];

    for (final entry in chaptersWithNum) {
      if (entry.key != null) {
        // 保留相同章号中最后出现的章节
        numericChapters[entry.key!] = entry.value;
      } else {
        nonNumericChapters.add(entry.value);
      }
    }

    // 按章号排序
    final sortedKeys = numericChapters.keys.toList()..sort();
    final sortedUnique = sortedKeys.map((k) => numericChapters[k]!).toList();

    // 添加没有章号的章节到末尾
    return [...sortedUnique, ...nonNumericChapters];
  }

  /// URL去重算法：去掉域名部分后比较URL路径
  static List<Map<String, dynamic>> _deduplicateByUrl(
    List<Map<String, dynamic>> chapters,
  ) {
    final uniqueChapters = <String, Map<String, dynamic>>{};

    for (final chapter in chapters) {
      final url = chapter['url'] ?? '';
      // 去掉URL的域名部分进行比较
      final normalizedUrl = _removeDomain(url);
      uniqueChapters[normalizedUrl] = chapter;
    }

    return uniqueChapters.values.toList();
  }

  /// 章节名去重：前后20章对比，去掉前面留后面
  static List<Map<String, dynamic>> _deduplicateByTitle(
    List<Map<String, dynamic>> chapters,
  ) {
    if (chapters.length <= 20) {
      return chapters;
    }

    // 提取前20章和后20章
    final first20 = chapters.sublist(0, 20);
    final last20 = chapters.sublist(chapters.length - 20);

    // 提取后20章的章节名集合
    final last20Titles = last20.map((ch) => ch['title'] ?? '').toSet();

    // 创建新的章节列表
    final newChapters = <Map<String, dynamic>>[];

    // 添加前20章中不与后20章章节名重复的章节
    for (final ch in first20) {
      if (!last20Titles.contains(ch['title'] ?? '')) {
        newChapters.add(ch);
      }
    }

    // 添加中间章节（如果有的话）
    if (chapters.length > 40) {
      newChapters.addAll(chapters.sublist(20, chapters.length - 20));
    }

    // 添加后20章
    newChapters.addAll(last20);

    return newChapters;
  }

  /// 章节过滤：过滤和排序章节
  ///
  /// 1. 初步过滤：去除明显的非章节链接
  /// 2. 长度过滤：过滤URL长度差异过大的章节
  /// 3. 分页过滤：过滤分页页面
  /// 4. 正则过滤：根据URL模式过滤
  /// 5. 相似度过滤：计算URL结构相似度
  static List<Map<String, dynamic>> filterChapters(
    List<Map<String, dynamic>> chapters, {
    String? standardUrl,
    String? urlPathPrefix,
    String? standardExtension,
  }) {
    if (chapters.length <= 2) {
      return chapters;
    }

    // 第一步：初步过滤
    var filtered = _preliminaryFilter(chapters);

    if (filtered.length <= 2) {
      return filtered;
    }

    // 第二步：精细过滤
    filtered = _fineFilter(
      filtered,
      standardUrl: standardUrl,
      urlPathPrefix: urlPathPrefix,
      standardExtension: standardExtension,
    );

    return filtered;
  }

  /// 初步过滤：去除明显的非章节链接
  static List<Map<String, dynamic>> _preliminaryFilter(
    List<Map<String, dynamic>> chapters,
  ) {
    final navKeywords = {
      '上一页', '下一页', '首页', '尾页', '目录', '收藏',
      '返回', '返回首页', '开始阅读', '立即阅读', '我的书架', '阅读记录',
    };
    final adKeywords = {'广告', '推广', '充值', 'VIP', '登录'};

    final filtered = <Map<String, dynamic>>[];

    for (final ch in chapters) {
      final title = ch['title'] ?? '';
      final url = ch['url'] ?? '';

      // 检查标题中的关键字
      if (navKeywords.any((kw) => title.contains(kw))) {
        continue;
      }
      if (adKeywords.any((kw) => title.contains(kw))) {
        continue;
      }

      // 过滤掉路径太短的URL和无效链接
      final path = _removeDomain(url);
      if (path.length <= 1) {
        continue;
      }

      // 过滤特殊功能页面
      if (RegExp(r'^/[a-zA-Z_]+\.(php|html)$').hasMatch(path)) {
        continue;
      }

      // 过滤不含.的URL
      if (!path.contains('.')) {
        continue;
      }

      // 标题长度过滤 (2-50字符)
      if (title.length < 2 || title.length > 50) {
        continue;
      }

      filtered.add(ch);
    }

    return filtered;
  }

  /// 精细过滤：使用标准URL进行更精细的过滤
  static List<Map<String, dynamic>> _fineFilter(
    List<Map<String, dynamic>> chapters, {
    String? standardUrl,
    String? urlPathPrefix,
    String? standardExtension,
  }) {
    if (chapters.isEmpty) return chapters;

    // 如果没有标准URL，使用中间位置的URL
    final urlValue = standardUrl ?? chapters[chapters.length ~/ 2]['url'] ?? '';
    if (urlValue.isEmpty) return chapters;

    final standardUrlPath = _removeDomain(urlValue);
    final standardUrlLength = standardUrlPath.length;
    const lengthThreshold = 0.1; // 允许10%的长度差异

    // 创建正则模板
    String? chapterRegexTemplate;
    if (urlPathPrefix != null && urlPathPrefix.isNotEmpty) {
      final escapedPathPrefix = RegExp.escape(urlPathPrefix);
      final extension = standardExtension ?? r'\.[^/]+';
      chapterRegexTemplate = '^$escapedPathPrefix/[0-9A-Za-z]+$extension\$';
    }

    final filtered = <Map<String, dynamic>>[];

    for (final ch in chapters) {
      final url = ch['url'] ?? '';
      if (url.isEmpty) continue;
      final urlPath = _removeDomain(url);

      // 长度过滤
      final lengthDiff = (urlPath.length - standardUrlLength).abs() / standardUrlLength;
      if (lengthDiff > lengthThreshold) {
        continue;
      }

      // 分页过滤
      if (RegExp(r'/p\d+\.html$').hasMatch(url)) {
        continue;
      }

      // 正则过滤
      if (chapterRegexTemplate != null) {
        if (!RegExp(chapterRegexTemplate).hasMatch(urlPath)) {
          continue;
        }
      } else {
        // 相似度过滤
        final similarity = calculateUrlSimilarity(url, urlValue);
        if (similarity < 0.5) {
          continue;
        }
      }

      filtered.add(ch);
    }

    // 如果过滤后没有章节，返回原始列表
    if (filtered.isEmpty) {
      return chapters;
    }

    return filtered;
  }

  /// 计算两个URL的结构相似度
  static double calculateUrlSimilarity(String url1, String url2) {
    // 移除协议和域名部分
    final path1 = _removeDomain(url1);
    final path2 = _removeDomain(url2);

    // 将URL分割成路径段
    final parts1 = path1.split('/');
    final parts2 = path2.split('/');

    // 计算路径结构相似度
    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    if (maxLen == 0) return 1.0;

    int matches = 0;
    for (int i = 0; i < parts1.length && i < parts2.length; i++) {
      // 如果两个部分相同或都是数字，认为匹配
      if (parts1[i] == parts2[i] ||
          (RegExp(r'^\d+$').hasMatch(parts1[i]) &&
              RegExp(r'^\d+$').hasMatch(parts2[i]))) {
        matches++;
      }
    }

    return matches / maxLen;
  }

  /// 移除URL的域名部分
  static String _removeDomain(String url) {
    return url.replaceFirst(RegExp(r'^https?://[^/]+'), '');
  }

  /// 从章节列表中选择标准URL
  ///
  /// 从中间位置开始查找符合条件的标准URL
  static Map<String, dynamic>? selectStandardUrl(
    List<Map<String, dynamic>> chapters,
  ) {
    if (chapters.isEmpty) return null;

    final midIndex = chapters.length ~/ 2;

    // 从中间位置开始查找
    for (int offset = 0; offset <= midIndex; offset++) {
      // 先检查右边
      final rightIndex = midIndex + offset;
      if (rightIndex < chapters.length) {
        final result = _checkAndExtractStandardUrl(chapters[rightIndex]);
        if (result != null) return result;
      }

      // 再检查左边
      if (offset > 0) {
        final leftIndex = midIndex - offset;
        if (leftIndex >= 0) {
          final result = _checkAndExtractStandardUrl(chapters[leftIndex]);
          if (result != null) return result;
        }
      }
    }

    // 如果都没找到，返回中间位置的URL
    final midChapter = chapters[midIndex];
    return {
      'standardUrl': midChapter['url'] ?? '',
      'urlPathPrefix': '',
      'standardExtension': '',
    };
  }

  /// 检查并提取标准URL信息
  static Map<String, dynamic>? _checkAndExtractStandardUrl(
    Map<String, dynamic> chapter,
  ) {
    final url = chapter['url'] ?? '';
    if (url.isEmpty) return null;

    final path = _removeDomain(url);
    final pathSegments = path.split('/');

    // 检查URL是否符合章节URL的特征
    // 1. 不是单个文件
    // 2. 包含多个路径段
    // 3. 有有效的文件扩展名
    final isValidChapterUrl = pathSegments.length >= 3 &&
        path.contains('.') &&
        !RegExp(r'^/[^/]+\.[^/]+$').hasMatch(path);

    if (!isValidChapterUrl) return null;

    // 提取文件扩展名
    String extension = '';
    final dotPos = url.lastIndexOf('.');
    if (dotPos != -1) {
      extension = url.substring(dotPos);
    }

    // 提取路径前缀
    final lastSlashPos = path.lastIndexOf('/');
    final pathPrefix = lastSlashPos != -1 ? path.substring(0, lastSlashPos) : path;

    return {
      'standardUrl': url,
      'urlPathPrefix': pathPrefix,
      'standardExtension': extension,
    };
  }

  /// 判断是否为有效的书籍标题
  static bool isValidBookTitle(String title) {
    if (title.length < 2 || title.length > 50) return false;

    final invalidKeywords = [
      '首页', '下一页', '上一页', '尾页', '返回',
      '登录', '注册', '收藏', '目录', '书架',
    ];

    return !invalidKeywords.any((kw) => title.contains(kw));
  }

  /// 过滤章节标题中的无效内容
  static String cleanChapterTitle(String title) {
    return title
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
