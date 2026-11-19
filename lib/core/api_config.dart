import 'package:flutter/foundation.dart';
import 'api_adapter.dart';
import 'api_gate.dart';

/// Definisi konfigurasi satu endpoint API (opsional — hanya jika butuh method POST/header/mapping khusus).
class EndpointConfig {
  final String path;
  final HttpMethod method;
  final Map<String, String> headers;
  final Map<String, dynamic> queryParameters;
  final Object? body;

  /// Lokasi List di JSON (`''` = deteksi otomatis, termasuk root Array & list dalam list).
  final String listPath;

  /// Lokasi Object detail di JSON (`''` = deteksi otomatis).
  final String detailPath;

  /// Mapping manual (`{}` = deteksi otomatis semua field tanpa perlu remap).
  final Map<String, FieldMapping> fieldMapping;

  const EndpointConfig({
    required this.path,
    this.method = HttpMethod.get,
    this.headers = const {},
    this.queryParameters = const {},
    this.body,
    this.listPath = '',
    this.detailPath = '',
    this.fieldMapping = const {},
  });
}

/// Konfigurasi terpusat seluruh API aplikasi.
///
/// MODE OTOMATIS (ZERO-REMAP):
/// Saat dapat 3 API baru, cukup paste 3 URL di [urls] di bawah ini.
/// Sistem otomatis mendeteksi lokasi List, list dalam list, gambar dalam list,
/// nested object, dan mengonversi tipe data tanpa perlu edit file lain.
class ApiConfig {
  // ╔══════════════════════════════════════════════════════════════════════╗
  // ║  1. URL DAFTAR / LIST (yang tampil di ListPage)                      ║
  // ║     Kalau besok dapat 2 atau 3 API, cukup buka komentar (//) di bawah║
  // ╚══════════════════════════════════════════════════════════════════════╝
  static const Map<String, String> urls = {
    'news': 'https://dummyjson.com/recipes',
    // 'blogs':   'https://url-list-api-2.com/...',
    // 'reports': 'https://url-list-api-3.com/...',
  };

  // ╔══════════════════════════════════════════════════════════════════════╗
  // ║  2. URL DETAIL PER ITEM (mendukung {id}, {game_id}, {{id}}, :id,     ║
  // ║     <id>, [id], $id, ${id}, atau ?id= kosong)                        ║
  // ║     Otomatis dipanggil di DetailPage saat item diklik!               ║
  // ║     Kalau API tidak punya endpoint detail terpisah, biarkan dikomen  ║
  // ╚══════════════════════════════════════════════════════════════════════╝
  static const Map<String, String> detailUrls = {
    'news': 'https://dummyjson.com/recipes/{id}',
    // 'blogs':   'https://url-detail-api-2.com/{id}',
    // 'reports': 'https://url-detail-api-3.com/{id}',
  };

  // ── OPSIONAL (Biarkan default jika tidak dibutuhkan) ────────────────────

  /// Isi token jika API butuh `Authorization: Bearer <token>`.
  static const String? authToken = null;

  /// Header global tambahan jika diperlukan API baru.
  static const Map<String, String> defaultHeaders = {
    'Accept': 'application/json',
  };

  /// Override lokasi List hanya jika auto-detect salah memilih list.
  static const Map<String, String> customListPaths = {};

  /// Override mapping hanya untuk 1-2 field tertentu jika hasil otomatis kurang pas
  /// (misalnya ingin mengganti patokan FilterChip di ListPage).
  /// Field lain yang tidak ditulis di sini TETAP dideteksi otomatis!
  ///
  /// Cara pakai: buka komentar (//) lalu ganti key JSON di dalam FieldMapping('...'):
  /// - `'news'` / `'blogs'` / `'reports'` → nama menu di `urls`
  /// - `'newsSite'`                       → patokan FilterChip & teks abu-abu di bawah judul (JANGAN ganti tulisan 'newsSite')
  /// - `'genre'` / `'network.name'` / `'genres[0]'` → nama key JSON dari API (cek daftarnya di Debug Console)
  static const Map<String, Map<String, FieldMapping>> customFieldMappings = {
    // 'news': {'newsSite': FieldMapping('genre', type: FieldType.string)},
    // 'blogs': {'newsSite': FieldMapping('strCategory', type: FieldType.string)},
    // 'reports': {'newsSite': FieldMapping('network.name', type: FieldType.string)},
  };

  /// Override penuh per endpoint jika butuh HTTP POST / body / header khusus per API.
  static const Map<String, EndpointConfig> customEndpoints = {};

  // ── PENGATURAN SISTEM (Tidak perlu diubah) ──────────────────────────────
  static const String baseUrl = 'https://api.spaceflightnewsapi.net/v4';
  static const Duration timeout = Duration(seconds: 15);
  static const bool enableDebugLog = kDebugMode;
  static const BoolRule boolRule = BoolRule();
  static const DateRule dateRule = DateRule(format: DateInputFormat.iso8601, toIsoString: true);

  /// Ambil konfigurasi endpoint list berdasarkan [type].
  static EndpointConfig getListEndpoint(String type) {
    final custom = customEndpoints[type];
    if (custom != null) return custom;

    return EndpointConfig(
      path: urls[type] ?? '/$type/',
      listPath: customListPaths[type] ?? '',
      fieldMapping: customFieldMappings[type] ?? const {},
    );
  }

  static final RegExp _detailPlaceholderRegex = RegExp(
    r'\{\{[^}]+\}\}|\$\{[^}]+\}|\{[^}]+\}|<[^>]+>|\[[^\]]+\]|(?<=[/=]):[a-zA-Z_][a-zA-Z0-9_]*|\$[a-zA-Z_][a-zA-Z0-9_]*',
  );

  /// Ganti berbagai gaya placeholder ID (`{game_id}`, `{{id}}`, `:id`, `<id>`, `[id]`, `$id`, `?id=`).
  static String resolveDetailUrl(String templateUrl, int id) {
    final trimmed = templateUrl.trim();
    final idStr = id.toString();
    if (_detailPlaceholderRegex.hasMatch(trimmed)) {
      return trimmed.replaceAll(_detailPlaceholderRegex, idStr);
    }
    if (trimmed.endsWith('=')) {
      return '$trimmed$idStr';
    }
    final withoutQuery = trimmed.split('?').first;
    return withoutQuery.endsWith('/') ? '$withoutQuery$idStr/' : '$withoutQuery/$idStr';
  }

  /// Ambil konfigurasi endpoint detail berdasarkan [type] dan [id].
  static EndpointConfig getDetailEndpoint(String type, int id) {
    final templateUrl = detailUrls[type];
    final String resolvedUrl;

    if (templateUrl != null && templateUrl.isNotEmpty) {
      resolvedUrl = resolveDetailUrl(templateUrl, id);
    } else {
      final listUrl = urls[type] ?? buildUrl('/$type/');
      resolvedUrl = resolveDetailUrl(listUrl, id);
    }

    return EndpointConfig(
      path: resolvedUrl,
      fieldMapping: customFieldMappings[type] ?? const {},
    );
  }

  /// Gabungkan [baseUrl] dan [path] jika [path] masih relatif.
  static String buildUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$cleanBase$cleanPath';
  }
}
