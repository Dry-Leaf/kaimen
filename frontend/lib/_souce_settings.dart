import 'package:flutter/material.dart';

import '_backend_conn.dart' show Conn, Message, messageByTypeProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SourceSettings extends ConsumerStatefulWidget {
  final Map<String, dynamic> board;
  final Message mode;
  final Conn conn;
  const SourceSettings({
    required this.board,
    required this.mode,
    required this.conn,
    super.key,
  });

  @override
  ConsumerState<SourceSettings> createState() => _SourceSettingsState();
}

/// Widget that displays a text file in a dialog
class _SourceSettingsState extends ConsumerState<SourceSettings> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    ref.listen(messageByTypeProvider(Message.updatestatus), (previous, next) {
      next.whenData((status) {
        final String msg;
        if (status[0]) {
          msg = "Changes successfully saved.";
        } else {
          msg = "Invalid input. Changes Discarded.";
        }
        showDialog(
          context: context,
          builder: (context) => AlertDialog(content: Text(msg)),
        );
      });
    });

    return AlertDialog(
      title: const Text('Source Settings'),
      content: Form(
        key: _formKey,
        child: Column(
          spacing: 16.0,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            TextFormField(
              initialValue: widget.board["NAME"],
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
              onSaved: (v) => widget.board["NAME"] = v,
            ),
            TextFormField(
              initialValue: widget.board["LOGIN"],
              decoration: const InputDecoration(
                labelText: 'Login',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
              onSaved: (v) => widget.board["LOGIN"] = v,
            ),
            TextFormField(
              initialValue: widget.board["API_KEY"],
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
              onSaved: (v) => widget.board["API_KEY"] = v,
            ),
            TextFormField(
              initialValue: widget.board["URL"],
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
              onSaved: (v) => widget.board["URL"] = v,
            ),
            TextFormField(
              initialValue: widget.board["API_PARAMS"],
              decoration: const InputDecoration(
                labelText: 'API Query string',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
              onSaved: (v) => widget.board["API_PARAMS"] = v,
            ),
            TextFormField(
              initialValue: widget.board["TAG_KEY"],
              decoration: const InputDecoration(
                labelText: 'JSON Tag Key',
                border: OutlineInputBorder(),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
              onSaved: (v) => widget.board["TAG_KEY"] = v,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop('dialog');
                      _formKey.currentState!.save();
                      try {
                        widget.conn.send(widget.mode, widget.board);
                      } catch (e) {
                        debugPrint('Failed to encode/send message: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Invalid data: $e')),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).pop('dialog');
                    },
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
