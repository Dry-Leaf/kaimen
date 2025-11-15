import 'dart:ui';
import 'dart:io' show exit;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:toml/toml.dart';

import 'package:file_selector/file_selector.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late WebSocketChannel? channel;

  @override
  void didChangeDependencies() {
    debugPrint("ENTERRRR");
    super.didChangeDependencies();
    channel = context.read<WebSocketChannel?>();
  }

  // Future<void> _listen() async {
  //   channel!.stream.listen((data) async {
  //     final message = jsonDecode(data);
  //     debugPrint(message['Type']);
  //     switch (message['Type']) {
  //       case 'update_conf':
  //         final directory = await getApplicationSupportDirectory();
  //         final confLocation = path.join(directory.path, 'config.toml');
  //         final document = await TomlDocument.load(confLocation);
  //         final newConfig = document.toMap();

  //         configNotifier.value = newConfig;
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(text: "Directories"),
              Tab(text: "Sources"),
              Tab(text: "Misc"),
            ],
          ),
          title: const Text('Settings'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                exit(0);
              },
            ),
          ],
        ),
        body: TabBarView(children: [DirectoryTab(), SourcesTab(), MiscTab()]),
      ),
    );
  }
}
