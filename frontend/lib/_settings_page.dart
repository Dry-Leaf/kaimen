import 'dart:ui';
import 'dart:io' show exit;
import 'dart:convert' show jsonEncode;

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:file_selector/file_selector.dart';

class MiscTab extends StatefulWidget {
  const MiscTab({super.key});

  @override
  State<MiscTab> createState() => _MiscTabState();
}

class _MiscTabState extends State<MiscTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    var config = Provider.of<Map<String, dynamic>>(context, listen: true);
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

/// Screen that shows an example of getDirectoryPath
class DirectoryTab extends StatelessWidget {
  /// Default Constructor
  const DirectoryTab({super.key});

  Future<void> _getDirectoryPath(BuildContext context) async {
    const String confirmButtonText = 'Choose';
    final String? directoryPath = await getDirectoryPath(
      confirmButtonText: confirmButtonText,
    );
    if (directoryPath == null) {
      // Operation was canceled by the user.
      return;
    }
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => TextDisplay(directoryPath),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    var config = Provider.of<Map<String, dynamic>>(context, listen: true);
    var dirs = config['DIRS'];

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color itemColor = colorScheme.primaryContainer;

    final List<Card> cards = <Card>[
      for (int index = 0; index < dirs.length; index += 1)
        Card(
          key: Key('$index'),
          color: itemColor,
          child: SizedBox(
            height: 60,
            width: 600,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    '${dirs[index]}',
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit), onPressed: () {}),
              ],
            ),
          ),
        ),
    ];

    return Scaffold(
      body: Center(
        child: cards.isEmpty
            ? const Text('Please add a directory to index.')
            : SizedBox(
                width: 600,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  children: cards,
                ),
              ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _getDirectoryPath(context);
        },
        tooltip: 'Add Directory',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Widget that displays a text file in a dialog
class TextDisplay extends StatelessWidget {
  const TextDisplay(this.directoryPath, {super.key});
  final String directoryPath;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selected Directory'),
      content: Scrollbar(
        child: SingleChildScrollView(child: Text(directoryPath)),
      ),
    );
  }
}

class SourceSettings extends StatefulWidget {
  final Map<String, dynamic> board;
  final WebSocketChannel? channel;
  const SourceSettings({required this.board, required this.channel, super.key});

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
              initialValue: widget.board["name"],
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
              onSaved: (v) => widget.board["name"] = v,
            ),
            TextFormField(
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
              onSaved: (v) => widget.board["login"] = v,
            ),
            TextFormField(
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
              onSaved: (v) => widget.board["api_key"] = v,
            ),
            TextFormField(
              initialValue: widget.board["url"],
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
              onSaved: (v) => widget.board["url"] = v,
            ),
            TextFormField(
              initialValue: widget.board["api_params"],
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
              onSaved: (v) => widget.board["api_params"] = v,
            ),
            TextFormField(
              initialValue: widget.board["tag_key"],
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
              onSaved: (v) => widget.board["tag_key"] = v,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _formKey.currentState!.save();
                      final message = {
                        'Type': "edit_source",
                        'Value': widget.board,
                      };
                      try {
                        final jsonString = jsonEncode(message);
                        widget.channel?.sink.add(jsonString);
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

class SourcesTab extends StatefulWidget {
  const SourcesTab({super.key});

  @override
  State<SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<SourcesTab> {
  late WebSocketChannel? channel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    channel = context.read<WebSocketChannel?>();
  }

  @override
  Widget build(BuildContext context) {
    var config = Provider.of<Map<String, dynamic>>(context, listen: true);
    var boards = config['boards'];

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
                    '${boards[index]["name"]}',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Map<String, dynamic> board = Map.of(boards[index]);
                    board['mode'] = "edit";
                    board['original_name'] = board['name'];
                    showDialog<void>(
                      context: context,
                      builder: (BuildContext context) =>
                          SourceSettings(board: board, channel: channel),
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
          final double animValue = Curves.easeInOutCubicEmphasized.transform(
            animation.value,
          );
          final double scale = lerpDouble(1, 1.02, animValue)!;
          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 300, // Keep the width same as original cards
              child:
                  child, // Use the passed-in child widget directly, NOT cards[index]
            ),
          );
        },
        child: child, // Pass the proxy child here to retain constraints
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
                  .map((board) => board['name'] as String)
                  .toList();
              final message = {'Type': "reorder_sources", 'Value': names};
              final jsonString = jsonEncode(message);
              channel?.sink.add(jsonString);
            },
            children: cards,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Map<String, String> newBoard = {
            'name': "",
            'url': "",
            'api_params': "",
            'tag_key': "",
            'api_key': "",
            'login': "",
            'mode': "create",
          };
          showDialog<void>(
            context: context,
            builder: (BuildContext context) =>
                SourceSettings(board: newBoard, channel: channel),
          );
        },
        tooltip: 'Add Source',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
