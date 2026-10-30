import 'package:flutter/material.dart';

import 'state/app_controller.dart';
import 'services/local_store.dart';
import 'theme/app_theme.dart';
import 'ui/app_shell.dart';
import 'ui/pairing_flow.dart';
import 'ui/supabase_setup.dart';

class MusicListenApp extends StatefulWidget {
  const MusicListenApp({super.key, this.controller});

  final AppController? controller;

  @override
  State<MusicListenApp> createState() => _MusicListenAppState();
}

class _MusicListenAppState extends State<MusicListenApp> {
  late final AppController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? AppController(LocalStore());
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Music App',
          theme: AppTheme.build(),
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _buildCurrentScreen(),
          ),
        );
      },
    );
  }

  Widget _buildCurrentScreen() {
    if (!_controller.isReady) {
      return const LoadingScreen(key: ValueKey('loading'));
    }

    if (!_controller.hasSupabaseCredentials) {
      return SupabaseSetupScreen(
        key: const ValueKey('supabase_setup'),
        controller: _controller,
      );
    }

    // Pairing is optional — users can use the app solo.
    // The celebration screen appears as a top-level overlay when pairing completes.
    if (_controller.showConnectionCelebration) {
      return ConnectionSuccessScreen(
        key: const ValueKey('connected'),
        controller: _controller,
      );
    }

    return AppShell(key: const ValueKey('shell'), controller: _controller);
  }
}
