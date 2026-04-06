// Windows 和其他平台的实现 - 使用 PowerShell SAPI
import 'dart:io';

// Android 平台使用真实的 flutter_tts
import 'package:flutter_tts/flutter_tts.dart' as real_tts;

class FakeFlutterTts {
  Function()? _completionHandler;
  Function(dynamic)? _errorHandler;
  double _speechRate = 1.0;
  double _volume = 1.0;
  Process? _currentProcess;
  real_tts.FlutterTts? _realTts;
  bool _isStopped = false; // 标记是否被停止

  FakeFlutterTts() {
    // Android 平台使用真实的 FlutterTts
    if (Platform.isAndroid) {
      _realTts = real_tts.FlutterTts();
    }
  }

  Future<dynamic> setEngine(String engine) async {
    if (_realTts != null) {
      return await _realTts!.setEngine(engine);
    }
    return null;
  }

  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async {
    if (_realTts != null) {
      return await _realTts!.awaitSpeakCompletion(awaitCompletion);
    }
    return null;
  }

  Future<dynamic> get getLanguages async {
    if (_realTts != null) {
      return await _realTts!.getLanguages;
    }
    return ['zh-CN', 'en-US'];
  }

  Future<dynamic> get getVoices async {
    if (_realTts != null) {
      return await _realTts!.getVoices;
    }
    return [];
  }

  Future<dynamic> setLanguage(String language) async {
    if (_realTts != null) {
      return await _realTts!.setLanguage(language);
    }
    return 1;
  }

  void setCompletionHandler(Function() handler) {
    _completionHandler = handler;
    if (_realTts != null) {
      _realTts!.setCompletionHandler(handler);
    }
  }

  void setErrorHandler(Function(dynamic) handler) {
    _errorHandler = handler;
    if (_realTts != null) {
      _realTts!.setErrorHandler(handler);
    }
  }

  Future<dynamic> speak(String text) async {
    // Android 平台使用真实 TTS
    if (_realTts != null) {
      return await _realTts!.speak(text);
    }

    // Windows 平台使用 PowerShell SAPI
    if (!Platform.isWindows) {
      // 非 Windows 非 Android 平台直接返回
      _completionHandler?.call();
      return 1;
    }

    try {
      // 停止之前的朗读
      await stop();

      // 重置停止标志
      _isStopped = false;

      // 转义文本中的单引号（PowerShell单引号字符串中，单引号需要用两个单引号转义）
      final escapedText = text.replaceAll("'", "''");

      // 使用 PowerShell SAPI 语音合成 - 隐藏窗口
      // 使用单引号包裹文本，避免中文引号等特殊字符的问题
      final psScript = "Add-Type -AssemblyName System.Speech; \$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer; \$synth.Speak('$escapedText')";


      // 使用 runInShell: true 并设置工作目录，避免窗口闪烁
      _currentProcess = await Process.start(
        'powershell.exe',
        ['-WindowStyle', 'Hidden', '-Command', psScript],
        runInShell: false,
      );

      // 等待朗读完成
      _currentProcess!.exitCode.then((code) {
        _currentProcess = null;
        // 只有未被停止时才触发完成回调
        if (!_isStopped && _completionHandler != null) {
          _completionHandler!();
        }
      });

      return 1;
    } catch (e) {
      if (_errorHandler != null) {
        _errorHandler!(e.toString());
      }
      return 0;
    }
  }

  Future<dynamic> stop() async {
    if (_realTts != null) {
      return await _realTts!.stop();
    }

    try {
      _isStopped = true; // 标记为已停止
      if (_currentProcess != null) {
        _currentProcess!.kill();
        _currentProcess = null;
      }
    } catch (e) {
    }
    return 1;
  }

  Future<dynamic> setSpeechRate(double rate) async {
    _speechRate = rate;
    if (_realTts != null) {
      return await _realTts!.setSpeechRate(rate);
    }
    return 1;
  }

  Future<dynamic> setVolume(double volume) async {
    _volume = volume;
    if (_realTts != null) {
      return await _realTts!.setVolume(volume);
    }
    return 1;
  }
}

dynamic createTts() {
  return FakeFlutterTts();
}
