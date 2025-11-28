import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_souce_settings.dart' show SourceSettings;
import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;

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
    AsyncValue<dynamic> config = ref.watch(
      messageByTypeProvider(Message.getconf),
    );

    return config.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
      data: (config) {
        var boards = config['Boards'];
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
                    Row(
                      children: [
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
                        IconButton(
                          icon: const Icon(Icons.delete),
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
