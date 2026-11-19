import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latres/core/api_adapter.dart';
import 'package:latres/core/api_config.dart';
import 'package:latres/core/api_gate.dart';
import 'package:latres/models/article_model.dart';
import 'package:latres/services/api_service.dart';

/// Model lama simulasi (Bagian 13) — tidak diubah ketika struktur API berubah drastis.
class _LegacyItemModel {
  final String nama;
  final int umur;
  final double harga;
  final Map<String, dynamic> rawData;

  const _LegacyItemModel({
    required this.nama,
    required this.umur,
    required this.harga,
    this.rawData = const {},
  });

  factory _LegacyItemModel.fromNormalized(AdaptedItem item) {
    return _LegacyItemModel(
      nama: item.normalized['nama'] as String,
      umur: item.normalized['umur'] as int,
      harga: item.normalized['harga'] as double,
      rawData: item.raw,
    );
  }
}

void main() {
  group('JsonInspector', () {
    test('membedah nested object, list, tipe data, dan panjang list tanpa asumsi key data', () {
      final sample = {
        'result': {
          'students': [
            {
              'student_name': 123,
              'student_age': '22',
              'academic': {'major': 'Teknik Mesin'},
            },
            {
              'student_name': 456,
              'student_age': '23',
              'academic': {'major': 'Informatika'},
            },
          ],
        },
      };

      final inspected = ApiGate.inspectJson(sample);
      final output = inspected.format();

      expect(output, contains('result: Object'));
      expect(output, contains('result.students: List (length: 2)'));
      expect(output, contains('result.students[0].student_name: int'));
      expect(output, contains('result.students[0].student_age: String'));
      expect(output, contains('result.students[0].academic: Object'));
      expect(output, contains('result.students[0].academic.major: String'));
      expect(inspected.listCounts['result.students'], 2);
    });

    test('mendukung response root berupa JSON Array', () {
      final rootList = [
        {'id': 1, 'title': 'A'},
        {'id': 2, 'title': 'B'},
      ];

      final inspected = ApiGate.inspectJson(rootList);
      expect(inspected.listCounts['<root>'], 2);
      expect(inspected.format(), contains('<root>: List (length: 2)'));
      expect(inspected.format(), contains('[0].title: String'));
    });
  });

  group('Type Conversion System', () {
    test('menangani seluruh konversi tipe dasar secara aman', () {
      expect(ApiAdapter.convertValue(123, FieldType.string), '123');
      expect(ApiAdapter.convertValue('22', FieldType.integer), 22);
      expect(ApiAdapter.convertValue(15, FieldType.decimal), 15.0);
      expect(ApiAdapter.convertValue('15000.50', FieldType.decimal), 15000.5);
      expect(ApiAdapter.convertValue(19.9, FieldType.integer), 19);
      expect(ApiAdapter.convertValue(1, FieldType.boolean), true);
      expect(ApiAdapter.convertValue(0, FieldType.boolean), false);
      expect(ApiAdapter.convertValue('true', FieldType.boolean), true);
      expect(ApiAdapter.convertValue('FALSE', FieldType.boolean), false);
      expect(
        ApiAdapter.convertValue(null, FieldType.string, defaultValue: 'N/A'),
        'N/A',
      );
      // Tidak menebak angka/string acak sebagai boolean
      expect(
        ApiAdapter.convertValue(42, FieldType.boolean, defaultValue: false),
        false,
      );
      expect(
        ApiAdapter.convertValue('bukan_angka', FieldType.integer, defaultValue: -1),
        -1,
      );
    });

    test('mendukung BoolRule dan DateRule yang dapat dikonfigurasi tanpa menebak timestamp', () {
      const customBool = BoolRule(
        trueValues: {'aktif', 'ya'},
        falseValues: {'nonaktif', 'tidak'},
      );
      expect(
        ApiAdapter.convertValue('AKTIF', FieldType.boolean, boolRule: customBool),
        true,
      );
      expect(
        ApiAdapter.convertValue('tidak', FieldType.boolean, boolRule: customBool),
        false,
      );

      // Default ISO 8601 TIDAK boleh menganggap angka sebagai timestamp
      expect(
        ApiAdapter.convertValue(1700000000, FieldType.dateTime, defaultValue: 'INVALID'),
        'INVALID',
      );

      // Hanya jika eksplisit epochSeconds
      final fromEpoch = ApiAdapter.convertValue(
        1700000000,
        FieldType.dateTime,
        dateRule: const DateRule(format: DateInputFormat.epochSeconds, isUtc: true),
      );
      expect(fromEpoch, '2023-11-14T22:13:20.000Z');

      // Format dd/MM/yyyy
      final fromDmy = ApiAdapter.convertValue(
        '18/11/2026 09:30',
        FieldType.dateTime,
        dateRule: const DateRule(format: DateInputFormat.dmySlash, isUtc: true),
      );
      expect(fromDmy, '2026-11-18T09:30:00.000Z');
    });
  });

  group('Simulasi Wajib: API Lama vs API Baru (Bagian 13)', () {
    test('API lama dan API baru menghasilkan format Model lama yang sama', () {
      final oldApiResponse = {
        'data': [
          {'nama': 'Budi', 'umur': 22, 'harga': 15000},
        ],
      };

      final newApiResponse = {
        'success': true,
        'result': {
          'items': [
            {
              'student_name': 12345,
              'student_age': '22',
              'product_price': '15000.50',
              'extra_note': 'field baru',
            },
          ],
        },
      };

      final oldRules = FieldMapping.fromSimple(
        {'nama': 'nama', 'umur': 'umur', 'harga': 'harga'},
        types: {
          'nama': FieldType.string,
          'umur': FieldType.integer,
          'harga': FieldType.decimal,
        },
      );

      final newRules = FieldMapping.fromSimple(
        {
          'nama': 'student_name',
          'umur': 'student_age',
          'harga': 'product_price',
        },
        types: {
          'nama': FieldType.string,
          'umur': FieldType.integer,
          'harga': FieldType.decimal,
        },
      );

      final oldAdapted = ApiAdapter.adaptList(
        oldApiResponse,
        listPath: 'data',
        rules: oldRules,
      );
      final newAdapted = ApiAdapter.adaptList(
        newApiResponse,
        listPath: 'result.items',
        rules: newRules,
      );

      final oldModel = _LegacyItemModel.fromNormalized(oldAdapted.items.first);
      final newModel = _LegacyItemModel.fromNormalized(newAdapted.items.first);

      // Keduanya langsung kompatibel dengan Model lama & Page lama
      expect(oldModel.nama, 'Budi');
      expect(oldModel.umur, 22);
      expect(oldModel.harga, 15000.0);

      expect(newModel.nama, '12345');
      expect(newModel.umur, 22);
      expect(newModel.harga, 15000.5);
      expect(newModel.rawData['extra_note'], 'field baru');
    });
  });

  group('Adaptasi ArticleModel & Skala Data Dinamis', () {
    test('memetakan API baru yang berbeda drastis ke ArticleModel lama tanpa ubah Model', () {
      final drasticNewApi = {
        'ok': true,
        'payload': {
          'records': [
            {
              'article_id': '901',
              'headline': 'Peluncuran Roket Terbaru',
              'links': {'official': 'https://example.com/roket'},
              'media': {'cover': 'https://example.com/img.jpg'},
              'author': {'agency': {'name': 'SpaceNews'}},
              'published_epoch': 1700000000,
              'meta': {'rating': 4.9, 'category': 'launch'},
              // summary sengaja hilang untuk menguji default value
            },
          ],
        },
      };

      const rules = <String, FieldMapping>{
        'id': FieldMapping('article_id', type: FieldType.integer, required: true),
        'title': FieldMapping('headline', type: FieldType.string, defaultValue: ''),
        'url': FieldMapping('links.official', type: FieldType.string, defaultValue: ''),
        'imageUrl': FieldMapping('media.cover', type: FieldType.string, defaultValue: ''),
        'newsSite': FieldMapping('author.agency.name', type: FieldType.string, defaultValue: 'Unknown'),
        'summary': FieldMapping('desc', type: FieldType.string, defaultValue: ''),
        'publishedAt': FieldMapping(
          'published_epoch',
          type: FieldType.dateTime,
          defaultValue: '',
          dateRule: DateRule(format: DateInputFormat.epochSeconds, isUtc: true),
        ),
      };

      final adapted = ApiAdapter.adaptList(
        drasticNewApi,
        listPath: 'payload.records',
        rules: rules,
      );

      final article = ArticleModel.fromJson(
        adapted.items.first.normalized,
        type: 'news',
        rawData: adapted.items.first.raw,
      );

      expect(article.id, 901);
      expect(article.title, 'Peluncuran Roket Terbaru');
      expect(article.url, 'https://example.com/roket');
      expect(article.imageUrl, 'https://example.com/img.jpg');
      expect(article.newsSite, 'SpaceNews');
      expect(article.summary, '');
      expect(article.publishedAt, '2023-11-14T22:13:20.000Z');
      expect(article.getExtra('meta.rating'), 4.9);

      // Pastikan toMap/fromMap tetap kompatibel dengan FavoriteService
      final restored = ArticleModel.fromMap(article.toMap());
      expect(restored.id, 901);
      expect(restored.getExtra('meta.category'), 'launch');
    });

    test('mendukung jumlah data dinamis (2, 100, 500 item)', () {
      const rules = {'nama': FieldMapping('n', type: FieldType.string)};

      for (final count in [2, 100, 500]) {
        final payload = List.generate(count, (i) => {'n': 'Item $i'});
        final adapted = ApiAdapter.adaptList(payload, listPath: '', rules: rules);
        expect(adapted.processedCount, count);
        expect(adapted.items.last.normalized['nama'], 'Item ${count - 1}');
      }
    });

    test('memberikan pesan error yang menyebut nama field bermasalah', () {
      const rules = {
        'id': FieldMapping('article_id', type: FieldType.integer, required: true),
      };

      expect(
        () => ApiAdapter.adaptObject({'other': 1}, rules: rules),
        throwsA(
          isA<ApiAdapterException>()
              .having((e) => e.field, 'field', 'id')
              .having((e) => e.sourcePath, 'sourcePath', 'article_id'),
        ),
      );
    });
  });

  group('ApiGate & ApiService Integration', () {
    test('ApiService.fetchList & fetchDetail bekerja dengan ApiGate + ApiAdapter', () async {
      final mockClient = MockClient((request) async {
        final isDetail = request.url.queryParameters['id'] == '77' ||
            request.url.path.contains('/77');
        if (!isDetail) {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 77,
                  'title': 'Berita Antariksa',
                  'url': 'https://space.example/77',
                  'image_url': 'https://space.example/77.png',
                  'news_site': 'NASA',
                  'summary': 'Ringkasan singkat',
                  'published_at': '2026-11-18T10:00:00Z',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'id': 77,
            'title': 'Detail Berita',
            'url': 'https://space.example/77',
            'image_url': 'https://space.example/77.png',
            'news_site': 'NASA',
            'summary': 'Detail lengkap',
            'published_at': '2026-11-18T10:00:00Z',
          }),
          200,
        );
      });

      final list = await ApiService.fetchList('news', client: mockClient);
      expect(list.length, 1);
      expect(list.first.id, 77);
      expect(list.first.newsSite, 'NASA');
      expect(list.first.type, 'news');

      final detail = await ApiService.fetchDetail('news', 77, client: mockClient);
      expect(detail.title, 'Detail Berita');
    });

    test('ApiGate mendukung POST, query params, redaksi token, error HTTP & JSON invalid', () async {
      final logs = <String>[];
      final mockClient = MockClient((request) async {
        if (request.url.path == '/create') {
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], 'Bearer rahasia_super');
          expect(request.url.queryParameters['page'], '2');
          return http.Response(
            jsonEncode({'status': 'ok', 'token': 'secret_resp_token', 'password': '123'}),
            201,
          );
        }
        if (request.url.path == '/invalid-json') {
          return http.Response('<html>Not JSON</html>', 200);
        }
        return http.Response(jsonEncode({'error': 'fail'}), 500);
      });

      final res = await ApiGate.request(
        url: 'https://api.example.com/create',
        method: HttpMethod.post,
        token: 'rahasia_super',
        queryParameters: {'page': 2},
        body: {'name': 'Dito'},
        enableDebugLog: true,
        logger: logs.add,
        client: mockClient,
      );
      expect(res.statusCode, 201);
      expect(logs.single, isNot(contains('rahasia_super')));
      expect(logs.single, isNot(contains('secret_resp_token')));
      expect(logs.single, contains('***REDACTED***'));

      await expectLater(
        () => ApiGate.request(url: 'https://api.example.com/invalid-json', client: mockClient),
        throwsA(isA<ApiGateException>()),
      );

      await expectLater(
        () => ApiGate.request(url: 'https://api.example.com/boom', client: mockClient),
        throwsA(isA<ApiGateException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });

  group('Mode Otomatis (Zero-Remap): Tanpa Edit Mapping', () {
    test('otomatis memetakan 3 API sangat berbeda (nested, root array, list dalam list, gambar dalam list)', () {
      // API 1: Wrapper nested + id String + gambar dalam List<String>
      final api1 = {
        'status': 'ok',
        'payload': {
          'posts': [
            {
              'post_id': '101',
              'headline': 'Roket Meluncur',
              'link': 'https://api1.com/p/101',
              'images': ['https://api1.com/img/cover-1.jpg', 'https://api1.com/img/2.jpg'],
              'writer': {'name': 'NASA'},
              'excerpt': 'Ringkasan API 1.',
              'created_at': '2026-11-18T09:30:00Z',
            },
          ],
        },
      };

      final res1 = ApiAdapter.autoAdaptList(api1);
      final a1 = ArticleModel.fromJson(res1.items.first.normalized, type: 'news', rawData: res1.items.first.raw);
      expect(a1.id, 101);
      expect(a1.title, 'Roket Meluncur');
      expect(a1.imageUrl, 'https://api1.com/img/cover-1.jpg');
      expect(a1.url, 'https://api1.com/p/101');
      expect(a1.newsSite, 'NASA');
      expect(a1.summary, 'Ringkasan API 1.');

      // API 2: Root Array + gambar dalam List<Object> + author dalam List<Object> + field summary hilang
      final api2 = [
        {
          'id': 205.0,
          'name': 'Blog Misi Mars',
          'web_url': 'https://api2.org/b/205',
          'media': {
            'gallery': [
              {'kind': 'thumb', 'src': 'https://api2.org/thumb/205.png'},
            ],
          },
          'authors': [
            {'profile': {'full_name': 'SpaceX Blog'}},
          ],
          'published_ts': 1700000000,
        },
      ];

      final res2 = ApiAdapter.autoAdaptList(api2);
      final a2 = ArticleModel.fromJson(res2.items.first.normalized, type: 'blogs', rawData: res2.items.first.raw);
      expect(a2.id, 205);
      expect(a2.title, 'Blog Misi Mars');
      expect(a2.imageUrl, 'https://api2.org/thumb/205.png');
      expect(a2.newsSite, 'SpaceX Blog');
      expect(a2.publishedAt, '2023-11-14T22:13:20.000Z');
      expect(a2.summary, '');

      // API 3: List di dalam List (2 kategori -> otomatis flatten jadi 3 item!) + gambar List 2D
      final api3 = {
        'result': {
          'categories': [
            {
              'category_name': 'ISS',
              'items': [
                {
                  'uid': 301,
                  'title': 'Laporan ISS 1',
                  'source_url': 'https://api3.io/r/301',
                  'photos': [
                    ['https://api3.io/p/301-small.jpg', 'https://api3.io/p/301-hd.jpg'],
                  ],
                  'agency': 'ESA',
                  'content': 'Isi laporan 1.',
                  'date': '2026-11-18T14:00:00Z',
                },
                {
                  'uid': 302,
                  'title': 'Laporan ISS 2',
                  'source_url': 'https://api3.io/r/302',
                  'photos': [['https://api3.io/p/302.jpg']],
                  'agency': 'JAXA',
                  'content': 'Isi laporan 2.',
                  'date': '2026-11-18T15:00:00Z',
                },
              ],
            },
            {
              'category_name': 'Lunar',
              'items': [
                {
                  'uid': 303,
                  'title': 'Laporan Bulan',
                  'source_url': 'https://api3.io/r/303',
                  'photos': [['https://api3.io/p/303.jpg']],
                  'agency': 'NASA',
                  'content': 'Isi laporan 3.',
                  'date': '2026-11-18T16:00:00Z',
                },
              ],
            },
          ],
        },
      };

      final res3 = ApiAdapter.autoAdaptList(api3);
      expect(res3.processedCount, 3);
      final a3 = ArticleModel.fromJson(res3.items.first.normalized, type: 'reports', rawData: res3.items.first.raw);
      expect(a3.id, 301);
      expect(a3.title, 'Laporan ISS 1');
      expect(a3.imageUrl, 'https://api3.io/p/301-small.jpg');
      expect(a3.newsSite, 'ESA');
      expect(a3.summary, 'Isi laporan 1.');
    });

    test('otomatis menangani format API praktikum populer (Jikan Anime & TheMealDB) + partial override', () {
      final jikan = {
        'data': [
          {
            'mal_id': 52991,
            'url': 'https://myanimelist.net/anime/52991',
            'images': {
              'jpg': {'image_url': 'https://cdn.myanimelist.net/images/anime/frieren.jpg'},
            },
            'title': 'Sousou no Frieren',
            'studios': [{'name': 'Madhouse'}],
            'synopsis': 'Kisah petualangan setelah mengalahkan Raja Iblis.',
            'aired': {'from': '2023-09-29T00:00:00+00:00'},
          },
        ],
      };

      final jikanAdapted = ApiAdapter.autoAdaptList(jikan);
      final anime = ArticleModel.fromJson(jikanAdapted.items.first.normalized, type: 'news');
      expect(anime.id, 52991);
      expect(anime.title, 'Sousou no Frieren');
      expect(anime.imageUrl, 'https://cdn.myanimelist.net/images/anime/frieren.jpg');
      expect(anime.newsSite, 'Madhouse');
      expect(anime.summary, contains('petualangan'));
      expect(anime.publishedAt, '2023-09-29T00:00:00+00:00');

      final mealDb = {
        'meals': [
          {
            'idMeal': '52772',
            'strMeal': 'Teriyaki Chicken',
            'strCategory': 'Chicken',
            'strInstructions': 'Masak ayam dengan saus teriyaki.',
            'strMealThumb': 'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg',
          },
        ],
      };

      // Partial override: hanya override 1 field, sisanya tetap otomatis!
      final mealAdapted = ApiAdapter.autoAdaptList(
        mealDb,
        overrides: const {
          'newsSite': FieldMapping('strCategory', type: FieldType.string),
        },
      );
      final meal = ArticleModel.fromJson(mealAdapted.items.first.normalized, type: 'blogs');
      expect(meal.id, 52772);
      expect(meal.title, 'Teriyaki Chicken');
      expect(meal.imageUrl, contains('themealdb.com'));
      expect(meal.newsSite, 'Chicken');
      expect(meal.summary, contains('teriyaki'));
    });

    test('otomatis menangani FreeToGame API dan API berbahasa Indonesia tanpa remap', () {
      final freeToGame = [
        {
          'id': 540,
          'title': 'Overwatch',
          'thumbnail': 'https://www.freetogame.com/g/540/thumbnail.jpg',
          'short_description':
              'A hero-focused first-person team shooter from Blizzard Entertainment.',
          'game_url': 'https://www.freetogame.com/open/overwatch',
          'genre': 'Shooter',
          'platform': 'PC (Windows)',
          'publisher': 'Activision Blizzard',
          'developer': 'Blizzard Entertainment',
          'release_date': '2022-10-04',
          'freetogame_profile_url': 'https://www.freetogame.com/overwatch',
        },
        {
          'id': 475,
          'title': 'Genshin Impact',
          'thumbnail': 'https://www.freetogame.com/g/475/thumbnail.jpg',
          'short_description': 'Open-world action RPG from miHoYo.',
          'game_url': 'https://www.freetogame.com/open/genshin-impact',
          'genre': 'Action RPG',
          'platform': 'PC (Windows)',
          'publisher': 'miHoYo',
          'developer': 'miHoYo',
          'release_date': '2020-09-28',
          'freetogame_profile_url': 'https://www.freetogame.com/genshin-impact',
        },
      ];

      final gameAdapted = ApiAdapter.autoAdaptList(freeToGame);
      expect(gameAdapted.processedCount, 2);
      final g1 = ArticleModel.fromJson(
        gameAdapted.items.first.normalized,
        type: 'news',
        rawData: gameAdapted.items.first.raw,
      );
      expect(g1.id, 540);
      expect(g1.title, 'Overwatch');
      expect(g1.imageUrl, 'https://www.freetogame.com/g/540/thumbnail.jpg');
      expect(g1.url, 'https://www.freetogame.com/open/overwatch');
      expect(g1.newsSite, 'Activision Blizzard');
      expect(g1.summary, contains('Blizzard Entertainment'));
      expect(g1.publishedAt, '2022-10-04');
      expect(g1.getExtra('genre'), 'Shooter');

      final apiIndonesia = {
        'daftar_wisata': [
          {
            'kode_wisata': 'W-01',
            'nama_tempat': 'Candi Borobudur',
            'foto_sampul': ['https://wisata.id/borobudur.jpg'],
            'situs_resmi': 'https://borobudurpark.com',
            'provinsi': 'Jawa Tengah',
            'deskripsi_singkat': 'Candi Buddha terbesar di dunia di Magelang.',
            'tanggal_diperbarui': '2026-11-18',
          },
        ],
      };

      final idnAdapted = ApiAdapter.autoAdaptList(apiIndonesia);
      final w1 = ArticleModel.fromJson(
        idnAdapted.items.first.normalized,
        type: 'reports',
        rawData: idnAdapted.items.first.raw,
      );
      expect(w1.id, isPositive);
      expect(w1.title, 'Candi Borobudur');
      expect(w1.imageUrl, 'https://wisata.id/borobudur.jpg');
      expect(w1.url, 'https://borobudurpark.com');
      expect(w1.newsSite, 'Jawa Tengah');
      expect(w1.summary, 'Candi Buddha terbesar di dunia di Magelang.');
      expect(w1.publishedAt, '2026-11-18');
    });

    test('resolveDetailUrl menangkap semua gaya placeholder ID tanpa merusak port/skema URL', () {
      expect(
        ApiConfig.resolveDetailUrl('https://www.freetogame.com/api/game?id={game_id}', 540),
        'https://www.freetogame.com/api/game?id=540',
      );
      expect(
        ApiConfig.resolveDetailUrl('https://api.example.com:8080/items/{{item_id}}', 9),
        'https://api.example.com:8080/items/9',
      );
      expect(
        ApiConfig.resolveDetailUrl('https://api.example.com:8080/movies/:movie_id', 42),
        'https://api.example.com:8080/movies/42',
      );
      expect(
        ApiConfig.resolveDetailUrl('https://api.example.com/posts/<int:post_id>', 7),
        'https://api.example.com/posts/7',
      );
      expect(
        ApiConfig.resolveDetailUrl('https://api.example.com/products/[slug]', 12),
        'https://api.example.com/products/12',
      );
      expect(
        ApiConfig.resolveDetailUrl('https://api.example.com/game?id=\${id}', 55),
        'https://api.example.com/game?id=55',
      );
      expect(
        ApiConfig.resolveDetailUrl('https://api.example.com/game?id=\$game_id', 55),
        'https://api.example.com/game?id=55',
      );
      expect(
        ApiConfig.resolveDetailUrl('https://api.example.com/game?id=', 540),
        'https://api.example.com/game?id=540',
      );
    });

    test('otomatis memetakan bidang kuliner, alat tulis, luar angkasa (NASA), dan buah (Indo + Inggris)', () {
      // 1. Kuliner Indonesia
      final kuliner = [
        {
          'id_kuliner': 11,
          'nama_hidangan': 'Gudeg Jogja',
          'foto_makanan': 'https://kuliner.id/gudeg.jpg',
          'asal_daerah': 'Yogyakarta',
          'cara_masak': 'Nangka muda dimasak santan dan gula aren.',
          'link_resep': 'https://kuliner.id/resep/gudeg',
          'tanggal_dibuat': '2026-05-01',
        },
      ];
      final k = ArticleModel.fromJson(ApiAdapter.autoAdaptList(kuliner).items.first.normalized, type: 'news');
      expect(k.id, 11);
      expect(k.title, 'Gudeg Jogja');
      expect(k.imageUrl, 'https://kuliner.id/gudeg.jpg');
      expect(k.newsSite, 'Yogyakarta');
      expect(k.summary, contains('Nangka muda'));

      // 2. Alat Tulis (ATK)
      final atk = {
        'katalog': [
          {
            'kode_atk': 'ATK-88',
            'nama_alat_tulis': 'Pulpen Gel 0.5mm',
            'gambar_produk': 'https://atk.id/pulpen.png',
            'merek': 'Joyko',
            'spesifikasi_barang': 'Tinta hitam cepat kering dan nyaman digenggam.',
            'tanggal_produksi': '2026-01-10',
          },
        ],
      };
      final a = ArticleModel.fromJson(ApiAdapter.autoAdaptList(atk).items.first.normalized, type: 'news');
      expect(a.title, 'Pulpen Gel 0.5mm');
      expect(a.imageUrl, 'https://atk.id/pulpen.png');
      expect(a.newsSite, 'Joyko');
      expect(a.summary, contains('Tinta hitam'));
      expect(a.publishedAt, '2026-01-10');

      // 3. Luar Angkasa (NASA APOD style)
      final nasa = [
        {
          'title': 'Pillars of Creation',
          'hdurl': 'https://apod.nasa.gov/pillars.jpg',
          'explanation': 'Giant columns of interstellar gas and dust in the Eagle Nebula.',
          'copyright': 'NASA Webb',
          'date': '2026-10-19',
        },
      ];
      final n = ArticleModel.fromJson(ApiAdapter.autoAdaptList(nasa).items.first.normalized, type: 'news');
      expect(n.title, 'Pillars of Creation');
      expect(n.imageUrl, 'https://apod.nasa.gov/pillars.jpg');
      expect(n.newsSite, 'NASA Webb');
      expect(n.summary, contains('Eagle Nebula'));
      expect(n.publishedAt, '2026-10-19');

      // 4. Buah (Fruityvice + Indonesia)
      final buah = [
        {
          'id_buah': 7,
          'nama_buah': 'Mangga Harum Manis',
          'foto_buah': 'https://buah.id/mangga.jpg',
          'famili': 'Anacardiaceae',
          'manfaat_buah': 'Kaya vitamin C dan serat untuk daya tahan tubuh.',
          'tanggal_panen': '2026-09-12',
        },
      ];
      final b = ArticleModel.fromJson(ApiAdapter.autoAdaptList(buah).items.first.normalized, type: 'news');
      expect(b.id, 7);
      expect(b.title, 'Mangga Harum Manis');
      expect(b.imageUrl, 'https://buah.id/mangga.jpg');
      expect(b.newsSite, 'Anacardiaceae');
      expect(b.summary, contains('vitamin C'));
      expect(b.publishedAt, '2026-09-12');
    });
  });
}

