import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_api_client/export.dart';


part 'rest_client_provider.g.dart';

/// API base URL. Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api/v1',
);

@Riverpod(keepAlive: true)
Dio dio(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));
  return dio;
}

@Riverpod(keepAlive: true)
RestClient restClient(Ref ref) =>
    RestClient(ref.watch(dioProvider), baseUrl: apiBaseUrl);

@riverpod
ItemsClient itemsClient(Ref ref) => ref.watch(restClientProvider).items;

// newdomain:providers
