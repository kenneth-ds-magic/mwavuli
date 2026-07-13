import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_state.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/offline/sync_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const ProviderScope(child: MwavuliApp()));
}

class MwavuliApp extends ConsumerWidget {
  const MwavuliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highContrast = ref.watch(highContrastProvider);
    final largeText = ref.watch(largeTextProvider);
    final router = ref.watch(routerProvider);
    ref.watch(syncControllerProvider); // bind connectivity → offline flag + flush

    return MaterialApp.router(
      title: 'mwavuli',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(highContrast: highContrast),
      routerConfig: router,
      builder: (context, child) {
        // Honour the app "larger text" toggle on top of the OS text scale,
        // clamped so layouts never break (WCAG 1.4.4).
        final osScale = MediaQuery.textScalerOf(context).scale(1.0);
        final double scale =
            (largeText ? osScale * 1.15 : osScale).clamp(0.9, 1.6).toDouble();
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
    );
  }
}
