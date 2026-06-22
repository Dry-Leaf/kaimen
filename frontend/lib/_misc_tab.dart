import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_backend_conn.dart'
    show Conn, Message, connProvider, messageByTypeProvider;

class MiscTab extends ConsumerStatefulWidget {
  const MiscTab({super.key});

  @override
  ConsumerState<MiscTab> createState() => _MiscTabState();
}

class _MiscTabState extends ConsumerState<MiscTab> {
  late final Conn conn;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    conn = ref
        .read(connProvider)
        .maybeWhen(
          data: (conn) => conn,
          orElse: () => throw Exception('Connection not ready'),
        );
  }

  @override
  Widget build(BuildContext context) {
    AsyncValue<dynamic> config = ref.watch(
      messageByTypeProvider(Message.getconf),
    );

    return config.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
      data: (config) {
        bool ignoreCheck = config['Ignore_enabled'];
        bool inferredCheck = config['Inferred_enabled'];

        return Scaffold(
          body: Center(
            child: SizedBox(
              width: 250,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CheckboxListTile(
                      value: ignoreCheck,
                      onChanged: (bool? value) {
                        conn.send(Message.editignore, !ignoreCheck);
                      },
                      title: const Text("Ignore Unfound"),
                    ),
                    CheckboxListTile(
                      value: inferredCheck,
                      onChanged: (bool? value) {
                        conn.send(Message.editinferred, !inferredCheck);
                      },
                      title: const Text("Query Inferred Tags"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
