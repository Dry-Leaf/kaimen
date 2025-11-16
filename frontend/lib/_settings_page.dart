import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_backend_conn.dart' show Conn, Message, connProvider;

import '_directory_tab.dart' show DirectoryTab;
import '_misc_tab.dart' show MiscTab;
import '_source_tab.dart' show SourcesTab;

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
