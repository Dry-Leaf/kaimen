import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_backend_conn.dart' show Message, messageByTypeProvider;

class MiscTab extends ConsumerStatefulWidget {
  const MiscTab({super.key});

  @override
  ConsumerState<MiscTab> createState() => _MiscTabState();
}

class _MiscTabState extends ConsumerState<MiscTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    AsyncValue<dynamic> config = ref.watch(
      messageByTypeProvider(Message.getconf),
    );

    return config.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
      data: (config) {
        var wsp = config['WEB_SOCKET_PORT'];

        return Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextFormField(
                      initialValue: wsp,
                      decoration: const InputDecoration(
                        labelText: 'Web Socket Port',
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter some text';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            tooltip: 'Save',
            child: const Icon(Icons.save),
          ),
        );
      },
    );
  }
}
