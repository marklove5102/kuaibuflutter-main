import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Directory? _cachedAppDir;
  bool _useExternalStorage = false;

  bool get isUsingExternalStorage => _useExternalStorage;

  Future<void> init() async {
    await _getAppDirectory();
  }

  void clearCache() {
    _cachedAppDir = null;
  }

  Future<Directory> _getAppDirectory() async {
    if (_cachedAppDir != null) return _cachedAppDir!;

    if (Platform.isAndroid) {
      final kuaibuDir = Directory('/storage/emulated/0/kuaibu');
      try {
        if (!await kuaibuDir.exists()) {
          await kuaibuDir.create(recursive: true);
        }
        final testFile = File('${kuaibuDir.path}/.test');
        await testFile.writeAsString('test');
        await testFile.delete();
        _cachedAppDir = kuaibuDir;
        _useExternalStorage = true;
      } catch (e) {
        final appDocDir = await getApplicationDocumentsDirectory();
        _cachedAppDir = appDocDir;
        _useExternalStorage = false;
      }
    } else {
      _cachedAppDir = Directory.current;
    }
    return _cachedAppDir!;
  }

  Future<Directory> getAppDirectory() async {
    return await _getAppDirectory();
  }

  Directory? getAppDirectorySync() {
    return _cachedAppDir;
  }

  Future<Directory> getBooksDirectory() async {
    final appDir = await _getAppDirectory();
    final booksDir = Directory('${appDir.path}/books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir;
  }

  Future<Directory> getDownloadDirectory() async {
    final appDir = await _getAppDirectory();
    final downloadDir = Directory('${appDir.path}/download');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  Future<Directory> getCoverDirectory() async {
    final appDir = await _getAppDirectory();
    final coverDir = Directory('${appDir.path}/cover');
    if (!await coverDir.exists()) {
      await coverDir.create(recursive: true);
    }
    return coverDir;
  }

  Future<Directory> getSourceDirectory() async {
    final appDir = await _getAppDirectory();
    final sourceDir = Directory('${appDir.path}/booksource');
    if (!await sourceDir.exists()) {
      await sourceDir.create(recursive: true);
    }
    return sourceDir;
  }

  Future<String> getBookDownloadPath(String bookTitle) async {
    final baseDir = (await _getAppDirectory()).path;
    final safeTitle = bookTitle.replaceAll(RegExp(r'[<>"/\\|?*]'), '_');
    final downloadPath = path.join(baseDir, 'download', safeTitle);

    final dir = Directory(downloadPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return downloadPath;
  }

  Future<String> getChapterFilePath(String bookTitle, int chapterIndex) async {
    final downloadPath = await getBookDownloadPath(bookTitle);
    return path.join(downloadPath, '${chapterIndex + 1}.txt');
  }

  Future<String> getCoverDirPath() async {
    final coverDir = await getCoverDirectory();
    return coverDir.path;
  }

  Future<String> getSourceDirPath() async {
    final sourceDir = await getSourceDirectory();
    return sourceDir.path;
  }
}