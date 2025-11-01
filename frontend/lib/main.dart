import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:toml/toml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import '_search_page.dart' show SearchPage;
import '_settings_page.dart' show SettingsPage;

void main() async {
  final directory = await getApplicationSupportDirectory();
  final confLocation = path.join(directory.path, 'config.toml');
  final document = await TomlDocument.load(confLocation);
  final config = document.toMap();

  debugPrint(config.toString());

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

  runApp(Provider.value(value: config, child: const UI()));
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
      initialRoute: '/settings',
      routes: {
        '/': (context) => const SearchPage(title: 'Search Page'),
        '/settings': (context) => SettingsPage(),
      },
    );
  }
}
