import 'package:flutter/material.dart';

import 'package:file_selector/file_selector.dart';

class DirectorySettings extends StatelessWidget {
  const DirectorySettings({super.key});

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
    var config = context.watch<Map<String, dynamic>>();
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
