import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:toml/toml.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io' show exit;
import 'package:web_socket_channel/web_socket_channel.dart';

import '_search_page.dart' show SearchPage;
import '_settings_page.dart' show SettingsPage;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final directory = await getApplicationSupportDirectory();
  final confLocation = path.join(directory.path, 'config.toml');
  final document = await TomlDocument.load(confLocation);
  final config = document.toMap();

  debugPrint(config.toString());

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

  WebSocketChannel? channel;
  try {
    final socketPort = config['WEB_SOCKET_PORT'];
    channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:$socketPort/ws'),
    );
    await channel.ready;
  } catch (e) {
    debugPrint('Failed to connect to WebSocket: $e');
    exit(1);
  }

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: config),
        Provider.value(value: channel),
      ],
      child: const UI(),
    ),
  );
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
