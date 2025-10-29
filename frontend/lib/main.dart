import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '_search_page.dart' show SearchPage;
import '_settings_page.dart' show SettingsPage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const UI());
}

class UI extends StatelessWidget {
  const UI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      initialRoute: '/second',
      routes: {
        '/': (context) => const SearchPage(title: 'Search Page'),
        '/second': (context) => const SettingsPage(),
      },
    );
  }
}
