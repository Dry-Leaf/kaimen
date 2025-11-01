import 'dart:ui';
import 'dart:io' show exit;

import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

class MiscTab extends StatefulWidget {
  const MiscTab({super.key});

  @override
  State<MiscTab> createState() => _MiscTabState();
}

class _MiscTabState extends State<MiscTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    var config = Provider.of<Map<String, dynamic>>(context, listen: false);
    var wsp = config['WEB_SOCKET_PORT'];

    return Center(
      child: SizedBox(
        width: 200,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                initialValue: wsp,
                decoration: const InputDecoration(hintText: 'Web Socket Port'),
                validator: (String? value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: ElevatedButton(
                  onPressed: () {
                    // Validate will return true if the form is valid, or false if
                    // the form is invalid.
                    if (_formKey.currentState!.validate()) {
                      // Process data.
                    }
                  },
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen that shows an example of getDirectoryPath
class DirectoryTab extends StatelessWidget {
  /// Default Constructor
  DirectoryTab({super.key});

  final bool _isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

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
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _isIOS ? null : () => _getDirectoryPath(context),
              child: const Text('Press to ask user to choose a directory.'),
            ),
          ],
        ),
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

class SourcesTab extends StatefulWidget {
  const SourcesTab({super.key});

  @override
  State<SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<SourcesTab> {
  @override
  Widget build(BuildContext context) {
    var config = Provider.of<Map<String, dynamic>>(context, listen: false);
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
            width: 400,
            child: Center(child: Text('${boards[index]["name"]}')),
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
              width: 400, // Keep the width same as original cards
              child:
                  child, // Use the passed-in child widget directly, NOT cards[index]
            ),
          );
        },
        child: child, // Pass the proxy child here to retain constraints
      );
    }

    return Center(
      child: SizedBox(
        width: 400, // This sets the overall width of the list area to 400px
        child: ReorderableListView(
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
          },
          children: cards,
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
