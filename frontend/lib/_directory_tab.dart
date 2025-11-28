import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:file_selector/file_selector.dart';

import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;

class DirectoryTab extends ConsumerStatefulWidget {
  const DirectoryTab({super.key});

  @override
  ConsumerState<DirectoryTab> createState() => _DirectoryTabState();
}

class _DirectoryTabState extends ConsumerState<DirectoryTab> {
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
      conn.send(Message.newdirectory, directoryPath);
    }
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
        debugPrint("WHAT I HAVE");
        debugPrint(config.toString());

        debugPrint("WHAT I HAVE");
        debugPrint(config.keys.toString());

        var dirs = config['Dirs'];

        debugPrint("WHAT I HAVE DIRS");
        debugPrint(dirs.toString());

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
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Tooltip(
                          message: '${dirs[index]}',
                          child: Text(
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            '${dirs[index]}',
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            _getDirectoryPath(context);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            _getDirectoryPath(context);
                          },
                        ),
                      ],
                    ),
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
      },
    );
  }
}
