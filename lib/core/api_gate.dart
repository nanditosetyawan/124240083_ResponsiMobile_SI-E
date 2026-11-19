import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP method yang didukung oleh [ApiGate].
enum HttpMethod { get, post, put, delete }

/// Exception terstruktur untuk error jaringan, HTTP non-2xx, atau JSON invalid.
class ApiGateException implements Exception {
  final String message;
  final int? statusCode;
  final String url;
  final HttpMethod method;
  final Object? cause;

  const ApiGateException({
    required this.message,
    required this.url,
    required this.method,
    this.statusCode,
    this.cause,
  });

  @override
  String toString() {
    final code = statusCode != null ? ' (HTTP $statusCode)' : '';
    return 'ApiGateException [${method.name.toUpperCase()} $url]$code: $message';
  }
}

/// Hasil standar dari [ApiGate.request].
/// [data] bisa berupa `Map<String, dynamic>` atau `List<dynamic>`.
class ApiGateResponse {
  final String url;
  final HttpMethod method;
  final int statusCode;
  final dynamic data;
  final Map<String, String> responseHeaders;

  const ApiGateResponse({
    required this.url,
    required this.method,
    required this.statusCode,
    required this.data,
    this.responseHeaders = const {},
  });

  bool get isObject => data is Map<String, dynamic>;
  bool get isList => data is List<dynamic>;
}

/// Hasil bedah struktur JSON dari [JsonInspector].
class JsonInspectionResult {
  final List<String> lines;
  final Map<String, int> listCounts;

  const JsonInspectionResult({
    required this.lines,
    required this.listCounts,
  });

  String format() => lines.join('\n');

  @override
  String toString() => format();
}

/// Membedah struktur JSON secara otomatis tanpa mengasumsikan nama key tertentu.
class JsonInspector {
  static JsonInspectionResult inspect(dynamic json) {
    final lines = <String>[];
    final listCounts = <String, int>{};

    if (json is Map) {
      _walkMap(json, '', lines, listCounts);
    } else if (json is List) {
      listCounts['<root>'] = json.length;
      lines.add('<root>: List (length: ${json.length})');
      if (json.isNotEmpty) {
        _walkValue(json.first, '[0]', lines, listCounts);
      }
    } else {
      lines.add('<root>: ${_typeName(json)}');
    }

    return JsonInspectionResult(lines: lines, listCounts: listCounts);
  }

  static void _walkMap(
    Map<dynamic, dynamic> map,
    String prefix,
    List<String> lines,
    Map<String, int> listCounts,
  ) {
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final path = prefix.isEmpty ? key : '$prefix.$key';
      _walkValue(entry.value, path, lines, listCounts);
    }
  }

  static void _walkValue(
    dynamic value,
    String path,
    List<String> lines,
    Map<String, int> listCounts,
  ) {
    if (value is Map) {
      lines.add('$path: Object');
      _walkMap(value, path, lines, listCounts);
    } else if (value is List) {
      listCounts[path] = value.length;
      lines.add('$path: List (length: ${value.length})');
      if (value.isNotEmpty) {
        final first = value.first;
        if (first is Map) {
          _walkMap(first, '$path[0]', lines, listCounts);
        } else {
          _walkValue(first, '$path[0]', lines, listCounts);
        }
      }
    } else {
      lines.add('$path: ${_typeName(value)}');
    }
  }

  static String _typeName(dynamic value) {
    if (value == null) return 'null';
    if (value is int) return 'int';
    if (value is double) return 'double';
    if (value is bool) return 'bool';
    if (value is String) return 'String';
    return value.runtimeType.toString();
  }
}

/// Gerbang HTTP universal tanpa ketergantungan pada Model mana pun.
class ApiGate {
  static const Set<String> _sensitiveKeys = {
    'authorization',
    'token',
    'access_token',
    'refresh_token',
    'password',
    'secret',
    'api_key',
    'apikey',
    'x-api-key',
    'cookie',
  };

  /// Kirim HTTP request (GET/POST/PUT/DELETE) dan kembalikan JSON ter-decode.
  static Future<ApiGateResponse> request({
    required String url,
    HttpMethod method = HttpMethod.get,
    Map<String, String>? headers,
    String? token,
    Map<String, dynamic>? queryParameters,
    Object? body,
    Duration timeout = const Duration(seconds: 15),
    bool enableDebugLog = false,
    void Function(String)? logger,
    http.Client? client,
  }) async {
    final uri = _buildUri(url, queryParameters);
    final mergedHeaders = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };

    if (token != null && token.isNotEmpty) {
      mergedHeaders.putIfAbsent('Authorization', () => 'Bearer $token');
    }

    String? encodedBody;
    if (body != null) {
      mergedHeaders.putIfAbsent('Content-Type', () => 'application/json');
      encodedBody = body is String ? body : jsonEncode(body);
    }

    final httpClient = client ?? http.Client();
    final shouldClose = client == null;

    try {
      final response = await _send(
        httpClient,
        method,
        uri,
        mergedHeaders,
        encodedBody,
      ).timeout(timeout);

      dynamic decoded;
      if (response.body.trim().isEmpty) {
        decoded = <String, dynamic>{};
      } else {
        try {
          decoded = jsonDecode(response.body);
        } on FormatException catch (e) {
          throw ApiGateException(
            message: 'Response bukan JSON yang valid: ${e.message}',
            statusCode: response.statusCode,
            url: uri.toString(),
            method: method,
            cause: e,
          );
        }
      }

      if (enableDebugLog) {
        _logResponse(
          logger ?? debugPrint,
          method: method,
          uri: uri,
          statusCode: response.statusCode,
          headers: mergedHeaders,
          decodedBody: decoded,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiGateException(
          message: 'HTTP error ${response.statusCode}',
          statusCode: response.statusCode,
          url: uri.toString(),
          method: method,
        );
      }

      if (decoded is! Map<String, dynamic> && decoded is! List<dynamic>) {
        throw ApiGateException(
          message: 'Root JSON harus Object atau Array, diterima: ${decoded.runtimeType}',
          statusCode: response.statusCode,
          url: uri.toString(),
          method: method,
        );
      }

      return ApiGateResponse(
        url: uri.toString(),
        method: method,
        statusCode: response.statusCode,
        data: decoded,
        responseHeaders: response.headers,
      );
    } on ApiGateException {
      rethrow;
    } on TimeoutException catch (e) {
      throw ApiGateException(
        message: 'Request timeout setelah ${timeout.inSeconds} detik',
        url: uri.toString(),
        method: method,
        cause: e,
      );
    } catch (e) {
      throw ApiGateException(
        message: 'Gagal menghubungi server: $e',
        url: uri.toString(),
        method: method,
        cause: e,
      );
    } finally {
      if (shouldClose) httpClient.close();
    }
  }

  /// Bedah struktur JSON secara langsung (object maupun list).
  static JsonInspectionResult inspectJson(dynamic json) {
    return JsonInspector.inspect(json);
  }

  /// Helper praktis: panggil URL API baru lalu langsung bedah struktur JSON-nya.
  static Future<JsonInspectionResult> inspectUrl({
    required String url,
    HttpMethod method = HttpMethod.get,
    Map<String, String>? headers,
    String? token,
    Map<String, dynamic>? queryParameters,
    Object? body,
    bool printResult = true,
    void Function(String)? logger,
    http.Client? client,
  }) async {
    final res = await request(
      url: url,
      method: method,
      headers: headers,
      token: token,
      queryParameters: queryParameters,
      body: body,
      client: client,
    );
    final result = inspectJson(res.data);
    if (printResult) {
      (logger ?? debugPrint)('[ApiGate Inspector] ${method.name.toUpperCase()} ${res.url}\n${result.format()}');
    }
    return result;
  }

  /// Redaksi data sensitif sebelum dicetak ke log.
  static dynamic redactSensitive(dynamic value) {
    if (value is Map) {
      return value.map((k, v) {
        final keyLower = k.toString().toLowerCase();
        final isSensitive = _sensitiveKeys.any((s) => keyLower.contains(s));
        return MapEntry(k.toString(), isSensitive ? '***REDACTED***' : redactSensitive(v));
      });
    }
    if (value is List) {
      return value.map(redactSensitive).toList();
    }
    return value;
  }

  static Uri _buildUri(String url, Map<String, dynamic>? queryParameters) {
    final base = Uri.parse(url.trim());
    if (queryParameters == null || queryParameters.isEmpty) return base;

    final merged = <String, String>{
      ...base.queryParameters,
      for (final e in queryParameters.entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    return base.replace(queryParameters: merged);
  }

  static Future<http.Response> _send(
    http.Client client,
    HttpMethod method,
    Uri uri,
    Map<String, String> headers,
    String? encodedBody,
  ) {
    switch (method) {
      case HttpMethod.get:
        return client.get(uri, headers: headers);
      case HttpMethod.post:
        return client.post(uri, headers: headers, body: encodedBody);
      case HttpMethod.put:
        return client.put(uri, headers: headers, body: encodedBody);
      case HttpMethod.delete:
        return client.delete(uri, headers: headers, body: encodedBody);
    }
  }

  static void _logResponse(
    void Function(String) log, {
    required HttpMethod method,
    required Uri uri,
    required int statusCode,
    required Map<String, String> headers,
    required dynamic decodedBody,
  }) {
    final safeHeaders = redactSensitive(headers);
    final safeBody = redactSensitive(decodedBody);
    final encoded = jsonEncode(safeBody);
    // shortcut: potong preview body di 600 karakter agar log tidak membanjiri console; ubah angka jika butuh dump penuh.
    final preview = encoded.length > 600 ? '${encoded.substring(0, 600)}...(truncated)' : encoded;
    log(
      '[ApiGate] ${method.name.toUpperCase()} $uri | status=$statusCode | '
      'headers=$safeHeaders | json=$preview',
    );
  }
}

