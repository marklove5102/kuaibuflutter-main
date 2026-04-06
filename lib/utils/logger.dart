import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// 日志工具类 - 写入kuaibu目录的debug.log
class Logger {
  static File? _logFile;
  static bool _initialized = false;
  static String? _pendingPath;

  static void _initSync() {
    if (_initialized) return;
    try {
      if (Platform.isAndroid) {
        // Android 使用外部存储的 kuaibu 目录
        final kuaibuDir = Directory('/storage/emulated/0/kuaibu');
        _pendingPath = '${kuaibuDir.path}/debug.log';
      } else if (Platform.isIOS) {
        // iOS 异步获取路径
        _pendingPath = null;
      } else {
        // Windows/Linux/Mac 使用当前目录
        _pendingPath = 'debug.log';
      }
    } catch (e) {
      print('[Logger] 初始化失败: $e');
    }
  }

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    try {
      if (Platform.isAndroid) {
        final kuaibuDir = Directory('/storage/emulated/0/kuaibu');
        try {
          if (!await kuaibuDir.exists()) {
            await kuaibuDir.create(recursive: true);
          }
          final testFile = File('${kuaibuDir.path}/.test');
          await testFile.writeAsString('test');
          await testFile.delete();
          _logFile = File('${kuaibuDir.path}/debug.log');
        } catch (e) {
          print('[Logger] 外部存储目录创建失败: $e');
          final directory = await getApplicationDocumentsDirectory();
          _logFile = File('${directory.path}/debug.log');
        }
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/debug.log');
      } else {
        _logFile = File('debug.log');
      }
      _initialized = true;
    } catch (e) {
      print('[Logger] 初始化失败: $e');
    }
  }

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    
    // 始终打印到控制台
    debugPrint(logMessage);
    
    // 同步写入（尽可能）
    _writeToFileSync(logMessage);
  }

  static void _writeToFileSync(String logMessage) {
    try {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // 桌面端同步写入
        _initSync();
        if (_pendingPath != null) {
          final file = File(_pendingPath!);
          if (!file.existsSync()) {
            file.createSync(recursive: true);
          }
          file.writeAsStringSync('$logMessage\n', mode: FileMode.append);
        }
      } else if (Platform.isAndroid) {
        // Android 尝试同步写入到外部存储
        try {
          final kuaibuDir = Directory('/storage/emulated/0/kuaibu');
          if (kuaibuDir.existsSync()) {
            final file = File('${kuaibuDir.path}/debug.log');
            file.writeAsStringSync('$logMessage\n', mode: FileMode.append);
          } else {
            // 目录不存在，使用异步写入
            _writeToFileAsync(logMessage);
          }
        } catch (e) {
          // 同步写入失败，使用异步写入
          _writeToFileAsync(logMessage);
        }
      } else {
        // 其他平台异步写入
        _writeToFileAsync(logMessage);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  static void _writeToFileAsync(String logMessage) async {
    await _ensureInitialized();
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString('$logMessage\n', mode: FileMode.append);
      }
    } catch (e) {
      // 忽略写入错误
    }
  }

  static void clear() async {
    await _ensureInitialized();
    try {
      if (_logFile != null) {
        await _logFile!.writeAsString('');
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 获取日志文件路径（用于调试）
  static Future<String?> getLogPath() async {
    await _ensureInitialized();
    return _logFile?.path;
  }
}
