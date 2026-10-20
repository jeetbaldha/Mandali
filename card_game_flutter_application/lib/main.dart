import 'package:flutter/material.dart';

import 'core/game_client.dart';
import 'ui/shell.dart';
import 'ui/motion.dart';
import 'ui/theme.dart';
import 'core/theme/brand.dart';
import 'core/audio/game_audio.dart';

import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
  unawaited(GameAudio.instance.initialize());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GameClient client;
  bool intro = true;
  @override
  void initState() {
    super.initState();
    client = GameClient();
    client.initialize();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => intro = false);
    });
  }

  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: GameAudio.instance,
    builder: (context, _) => MaterialApp(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      theme: mandaliTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              GameAudio.instance.reduceMotion,
        ),
        child: child!,
      ),
      home: intro ? const BrandSplash() : GameShell(client: client),
    ),
  );
}
