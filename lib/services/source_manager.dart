import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/book_source.dart';
import '../utils/crypto_util.dart';
import 'storage_service.dart';
import 'network_service.dart';

/// 书源管理器
class SourceManager {
  static final SourceManager _instance = SourceManager._internal();
  factory SourceManager() => _instance;
  SourceManager._internal();

  final List<BookSource> _sources = [];
  String? _sourceDir;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  /// 获取所有书源
  List<BookSource> get sources => List.unmodifiable(_sources);

  /// 获取启用的书源
  List<BookSource> get enabledSources =>
      _sources.where((s) => s.isEnabled).toList();

  /// 初始化 - 确保只执行一次
  Future<void> init() async {
    if (_initialized) return;
    
    // 如果正在初始化，等待完成
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    
    // 创建 Completer 防止并发初始化
    _initCompleter = Completer<void>();
    
    try {
      await _initSourceDir();
      await loadSources();
      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      rethrow;
    }
  }

  /// 初始化书源目录
  Future<void> _initSourceDir() async {
    _sourceDir = await StorageService().getSourceDirPath();
  }

  /// 加载所有书源
  Future<void> loadSources() async {
    if (_sourceDir == null) await _initSourceDir();

    _sources.clear();
    

    final dir = Directory(_sourceDir!);
    if (await dir.exists()) {
      final files = await dir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();
      

      for (final file in files) {
        try {
          final source = await _loadFromTxt(file.path);
          if (source != null && source.sourceName.isNotEmpty) {
            // 根据 sourceName 去重，避免重复添加
            if (!_sources.any((s) => s.sourceName == source.sourceName)) {
              _sources.add(source);
            } else {
            }
          }
        } catch (e) {
        }
      }
    }
    
  }

  /// 从txt文件加载书源
  Future<BookSource?> _loadFromTxt(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }

    String content = await file.readAsString();

    final isEncrypted = CryptoUtil.isEncrypted(content);

    if (isEncrypted) {
      content = CryptoUtil.xorDecrypt(content);
    }

    final lines = content.split('\n');

    final source = BookSource();

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.contains('=')) {
        final eqIndex = trimmedLine.indexOf('=');
        final key = trimmedLine.substring(0, eqIndex).trim();
        final value = trimmedLine.substring(eqIndex + 1).trim();

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
            source.chapterOrder = value == '倒序' ? 1 : 0;
            break;
          case '搜索网址':
            source.searchUrl = value;
            break;
          case '搜索类型':
            source.searchType = value;
            break;
          case '分类排行':
            source.categoryRank = value;
            break;
          case '搜索状态':
            source.searchStatus = int.tryParse(value) ?? 2;
            break;
          case '分类状态':
            source.exploreStatus = int.tryParse(value) ?? 2;
            break;
        }
      }
    }

    return source;
  }

  /// 保存书源到txt文件
  Future<bool> saveSource(BookSource source) async {
    try {
      if (_sourceDir == null) await _initSourceDir();

      final filename = '${source.sourceName}.txt';
      final filePath = path.join(_sourceDir!, filename);

      final contentLines = <String>[];
      contentLines.add('网站名称=${source.sourceName}');
      contentLines.add('网站网址=${source.websiteUrl}');
      contentLines.add('网站编码=${source.websiteEncoding}');
      contentLines.add('简介页网址规则=${source.bookUrlPattern}');
      contentLines.add('目录页网址规则=${source.tocUrlPattern}');
      contentLines.add('章节页网址规则=${source.chapterUrlPattern}');
      contentLines.add('目录章节排序方式=${source.chapterOrder == 1 ? '倒序' : '正序'}');
      contentLines.add('搜索网址=${source.searchUrl}');
      contentLines.add('搜索类型=${source.searchType}');
      contentLines.add('分类排行=${source.categoryRank}');
      contentLines.add('搜索状态=${source.searchStatus}');
      contentLines.add('分类状态=${source.exploreStatus}');

      final content = contentLines.join('\n');
      final encryptedContent = CryptoUtil.xorEncrypt(content);

      final file = File(filePath);
      await file.writeAsString(encryptedContent);

      await loadSources();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 删除书源
  Future<bool> deleteSource(String sourceName) async {
    try {
      if (_sourceDir == null) await _initSourceDir();

      final filename = '$sourceName.txt';
      final filePath = path.join(_sourceDir!, filename);

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await loadSources();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 添加书源
  Future<void> addSource(BookSource source) async {
    source.createdAt = DateTime.now();
    source.updatedAt = DateTime.now();
    await saveSource(source);
  }

  /// 更新书源
  Future<void> updateSource(BookSource source) async {
    source.updatedAt = DateTime.now();
    await saveSource(source);
  }

  /// 根据名称获取书源
  BookSource? getSourceByName(String sourceName) {
    try {
      return _sources.firstWhere((s) => s.sourceName == sourceName);
    } catch (e) {
      return null;
    }
  }

  /// 根据ID获取书源
  BookSource? getSourceById(int id) {
    if (id >= 0 && id < _sources.length) {
      return _sources[id];
    }
    return null;
  }

  /// 批量删除书源
  Future<void> deleteSources(List<String> sourceNames) async {
    if (_sourceDir == null) await _initSourceDir();
    for (final name in sourceNames) {
      final filename = '$name.txt';
      final filePath = path.join(_sourceDir!, filename);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await loadSources();
  }

  /// 创建默认书源
  BookSource createDefaultSource() {
    return BookSource.createDefault();
  }

  /// 创建空白书源
  BookSource createBlankSource() {
    return BookSource(
      sourceName: '空白书源',
      websiteUrl: '',
      websiteEncoding: 'UTF-8',
      searchType: 'GET',
    );
  }

  /// 导出书源到文件
  Future<String> exportSources(String exportPath, {List<String>? sourceNames}) async {
    final sourcesToExport = sourceNames != null
        ? _sources.where((s) => sourceNames.contains(s.sourceName)).toList()
        : _sources;

    final buffer = StringBuffer();
    for (final source in sourcesToExport) {
      buffer.writeln(source.toSourceText());
      buffer.writeln('---');
    }

    final file = File(exportPath);
    await file.writeAsString(buffer.toString());
    return exportPath;
  }

  /// 从文件导入书源
  Future<int> importSources(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();

      String sourceText;
      if (CryptoUtil.isEncrypted(content)) {
        sourceText = CryptoUtil.xorDecrypt(content);
      } else {
        sourceText = content;
      }

      final sources = _parseSourceText(sourceText);
      int count = 0;

      for (final source in sources) {
        final exists = _sources.any((s) => s.sourceName == source.sourceName);
        if (!exists && source.sourceName.isNotEmpty) {
          source.createdAt = DateTime.now();
          source.updatedAt = DateTime.now();
          
          if (_sourceDir == null) await _initSourceDir();
          final filename = '${source.sourceName}.txt';
          final filePath = path.join(_sourceDir!, filename);
          final contentLines = <String>[];
          contentLines.add('网站名称=${source.sourceName}');
          contentLines.add('网站网址=${source.websiteUrl}');
          contentLines.add('网站编码=${source.websiteEncoding}');
          contentLines.add('简介页网址规则=${source.bookUrlPattern}');
          contentLines.add('目录页网址规则=${source.tocUrlPattern}');
          contentLines.add('章节页网址规则=${source.chapterUrlPattern}');
          contentLines.add('目录章节排序方式=${source.chapterOrder == 1 ? '倒序' : '正序'}');
          contentLines.add('搜索网址=${source.searchUrl}');
          contentLines.add('搜索类型=${source.searchType}');
          contentLines.add('分类排行=${source.categoryRank}');
          contentLines.add('搜索状态=${source.searchStatus}');
          contentLines.add('分类状态=${source.exploreStatus}');
          final fileContent = contentLines.join('\n');
          final encryptedContent = CryptoUtil.xorEncrypt(fileContent);
          await File(filePath).writeAsString(encryptedContent);
          count++;
        }
      }

      if (count > 0) {
        await loadSources();
      }
      return count;
    } catch (e) {
      throw Exception('导入书源失败: $e');
    }
  }

  /// 从书源文本导入
  Future<void> importFromText(String text) async {
    String sourceText;
    if (CryptoUtil.isEncrypted(text)) {
      sourceText = CryptoUtil.xorDecrypt(text);
    } else {
      sourceText = text;
    }

    final sources = _parseSourceText(sourceText);
    int count = 0;
    
    if (_sourceDir == null) await _initSourceDir();

    for (final source in sources) {
      final exists = _sources.any((s) => s.sourceName == source.sourceName);
      if (!exists && source.sourceName.isNotEmpty) {
        source.createdAt = DateTime.now();
        source.updatedAt = DateTime.now();
        
        final filename = '${source.sourceName}.txt';
        final filePath = path.join(_sourceDir!, filename);
        final contentLines = <String>[];
        contentLines.add('网站名称=${source.sourceName}');
        contentLines.add('网站网址=${source.websiteUrl}');
        contentLines.add('网站编码=${source.websiteEncoding}');
        contentLines.add('简介页网址规则=${source.bookUrlPattern}');
        contentLines.add('目录页网址规则=${source.tocUrlPattern}');
        contentLines.add('章节页网址规则=${source.chapterUrlPattern}');
        contentLines.add('目录章节排序方式=${source.chapterOrder == 1 ? '倒序' : '正序'}');
        contentLines.add('搜索网址=${source.searchUrl}');
        contentLines.add('搜索类型=${source.searchType}');
        contentLines.add('分类排行=${source.categoryRank}');
        contentLines.add('搜索状态=${source.searchStatus}');
        contentLines.add('分类状态=${source.exploreStatus}');
        final fileContent = contentLines.join('\n');
        final encryptedContent = CryptoUtil.xorEncrypt(fileContent);
        await File(filePath).writeAsString(encryptedContent);
        count++;
      }
    }
    
    if (count > 0) {
      await loadSources();
    }
  }

  /// 导出书源为文本
  Future<String> exportToText({List<String>? sourceNames}) async {
    final sourcesToExport = sourceNames != null
        ? _sources.where((s) => sourceNames.contains(s.sourceName)).toList()
        : _sources;

    final buffer = StringBuffer();
    for (final source in sourcesToExport) {
      buffer.writeln(source.toSourceText());
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  /// 解析书源文本
  List<BookSource> _parseSourceText(String text) {
    final sources = <BookSource>[];
    final blocks = text.split('---');

    for (final block in blocks) {
      if (block.trim().isNotEmpty) {
        try {
          final source = BookSource.fromSourceText(block.trim());
          sources.add(source);
        } catch (e) {
          // 解析失败，跳过
        }
      }
    }

    return sources;
  }

  /// 批量校验书源（并发）
  Future<Map<String, Map<String, int>>> batchVerify({int concurrency = 5}) async {
    final results = <String, Map<String, int>>{};
    final sources = List<BookSource>.from(_sources);

    for (var i = 0; i < sources.length; i += concurrency) {
      final batch = sources.skip(i).take(concurrency).toList();
      final futures = batch.map((source) async {
        final result = await verifySource(source);
        return MapEntry(source.sourceName, result);
      });

      final batchResults = await Future.wait(futures);
      for (final entry in batchResults) {
        results[entry.key] = entry.value;
      }
    }

    return results;
  }

  /// 校验单个书源
  Future<Map<String, int>> verifySource(BookSource source, {int timeout = 20}) async {
    final result = <String, int>{
      'search': 2,
      'explore': 2,
    };

    final networkService = NetworkService();

    if (source.searchUrl != null && source.searchUrl!.isNotEmpty) {
      try {
        final testKeyword = '测试';
        final searchUrl = source.searchUrl!;

        if (source.searchType.toUpperCase() == 'POST' && searchUrl.contains(',')) {
          String processedUrl = searchUrl.replaceAll('{key}', testKeyword);
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
                var value = kv[1].replaceAll('{key}', testKeyword);
                value = value.replaceAll('{', '').replaceAll('}', '');
                postBody[key] = value;
              }
            }
          }

          final html = await networkService.post(
            requestUrl,
            body: postBody,
            encoding: source.websiteEncoding,
            timeout: timeout,
          );

          if (html.isNotEmpty && html.contains('<a')) {
            result['search'] = 1;
            source.searchStatus = 1;
          } else {
            result['search'] = 0;
            source.searchStatus = 0;
          }
        } else {
          String getUrl = searchUrl.replaceAll('{key}', Uri.encodeComponent(testKeyword));
          getUrl = getUrl.replaceAll('{page}', '1');

          final html = await networkService.get(
            getUrl,
            encoding: source.websiteEncoding,
            timeout: timeout,
          );

          if (html.isNotEmpty && html.contains('<a')) {
            result['search'] = 1;
            source.searchStatus = 1;
          } else {
            result['search'] = 0;
            source.searchStatus = 0;
          }
        }
      } catch (e) {
        result['search'] = 0;
        source.searchStatus = 0;
      }
    }

    if (source.exploreUrl != null && source.exploreUrl!.isNotEmpty) {
      try {
        final exploreUrl = source.exploreUrl!;
        String? verifyUrl;

        if (exploreUrl.contains('::')) {
          final groups = exploreUrl.split('&&');
          if (groups.isNotEmpty) {
            final firstGroup = groups.first.trim();
            if (firstGroup.contains('::')) {
              final parts = firstGroup.split('::');
              if (parts.length >= 2) {
                verifyUrl = parts[1].trim();
              }
            }
          }
        }

        verifyUrl ??= exploreUrl;

        if (verifyUrl.contains('{page}')) {
          verifyUrl = verifyUrl.replaceAll('{page}', '1');
        }

        final isAccessible = await networkService.head(
          verifyUrl,
          timeout: timeout,
        );

        if (isAccessible) {
          result['explore'] = 1;
          source.exploreStatus = 1;
        } else {
          result['explore'] = 0;
          source.exploreStatus = 0;
        }
      } catch (e) {
        result['explore'] = 0;
        source.exploreStatus = 0;
      }
    }

    await saveSource(source);

    return result;
  }

  /// 批量删除失效书源
  Future<int> batchDeleteFailed(String type) async {
    final namesToDelete = <String>[];

    for (final source in _sources) {
      bool shouldDelete = false;

      switch (type) {
        case 'all':
          shouldDelete = (source.searchStatus == 0) && (source.exploreStatus == 0);
          break;
        case 'search':
          shouldDelete = source.searchStatus == 0;
          break;
        case 'explore':
          shouldDelete = source.exploreStatus == 0;
          break;
      }

      if (shouldDelete) {
        namesToDelete.add(source.sourceName);
      }
    }

    for (final name in namesToDelete) {
      await deleteSource(name);
    }

    return namesToDelete.length;
  }
}
