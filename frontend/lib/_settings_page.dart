import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;

import '_directory_tab.dart' show DirectoryTab;
import '_misc_tab.dart' show MiscTab;
import '_source_tab.dart' show SourcesTab;
import '_tags_tab.dart' show TagsTab;
import '_hydrus_tab.dart' show HydrusTab;

import 'main.dart' show Winop;

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final Conn conn;

  @override
  void initState() {
    super.initState();

    ref.listenManual<AsyncValue<Conn>>(
      connProvider,
      (prev, next) => next.whenData((c) => c.send(Message.getconf, '')),
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(messageByTypeProvider(Message.updatestatus), (previous, next) {
      next.whenData((status) {
        final String msg = status[0];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(content: Text(msg)),
        );
      });
    });

    return DefaultTabController(
      animationDuration: Duration.zero,
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(text: "Directories"),
              Tab(text: "Sources"),
              Tab(text: "Tags"),
              Tab(text: "Hydrus"),
              Tab(text: "Misc"),
            ],
          ),
          title: const Text('Settings'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
            IconButton(
              tooltip: 'Edit Tags',
              icon: const Icon(Icons.sell),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/tagedit');
              },
            ),
            Winop(),
          ],
        ),
        body: TabBarView(
          children: [
            DirectoryTab(),
            SourcesTab(),
            TagsTab(),
            HydrusTab(),
            MiscTab(),
          ],
        ),
      ),
    );
  }
}
