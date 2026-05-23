import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

import '_backend_conn.dart' show Message, messageByTypeProvider;

import '_video_player.dart' show DesktopFriendlyVideoPlayer;
import "_search_box.dart" show WithSuggestions;
import '_suggestions.dart' show Suggestion, SuggestionList;

class TagInputText extends Notifier<String> {
  @override
  String build() => "";

  void update(String newText) => state = newText;
}

final tagInputTextProvider = NotifierProvider<TagInputText, String>(
  TagInputText.new,
);

class TagEditPage extends ConsumerStatefulWidget {
  const TagEditPage({super.key});

  @override
  ConsumerState createState() => _TagEditPageState();
}

class _TagEditPageState extends ConsumerState with WithSuggestions {
  late final TextEditingController hashController;

  @override
  void initState() {
    super.initState();
    hashController = TextEditingController();

    initSuggestions(3);

    textController.addListener(() {
      ref.read(tagInputTextProvider.notifier).update(textController.text);
    });
  }

  @override
  void dispose() {
    hashController.dispose();
    super.dispose();
  }

  void _onHashSubmitted(String value) {
    if (value.isNotEmpty) {
      ref.read(tagInputTextProvider.notifier).update("");
      textController.clear();
      hashController.clear();
      conn.send(Message.gettags, value);
    }
  }

  Widget createTextBox(dynamic info) {
    return OverlayPortal(
      controller: overlayController,
      overlayChildBuilder: (context) => UnconstrainedBox(
        child: CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, .5),
          child: ValueListenableBuilder<List<Suggestion>>(
            valueListenable: suggestions,
            builder: (context, currentSuggestions, _) {
              if (currentSuggestions.isEmpty) return const SizedBox.shrink();
              final double targetWidth = link.leaderSize?.width ?? 100.0;

              return SizedBox(
                width: targetWidth,
                height: suggestions.value.length * 27 + 2,
                child: SuggestionList(
                  suggestions,
                  textController,
                  textFieldFocusNode,
                  suggestionsFocusNode,
                ),
              );
            },
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: link,
        child: Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              priorIndex = 0;
            }
          },
          onKeyEvent: handleKeyEvent,
          child: TextFormField(
            focusNode: textFieldFocusNode,
            controller: textController,
            minLines: 9,
            maxLines: 9,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter tags here...',
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<dynamic> info = ref.watch(
      messageByTypeProvider(Message.gettags),
    );

    final preservedText = ref.watch(tagInputTextProvider);

    info.whenData((data) {
      if (data != null && data["path"] != "n/a") {
        final String incomingTags = data["tags"] ?? "";

        if (textController.text.isEmpty) {
          if (preservedText.isNotEmpty) {
            textController.text = preservedText;
          } else {
            textController.text = incomingTags;
          }
        }
      }
    });

    final autosuggestMessage = ref.watch(
      messageByTypeProvider(Message.autosuggest),
    );

    autosuggestMessage.when(
      data: (msg) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (msg == null) {
            suggestions.value = [];
            return;
          }

          final parsed = (msg as List)
              .map((e) => Suggestion.fromJson(e))
              .toList();

          suggestions.value = parsed;
        });
      },
      loading: () {},
      error: (_, _) {},
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
                controller: hashController,
                onSubmitted: _onHashSubmitted,
                decoration: InputDecoration(
                  hintText: "e.g. 5a8420afd7ea4b3e4bbf4186c02570ee",
                  suffixIcon: IconButton(
                    onPressed: () => _onHashSubmitted(hashController.text),
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
                            height: 335,
                            width: 335,
                            fit: BoxFit.contain,
                            alignment: Alignment.centerLeft,
                          ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10.0),
                        child: createTextBox(info),
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
        onPressed: () => {sendInput(Message.sendtags)},
        tooltip: 'Save Changes',
        child: const Icon(Icons.save),
      ),
    );
  }
}
