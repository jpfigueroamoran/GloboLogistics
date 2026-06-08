import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'demo/demo_providers.dart';
import 'presentation/app/app.dart';

/// Entry point de DEMO — sin Firebase, sin GetIt.
/// Ejecutar con: flutter run -d chrome -t lib/main_demo.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    ProviderScope(
      overrides: demoOverrides,
      child: const GloboApp(),
    ),
  );
}
