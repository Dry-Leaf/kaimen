import 'dart:io';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

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
  final priorHash = Queue<String>();
  int priorHashIndex = 0;

  @override
  void initState() {
    super.initState();
    hashController = TextEditingController();

    initSuggestions(3);
    final initialText = ref.read(tagInputTextProvider);
    textController.text = initialText;

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
      priorHash.addFirst(hashController.text);
      if (priorHash.length > 5) {
        priorHash.removeLast();
      }

      ref.read(tagInputTextProvider.notifier).update("");
      textController.clear();
      hashController.clear();
      conn.send(Message.gettags, value);
    }
  }

  KeyEventResult handleHashKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          priorHash.isNotEmpty) {
        hashController.text = priorHash.elementAt(priorHashIndex);
        priorHashIndex += 1;
        if (priorHashIndex > priorHash.length - 1) {
          priorHashIndex = 0;
        }
        hashController.selection = TextSelection.collapsed(
          offset: hashController.text.length,
        );
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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

  Table getInfoTable(dynamic infoData) {
    final Map<dynamic, dynamic> info = infoData is Map ? infoData : {};

    final Map<String, String> displayFields = {
      "Artist(s):": info["artists"]?.toString() ?? "",
      "Timestamp:": info["timestamp"]?.toString() ?? "",
      "Filename:": info["filename"]?.toString() ?? "",
      "Dimensions:": info["dimension"]?.toString() ?? "",
    };

    final List<TableRow> tableRows = [];
    displayFields.forEach((label, value) {
      if (value.isNotEmpty) {
        tableRows.add(
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SelectableText(value),
              ),
            ],
          ),
        );
      }
    });

    return Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      children: tableRows,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    ref.listen<AsyncValue<dynamic>>(messageByTypeProvider(Message.gettags), (
      previous,
      next,
    ) {
      next.whenData((data) {
        if (data != null && data["path"] != "n/a") {
          final String incomingTags = data["tags"] ?? "";
          final preservedText = ref.read(tagInputTextProvider);

          if (preservedText.isNotEmpty) {
            textController.text = preservedText;
          } else {
            textController.text = incomingTags;
          }
        }
      });
    });

    final AsyncValue<dynamic> info = ref.watch(
      messageByTypeProvider(Message.gettags),
    );

    var overPath = "";

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
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/settings');
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
              child: Focus(
                onFocusChange: (hasFocus) {
                  if (hasFocus) {
                    priorHashIndex = 0;
                  }
                },
                onKeyEvent: handleHashKeyEvent,
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

                overPath = lowerPath;

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

      floatingActionButton: Wrap(
        spacing: 16,
        children: [
          FloatingActionButton(
            foregroundColor: colorScheme.onSecondaryContainer,
            backgroundColor: colorScheme.surface,
            onPressed: () {
              final rawData = info.value;

              if (rawData == null || rawData["path"] == "n/a") {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No file data available to display.'),
                  ),
                );
                return;
              }
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 400,
                      maxWidth: 700,
                    ),
                    child: getInfoTable(rawData),
                  ),
                ),
              );
            },
            tooltip: 'File Info',
            child: const Icon(Icons.info_outline),
          ),
          FloatingActionButton(
            foregroundColor: colorScheme.onSecondaryContainer,
            backgroundColor: colorScheme.surface,
            onPressed: () => {conn.send(Message.openresults, overPath)},
            tooltip: 'Show in Folder',
            child: const Icon(Icons.folder_open),
          ),
          FloatingActionButton(
            onPressed: () => {sendInput(Message.sendtags)},
            tooltip: 'Save Changes',
            child: const Icon(Icons.save),
          ),
        ],
      ),
    );
  }
}
