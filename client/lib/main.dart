import 'package:flutter/material.dart';
import 'app/app.dart';
import 'shared/api_client.dart';
import 'shared/config.dart';
import 'shared/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = SessionStorage();
  final apiClient = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
  );

  runApp(AIHelpdeskApp(
    apiClient: apiClient,
    storage: storage,
  ));
}
