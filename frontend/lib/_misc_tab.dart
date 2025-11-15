import 'package:flutter/material.dart';

class MiscSettings extends StatefulWidget {
  const MiscSettings({super.key});

  @override
  State<MiscSettings> createState() => _MiscSettingsState();
}

class _MiscSettingsState extends State<MiscSettings> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    var config = context.watch<Map<String, dynamic>>();
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
  }
}
