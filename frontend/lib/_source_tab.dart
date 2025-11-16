import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_backend_conn.dart' show Conn, Message, connProvider;
import '_conf.dart' show configProvider;

class SourceSettings extends StatefulWidget {
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
  State<SourceSettings> createState() => _SourceSettingsState();
}

/// Widget that displays a text file in a dialog
class _SourceSettingsState extends State<SourceSettings> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Source Settings'),
      constraints: const BoxConstraints(maxWidth: 500.0, minWidth: 500.0),
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

class SourcesTab extends ConsumerStatefulWidget {
  const SourcesTab({super.key});

  @override
  ConsumerState<SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends ConsumerState<SourcesTab> {
  late final Conn conn;

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
    AsyncValue<Map<String, dynamic>> config = ref.watch(configProvider);

    return config.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
      data: (config) {
        var boards = config['boards'];
        debugPrint(boards.toString());

        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        final Color itemColor = colorScheme.primaryContainer;

        final List<Card> cards = <Card>[
          for (int index = 0; index < boards.length; index += 1)
            Card(
              key: Key('$index'),
              color: itemColor,
              child: SizedBox(
                height: 60,
                width: 300,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        '${boards[index]["NAME"]}',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Map<String, dynamic> board = Map.of(boards[index]);
                        board['ORIGINAL_NAME'] = board['NAME'];
                        showDialog<void>(
                          context: context,
                          builder: (BuildContext context) => SourceSettings(
                            board: board,
                            mode: Message.editsource,
                            conn: conn,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ];

        Widget proxyDecorator(
          Widget child,
          int index,
          Animation<double> animation,
        ) {
          return AnimatedBuilder(
            animation: animation,
            builder: (BuildContext context, Widget? child) {
              final double animValue = Curves.easeInOutCubicEmphasized
                  .transform(animation.value);
              final double scale = lerpDouble(1, 1.02, animValue)!;
              return Transform.scale(
                scale: scale,
                child: SizedBox(width: 300, child: child),
              );
            },
            child: child,
          );
        }

        return Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ReorderableListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 40),
                proxyDecorator: proxyDecorator,
                onReorder: (int oldIndex, int newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = boards.removeAt(oldIndex);
                    boards.insert(newIndex, item);
                  });
                  List<dynamic> names = boards
                      .map((board) => board['NAME'] as String)
                      .toList();
                  conn.send(Message.reordersources, names);
                },
                children: cards,
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
              showDialog<void>(
                context: context,
                builder: (BuildContext context) => SourceSettings(
                  board: newBoard,
                  mode: Message.createsource,
                  conn: conn,
                ),
              );
            },
            tooltip: 'Add Source',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
