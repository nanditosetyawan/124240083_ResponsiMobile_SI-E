import 'package:flutter/foundation.dart';

/// Target tipe data yang dibutuhkan oleh Model aplikasi.
enum FieldType {
  string,
  integer,
  decimal,
  boolean,
  dateTime,
  list,
  map,
  dynamicType,
}

/// Aturan konversi boolean yang dapat dikonfigurasi (tidak menebak sembarangan).
class BoolRule {
  final Set<Object> trueValues;
  final Set<Object> falseValues;
  final bool caseInsensitive;

  const BoolRule({
    this.trueValues = const {true, 1, '1', 'true', 'yes', 'y'},
    this.falseValues = const {false, 0, '0', 'false', 'no', 'n'},
    this.caseInsensitive = true,
  });

  bool? parse(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;

    final Object normalized = (value is String && caseInsensitive)
        ? value.trim().toLowerCase()
        : value;

    if (trueValues.contains(normalized)) return true;
    if (falseValues.contains(normalized)) return false;
    return null;
  }
}

/// Format input tanggal yang eksplisit — angka tidak pernah dianggap timestamp
/// kecuali [epochSeconds] atau [epochMilliseconds] dipilih secara sadar.
enum DateInputFormat {
  iso8601,
  dmySlash,
  dmyDash,
  mdySlash,
  epochSeconds,
  epochMilliseconds,
  customPattern,
}

/// Aturan konversi tanggal yang dapat dikonfigurasi.
class DateRule {
  final DateInputFormat format;
  final String? pattern;
  final bool toIsoString;
  final bool isUtc;

  const DateRule({
    this.format = DateInputFormat.iso8601,
    this.pattern,
    this.toIsoString = true,
    this.isUtc = false,
  });

  DateTime? parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    switch (format) {
      case DateInputFormat.iso8601:
        if (value is! String) return null;
        return DateTime.tryParse(value.trim());

      case DateInputFormat.epochSeconds:
        final int? secs = value is int ? value : int.tryParse(value.toString().trim());
        if (secs == null) return null;
        return DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: isUtc);

      case DateInputFormat.epochMilliseconds:
        final int? ms = value is int ? value : int.tryParse(value.toString().trim());
        if (ms == null) return null;
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: isUtc);

      case DateInputFormat.dmySlash:
        return value is String ? _parseDelimited(value.trim(), '/', dayFirst: true) : null;

      case DateInputFormat.dmyDash:
        return value is String ? _parseDelimited(value.trim(), '-', dayFirst: true) : null;

      case DateInputFormat.mdySlash:
        return value is String ? _parseDelimited(value.trim(), '/', dayFirst: false) : null;

      case DateInputFormat.customPattern:
        if (value is! String || pattern == null || pattern!.isEmpty) return null;
        return _parsePattern(value.trim(), pattern!);
    }
  }

  DateTime? _parseDelimited(String input, String sep, {required bool dayFirst}) {
    final parts = input.split(RegExp(r'[ T]'));
    final dateParts = parts.first.split(sep);
    if (dateParts.length != 3) return null;

    final int? p0 = int.tryParse(dateParts[0]);
    final int? p1 = int.tryParse(dateParts[1]);
    final int? p2 = int.tryParse(dateParts[2]);
    if (p0 == null || p1 == null || p2 == null) return null;

    final int day = dayFirst ? p0 : p1;
    final int month = dayFirst ? p1 : p0;
    final int year = p2;

    int hour = 0, minute = 0, second = 0;
    if (parts.length > 1) {
      final t = parts[1].split(':');
      if (t.length >= 2) {
        hour = int.tryParse(t[0]) ?? 0;
        minute = int.tryParse(t[1]) ?? 0;
        second = t.length >= 3 ? (int.tryParse(t[2]) ?? 0) : 0;
      }
    }

    return _validatedDate(year, month, day, hour, minute, second);
  }

  // shortcut: mendukung token yyyy, MM, dd, HH, mm, ss dengan panjang tetap; tambah package intl jika butuh nama bulan/locale.
  DateTime? _parsePattern(String input, String fmt) {
    int? extract(String token) {
      final idx = fmt.indexOf(token);
      if (idx == -1 || idx + token.length > input.length) return null;
      return int.tryParse(input.substring(idx, idx + token.length));
    }

    final year = extract('yyyy');
    final month = extract('MM');
    final day = extract('dd');
    if (year == null || month == null || day == null) return null;

    final hour = extract('HH') ?? 0;
    final minute = extract('mm') ?? 0;
    final second = extract('ss') ?? 0;
    return _validatedDate(year, month, day, hour, minute, second);
  }

  DateTime? _validatedDate(int y, int m, int d, int h, int min, int s) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = isUtc ? DateTime.utc(y, m, d, h, min, s) : DateTime(y, m, d, h, min, s);
    if (dt.year != y || dt.month != m || dt.day != d) return null;
    return dt;
  }
}

/// Aturan mapping satu field: dari path JSON API baru → field standar Model lama.
class FieldMapping {
  final String source;
  final FieldType type;
  final dynamic defaultValue;
  final bool required;
  final BoolRule? boolRule;
  final DateRule? dateRule;

  const FieldMapping(
    this.source, {
    this.type = FieldType.string,
    this.defaultValue,
    this.required = false,
    this.boolRule,
    this.dateRule,
  });

  /// Helper untuk membuat aturan dari map sederhana `{"nama": "student_name"}`.
  static Map<String, FieldMapping> fromSimple(
    Map<String, String> mapping, {
    Map<String, FieldType> types = const {},
    Map<String, dynamic> defaults = const {},
    Set<String> requiredFields = const {},
  }) {
    return mapping.map(
      (targetKey, sourcePath) => MapEntry(
        targetKey,
        FieldMapping(
          sourcePath,
          type: types[targetKey] ?? FieldType.string,
          defaultValue: defaults[targetKey],
          required: requiredFields.contains(targetKey),
        ),
      ),
    );
  }
}

/// Exception saat mapping atau konversi field wajib gagal.
class ApiAdapterException implements Exception {
  final String field;
  final String sourcePath;
  final String message;

  const ApiAdapterException({
    required this.field,
    required this.sourcePath,
    required this.message,
  });

  @override
  String toString() =>
      'ApiAdapterException [field="$field", source="$sourcePath"]: $message';
}

/// Jejak debugging untuk satu field hasil adaptasi.
class FieldTrace {
  final String targetField;
  final String sourcePath;
  final bool found;
  final String originalType;
  final String convertedType;
  final bool usedDefault;
  final String? warning;

  const FieldTrace({
    required this.targetField,
    required this.sourcePath,
    required this.found,
    required this.originalType,
    required this.convertedType,
    required this.usedDefault,
    this.warning,
  });
}

/// Hasil adaptasi satu objek: [normalized] siap untuk Model lama, [raw] menyimpan seluruh JSON asli.
class AdaptedItem {
  final Map<String, dynamic> normalized;
  final Map<String, dynamic> raw;
  final List<FieldTrace> traces;

  const AdaptedItem({
    required this.normalized,
    required this.raw,
    required this.traces,
  });

  List<String> get foundFields =>
      traces.where((t) => t.found).map((t) => t.targetField).toList();

  List<String> get missingFields =>
      traces.where((t) => !t.found).map((t) => t.targetField).toList();
}

/// Hasil adaptasi list beserta ringkasan debugging.
class AdaptedListResult {
  final List<AdaptedItem> items;
  final int totalRawCount;
  final List<String> warnings;

  const AdaptedListResult({
    required this.items,
    required this.totalRawCount,
    required this.warnings,
  });

  int get processedCount => items.length;
  List<Map<String, dynamic>> get normalizedList =>
      items.map((e) => e.normalized).toList();
}

class _MissingSentinel {
  const _MissingSentinel();
}

const Object _missing = _MissingSentinel();

/// Penerjemah universal antara JSON API eksternal dan format standar Model lama.
class ApiAdapter {
  static final RegExp _segmentRegex = RegExp(r'^([^\[\]]+)(?:\[(\d+)\])?$');
  static final RegExp _bracketOnlyRegex = RegExp(r'^\[(\d+)\]$');

  /// Mengambil nilai dari JSON menggunakan dot notation dan index array,
  /// contoh: `"academic.major"`, `"result.items"`, `"authors[0].name"`.
  /// Mengembalikan `null` jika path tidak ditemukan.
  static dynamic extractPath(dynamic root, String path) {
    final result = _resolvePath(root, path);
    return identical(result, _missing) ? null : result;
  }

  /// Konversi nilai secara aman sesuai [targetType] tanpa menebak makna data.
  static dynamic convertValue(
    dynamic value,
    FieldType targetType, {
    dynamic defaultValue,
    BoolRule boolRule = const BoolRule(),
    DateRule dateRule = const DateRule(),
  }) {
    final conversion = _tryConvert(
      value,
      targetType,
      boolRule: boolRule,
      dateRule: dateRule,
    );
    if (conversion.ok) return conversion.value;
    return defaultValue ?? _defaultFor(targetType, dateRule: dateRule);
  }

  /// Adaptasi satu objek JSON (bisa langsung root object atau dibungkus [objectPath]).
  static AdaptedItem adaptObject(
    dynamic rawResponse, {
    required Map<String, FieldMapping> rules,
    String objectPath = '',
    BoolRule defaultBoolRule = const BoolRule(),
    DateRule defaultDateRule = const DateRule(),
    bool enableDebugLog = false,
    void Function(String)? logger,
  }) {
    final dynamic target = _resolvePath(rawResponse, objectPath);
    if (identical(target, _missing) || target is! Map) {
      throw ApiAdapterException(
        field: '<object>',
        sourcePath: objectPath.isEmpty ? '<root>' : objectPath,
        message: 'Data objek tidak ditemukan atau bukan JSON Object (diterima: ${target.runtimeType})',
      );
    }

    final rawMap = Map<String, dynamic>.from(target);
    final item = _adaptSingleMap(
      rawMap,
      rules: rules,
      defaultBoolRule: defaultBoolRule,
      defaultDateRule: defaultDateRule,
    );

    if (enableDebugLog) {
      _logSummary(logger ?? debugPrint, items: [item], totalRaw: 1, warnings: const []);
    }
    return item;
  }

  /// Adaptasi response berupa List (di root `listPath: ''` maupun nested `listPath: 'result.items'`).
  static AdaptedListResult adaptList(
    dynamic rawResponse, {
    required Map<String, FieldMapping> rules,
    String listPath = '',
    BoolRule defaultBoolRule = const BoolRule(),
    DateRule defaultDateRule = const DateRule(),
    bool enableDebugLog = false,
    void Function(String)? logger,
  }) {
    final dynamic extracted = _resolvePath(rawResponse, listPath);
    if (identical(extracted, _missing) || extracted is! List) {
      throw ApiAdapterException(
        field: '<list>',
        sourcePath: listPath.isEmpty ? '<root>' : listPath,
        message: 'Lokasi List tidak ditemukan atau bukan JSON Array (diterima: ${extracted.runtimeType})',
      );
    }

    final items = <AdaptedItem>[];
    final warnings = <String>[];

    for (int i = 0; i < extracted.length; i++) {
      final element = extracted[i];
      if (element is! Map) {
        warnings.add('Item [$i] dilewati karena bukan JSON Object (${element.runtimeType})');
        continue;
      }

      final rawMap = Map<String, dynamic>.from(element);
      items.add(
        _adaptSingleMap(
          rawMap,
          rules: rules,
          defaultBoolRule: defaultBoolRule,
          defaultDateRule: defaultDateRule,
        ),
      );
    }

    final result = AdaptedListResult(
      items: items,
      totalRawCount: extracted.length,
      warnings: warnings,
    );

    if (enableDebugLog) {
      _logSummary(
        logger ?? debugPrint,
        items: items,
        totalRaw: extracted.length,
        warnings: warnings,
      );
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════
  // MODE OTOMATIS (ZERO-REMAP): Deteksi List & Mapping Field Secara Dinamis
  // ══════════════════════════════════════════════════════════════════════

  static final RegExp _isoDateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}');
  static final RegExp _tokenSplitRegex = RegExp(r'(?<=[a-z])(?=[A-Z])|[_\-\s]+');
  static final RegExp _imageUrlHintRegex = RegExp(
    r'\.(jpg|jpeg|png|webp|gif|bmp|avif)(\?|$)|/(img|image|images|photo|photos|thumb|thumbnail|avatar|poster|cover|media|foto|gambar)/',
    caseSensitive: false,
  );

  // Kamus alias Inggris + Indonesia lintas bidang:
  // berita, kuliner, game, alat tulis/produk, luar angkasa, buah/tanaman, film/anime, buku, musik, wisata, otomotif
  static const List<String> _idAliases = [
    'id', 'uid', 'uuid', 'guid', '_id',
    'article_id', 'post_id', 'item_id', 'product_id', 'game_id', 'app_id', 'appid',
    'steam_id', 'rawg_id', 'igdb_id', 'movie_id', 'anime_id', 'mal_id', 'book_id',
    'user_id', 'student_id', 'meal_id', 'drink_id', 'food_id', 'dish_id', 'menu_id',
    'recipe_id', 'restaurant_id', 'cafe_id', 'track_id', 'song_id', 'event_id',
    'place_id', 'character_id', 'hero_id', 'weapon_id', 'map_id', 'match_id',
    'catalog_id', 'stationery_id', 'item_code', 'product_code', 'part_number', 'serial_number',
    'mission_id', 'launch_id', 'flight_number', 'norad_id', 'cospar_id', 'catalog_number',
    'planet_id', 'star_id', 'astronaut_id', 'rocket_id', 'satellite_id',
    'fruit_id', 'plant_id', 'species_id', 'variety_id', 'crop_id',
    'id_berita', 'id_artikel', 'id_produk', 'id_barang', 'id_game', 'id_karakter',
    'id_hero', 'id_senjata', 'id_film', 'id_buku', 'id_makanan', 'id_minuman',
    'id_resep', 'id_kuliner', 'id_menu', 'id_wisata', 'id_alat', 'id_atk',
    'id_misi', 'id_planet', 'id_roket', 'id_satelit', 'id_astronot',
    'id_buah', 'id_tanaman', 'id_tumbuhan',
    'kode_barang', 'kode_produk', 'kode_wisata', 'kode_atk', 'kode_alat',
    'kode_katalog', 'kode_buah', 'kode_resep', 'no_seri',
    'kode', 'code', 'sku', 'isbn', 'barcode', 'ean', 'upc',
    'nim', 'nip', 'nik', 'nisn', 'nomor', 'no_urut', 'number', 'num', 'no', 'pk',
  ];

  static const List<String> _imageAliases = [
    'image_url', 'imageurl', 'img_url', 'imgurl', 'thumbnail_url', 'thumbnail',
    'thumb_url', 'thumb', 'poster_url', 'poster_path', 'poster',
    'cover_url', 'cover_image', 'cover', 'backdrop_path', 'backdrop',
    'banner_url', 'banner', 'featured_image', 'hero_image', 'preview_image',
    'background_image', 'header_image', 'capsule_image', 'splash_art', 'splash',
    'portrait', 'full_portrait', 'bust_portrait', 'display_icon', 'key_art', 'game_image',
    'food_image', 'dish_image', 'meal_thumb', 'drink_thumb', 'menu_image',
    'product_image', 'item_image', 'catalog_image', 'album_art', 'artwork_url',
    'hdurl', 'mission_patch', 'mission_patch_small', 'patch', 'flickr_images',
    'img_src', 'telescope_image', 'nasa_image',
    'fruit_image', 'plant_image', 'photo_fruit',
    'photo_url', 'photo', 'photos', 'picture_url', 'picture', 'pictures', 'pic', 'pics',
    'avatar_url', 'avatar', 'icon_url', 'icon', 'logo_url', 'logo',
    'image', 'images', 'img', 'imgs', 'gallery', 'media',
    'screenshots', 'screenshot', 'sprites', 'sprite', 'artwork', 'box_art',
    'flag', 'flags', 'crest', 'emblem',
    'gambar_url', 'url_gambar', 'link_gambar', 'gambar_produk', 'gambar_barang',
    'gambar_makanan', 'gambar_resep', 'gambar_game', 'gambar_planet', 'gambar_buah',
    'gambar_tanaman', 'gambar',
    'foto_url', 'url_foto', 'foto_sampul', 'foto_produk', 'foto_barang', 'foto_alat',
    'foto_profil', 'foto_makanan', 'foto_menu', 'foto_hidangan', 'foto_karakter',
    'foto_antariksa', 'foto_misi', 'foto_buah', 'foto_tanaman', 'foto',
    'sampul', 'ilustrasi', 'galeri', 'ikon', 'ikon_hero', 'lambang', 'lambang_misi',
    'bendera', 'cuplikan', 'potret',
  ];

  static const List<String> _urlAliases = [
    'url', 'link', 'web_url', 'game_url', 'article_url', 'article_link', 'post_url',
    'product_url', 'store_url', 'steam_url', 'recipe_url', 'menu_url', 'source_url',
    'official_url', 'freetogame_profile_url', 'profile_url', 'detail_url', 'page_url',
    'site_url', 'external_url', 'canonical_url', 'wiki_url', 'wikipedia', 'wiki',
    'nasa_url', 'webcast', 'presskit', 'video_link', 'video_recipe', 'str_source',
    'str_youtube', 'youtube', 'html_url', 'homepage', 'website', 'permalink', 'href', 'uri',
    'download_url', 'trailer_url', 'video_url', 'stream_url', 'preview_url',
    'situs_resmi', 'link_resmi', 'link_berita', 'link_sumber', 'link_game', 'link_resep',
    'link_misi', 'link_download', 'video_masak', 'url_resmi', 'url_sumber', 'sumber_url',
    'alamat_web', 'alamat_url', 'tautan', 'situs', 'laman',
  ];

  static const List<String> _titleAliases = [
    'title', 'headline', 'name', 'full_name', 'fullname', 'display_name',
    'title_english', 'title_default', 'original_title', 'official_name', 'common_name',
    'short_name', 'article_title', 'post_title', 'game_title', 'game_name',
    'movie_title', 'movie_name', 'book_title', 'song_title', 'track_name',
    'product_name', 'item_name', 'item_title', 'goods_name', 'stationery_name',
    'tool_name', 'supply_name', 'equipment_name', 'merchandise',
    'food_name', 'menu_name', 'dish_name', 'drink_name', 'beverage', 'recipe_name',
    'cuisine_name', 'restaurant_name', 'cafe_name', 'meal', 'drink', 'dish',
    'hero_name', 'champion_name', 'agent_name', 'character_name', 'weapon_name',
    'skin_name', 'quest_name', 'map_name', 'boss_name', 'npc_name',
    'mission_name', 'rocket_name', 'spacecraft_name', 'planet_name', 'star_name',
    'galaxy_name', 'satellite_name', 'astronaut_name', 'celestial_body',
    'asteroid_name', 'nebula_name',
    'fruit_name', 'plant_name', 'scientific_name', 'botanical_name', 'latin_name',
    'species_name', 'crop_name', 'vegetable_name', 'flower_name', 'variety', 'cultivar',
    'student_name', 'car_name', 'vehicle_name',
    'subject', 'heading', 'caption', 'label', 'topic', 'theme', 'model',
    'judul_berita', 'judul_artikel', 'judul_buku', 'judul_film', 'judul',
    'nama_lengkap', 'nama_produk', 'nama_barang', 'nama_alat_tulis', 'nama_alat',
    'nama_atk', 'nama_perlengkapan', 'nama_makanan', 'nama_minuman', 'nama_resep',
    'nama_kuliner', 'nama_menu', 'nama_hidangan', 'nama_restoran', 'nama_warung',
    'nama_game', 'nama_hero', 'nama_karakter', 'nama_senjata', 'nama_map', 'nama_misi',
    'nama_roket', 'nama_planet', 'nama_bintang', 'nama_galaksi', 'nama_satelit',
    'nama_astronot', 'nama_buah', 'nama_tanaman', 'nama_tumbuhan', 'nama_ilmiah',
    'nama_latin', 'nama_sayur', 'nama_bunga', 'nama_tempat', 'nama_wisata',
    'nama_mahasiswa', 'nama_siswa', 'nama_tokoh', 'nama_kota', 'nama_negara',
    'nama_kendaraan', 'nama',
    'alat_tulis', 'perlengkapan', 'masakan', 'hidangan', 'kuliner', 'menu',
    'makanan', 'minuman', 'wahana', 'pesawat_antariksa', 'benda_langit',
    'buah', 'tanaman', 'varietas', 'barang', 'produk', 'lagu', 'topik', 'tajuk', 'perihal', 'subjek',
  ];

  static const List<String> _authorAliases = [
    'news_site', 'newssite', 'author', 'authors', 'author_name', 'publisher',
    'publisher_name', 'developer', 'developers', 'dev', 'source_name', 'source',
    'studio', 'studios', 'creator', 'creators', 'writer', 'writers', 'copyright',
    'artist', 'artists', 'artist_name', 'singer', 'band', 'director', 'producer',
    'agency', 'space_agency', 'launch_service_provider', 'program',
    'organization', 'org', 'company', 'brand', 'manufacturer', 'maker',
    'supplier', 'distributor', 'vendor', 'merchant', 'store', 'shop', 'seller', 'owner',
    'chef', 'cook', 'restaurant', 'cafe', 'bakery', 'kitchen', 'cuisine', 'course',
    'meal_type', 'diet',
    'platform', 'platforms', 'console', 'engine', 'genre', 'genres', 'category', 'categories',
    'subcategory', 'type', 'body_type', 'planet_type', 'orbit', 'orbit_type',
    'launchpad', 'launch_site', 'constellation', 'galaxy', 'spectral_type',
    'family', 'botanical_family', 'genus', 'order', 'phylum', 'kingdom',
    'habitat', 'climate', 'harvest_season', 'season', 'soil_type', 'taste', 'flavor', 'flavour',
    'material', 'color', 'colour', 'size', 'paper_size', 'ink_color', 'tip_size',
    'species', 'race', 'class', 'hero_class', 'role', 'faction', 'element', 'weapon_type',
    'rank', 'tier', 'rarity', 'difficulty', 'esrb_rating', 'server',
    'team', 'club', 'league', 'channel', 'network', 'site', 'domain', 'provider',
    'region', 'country', 'origin_country', 'area', 'location', 'city', 'origin',
    'language', 'major', 'department', 'faculty', 'warehouse', 'aisle', 'rack',
    'status', 'make',
    'penulis', 'pengarang', 'penerbit', 'pengembang', 'pembuat', 'pencipta',
    'sutradara', 'penyanyi', 'koki', 'sumber_berita', 'sumber', 'nama_media',
    'media_berita', 'redaksi', 'penyedia', 'perusahaan', 'produsen', 'pabrik',
    'pemasok', 'merek', 'merk', 'merk_mobil', 'toko', 'penjual', 'pemilik',
    'restoran', 'warung', 'kedai', 'dapur', 'badan_antariksa', 'lembaga_antariksa',
    'orbit_satelit', 'lokasi_peluncuran', 'galaksi', 'rasi_bintang', 'jenis_planet',
    'famili', 'suku', 'marga', 'ordo', 'kerajaan', 'habitat_tumbuh', 'iklim',
    'musim_panen', 'musim', 'cita_rasa', 'rasa', 'bahan_baku', 'warna', 'ukuran',
    'satuan', 'rak', 'gudang', 'konsol', 'mesin_game', 'peran_hero', 'kelas_karakter',
    'elemen', 'kategori', 'jenis', 'tipe', 'golongan', 'kelompok', 'kelas', 'aliran',
    'provinsi', 'kota', 'kabupaten', 'wilayah', 'daerah', 'daerah_asal', 'asal_daerah',
    'negara', 'asal', 'lokasi', 'alamat', 'tempat', 'bahasa', 'jurusan', 'prodi',
    'fakultas', 'instansi', 'lembaga', 'tim', 'klub', 'divisi', 'bidang', 'posisi',
    'peran', 'jabatan',
  ];

  static const List<String> _summaryAliases = [
    'summary', 'short_description', 'description', 'long_description',
    'detailed_description', 'about_the_game', 'product_description',
    'mission_description', 'mission_details', 'flight_details', 'desc',
    'synopsis', 'synopsys', 'overview', 'excerpt', 'abstract', 'intro', 'introduction',
    'lead', 'snippet', 'blurb', 'explanation', 'content', 'body', 'full_text', 'text',
    'article_text', 'story', 'storyline', 'plot', 'lore', 'background', 'biography', 'bio',
    'about', 'info', 'information', 'detail', 'details',
    'instructions', 'cooking_steps', 'preparation', 'steps', 'directions', 'recipe',
    'ingredients', 'serving', 'how_to_use', 'usage', 'care_guide', 'cultivation',
    'gameplay', 'ability', 'abilities', 'skills', 'skill', 'passive', 'ultimate',
    'patch_notes', 'system_requirements', 'requirements',
    'objective', 'findings', 'discovery', 'composition', 'atmosphere',
    'benefits', 'health_benefits', 'vitamins', 'taste_profile', 'uses',
    'watering', 'sunlight', 'specs', 'specification', 'features', 'package_contents',
    'dimensions', 'warranty', 'lyrics', 'notes', 'note', 'remarks', 'comment',
    'review', 'message', 'quote', 'tagline', 'subtitle', 'sub_title',
    'meaning', 'definition', 'effects', 'effect', 'nutrition', 'nutritions', 'nutrients', 'calories',
    'ringkasan', 'deskripsi_singkat', 'deskripsi_produk', 'deskripsi', 'keterangan',
    'penjelasan_misi', 'penjelasan', 'uraian', 'sinopsis_game', 'sinopsis', 'ikhtisar',
    'rangkuman', 'cuplikan', 'isi_berita', 'isi_artikel', 'isi_paket', 'isi', 'konten',
    'artikel', 'cerita_game', 'cerita', 'kisah', 'alur', 'profil', 'biografi', 'tentang',
    'informasi', 'rincian', 'langkah', 'cara_membuat', 'cara_masak', 'cara_penyajian',
    'cara_tanam', 'perawatan', 'resep', 'bahan', 'bumbu', 'komposisi_planet', 'komposisi',
    'atmosfer', 'tujuan_misi', 'temuan', 'keahlian', 'kemampuan', 'jurus', 'spesifikasi_pc',
    'spesifikasi_barang', 'spesifikasi', 'kegunaan', 'fungsi', 'keunggulan', 'garansi',
    'manfaat_buah', 'manfaat', 'khasiat', 'kandungan_gizi', 'gizi', 'nutrisi', 'vitamin',
    'kalori', 'ciri_ciri', 'lirik', 'catatan', 'ulasan', 'komentar', 'pesan', 'kutipan',
    'fitur', 'arti', 'makna', 'definisi', 'latar_belakang',
  ];

  static const List<String> _dateAliases = [
    'published_at', 'publishedat', 'publish_date', 'published_date', 'published',
    'release_date', 'released_at', 'released', 'launch_date', 'launch_date_utc',
    'launch_date_local', 'date_utc', 'earth_date', 'discovery_date', 'window_start',
    'created_at', 'createdat', 'create_date', 'created_date', 'created',
    'updated_at', 'updatedat', 'update_date', 'modified_at', 'last_updated',
    'date', 'datetime', 'date_time', 'aired', 'air_date', 'first_air_date',
    'start_date', 'end_date', 'event_date', 'patch_date', 'season_start',
    'manufacture_date', 'production_date', 'expiry_date', 'restock_date',
    'harvest_date', 'planting_date', 'birth_date', 'birthday', 'dob',
    'due_date', 'deadline', 'posted_at', 'post_date', 'uploaded_at',
    'published_ts', 'created_ts', 'timestamp', 'epoch', 'time',
    'release_year', 'year', 'founded', 'established', 'since', 'period', 'season',
    'tanggal_terbit', 'tanggal_rilis', 'tanggal_peluncuran', 'tanggal_penemuan',
    'tanggal_publikasi', 'tanggal_posting', 'tanggal_dibuat', 'tanggal_diubah',
    'tanggal_diperbarui', 'tanggal_update', 'tanggal_acara', 'tanggal_lahir',
    'tanggal_produksi', 'tanggal_masuk', 'tanggal_kadaluarsa', 'tanggal_panen',
    'tanggal_mulai', 'tanggal_selesai', 'tanggal',
    'tgl_terbit', 'tgl_rilis', 'tgl_posting', 'tgl_dibuat', 'tgl_lahir', 'tgl',
    'waktu_terbit', 'waktu_posting', 'waktu_peluncuran', 'waktu_tanam', 'waktu', 'jam',
    'tahun_rilis', 'tahun_terbit', 'tahun_keluaran', 'tahun',
    'dibuat_pada', 'diperbarui_pada', 'dipublikasikan', 'diterbitkan', 'dirilis',
    'jadwal', 'periode', 'masa',
  ];

  /// Otomatis mencari List item utama di dalam JSON (root Array, nested Object,
  /// maupun List-di-dalam-List yang otomatis di-flatten).
  static List<Map<String, dynamic>> autoExtractList(dynamic rawResponse) {
    if (rawResponse is List) {
      final maps = _extractMapsFromList(rawResponse);
      return _flattenIfWrapperGroup(maps);
    }

    if (rawResponse is! Map) return const [];

    // BFS agar list utama di level teratas diprioritaskan sebelum list kecil di dalam item.
    final queue = <Map<dynamic, dynamic>>[rawResponse];
    List<Map<String, dynamic>> bestList = const [];

    while (queue.isNotEmpty) {
      final levelCount = queue.length;
      final levelCandidates = <List<Map<String, dynamic>>>[];

      for (int i = 0; i < levelCount; i++) {
        final current = queue.removeAt(0);
        for (final value in current.values) {
          if (value is List) {
            final maps = _extractMapsFromList(value);
            if (maps.isNotEmpty) {
              levelCandidates.add(_flattenIfWrapperGroup(maps));
            }
          } else if (value is Map) {
            queue.add(value);
          }
        }
      }

      if (levelCandidates.isNotEmpty) {
        levelCandidates.sort((a, b) => b.length.compareTo(a.length));
        bestList = levelCandidates.first;
        break;
      }
    }

    return bestList;
  }

  /// Adaptasi List secara OTOMATIS tanpa perlu menulis mapping manual.
  /// Jika [overrides] diisi sebagian, hanya field itu yang pakai aturan manual, sisanya otomatis.
  static AdaptedListResult autoAdaptList(
    dynamic rawResponse, {
    String listPath = '',
    Map<String, FieldMapping> overrides = const {},
    BoolRule defaultBoolRule = const BoolRule(),
    DateRule defaultDateRule = const DateRule(),
    bool enableDebugLog = false,
    void Function(String)? logger,
  }) {
    final List<Map<String, dynamic>> rawItems;
    if (listPath.trim().isNotEmpty) {
      final extracted = _resolvePath(rawResponse, listPath);
      if (identical(extracted, _missing) || extracted is! List) {
        throw ApiAdapterException(
          field: '<list>',
          sourcePath: listPath,
          message: 'Lokasi List tidak ditemukan atau bukan Array (${extracted.runtimeType})',
        );
      }
      rawItems = _extractMapsFromList(extracted);
    } else {
      rawItems = autoExtractList(rawResponse);
    }

    final items = <AdaptedItem>[];
    for (int i = 0; i < rawItems.length; i++) {
      items.add(
        _autoAdaptSingleMap(
          rawItems[i],
          index: i,
          overrides: overrides,
          defaultBoolRule: defaultBoolRule,
          defaultDateRule: defaultDateRule,
        ),
      );
    }

    final result = AdaptedListResult(
      items: items,
      totalRawCount: rawItems.length,
      warnings: const [],
    );

    if (enableDebugLog) {
      _logSummary(
        logger ?? debugPrint,
        items: items,
        totalRaw: rawItems.length,
        warnings: const [],
      );
    }
    return result;
  }

  /// Adaptasi 1 objek detail secara OTOMATIS tanpa perlu menulis mapping manual.
  static AdaptedItem autoAdaptObject(
    dynamic rawResponse, {
    String objectPath = '',
    Map<String, FieldMapping> overrides = const {},
    BoolRule defaultBoolRule = const BoolRule(),
    DateRule defaultDateRule = const DateRule(),
    bool enableDebugLog = false,
    void Function(String)? logger,
  }) {
    Map<String, dynamic>? rawMap;
    if (objectPath.trim().isNotEmpty) {
      final target = _resolvePath(rawResponse, objectPath);
      if (!identical(target, _missing) && target is Map) {
        rawMap = Map<String, dynamic>.from(target);
      }
    } else {
      rawMap = _autoUnwrapObject(rawResponse);
    }

    if (rawMap == null) {
      throw ApiAdapterException(
        field: '<object>',
        sourcePath: objectPath.isEmpty ? '<root>' : objectPath,
        message: 'Data objek detail tidak ditemukan (diterima: ${rawResponse.runtimeType})',
      );
    }

    final item = _autoAdaptSingleMap(
      rawMap,
      index: 0,
      overrides: overrides,
      defaultBoolRule: defaultBoolRule,
      defaultDateRule: defaultDateRule,
    );

    if (enableDebugLog) {
      _logSummary(logger ?? debugPrint, items: [item], totalRaw: 1, warnings: const []);
    }
    return item;
  }

  static List<Map<String, dynamic>> _extractMapsFromList(List<dynamic> list) {
    final result = <Map<String, dynamic>>[];
    for (final el in list) {
      if (el is Map) {
        result.add(Map<String, dynamic>.from(el));
      } else if (el is List) {
        result.addAll(_extractMapsFromList(el));
      }
    }
    return result;
  }

  /// Jika List berisi grup pembungkus (mis. `categories: [{name, items: [...]}]`),
  /// otomatis gabungkan (flatten) semua inner items.
  static List<Map<String, dynamic>> _flattenIfWrapperGroup(
    List<Map<String, dynamic>> list,
  ) {
    if (list.isEmpty) return list;
    final sample = list.first;

    String? innerListKey;
    int primitiveCount = 0;
    for (final entry in sample.entries) {
      if (entry.value is List && _extractMapsFromList(entry.value as List).isNotEmpty) {
        innerListKey ??= entry.key;
      } else if (entry.value is! Map && entry.value is! List) {
        primitiveCount++;
      }
    }

    if (innerListKey == null) return list;
    final sampleInner = _extractMapsFromList(sample[innerListKey] as List);
    if (sampleInner.isEmpty) return list;

    // Anggap wrapper jika elemen luar hanya punya sedikit field primitif (<= 2)
    // sementara item di dalam list-nya jauh lebih kaya field-nya.
    if (primitiveCount <= 2 && sampleInner.first.length > sample.length) {
      final flattened = <Map<String, dynamic>>[];
      for (final group in list) {
        final inner = group[innerListKey];
        if (inner is List) {
          flattened.addAll(_extractMapsFromList(inner));
        }
      }
      if (flattened.isNotEmpty) return flattened;
    }

    return list;
  }

  static Map<String, dynamic>? _autoUnwrapObject(dynamic raw) {
    if (raw is List) {
      final maps = _extractMapsFromList(raw);
      return maps.isNotEmpty ? maps.first : null;
    }
    if (raw is! Map) return null;

    final map = Map<String, dynamic>.from(raw);
    // Jika dibungkus wrapper seperti {"success": true, "data": {...}}, kupas otomatis.
    for (final wrapperKey in const ['data', 'result', 'item', 'post', 'article', 'payload']) {
      final inner = map[wrapperKey];
      if (inner is Map && inner.isNotEmpty) {
        return _autoUnwrapObject(inner);
      }
      if (inner is List && inner.isNotEmpty && inner.first is Map) {
        return Map<String, dynamic>.from(inner.first as Map);
      }
    }
    return map;
  }

  static AdaptedItem _autoAdaptSingleMap(
    Map<String, dynamic> rawMap, {
    required int index,
    required Map<String, FieldMapping> overrides,
    required BoolRule defaultBoolRule,
    required DateRule defaultDateRule,
  }) {
    final entries = <({String key, String lowerKey, String path, dynamic value})>[];
    _flattenEntries(rawMap, '', entries);

    final traces = <FieldTrace>[];
    final normalized = <String, dynamic>{};

    // Terapkan override manual terlebih dahulu jika user mengisinya.
    if (overrides.isNotEmpty) {
      final manual = _adaptSingleMap(
        rawMap,
        rules: overrides,
        defaultBoolRule: defaultBoolRule,
        defaultDateRule: defaultDateRule,
      );
      normalized.addAll(manual.normalized);
      traces.addAll(manual.traces);
    }

    void fillIfAbsent(String field, ({dynamic value, String sourcePath, String originalType}) picked) {
      if (normalized.containsKey(field)) return;
      normalized[field] = picked.value;
      traces.add(
        FieldTrace(
          targetField: field,
          sourcePath: picked.sourcePath,
          found: picked.sourcePath != '<fallback>',
          originalType: picked.originalType,
          convertedType: picked.value.runtimeType.toString(),
          usedDefault: picked.sourcePath == '<fallback>',
        ),
      );
    }

    final idPick = _autoPickId(entries, index);
    fillIfAbsent('id', idPick);

    final imagePick = _autoPickImageUrl(entries);
    fillIfAbsent('imageUrl', imagePick);
    final chosenImage = (normalized['imageUrl'] ?? '').toString();

    final urlPick = _autoPickUrl(entries, excludeUrl: chosenImage);
    fillIfAbsent('url', urlPick);

    final titlePick = _autoPickTitle(entries, excludePath: idPick.sourcePath);
    fillIfAbsent('title', titlePick);
    final chosenTitle = (normalized['title'] ?? '').toString();

    final authorPick = _autoPickAuthor(
      entries,
      excludeText: chosenTitle,
      excludePath: idPick.sourcePath,
    );
    fillIfAbsent('newsSite', authorPick);
    final chosenAuthor = (normalized['newsSite'] ?? '').toString();

    final summaryPick = _autoPickSummary(
      entries,
      excludeTexts: {chosenTitle, chosenAuthor, chosenImage},
      excludePaths: {idPick.sourcePath, titlePick.sourcePath, authorPick.sourcePath},
    );
    fillIfAbsent('summary', summaryPick);

    final datePick = _autoPickDate(entries);
    fillIfAbsent('publishedAt', datePick);

    return AdaptedItem(normalized: normalized, raw: rawMap, traces: traces);
  }

  static void _flattenEntries(
    dynamic node,
    String prefix,
    List<({String key, String lowerKey, String path, dynamic value})> out, {
    int depth = 0,
  }) {
    // shortcut: batasi kedalaman flatten di 5 level dan 3 elemen list pertama agar tetap cepat pada 500+ item.
    if (depth > 5) return;

    if (node is Map) {
      for (final e in node.entries) {
        final key = e.key.toString();
        final path = prefix.isEmpty ? key : '$prefix.$key';
        out.add((key: key, lowerKey: key.toLowerCase(), path: path, value: e.value));
        if (e.value is Map || e.value is List) {
          _flattenEntries(e.value, path, out, depth: depth + 1);
        }
      }
    } else if (node is List) {
      final limit = node.length < 3 ? node.length : 3;
      for (int i = 0; i < limit; i++) {
        final item = node[i];
        final path = '$prefix[$i]';
        if (item is Map || item is List) {
          _flattenEntries(item, path, out, depth: depth + 1);
        }
      }
    }
  }

  static ({String path, dynamic value})? _matchByAliases(
    List<({String key, String lowerKey, String path, dynamic value})> entries,
    List<String> aliases, {
    bool Function(dynamic value)? accept,
    Set<String> excludePaths = const {},
  }) {
    bool isExcludedPath(String path) {
      for (final p in excludePaths) {
        if (p.isEmpty || p == '<fallback>') continue;
        if (path == p || path.startsWith('$p.') || path.startsWith('$p[')) return true;
      }
      return false;
    }

    bool isValid(({String key, String lowerKey, String path, dynamic value}) e) =>
        !isExcludedPath(e.path) &&
        e.value != null &&
        (accept == null || accept(e.value));

    // Pass 1: kecocokan nama key persis (mis. `short_description`, `release_date`, `nama_tempat`)
    for (final alias in aliases) {
      for (final e in entries) {
        if (e.lowerKey == alias && isValid(e)) {
          return (path: e.path, value: e.value);
        }
      }
    }

    // Pass 2: kecocokan per token snake_case / camelCase (mis. `idMeal` -> `id`, `game_url` -> `url`, `tglLahir` -> `tgl`)
    final tokenCache = <String, Set<String>>{};
    Set<String> tokensOf(String key) {
      return tokenCache.putIfAbsent(
        key,
        () => key
            .split(_tokenSplitRegex)
            .where((t) => t.isNotEmpty)
            .map((t) => t.toLowerCase())
            .toSet(),
      );
    }

    for (final alias in aliases) {
      if (alias.contains('_')) continue;
      for (final e in entries) {
        if (isValid(e) && tokensOf(e.key).contains(alias)) {
          return (path: e.path, value: e.value);
        }
      }
    }

    // Pass 3: kecocokan substring hanya untuk alias >= 4 huruf agar tidak bentrok dengan kata lain
    for (final alias in aliases) {
      if (alias.length < 4) continue;
      for (final e in entries) {
        if (e.lowerKey.contains(alias) && isValid(e)) {
          return (path: e.path, value: e.value);
        }
      }
    }
    return null;
  }

  static String? _digFirstUrl(dynamic value, {String? exclude}) {
    if (value is String) {
      final s = value.trim();
      if ((s.startsWith('http://') || s.startsWith('https://')) && s != exclude) {
        return s;
      }
      return null;
    }
    if (value is List) {
      for (final el in value) {
        final found = _digFirstUrl(el, exclude: exclude);
        if (found != null) return found;
      }
    }
    if (value is Map) {
      // Prioritaskan key gambar umum di dalam nested object (mis. Jikan `images.jpg.image_url`)
      for (final pref in const ['image_url', 'url', 'src', 'large', 'medium', 'small', 'front_default', 'jpg', 'webp']) {
        if (value.containsKey(pref)) {
          final found = _digFirstUrl(value[pref], exclude: exclude);
          if (found != null) return found;
        }
      }
      for (final v in value.values) {
        final found = _digFirstUrl(v, exclude: exclude);
        if (found != null) return found;
      }
    }
    return null;
  }

  static String? _digFirstText(dynamic value) {
    if (value is String) {
      final s = value.trim();
      return s.isNotEmpty ? s : null;
    }
    if (value is num) return value.toString();
    if (value is List) {
      for (final el in value) {
        final found = _digFirstText(el);
        if (found != null) return found;
      }
    }
    if (value is Map) {
      for (final pref in const ['name', 'full_name', 'title', 'label', 'text', 'from', 'value']) {
        if (value.containsKey(pref)) {
          final found = _digFirstText(value[pref]);
          if (found != null) return found;
        }
      }
      for (final v in value.values) {
        final found = _digFirstText(v);
        if (found != null) return found;
      }
    }
    return null;
  }

  static ({dynamic value, String sourcePath, String originalType}) _autoPickId(
    List<({String key, String lowerKey, String path, dynamic value})> entries,
    int index,
  ) {
    final match = _matchByAliases(
      entries,
      _idAliases,
      accept: (v) => v is num || (v is String && v.trim().isNotEmpty),
    );
    if (match != null) {
      final v = match.value;
      int? parsed;
      if (v is int) {
        parsed = v;
      } else if (v is double) {
        parsed = v.toInt();
      } else if (v is String) {
        parsed = int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt() ?? v.hashCode.abs();
      }
      if (parsed != null) {
        return (value: parsed, sourcePath: match.path, originalType: v.runtimeType.toString());
      }
    }
    return (value: index + 1, sourcePath: '<fallback>', originalType: 'missing');
  }

  static ({dynamic value, String sourcePath, String originalType}) _autoPickImageUrl(
    List<({String key, String lowerKey, String path, dynamic value})> entries,
  ) {
    final match = _matchByAliases(
      entries,
      _imageAliases,
      accept: (v) => _digFirstUrl(v) != null,
    );
    if (match != null) {
      return (
        value: _digFirstUrl(match.value)!,
        sourcePath: match.path,
        originalType: match.value.runtimeType.toString(),
      );
    }

    // Fallback: cari URL gambar mana pun di seluruh field (termasuk di dalam list)
    for (final e in entries) {
      final url = _digFirstUrl(e.value);
      if (url != null && _imageUrlHintRegex.hasMatch(url)) {
        return (value: url, sourcePath: e.path, originalType: e.value.runtimeType.toString());
      }
    }
    return (value: '', sourcePath: '<fallback>', originalType: 'missing');
  }

  static ({dynamic value, String sourcePath, String originalType}) _autoPickUrl(
    List<({String key, String lowerKey, String path, dynamic value})> entries, {
    required String excludeUrl,
  }) {
    final match = _matchByAliases(
      entries,
      _urlAliases,
      accept: (v) => _digFirstUrl(v, exclude: excludeUrl) != null,
    );
    if (match != null) {
      return (
        value: _digFirstUrl(match.value, exclude: excludeUrl)!,
        sourcePath: match.path,
        originalType: match.value.runtimeType.toString(),
      );
    }

    for (final e in entries) {
      final url = _digFirstUrl(e.value, exclude: excludeUrl);
      if (url != null) {
        return (value: url, sourcePath: e.path, originalType: e.value.runtimeType.toString());
      }
    }
    return (value: '', sourcePath: '<fallback>', originalType: 'missing');
  }

  static ({dynamic value, String sourcePath, String originalType}) _autoPickTitle(
    List<({String key, String lowerKey, String path, dynamic value})> entries, {
    required String excludePath,
  }) {
    final match = _matchByAliases(
      entries,
      _titleAliases,
      excludePaths: {excludePath},
      accept: (v) {
        final text = _digFirstText(v);
        return text != null && !text.startsWith('http');
      },
    );
    if (match != null) {
      return (
        value: _digFirstText(match.value)!,
        sourcePath: match.path,
        originalType: match.value.runtimeType.toString(),
      );
    }

    for (final e in entries) {
      if (e.path != excludePath && e.value is String) {
        final s = (e.value as String).trim();
        if (s.isNotEmpty && !s.startsWith('http')) {
          return (value: s, sourcePath: e.path, originalType: 'String');
        }
      }
    }
    return (value: 'Tanpa Judul', sourcePath: '<fallback>', originalType: 'missing');
  }

  static ({dynamic value, String sourcePath, String originalType}) _autoPickAuthor(
    List<({String key, String lowerKey, String path, dynamic value})> entries, {
    required String excludeText,
    required String excludePath,
  }) {
    final match = _matchByAliases(
      entries,
      _authorAliases,
      excludePaths: {excludePath},
      accept: (v) {
        final text = _digFirstText(v);
        return text != null && !text.startsWith('http') && text != excludeText;
      },
    );
    if (match != null) {
      return (
        value: _digFirstText(match.value)!,
        sourcePath: match.path,
        originalType: match.value.runtimeType.toString(),
      );
    }
    return (value: 'Umum', sourcePath: '<fallback>', originalType: 'missing');
  }

  static ({dynamic value, String sourcePath, String originalType}) _autoPickSummary(
    List<({String key, String lowerKey, String path, dynamic value})> entries, {
    required Set<String> excludeTexts,
    required Set<String> excludePaths,
  }) {
    final match = _matchByAliases(
      entries,
      _summaryAliases,
      excludePaths: excludePaths,
      accept: (v) {
        final text = _digFirstText(v);
        return text != null && !text.startsWith('http') && !excludeTexts.contains(text);
      },
    );
    if (match != null) {
      return (
        value: _digFirstText(match.value)!,
        sourcePath: match.path,
        originalType: match.value.runtimeType.toString(),
      );
    }

    // Fallback: hanya ambil teks deskriptif panjang (>= 20 karakter & punya spasi)
    // agar metadata pendek seperti "thumb" / "active" tidak salah dianggap ringkasan.
    ({String path, String text})? longest;
    for (final e in entries) {
      if (!excludePaths.contains(e.path) && e.value is String) {
        final s = (e.value as String).trim();
        if (s.length >= 20 &&
            s.contains(' ') &&
            !s.startsWith('http') &&
            !_isoDateRegex.hasMatch(s) &&
            !excludeTexts.contains(s)) {
          if (longest == null || s.length > longest.text.length) {
            longest = (path: e.path, text: s);
          }
        }
      }
    }
    if (longest != null) {
      return (value: longest.text, sourcePath: longest.path, originalType: 'String');
    }
    return (value: '', sourcePath: '<fallback>', originalType: 'missing');
  }

  static ({dynamic value, String sourcePath, String originalType}) _autoPickDate(
    List<({String key, String lowerKey, String path, dynamic value})> entries,
  ) {
    final match = _matchByAliases(
      entries,
      _dateAliases,
      accept: (v) => _digFirstText(v) != null,
    );
    if (match != null) {
      final v = match.value;
      // Hanya konversi int ke tanggal jika nama key eksplisit mengandung ts/timestamp/epoch
      if (v is int && (match.path.toLowerCase().contains('ts') ||
          match.path.toLowerCase().contains('timestamp') ||
          match.path.toLowerCase().contains('epoch'))) {
        final isMs = v > 100000000000;
        final dt = DateTime.fromMillisecondsSinceEpoch(isMs ? v : v * 1000, isUtc: true);
        return (value: dt.toIso8601String(), sourcePath: match.path, originalType: 'int');
      }
      final text = _digFirstText(v)!;
      return (value: text, sourcePath: match.path, originalType: v.runtimeType.toString());
    }

    for (final e in entries) {
      if (e.value is String && _isoDateRegex.hasMatch((e.value as String).trim())) {
        return (value: (e.value as String).trim(), sourcePath: e.path, originalType: 'String');
      }
    }
    return (value: '', sourcePath: '<fallback>', originalType: 'missing');
  }

  static AdaptedItem _adaptSingleMap(
    Map<String, dynamic> rawMap, {
    required Map<String, FieldMapping> rules,
    required BoolRule defaultBoolRule,
    required DateRule defaultDateRule,
  }) {
    final normalized = <String, dynamic>{};
    final traces = <FieldTrace>[];

    for (final entry in rules.entries) {
      final targetKey = entry.key;
      final rule = entry.value;
      final dynamic rawValue = _resolvePath(rawMap, rule.source);
      final bool found = !identical(rawValue, _missing);

      if (!found || rawValue == null) {
        if (rule.required) {
          throw ApiAdapterException(
            field: targetKey,
            sourcePath: rule.source,
            message: found ? 'Field wajib bernilai null' : 'Field wajib tidak ditemukan di JSON',
          );
        }
        final effectiveDateRule = rule.dateRule ?? defaultDateRule;
        final fallback = rule.defaultValue ?? _defaultFor(rule.type, dateRule: effectiveDateRule);
        normalized[targetKey] = fallback;
        traces.add(
          FieldTrace(
            targetField: targetKey,
            sourcePath: rule.source,
            found: found,
            originalType: found ? 'null' : 'missing',
            convertedType: fallback.runtimeType.toString(),
            usedDefault: true,
            warning: found ? null : 'Field tidak ditemukan, memakai default',
          ),
        );
        continue;
      }

      final converted = _tryConvert(
        rawValue,
        rule.type,
        boolRule: rule.boolRule ?? defaultBoolRule,
        dateRule: rule.dateRule ?? defaultDateRule,
      );

      if (!converted.ok) {
        if (rule.required) {
          throw ApiAdapterException(
            field: targetKey,
            sourcePath: rule.source,
            message:
                'Gagal konversi nilai tipe ${rawValue.runtimeType} ke ${rule.type.name}',
          );
        }
        final effectiveDateRule = rule.dateRule ?? defaultDateRule;
        final fallback = rule.defaultValue ?? _defaultFor(rule.type, dateRule: effectiveDateRule);
        normalized[targetKey] = fallback;
        traces.add(
          FieldTrace(
            targetField: targetKey,
            sourcePath: rule.source,
            found: true,
            originalType: rawValue.runtimeType.toString(),
            convertedType: fallback.runtimeType.toString(),
            usedDefault: true,
            warning:
                'Konversi ${rawValue.runtimeType} → ${rule.type.name} gagal, memakai default',
          ),
        );
        continue;
      }

      normalized[targetKey] = converted.value;
      traces.add(
        FieldTrace(
          targetField: targetKey,
          sourcePath: rule.source,
          found: true,
          originalType: rawValue.runtimeType.toString(),
          convertedType: converted.value.runtimeType.toString(),
          usedDefault: false,
        ),
      );
    }

    return AdaptedItem(normalized: normalized, raw: rawMap, traces: traces);
  }

  static dynamic _resolvePath(dynamic root, String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return root;

    dynamic current = root;
    for (final rawSegment in trimmed.split('.')) {
      final segment = rawSegment.trim();
      if (segment.isEmpty) continue;

      final bracketOnly = _bracketOnlyRegex.firstMatch(segment);
      if (bracketOnly != null) {
        final index = int.tryParse(bracketOnly.group(1)!);
        if (current is List && index != null && index >= 0 && index < current.length) {
          current = current[index];
          continue;
        }
        return _missing;
      }

      final match = _segmentRegex.firstMatch(segment);
      if (match != null) {
        final key = match.group(1)!;
        final indexStr = match.group(2);

        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else if (current is List) {
          final listIdx = int.tryParse(key);
          if (listIdx != null && listIdx >= 0 && listIdx < current.length) {
            current = current[listIdx];
          } else {
            return _missing;
          }
        } else {
          return _missing;
        }

        if (indexStr != null) {
          final index = int.tryParse(indexStr);
          if (current is List && index != null && index >= 0 && index < current.length) {
            current = current[index];
          } else {
            return _missing;
          }
        }
      } else {
        return _missing;
      }
    }
    return current;
  }

  static ({bool ok, dynamic value}) _tryConvert(
    dynamic value,
    FieldType targetType, {
    required BoolRule boolRule,
    required DateRule dateRule,
  }) {
    if (value == null) return (ok: false, value: null);

    switch (targetType) {
      case FieldType.string:
        if (value is String) return (ok: true, value: value);
        if (value is num || value is bool) return (ok: true, value: value.toString());
        return (ok: false, value: null);

      case FieldType.integer:
        if (value is int) return (ok: true, value: value);
        if (value is double) return (ok: true, value: value.toInt());
        if (value is String) {
          final parsedInt = int.tryParse(value.trim());
          if (parsedInt != null) return (ok: true, value: parsedInt);
        }
        return (ok: false, value: null);

      case FieldType.decimal:
        if (value is double) return (ok: true, value: value);
        if (value is int) return (ok: true, value: value.toDouble());
        if (value is String) {
          final parsedDouble = double.tryParse(value.trim());
          if (parsedDouble != null) return (ok: true, value: parsedDouble);
        }
        return (ok: false, value: null);

      case FieldType.boolean:
        final parsedBool = boolRule.parse(value);
        if (parsedBool != null) return (ok: true, value: parsedBool);
        return (ok: false, value: null);

      case FieldType.dateTime:
        final parsedDate = dateRule.parse(value);
        if (parsedDate == null) return (ok: false, value: null);
        return (
          ok: true,
          value: dateRule.toIsoString ? parsedDate.toIso8601String() : parsedDate,
        );

      case FieldType.list:
        if (value is List) return (ok: true, value: value);
        return (ok: false, value: null);

      case FieldType.map:
        if (value is Map) return (ok: true, value: Map<String, dynamic>.from(value));
        return (ok: false, value: null);

      case FieldType.dynamicType:
        return (ok: true, value: value);
    }
  }

  static dynamic _defaultFor(FieldType type, {DateRule? dateRule}) {
    switch (type) {
      case FieldType.string:
        return '';
      case FieldType.dateTime:
        return (dateRule?.toIsoString ?? true) ? '' : null;
      case FieldType.integer:
        return 0;
      case FieldType.decimal:
        return 0.0;
      case FieldType.boolean:
        return false;
      case FieldType.list:
        return <dynamic>[];
      case FieldType.map:
        return <String, dynamic>{};
      case FieldType.dynamicType:
        return null;
    }
  }

  static void _logSummary(
    void Function(String) log, {
    required List<AdaptedItem> items,
    required int totalRaw,
    required List<String> warnings,
  }) {
    final buffer = StringBuffer()
      ..writeln('[ApiAdapter] Diproses: ${items.length}/$totalRaw item');

    if (items.isNotEmpty) {
      final sample = items.first;
      buffer.writeln('  Field ditemukan : ${sample.foundFields.join(', ')}');
      if (sample.missingFields.isNotEmpty) {
        buffer.writeln('  Field hilang    : ${sample.missingFields.join(', ')}');
      }
      for (final t in sample.traces) {
        final warn = t.warning != null ? ' ⚠ ${t.warning}' : '';
        buffer.writeln(
          '  - ${t.targetField} <- "${t.sourcePath}" '
          '(${t.originalType} -> ${t.convertedType})$warn',
        );
      }

      // Cetak semua path key siap pakai untuk `article.extra('...')` (termasuk nested & list)
      final flat = <({String key, String lowerKey, String path, dynamic value})>[];
      _flattenEntries(sample.raw, '', flat);
      final extraKeys = flat
          .where((e) => e.value is! Map && e.value is! List)
          .map((e) => e.path)
          .toList();
      if (extraKeys.isNotEmpty) {
        buffer.writeln("  Key siap pakai di article.extra('...'): ${extraKeys.join(', ')}");
      }
    }
    for (final w in warnings) {
      buffer.writeln('  ⚠ $w');
    }
    log(buffer.toString().trimRight());
  }
}
