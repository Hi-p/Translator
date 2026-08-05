import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/theme/app_theme.dart';
import 'features/translation/translation_screen.dart';

import 'features/auth/auth_service.dart';
import 'features/auth/auth_modal.dart';
import 'features/premium/premium_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    MobileAds.instance.initialize();
  }

  final container = ProviderContainer();
  final authService = container.read(authServiceProvider);
  final session = await authService.getLoginSession();
  
  if (session != null) {
    container.read(userProvider.notifier).state = UserProfile(
      id: session.id,
      email: session.email,
      displayName: session.displayName,
    );
    container.read(isProUserProvider.notifier).state = session.isPro;
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PolyGlotApp(),
    ),
  );
}

class PolyGlotApp extends StatelessWidget {
  const PolyGlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PolyGlot AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const TranslationScreen(),
    );
  }
}
