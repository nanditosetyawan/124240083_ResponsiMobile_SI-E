import 'package:http/http.dart' as http;
import '../core/api_adapter.dart';
import '../core/api_config.dart';
import '../core/api_gate.dart';
import '../models/article_model.dart';

/// Service penghubung antara [ApiConfig], [ApiGate], [ApiAdapter], dan [ArticleModel].
/// Signature lama [fetchList] dan [fetchDetail] dipertahankan agar Page lama tidak perlu diubah.
class ApiService {
  /// Ambil daftar artikel berdasarkan [type] (`"news"`, `"blogs"`, `"reports"`).
  static Future<List<ArticleModel>> fetchList(
    String type, {
    http.Client? client,
  }) async {
    final config = ApiConfig.getListEndpoint(type);
    final url = ApiConfig.buildUrl(config.path);

    final response = await ApiGate.request(
      url: url,
      method: config.method,
      headers: {...ApiConfig.defaultHeaders, ...config.headers},
      token: ApiConfig.authToken,
      queryParameters: config.queryParameters,
      body: config.body,
      timeout: ApiConfig.timeout,
      enableDebugLog: ApiConfig.enableDebugLog,
      client: client,
    );

    final adapted = ApiAdapter.autoAdaptList(
      response.data,
      listPath: config.listPath,
      overrides: config.fieldMapping,
      defaultBoolRule: ApiConfig.boolRule,
      defaultDateRule: ApiConfig.dateRule,
      enableDebugLog: ApiConfig.enableDebugLog,
    );

    return adapted.items
        .map(
          (item) => ArticleModel.fromJson(
            item.normalized,
            type: type,
            rawData: item.raw,
          ),
        )
        .toList();
  }

  /// Ambil detail satu artikel berdasarkan [type] dan [id].
  static Future<ArticleModel> fetchDetail(
    String type,
    int id, {
    http.Client? client,
  }) async {
    final config = ApiConfig.getDetailEndpoint(type, id);
    final url = ApiConfig.buildUrl(config.path);

    final response = await ApiGate.request(
      url: url,
      method: config.method,
      headers: {...ApiConfig.defaultHeaders, ...config.headers},
      token: ApiConfig.authToken,
      queryParameters: config.queryParameters,
      body: config.body,
      timeout: ApiConfig.timeout,
      enableDebugLog: ApiConfig.enableDebugLog,
      client: client,
    );

    final adapted = ApiAdapter.autoAdaptObject(
      response.data,
      objectPath: config.detailPath,
      overrides: config.fieldMapping,
      defaultBoolRule: ApiConfig.boolRule,
      defaultDateRule: ApiConfig.dateRule,
      enableDebugLog: ApiConfig.enableDebugLog,
    );

    return ArticleModel.fromJson(
      adapted.normalized,
      type: type,
      rawData: adapted.raw,
    );
  }

  /// Helper untuk membedah struktur JSON endpoint list yang sedang aktif di [ApiConfig].
  static Future<JsonInspectionResult> inspectListEndpoint(
    String type, {
    http.Client? client,
  }) {
    final config = ApiConfig.getListEndpoint(type);
    return ApiGate.inspectUrl(
      url: ApiConfig.buildUrl(config.path),
      method: config.method,
      headers: {...ApiConfig.defaultHeaders, ...config.headers},
      token: ApiConfig.authToken,
      queryParameters: config.queryParameters,
      body: config.body,
      client: client,
    );
  }
}
