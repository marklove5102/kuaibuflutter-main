import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fast_gbk/fast_gbk.dart';

/// HTTP 服务
/// 用于抓取网页内容
class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  final Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
  };

  /// 获取网页内容
  Future<HttpResponse> get(String url, {Map<String, String>? headers, String? charset}) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {..._defaultHeaders, ...?headers},
      ).timeout(Duration(seconds: 30));

      return _processResponse(response, charset);
    } catch (e) {
      return HttpResponse(success: false, error: e.toString());
    }
  }

  /// POST 请求
  Future<HttpResponse> post(String url, {Map<String, String>? headers, Map<String, String>? body, String? charset, String? encoding}) async {
    try {
      Object? requestBody;
      Map<String, String> requestHeaders = {..._defaultHeaders, ...?headers};
      
      if (body != null) {
        if (encoding != null && (encoding.toLowerCase().contains('gbk') || encoding.toLowerCase().contains('gb2312'))) {
          final encodedParams = <String>[];
          body.forEach((key, value) {
            final keyBytes = gbk.encode(key);
            final valueBytes = gbk.encode(value);
            final encodedKey = keyBytes.map((b) => '%${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join();
            final encodedValue = valueBytes.map((b) => '%${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join();
            encodedParams.add('$encodedKey=$encodedValue');
          });
          requestBody = encodedParams.join('&');
          requestHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
        } else {
          requestBody = body;
        }
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: requestHeaders,
        body: requestBody,
      ).timeout(Duration(seconds: 30));

      return _processResponse(response, charset);
    } catch (e) {
      return HttpResponse(success: false, error: e.toString());
    }
  }

  Future<HttpResponse> _processResponse(http.Response response, String? charset) async {
    if (response.statusCode != 200) {
      return HttpResponse(
        success: false,
        error: 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    String? detectedCharset = charset;
    if (detectedCharset == null || detectedCharset.isEmpty) {
      final contentType = response.headers['content-type'];
      if (contentType != null) {
        final charsetMatch = RegExp(r'charset=([^;]+)', caseSensitive: false).firstMatch(contentType);
        if (charsetMatch != null) {
          detectedCharset = charsetMatch.group(1)?.trim().toLowerCase();
        }
      }
    }

    if (detectedCharset == null || detectedCharset.isEmpty) {
      try {
        final tempHtml = utf8.decode(response.bodyBytes, allowMalformed: true);
        final charsetMatch = RegExp('<meta[^>]+charset=["\']?([^"\' >\s]+)', caseSensitive: false)
            .firstMatch(tempHtml);
        if (charsetMatch != null) {
          detectedCharset = charsetMatch.group(1)?.trim().toLowerCase();
        }
      } catch (e) {
      }
    }

    String html;
    if (detectedCharset != null && (detectedCharset.contains('gbk') || detectedCharset.contains('gb2312'))) {
      try {
        html = gbk.decode(response.bodyBytes);
        detectedCharset = 'gb2312';
      } catch (e) {
        html = utf8.decode(response.bodyBytes, allowMalformed: true);
        detectedCharset = 'utf-8';
      }
    } else if (detectedCharset != null && detectedCharset != 'utf-8') {
      html = utf8.decode(response.bodyBytes, allowMalformed: true);
      detectedCharset = 'utf-8';
    } else {
      html = utf8.decode(response.bodyBytes, allowMalformed: true);
      detectedCharset = 'utf-8';
    }

    return HttpResponse(
      success: true,
      html: html,
      charset: detectedCharset,
      finalUrl: response.request?.url.toString() ?? '',
      statusCode: response.statusCode,
    );
  }
}

/// HTTP 响应
class HttpResponse {
  final bool success;
  final String? html;
  final String? error;
  final String? charset;
  final String? finalUrl;
  final int? statusCode;

  HttpResponse({
    required this.success,
    this.html,
    this.error,
    this.charset,
    this.finalUrl,
    this.statusCode,
  });
}
