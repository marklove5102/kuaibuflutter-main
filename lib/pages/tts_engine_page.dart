import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/tts_engine.dart';
import '../services/tts_engine_manager.dart';

class TTSEnginePage extends StatefulWidget {
  const TTSEnginePage({super.key});

  @override
  State<TTSEnginePage> createState() => _TTSEnginePageState();
}

class _TTSEnginePageState extends State<TTSEnginePage> {
  List<TTSEngine> _engines = [];
  TTSEngine? _selectedEngine;
  bool _isLoading = true;

  static const MethodChannel _channel = MethodChannel('com.kuaibu/tts');

  @override
  void initState() {
    super.initState();
    _loadEngines();
  }

  Future<void> _loadEngines() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final manager = TTSEngineManager();
      await manager.init();

      final engines = await manager.getSystemEngines();
      final selected = manager.selectedEngine;

      setState(() {
        _engines = engines;
        _selectedEngine = selected;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectEngine(TTSEngine? engine) async {
    await TTSEngineManager().setEngine(engine);
    setState(() {
      _selectedEngine = engine;
    });
  }

  Future<void> _openTTSSettings() async {
    try {
      await _channel.invokeMethod('openTtsSettings');
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('朗读引擎'),
        actions: [
          if (Platform.isAndroid)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openTTSSettings,
              tooltip: '系统TTS设置',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    '系统引擎',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                RadioListTile<TTSEngine?>(
                  title: const Text('系统默认'),
                  subtitle: const Text('使用系统默认TTS引擎'),
                  value: null,
                  groupValue: _selectedEngine,
                  onChanged: (value) => _selectEngine(value),
                ),
                ..._engines.map((engine) {
                  return RadioListTile<TTSEngine?>(
                    title: Text(engine.label),
                    subtitle: Text(engine.name),
                    value: engine,
                    groupValue: _selectedEngine,
                    onChanged: (value) => _selectEngine(value),
                  );
                }),
                if (_engines.isEmpty && !Platform.isAndroid)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      '当前平台不支持选择TTS引擎',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                if (_engines.isEmpty && Platform.isAndroid)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      '未检测到第三方TTS引擎，请安装后重试',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
    );
  }
}
