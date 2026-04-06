import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:fast_gbk/fast_gbk.dart';
import '../utils/url_utils.dart';

/// 网络请求服务 - 统一网络请求处理
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Map<String, String> _defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 Edg/120.0.0.0',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Cache-Control': 'max-age=0',
  };

  /// 创建忽略证书验证的HTTP客户端
  http.Client _createUnsafeClient() {
    final context = SecurityContext(withTrustedRoots: false);
    final httpClient = HttpClient(context: context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(httpClient);
  }

  /// 发送GET请求
  Future<String> get(String url, {
    Map<String, String>? headers,
    String? encoding,
    int timeout = 30,
    String? referer,
  }) async {
    try {
      final requestHeaders = {..._defaultHeaders, ...?headers};

      if (referer != null && referer.isNotEmpty) {
        requestHeaders['Referer'] = referer;
      }

      final client = _createUnsafeClient();
      try {
        final request = http.Request('GET', Uri.parse(url));
        request.headers.addAll(requestHeaders);

        final streamedResponse = await client.send(request)
            .timeout(Duration(seconds: timeout));

        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          return _decodeResponse(response, encoding);
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  /// 发送HEAD请求检查URL是否可访问
  Future<bool> head(String url, {
    Map<String, String>? headers,
    int timeout = 20,
  }) async {
    try {
      final requestHeaders = {..._defaultHeaders, ...?headers};

      final client = _createUnsafeClient();
      try {
        final request = http.Request('HEAD', Uri.parse(url));
        request.headers.addAll(requestHeaders);

        final streamedResponse = await client.send(request)
            .timeout(Duration(seconds: timeout));

        return streamedResponse.statusCode == 200;
      } finally {
        client.close();
      }
    } catch (e) {
      return false;
    }
  }

  /// 发送POST请求
  Future<String> post(String url, {
    Map<String, String>? headers,
    Map<String, String>? body,
    String? encoding,
    int timeout = 30,
  }) async {
    try {
      final requestHeaders = {..._defaultHeaders, ...?headers};
      
      // 对于GBK编码的网站，需要对body进行GBK编码
      String? encodedBody;
      if (body != null && encoding != null) {
        final enc = encoding.toLowerCase();
        if (enc != 'utf-8' && enc != 'utf8') {
          // GBK编码：将body转换为application/x-www-form-urlencoded格式，并用GBK编码
          final parts = <String>[];
          body.forEach((key, value) {
            // 对value进行GBK编码后再URL编码
            final gbkBytes = gbk.encode(value);
            final encodedValue = gbkBytes.map((b) => '%${b.toRadixString(16).padLeft(2, '0')}').join();
            parts.add('$key=$encodedValue');
          });
          encodedBody = parts.join('&');
          requestHeaders['Content-Type'] = 'application/x-www-form-urlencoded';
        }
      }

      final client = _createUnsafeClient();
      try {
        final response = await client.post(
          Uri.parse(url),
          headers: requestHeaders,
          body: encodedBody ?? body,
        ).timeout(Duration(seconds: timeout));

        if (response.statusCode == 200) {
          return _decodeResponse(response, encoding);
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      throw Exception('请求失败: $e');
    }
  }

  /// 解码响应内容
  String _decodeResponse(http.Response response, String? encoding) {
    if (encoding != null) {
      final enc = encoding.toLowerCase();
      if (enc == 'utf-8' || enc == 'utf8') {
        return utf8.decode(response.bodyBytes, allowMalformed: true);
      } else {
        return gbkDecode(response.bodyBytes);
      }
    }

    final contentType = response.headers['content-type'];
    if (contentType != null) {
      final charsetMatch = RegExp('charset=([\\w-]+)', caseSensitive: false)
          .firstMatch(contentType);
      if (charsetMatch != null) {
        final charset = charsetMatch.group(1)?.toLowerCase();
        if (charset == 'utf-8' || charset == 'utf8') {
          return utf8.decode(response.bodyBytes, allowMalformed: true);
        } else {
          return gbkDecode(response.bodyBytes);
        }
      }
    }

    final htmlContent = utf8.decode(response.bodyBytes, allowMalformed: true);
    final metaCharsetMatch = RegExp(
      '<meta[^>]*charset=(["\'"]?)([\\w-]+)\\1',
      caseSensitive: false,
    ).firstMatch(htmlContent);

    if (metaCharsetMatch != null) {
      final charset = metaCharsetMatch.group(2)?.toLowerCase();
      if (charset == 'utf-8' || charset == 'utf8') {
        return utf8.decode(response.bodyBytes, allowMalformed: true);
      } else {
        return gbkDecode(response.bodyBytes);
      }
    }

    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// GBK解码
  String gbkDecode(List<int> bytes) {
    try {
      return gbk.decode(bytes);
    } catch (e) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// 获取二进制数据
  Future<List<int>?> getBytes(String url, {
    Map<String, String>? headers,
    int timeout = 30,
    String? referer,
  }) async {
    try {
      final requestHeaders = {..._defaultHeaders, ...?headers};

      if (referer != null && referer.isNotEmpty) {
        requestHeaders['Referer'] = referer;
      }

      final client = _createUnsafeClient();
      try {
        final request = http.Request('GET', Uri.parse(url));
        request.headers.addAll(requestHeaders);

        final streamedResponse = await client.send(request)
            .timeout(Duration(seconds: timeout));

        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e) {
      return null;
    }
  }

  /// 将相对URL转换为绝对URL - 委托给 UrlUtils
  String convertToAbsoluteUrl(String link, String baseUrl) {
    return UrlUtils.convertToAbsoluteUrl(link, baseUrl);
  }

  /// 验证URL是否匹配模式 - 委托给 UrlUtils
  bool validateUrl(String url, String pattern) {
    return UrlUtils.validateUrl(url, pattern);
  }

  /// 将书源配置中的URL模式转换为正则表达式 - 委托给 UrlUtils
  String convertPatternToRegex(String pattern) {
    return UrlUtils.convertPatternToRegex(pattern);
  }

  /// 从URL中提取参数 - 委托给 UrlUtils
  Map<String, String> extractUrlParams(String url, String pattern) {
    return UrlUtils.extractUrlParams(url, pattern);
  }

  /// 替换URL模板中的变量 - 委托给 UrlUtils
  String replaceUrlTemplate(String template, Map<String, String> params) {
    return UrlUtils.replaceUrlTemplate(template, params);
  }
}
