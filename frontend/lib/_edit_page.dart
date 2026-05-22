import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;

import '_video_player.dart' show DesktopFriendlyVideoPlayer;

class TagEditPage extends ConsumerStatefulWidget {
  const TagEditPage({super.key});

  @override
  ConsumerState<TagEditPage> createState() => _TagEditPageState();
}

class _TagEditPageState extends ConsumerState<TagEditPage> {
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
    var controller = TextEditingController();

    AsyncValue<dynamic> info = ref.watch(
      messageByTypeProvider(Message.gettags),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Tags'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, '/');
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              windowManager.hide();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 32.0, bottom: 40.0),
            child: SizedBox(
              width: 370,
              child: TextField(
                maxLength: 32,
                controller: controller,
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    conn.send(Message.gettags, value);
                  }
                },
                decoration: InputDecoration(
                  hintText: "e.g. 5a8420afd7ea4b3e4bbf4186c02570ee",
                  suffixIcon: IconButton(
                    onPressed: () {
                      conn.send(Message.gettags, controller.text);
                    },
                    icon: const Icon(Icons.tag),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 32.0, right: 32.0),
            child: info.when(
              loading: () => Text('No valid file selected.'),
              error: (err, stack) => Text('Error: $err'),
              data: (info) {
                if (info["path"] == "n/a") {
                  return Text('No valid file selected.');
                }

                final String path = info["path"] ?? "";
                final String lowerPath = path.toLowerCase();
                final bool isVideo =
                    lowerPath.endsWith('.mp4') ||
                    lowerPath.endsWith('.mov') ||
                    lowerPath.endsWith('.webm') ||
                    lowerPath.endsWith('.mkv');

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isVideo
                        ? DesktopFriendlyVideoPlayer(videoPath: path)
                        : Image.file(
                            File(path),
                            height: 300,
                            width: 300,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                          ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: TextFormField(
                          minLines: 13,
                          maxLines: 13,
                          key: ValueKey(info["path"]),
                          keyboardType: TextInputType.multiline,
                          initialValue: info["tags"],
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter tags here...',
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Save Changes',
        child: const Icon(Icons.save),
      ),
    );
  }
}
