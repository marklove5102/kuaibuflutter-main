import 'dart:io';
import 'tts_engine_manager.dart';

// 条件导入：Android 使用真实 TTS，其他平台使用空实现
import 'tts_stub.dart';

enum ReadAloudState { stopped, playing, paused }

class TTSReadAloudService {
  static final TTSReadAloudService _instance = TTSReadAloudService._internal();
  factory TTSReadAloudService() => _instance;
  TTSReadAloudService._internal();

  bool _isInitialized = false;
  bool _ttsInitFinish = false;
  ReadAloudState _state = ReadAloudState.stopped;
  List<String> _contentList = [];
  int _nowSpeak = 0;
  double _speechRate = 1.0;
  double _volume = 1.0;
  dynamic _flutterTts;
  String? _currentEngine;

  Function(int current, int total)? onProgress;
  Function()? onComplete;
  Function(String state)? onStateChanged;
  Function(int index, String text)? onSentenceStart;

  bool get _isWindows => Platform.isWindows;
  bool get _isAndroid => Platform.isAndroid;

  double get speechRate => _speechRate;
  double get volume => _volume;

  Future<void> init() async {
    if (_isInitialized) {
      final engine = TTSEngineManager().getEngineName();
      if (engine != _currentEngine) {
        await _reinitTts();
      }
      return;
    }

    await TTSEngineManager().init();
    await _initTts();

    _isInitialized = true;
  }

  Future<void> _reinitTts() async {
    _ttsInitFinish = false;
    _currentEngine = null;
    if (_flutterTts != null) {
      await _stopTts();
    }
    await _initTts();
  }

  Future<void> _stopTts() async {
    if (_flutterTts != null) {
      try {
        await _flutterTts.stop();
      } catch (e) {
      }
    }
  }

  Future<void> _initTts() async {
    _ttsInitFinish = false;

    try {
      _flutterTts = createTts();

      if (_isAndroid) {
        final engine = TTSEngineManager().getEngineName();
        _currentEngine = engine;

        if (engine != null && engine.isNotEmpty) {
          try {
            var result = await _flutterTts.setEngine(engine);
          } catch (e) {
          }
        } else {
        }

        await _flutterTts.awaitSpeakCompletion(true);

        var availableLangs = await _flutterTts.getLanguages;

        var availableVoices = await _flutterTts.getVoices;

        var langAvailable = 0;

        if (availableLangs != null && availableLangs is List && availableLangs.isNotEmpty) {
          var langs = availableLangs.map((e) => e.toString()).toList();

          var langToUse = _findBestLanguage(langs);

          langAvailable = await _flutterTts.setLanguage(langToUse);
        } else {
          try {
            langAvailable = await _flutterTts.setLanguage('zh-CN');
          } catch (e) {
          }
        }

        if (langAvailable == 1) {
          _ttsInitFinish = true;
        } else {
          _ttsInitFinish = true;
        }
      } else {
        // Windows 或其他平台简化初始化
        _ttsInitFinish = true;
      }

      _flutterTts.setCompletionHandler(() {
        _nextParagraph();
      });

      _flutterTts.setErrorHandler((msg) {
      });

    } catch (e, stackTrace) {
    }
  }

  String _findBestLanguage(List<String> langs) {
    final candidates = ['zh-CN', 'zh_CN', 'zh', 'cmn-CN', 'cmn', 'zh-TW', 'zh_HK', 'zh-TW', 'zh_TW'];
    for (var candidate in candidates) {
      if (langs.contains(candidate)) {
        return candidate;
      }
    }
    return langs.first;
  }

  Future<void> play(String content) async {
    await init();
    _contentList = _splitContent(content);
    _nowSpeak = 0;
    _state = ReadAloudState.playing;
    await _doPlay();
  }

  Future<void> playList(List<String> paragraphs) async {
    await init();
    _contentList = paragraphs;
    _nowSpeak = 0;
    _state = ReadAloudState.playing;
    await _doPlay();
  }

  Future<void> _doPlay() async {
    if (!_ttsInitFinish) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!_ttsInitFinish) {
        return;
      }
    }

    if (_contentList.isEmpty) {
      _state = ReadAloudState.stopped;
      onComplete?.call();
      return;
    }

    onStateChanged?.call('playing');

    if (_flutterTts != null) {
      await _stopTts();
    }

    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    if (_nowSpeak >= _contentList.length) {
      _state = ReadAloudState.stopped;
      onComplete?.call();
      return;
    }
    final text = _contentList[_nowSpeak];
    if (text.isEmpty) {
      _nextParagraph();
      return;
    }
    onProgress?.call(_nowSpeak + 1, _contentList.length);
    onSentenceStart?.call(_nowSpeak, text);
    await _speak(text);
  }

  Future<void> _nextParagraph() async {
    _nowSpeak++;
    if (_nowSpeak < _contentList.length) {
      await _speakCurrent();
    } else {
      _state = ReadAloudState.stopped;
      onComplete?.call();
    }
  }

  void prevParagraph() {
    if (_nowSpeak > 0) {
      _nowSpeak--;
      if (_state == ReadAloudState.playing) {
        _speakCurrent();
      }
    }
  }

  void nextParagraph() {
    if (_nowSpeak < _contentList.length - 1) {
      _nowSpeak++;
      if (_state == ReadAloudState.playing) {
        _speakCurrent();
      }
    } else {
      stop();
    }
  }

  Future<void> pause() async {
    if (_state == ReadAloudState.playing) {
      _state = ReadAloudState.paused;
      onStateChanged?.call('paused');
      if (_flutterTts != null) {
        await _stopTts();
      }
    }
  }

  Future<void> resume() async {
    if (_state == ReadAloudState.paused) {
      _state = ReadAloudState.playing;
      onStateChanged?.call('playing');
      await _speakCurrent();
    }
  }

  Future<void> stop() async {
    _state = ReadAloudState.stopped;
    _nowSpeak = 0;
    _contentList = [];
    if (_flutterTts != null) {
      await _stopTts();
    }
    onStateChanged?.call('stopped');
  }

  Future<void> _speak(String text) async {
    if (_flutterTts != null) {
      try {
        await _flutterTts.speak(text);
      } catch (e) {
        _nextParagraph();
      }
    }
  }

  List<String> _splitContent(String content) {
    // 按句子分割，保留标点符号
    final sentences = <String>[];
    final regex = RegExp(r'[^。！？.!?]+[。！？.!?]*');
    final matches = regex.allMatches(content);

    for (final match in matches) {
      final sentence = match.group(0)?.trim();
      if (sentence != null && sentence.isNotEmpty) {
        sentences.add(sentence);
      }
    }

    if (sentences.isEmpty) {
      // 如果没有匹配到句子，按段落分割
      return content
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return sentences;
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 2.0);
    if (_flutterTts != null) {
      await _flutterTts.setSpeechRate(_speechRate);
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_flutterTts != null) {
      await _flutterTts.setVolume(_volume);
    }
  }
}
