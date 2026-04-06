import 'package:flutter/material.dart';
import 'read_aloud_service.dart';

class ReadAloud {
  static final ReadAloud _instance = ReadAloud._internal();
  factory ReadAloud() => _instance;
  ReadAloud._internal();

  final TTSReadAloudService _ttsService = TTSReadAloudService();
  bool _isRunning = false;
  String? _bookTitle;
  int _pageIndex = 0;
  int _startPos = 0;

  TTSReadAloudService get tts => _ttsService;
  bool get isRun => _isRunning;

  Future<void> play({
    required String content,
    String? bookTitle,
    int pageIndex = 0,
    int startPos = 0,
  }) async {
    _bookTitle = bookTitle;
    _pageIndex = pageIndex;
    _startPos = startPos;
    _isRunning = true;


    // 保存外部设置的回调
    final externalOnComplete = _ttsService.onComplete;
    final externalOnStateChanged = _ttsService.onStateChanged;
    final externalOnProgress = _ttsService.onProgress;
    final externalOnSentenceStart = _ttsService.onSentenceStart;

    _ttsService.onComplete = () {
      _isRunning = false;
      externalOnComplete?.call();
    };

    _ttsService.onStateChanged = (state) {
      externalOnStateChanged?.call(state);
    };

    _ttsService.onProgress = (current, total) {
      externalOnProgress?.call(current, total);
    };

    _ttsService.onSentenceStart = (index, text) {
      externalOnSentenceStart?.call(index, text);
    };

    final paragraphs = _splitIntoParagraphs(content, startPos);
    if (paragraphs.isNotEmpty) {
    }
    
    await _ttsService.playList(paragraphs);
  }

  Future<void> playList(
    List<String> sentences, {
    String? bookTitle,
    int pageIndex = 0,
  }) async {
    _bookTitle = bookTitle;
    _pageIndex = pageIndex;
    _startPos = 0;
    _isRunning = true;

    if (sentences.isNotEmpty) {
    }

    final externalOnComplete = _ttsService.onComplete;
    final externalOnStateChanged = _ttsService.onStateChanged;
    final externalOnProgress = _ttsService.onProgress;
    final externalOnSentenceStart = _ttsService.onSentenceStart;

    _ttsService.onComplete = () {
      _isRunning = false;
      externalOnComplete?.call();
    };

    _ttsService.onStateChanged = (state) {
      externalOnStateChanged?.call(state);
    };

    _ttsService.onProgress = (current, total) {
      externalOnProgress?.call(current, total);
    };

    _ttsService.onSentenceStart = (index, text) {
      externalOnSentenceStart?.call(index, text);
    };

    await _ttsService.playList(sentences);
  }

  void pause() {
    if (_isRunning) {
      _ttsService.pause();
    }
  }

  void resume() {
    if (_isRunning) {
      _ttsService.resume();
    }
  }

  void stop() {
    _ttsService.stop();
    _isRunning = false;
    _bookTitle = null;
  }

  void prevParagraph() {
    _ttsService.prevParagraph();
  }

  void nextParagraph() {
    _ttsService.nextParagraph();
  }

  List<String> _splitIntoParagraphs(String content, int startPos) {
    final processedText = content.replaceAll('\n', '');

    final sentenceParts = processedText.split(RegExp(r'([。！？])'));

    final sentences = <String>[];
    for (int i = 0; i < sentenceParts.length; i += 2) {
      if (i + 1 < sentenceParts.length) {
        final sentence = '${sentenceParts[i].trim()}${sentenceParts[i + 1].trim()}';
        if (sentence.isNotEmpty) {
          sentences.add(sentence);
        }
      } else {
        final lastSentence = sentenceParts[i].trim();
        if (lastSentence.isNotEmpty) {
          sentences.add(lastSentence);
        }
      }
    }

    if (startPos > 0 && startPos < sentences.length) {
      return sentences.sublist(startPos);
    }
    return sentences;
  }

  String processContentForReadAloud(String content) {
    content = content.replaceAll(RegExp(r'\s+'), ' ');

    content = content.replaceAllMapped(
      RegExp(r'「([^」]+)」'),
      (m) => ' ${m.group(1)} ',
    );

    content = content.replaceAllMapped(
      RegExp(r'"([^"]+)"'),
      (m) => ' ${m.group(1)} ',
    );

    content = content.replaceAllMapped(
      RegExp(r"'([^']+)'"),
      (m) => ' ${m.group(1)} ',
    );

    return content;
  }

  String? detectSpeaker(String text) {
    final dialoguePattern = RegExp(r'^"?([^""'':\s]+)[:：""]');
    final match = dialoguePattern.firstMatch(text.trim());
    if (match != null) {
      return match.group(1);
    }
    return null;
  }

  bool isDialogue(String text) {
    return detectSpeaker(text) != null;
  }
}

class ReadAloudConfig extends ChangeNotifier {
  static final ReadAloudConfig _instance = ReadAloudConfig._internal();
  factory ReadAloudConfig() => _instance;
  ReadAloudConfig._internal();

  double _speechRate = 1.0;
  String _language = 'zh-CN';

  double get speechRate => _speechRate;
  String get language => _language;

  void setSpeechRate(double rate) {
    _speechRate = rate.clamp(0.5, 2.0);
    notifyListeners();
  }

  void setLanguage(String lang) {
    _language = lang;
    notifyListeners();
  }
}
