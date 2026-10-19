import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'app/monee_app.dart';
import 'app/startup_error_app.dart';
import 'data/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

Future<void> _start() async {
  try {
    final store = await openAppDataStore();

    runApp(
      MonneeApp(dependencies: AppDependencies.create(store: store)),
    );
  } catch (_) {
    runApp(StartupErrorApp(onRetry: _start));
  }
}