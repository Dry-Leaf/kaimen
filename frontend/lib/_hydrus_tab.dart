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

  var hydrusForm = {'URL': "", 'ACCESS_KEY': "", "ENABLED": false};
  bool? _hydrusCheck;

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

    ref.listen(messageByTypeProvider(Message.updatestatus), (previous, next) {
      next.whenData((status) {
        if (!status[1]) {
          setState(() {
            _hydrusCheck = false;
          });
        }
      });
    });

    return config.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
      data: (config) {
        _hydrusCheck ??= config['Hydrus_conf']['ENABLED'];
        String hydrusURL = config['Hydrus_conf']['URL'];
        String hydrusAK = config['Hydrus_conf']['ACCESS_KEY'];
        return Scaffold(
          body: Center(
            child: SizedBox(
              width: 250,
              child: Form(
                key: _formKey,
                child: Column(
                  spacing: 16.0,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CheckboxListTile(
                      value: _hydrusCheck,
                      onChanged: (bool? value) {
                        setState(() {
                          _hydrusCheck = value ?? false;
                          hydrusForm["ENABLED"] = value ?? false;
                        });
                      },
                      title: const Text("Hydrus Enabled"),
                    ),
                    TextFormField(
                      initialValue: hydrusURL,
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
                      onSaved: (v) => hydrusForm["URL"] = v ?? "",
                    ),
                    TextFormField(
                      initialValue: hydrusAK,
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
                      onSaved: (v) => hydrusForm["ACCESS_KEY"] = v ?? "",
                    ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
              } else {
                return;
              }

              try {
                conn.send(Message.edithydrus, hydrusForm);
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
