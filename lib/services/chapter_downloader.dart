import 'dart:io';
import 'dart:convert';
import '../models/book_source.dart';
import '../utils/url_utils.dart';
import 'network_service.dart';
import 'storage_service.dart';
import 'chapter_content_parser.dart';
import 'replace_rule_manager.dart';

/// 章节下载器 - 下载章节内容并保存到本地
class ChapterDownloader {
  final NetworkService _networkService = NetworkService();
  final ReplaceRuleManager _ruleManager = ReplaceRuleManager();
  
  // 用于记住当前章节的提取模式（首页检测后记住，分页时复用）
  String? _currentExtractionMode;

  /// 下载单个章节（支持分页）
  Future<bool> downloadChapter({
    required String chapterUrl,
    required String chapterTitle,
    required String bookTitle,
    required int chapterIndex,
    required BookSource source,
    bool downloadAllPages = true,
  }) async {
    try {

      final filePath = await StorageService().getChapterFilePath(bookTitle, chapterIndex);
      final file = File(filePath);

      if (await file.exists()) {
        return true;
      }

      var content = await _downloadChapterContent(
        chapterUrl: chapterUrl,
        source: source,
        downloadAllPages: downloadAllPages,
      );

      if (content.isEmpty) {
        return false;
      }

      await _ruleManager.init();
      content = await _ruleManager.applyRulesAsync(content, chapterUrl, bookTitle);

      final contentToSave = '$chapterTitle\n\n$content';
      await file.writeAsString(contentToSave, encoding: utf8);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 检查两个URL是否属于同一章节（用于防止下载到下一章内容）
  bool _isSameChapter(String currentUrl, String? nextPageUrl) {
    return UrlUtils.isSameChapter(currentUrl, nextPageUrl);
  }

  /// 下载章节内容（支持分页）
  Future<String> _downloadChapterContent({
    required String chapterUrl,
    required BookSource source,
    bool downloadAllPages = true,
  }) async {
    final allContent = StringBuffer();
    final processedUrls = <String>{chapterUrl};
    var currentUrl = chapterUrl;
    var pageCount = 0;
    const maxPages = 10;
    
    // 重置提取模式（每个章节开始时重置）
    _currentExtractionMode = null;

    while (currentUrl.isNotEmpty && pageCount < maxPages) {

      if (pageCount > 0) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      String html = '';
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          final referer = pageCount > 0 ? processedUrls.last : null;
          html = await _networkService.get(
            currentUrl,
            encoding: source.websiteEncoding,
            referer: referer,
          );
          break;
        } catch (e) {
          retryCount++;

          if (retryCount >= maxRetries) {
            if (pageCount == 0) {
              return '';
            }
            break;
          }

          await Future.delayed(Duration(milliseconds: 500 * retryCount));
        }
      }

      if (html.isEmpty) {
        if (pageCount == 0) {
          return '';
        }
        break;
      }

      // 第一页检测提取模式，后续页面复用该模式
      String content;
      if (pageCount == 0) {
        // 第一页：检测最佳提取模式
        final result = ChapterContentParser.detectExtractionMode(html, source);
        _currentExtractionMode = result['mode'] as String?;
        content = result['content'] as String? ?? '';
      } else {
        // 后续页面：使用已确定的提取模式
        content = ChapterContentParser.parseContent(html, source, extractionMode: _currentExtractionMode);
      }

      if (content.isNotEmpty) {
        if (allContent.isNotEmpty) {
          allContent.write('\n\n');
        }
        allContent.write(content);
      }

      if (!downloadAllPages) {
        break;
      }

      final nextPageUrl = ChapterContentParser.parseNextPageUrl(html, currentUrl);

      if (nextPageUrl == null || nextPageUrl.isEmpty) {
        break;
      }

      bool isSameChapter = _isSameChapter(currentUrl, nextPageUrl);
      if (!isSameChapter) {
        break;
      }

      if (!processedUrls.contains(nextPageUrl) && nextPageUrl != currentUrl) {
        processedUrls.add(nextPageUrl);
        currentUrl = nextPageUrl;
        pageCount++;
      } else {
        break;
      }
    }

    return allContent.toString();
  }

  /// 批量下载章节
  Future<Map<String, dynamic>> downloadChapters({
    required List<Map<String, String>> chapters,
    required String bookTitle,
    required BookSource source,
    Function(int current, int total)? onProgress,
    bool downloadAllPages = true,
  }) async {
    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final chapterUrl = chapter['url'] as String? ?? '';
      final chapterTitle = chapter['title'] as String? ?? '第${i + 1}章';

      if (chapterUrl.isEmpty) {
        failCount++;
        continue;
      }

      final success = await downloadChapter(
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        bookTitle: bookTitle,
        chapterIndex: i,
        source: source,
        downloadAllPages: downloadAllPages,
      );

      if (success) {
        successCount++;
      } else {
        failCount++;
      }

      if (onProgress != null) {
        onProgress(i + 1, chapters.length);
      }

      await Future.delayed(const Duration(milliseconds: 200));
    }

    return {
      'success': successCount,
      'fail': failCount,
      'total': chapters.length,
    };
  }

  /// 预下载后续章节（提升阅读体验）
  /// [onChapterDownloaded] 每个章节下载完成后回调，参数为章节索引
  Future<void> prefetchChapters({
    required List<Map<String, String>> chapters,
    required String bookTitle,
    required BookSource source,
    required int startIndex,
    int count = 3,
    Function(int)? onChapterDownloaded,
  }) async {

    for (int i = 0; i < count; i++) {
      final chapterIndex = startIndex + i;
      if (chapterIndex >= chapters.length) {
        break;
      }

      final chapter = chapters[chapterIndex];
      final chapterUrl = chapter['url'] as String? ?? '';
      final chapterTitle = chapter['title'] as String? ?? '第${chapterIndex + 1}章';

      if (chapterUrl.isEmpty) {
        continue;
      }

      final isDownloaded = await isChapterDownloaded(bookTitle, chapterIndex);
      if (isDownloaded) {
        continue;
      }

      final success = await downloadChapter(
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        bookTitle: bookTitle,
        chapterIndex: chapterIndex,
        source: source,
        downloadAllPages: true,
      );

      if (success) {
        onChapterDownloaded?.call(chapterIndex);
      } else {
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// 读取本地章节内容
  Future<String?> readChapterContent(String bookTitle, int chapterIndex) async {
    try {
      final filePath = await StorageService().getChapterFilePath(bookTitle, chapterIndex);
      final file = File(filePath);

      if (await file.exists()) {
        return await file.readAsString(encoding: utf8);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查章节是否已下载
  Future<bool> isChapterDownloaded(String bookTitle, int chapterIndex) async {
    try {
      final filePath = await StorageService().getChapterFilePath(bookTitle, chapterIndex);
      final file = File(filePath);

      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// 删除已下载的章节
  Future<bool> deleteChapter(String bookTitle, int chapterIndex) async {
    try {
      final filePath = await StorageService().getChapterFilePath(bookTitle, chapterIndex);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 删除整本书的所有章节
  Future<bool> deleteAllChapters(String bookTitle) async {
    try {
      final downloadPath = await StorageService().getBookDownloadPath(bookTitle);
      final downloadDir = Directory(downloadPath);

      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
