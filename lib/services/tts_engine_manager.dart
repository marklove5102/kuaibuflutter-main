import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tts_engine.dart';

class TTSEngineManager {
  static final TTSEngineManager _instance = TTSEngineManager._internal();
  factory TTSEngineManager() => _instance;
  TTSEngineManager._internal();

  static const String _ttsEngineKey = 'tts_engine';
  static const MethodChannel _channel = MethodChannel('com.kuaibu/tts');

  TTSEngine? _selectedEngine;
  List<TTSEngine> _systemEngines = [];

  TTSEngine? get selectedEngine => _selectedEngine;
  List<TTSEngine> get systemEngines => _systemEngines;

  Future<void> init() async {
    await _loadSavedEngine();
    if (Platform.isAndroid) {
      await _loadSystemEngines();
    }
  }

  Future<void> _loadSavedEngine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final engineJson = prefs.getString(_ttsEngineKey);
      if (engineJson != null && engineJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(engineJson);
        _selectedEngine = TTSEngine.fromJson(data);
      }
    } catch (e) {
    }
  }

  Future<void> _loadSystemEngines() async {
    try {
      final List<dynamic> engines = await _channel.invokeMethod('getTtsEngines');
      _systemEngines = engines.map((e) => TTSEngine.fromJson(Map<String, dynamic>.from(e))).toList();
      for (var engine in _systemEngines) {
      }
    } catch (e) {
    }
  }

  Future<List<TTSEngine>> getSystemEngines() async {
    if (Platform.isAndroid) {
      try {
        final List<dynamic> engines = await _channel.invokeMethod('getTtsEngines');
        return engines.map((e) => TTSEngine.fromJson(Map<String, dynamic>.from(e))).toList();
      } catch (e, stackTrace) {
      }
    } else {
    }
    return [];
  }

  Future<void> setEngine(TTSEngine? engine) async {
    _selectedEngine = engine;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (engine != null) {
        await prefs.setString(_ttsEngineKey, jsonEncode(engine.toJson()));
      } else {
        await prefs.remove(_ttsEngineKey);
      }
    } catch (e) {
    }
  }

  Future<void> clearEngine() async {
    _selectedEngine = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ttsEngineKey);
    } catch (e) {
    }
  }

  String? getEngineName() {
    return _selectedEngine?.name;
  }

  String getEngineDisplayName() {
    if (_selectedEngine == null || _selectedEngine!.name.isEmpty) {
      return '系统默认';
    }
    return _selectedEngine!.label;
  }
}
