import 'dart:io';
import 'package:path/path.dart' as path;
import 'storage_service.dart';

class ReaderConfigManager {
  static final ReaderConfigManager _instance = ReaderConfigManager._internal();
  factory ReaderConfigManager() => _instance;
  ReaderConfigManager._internal();

  String? _bgImagePath;
  int _bgColor = 0xFFFFFCE6;
  int _textColor = 0xFF000000;
  String _fontFamily = 'SimHei';
  double _fontSize = 16;
  double _lineHeight = 1.8;
  int _scrollSpeed = 1600;
  int _autoPageSpeed = 10000;

  bool _initialized = false;

  String? get bgImagePath => _bgImagePath;
  int get bgColor => _bgColor;
  int get textColor => _textColor;
  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  int get scrollSpeed => _scrollSpeed;
  int get autoPageSpeed => _autoPageSpeed;

  Future<void> init() async {
    if (_initialized) return;
    await _loadConfig();
    _initialized = true;
  }

  Future<String> _getConfigPath() async {
    final appDir = await StorageService().getAppDirectory();
    return path.join(appDir.path, 'reader_config.ini');
  }

  Future<void> _loadConfig() async {
    try {
      final configPath = await _getConfigPath();
      final file = File(configPath);

      if (!await file.exists()) {
        return;
      }

      final content = await file.readAsString();
      final lines = content.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#') || trimmed.startsWith(';') || trimmed.startsWith('[')) {
          continue;
        }

        final parts = trimmed.split('=');
        if (parts.length != 2) continue;

        final key = parts[0].trim();
        final value = parts[1].trim();

        switch (key) {
          case 'bg_image_path':
            _bgImagePath = value.isEmpty ? null : value;
            break;
          case 'bg_color':
            _bgColor = int.tryParse(value, radix: 16) ?? 0xFFFFFCE6;
            break;
          case 'text_color':
            _textColor = int.tryParse(value, radix: 16) ?? 0xFF000000;
            break;
          case 'font_family':
            _fontFamily = value.isEmpty ? 'SimHei' : value;
            break;
          case 'font_size':
            _fontSize = double.tryParse(value) ?? 16;
            break;
          case 'line_height':
            _lineHeight = double.tryParse(value) ?? 1.8;
            break;
          case 'scroll_speed':
            _scrollSpeed = int.tryParse(value) ?? 500;
            break;
          case 'auto_page_speed':
            _autoPageSpeed = int.tryParse(value) ?? 5;
            break;
        }
      }
    } catch (e) {
      // 忽略加载错误，使用默认值
    }
  }

  Future<void> _saveConfig() async {
    try {
      final configPath = await _getConfigPath();
      final file = File(configPath);

      final content = StringBuffer();
      content.writeln('[Background]');
      content.writeln('bg_image_path = ${_bgImagePath ?? ''}');
      content.writeln('bg_color = ${_bgColor.toRadixString(16).toUpperCase()}');
      content.writeln('text_color = ${_textColor.toRadixString(16).toUpperCase()}');
      content.writeln();
      content.writeln('[Font]');
      content.writeln('font_family = $_fontFamily');
      content.writeln('font_size = $_fontSize');
      content.writeln('line_height = $_lineHeight');
      content.writeln();
      content.writeln('[Reading]');
      content.writeln('scroll_speed = $_scrollSpeed');
      content.writeln('auto_page_speed = $_autoPageSpeed');

      await file.writeAsString(content.toString());
    } catch (e) {
      // 忽略保存错误
    }
  }

  void setBgImagePath(String? value) {
    _bgImagePath = value;
    _saveConfig();
  }

  void setBgColor(int value) {
    _bgColor = value;
    _saveConfig();
  }

  void setTextColor(int value) {
    _textColor = value;
    _saveConfig();
  }

  void setFontFamily(String value) {
    _fontFamily = value;
    _saveConfig();
  }

  void setFontSize(double value) {
    _fontSize = value;
    _saveConfig();
  }

  void setLineHeight(double value) {
    _lineHeight = value;
    _saveConfig();
  }

  void setScrollSpeed(int value) {
    _scrollSpeed = value;
    _saveConfig();
  }

  void setAutoPageSpeed(int value) {
    _autoPageSpeed = value;
    _saveConfig();
  }
}
