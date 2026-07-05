import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_backend_conn.dart'
    show Conn, Message, connProvider, messageByTypeProvider;

class HydrusTab extends ConsumerStatefulWidget {
  const HydrusTab({super.key});

  @override
  ConsumerState<HydrusTab> createState() => _HydrusTabState();
}

class _HydrusTabState extends ConsumerState<HydrusTab> {
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
        bool hydrusCheck = false; //config['Hydrus_enabled'];

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
                      value: hydrusCheck,
                      onChanged: (bool? value) {
                        hydrusCheck = !hydrusCheck;
                      },
                      title: const Text("Hydrus Enabled"),
                    ),
                    TextFormField(
                      initialValue: "http://127.0.0.1:45869",
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'URL input missing';
                        }
                        return null;
                      },
                      onSaved: (v) => {},
                    ),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Access Key',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Access Key input missing';
                        }
                        return null;
                      },
                      onSaved: (v) => {},
                    ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Map<String, String> newBoard = {
                'NAME': "",
                'URL': "",
                'API_PARAMS': "",
                'TAG_KEY': "",
                'API_KEY': "",
                'LOGIN': "",
              };
              try {
                conn.send(Message.createsource, newBoard);
              } catch (e) {
                debugPrint('Failed to encode/send message: $e');
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Invalid data: $e')));
              }
            },
            tooltip: 'Save Hydrus Settings',
            child: const Icon(Icons.save),
          ),
        );
      },
    );
  }
}
