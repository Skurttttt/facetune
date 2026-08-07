import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({this.debugShowCheckedModeBanner = false});

  final bool debugShowCheckedModeBanner;
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());
