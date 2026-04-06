import 'dart:convert';

/// 加密解密工具类
class CryptoUtil {
  static const String _defaultKey = "kuaibu_secret_key";

  /// 使用XOR算法加密文本 - 完全匹配Python实现
  static String xorEncrypt(String text, {String key = _defaultKey}) {
    // 在字符级别进行XOR运算，与Python版一致
    final result = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final keyChar = key[i % key.length];
      final encryptedChar = String.fromCharCode(char.codeUnitAt(0) ^ keyChar.codeUnitAt(0));
      result.write(encryptedChar);
    }
    // 对结果进行base64编码
    return base64.encode(utf8.encode(result.toString()));
  }

  /// 使用XOR算法解密文本 - 完全匹配Python实现
  static String xorDecrypt(String encryptedText, {String key = _defaultKey}) {
    try {
      // 先base64解码
      final decodedBytes = base64.decode(encryptedText);
      final decodedText = utf8.decode(decodedBytes);
      
      // 在字符级别进行XOR运算，与Python版一致
      final result = StringBuffer();
      for (int i = 0; i < decodedText.length; i++) {
        final char = decodedText[i];
        final keyChar = key[i % key.length];
        final decryptedChar = String.fromCharCode(char.codeUnitAt(0) ^ keyChar.codeUnitAt(0));
        result.write(decryptedChar);
      }
      
      return result.toString();
    } catch (e) {
      return encryptedText;
    }
  }

  /// 加密文件特征码（"网站名称=" 加密后的base64前12个字符）
  static const String _encryptedSignature = '57y656qs5ZGs56aZ';

  /// 判断文本是否已经加密
  static bool isEncrypted(String text) {
    // 快速检测：检查是否以加密特征码开头
    if (text.startsWith(_encryptedSignature)) {
      return true;
    }

    // 检查文本是否包含书源格式的关键字，如果包含，说明是明文
    if (text.contains('网站名称=') || text.contains('网站网址=')) {
      return false;
    }

    try {
      // 尝试base64解码
      final decoded = base64.decode(text);

      // 尝试解密
      final keyBytes = utf8.encode(_defaultKey);
      final result = <int>[];

      for (int i = 0; i < decoded.length; i++) {
        final keyByte = keyBytes[i % keyBytes.length];
        result.add(decoded[i] ^ keyByte);
      }

      // 尝试将解密后的内容解码为UTF-8
      final decryptedText = utf8.decode(result, allowMalformed: true);

      // 如果解密后的内容包含书源格式关键字，说明是加密的
      if (decryptedText.contains('网站名称=') || decryptedText.contains('网站网址=')) {
        return true;
      }

      return false;
    } catch (e) {
      // 如果base64解码失败，不是加密文本
      return false;
    }
  }

  /// 判断文本是否已经加密（带调试信息）
  static Map<String, dynamic> isEncryptedDebug(String text) {
    final result = <String, dynamic>{};
    result['contains_plaintext_keywords'] = text.contains('网站名称=') || text.contains('网站网址=');

    if (result['contains_plaintext_keywords'] == true) {
      result['is_encrypted'] = false;
      return result;
    }

    try {
      // 尝试base64解码
      final decoded = base64.decode(text);
      result['base64_decoded_length'] = decoded.length;

      // 尝试解密
      final keyBytes = utf8.encode(_defaultKey);
      final decrypted = <int>[];

      for (int i = 0; i < decoded.length; i++) {
        final keyByte = keyBytes[i % keyBytes.length];
        decrypted.add(decoded[i] ^ keyByte);
      }

      // 尝试将解密后的内容解码为UTF-8
      final decryptedText = utf8.decode(decrypted, allowMalformed: true);
      result['decrypted_text_preview'] = decryptedText.substring(0, decryptedText.length > 100 ? 100 : decryptedText.length);
      result['contains_decrypted_keywords'] = decryptedText.contains('网站名称=') || decryptedText.contains('网站网址=');

      result['is_encrypted'] = result['contains_decrypted_keywords'] == true;
      return result;
    } catch (e) {
      result['error'] = e.toString();
      result['is_encrypted'] = false;
      return result;
    }
  }

  /// 智能解密（如果是加密文本则解密，否则返回原文）
  static String smartDecrypt(String text) {
    if (isEncrypted(text)) {
      return xorDecrypt(text);
    }
    return text;
  }

  /// 智能加密（如果文本包含书源格式则加密）
  static String smartEncrypt(String text) {
    if (text.contains('网站名称=') || text.contains('网站网址=')) {
      return xorEncrypt(text);
    }
    return text;
  }
}
