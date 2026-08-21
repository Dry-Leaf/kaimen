import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_suggestions.dart' show Suggestion, SuggestionList;

import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;

enum HydrusSortOrder(final String label) {
  fileSize("File Size"),
  duration("Duration"),
  importTime("Import Time (Default)"),
  filetype("File Type"),
  random("Random"),
  width("Width"),
  height("Height"),
  ratio("Ratio"),
  numberOfPixels("Number Of Pixels"),
  numberOfTags("Number Of Tags"),
  numberOfMediaViews("Number Of Media Views"),
  totalMediaViewtime("Total Media Viewtime"),
  approximateBitrate("Approximate Bitrate"),
  hasAudio("Has Audio"),
  modifiedTime("Modified Time"),
  framerate("Framerate"),
  numberOfFrames("Number Of Frames"),
  numberOfCollectionFiles("Size of Collection"),
  lastViewedTime("Last Viewed Time"),
  archiveTimestamp("Archive Timestamp"),
  hashHex("Hash Hex"),
  pixelHashHex("Pixel Hash Hex"),
  blurhash("Blurhash"),
  averageColourL("Average Colour (Light)"),
  averageColourC("Average Colour (Chromatic)"),
  averageColourGR("Average Colour (Green/Red Axis)"),
  averageColourBY("Average Colour (Blue/Yellow Axis)"),
  averageColourH("Average Colour (Hue)")
}

mixin WithSuggestions on ConsumerState {
  final textController = TextEditingController();
  String priorText = "";
  int priorCursor = 0;
  late final Conn conn;

  final FocusNode textFieldFocusNode = FocusNode();
  final FocusNode suggestionsFocusNode = FocusNode();

  late final ValueNotifier<List<Suggestion>> suggestions;
  final overlayController = OverlayPortalController();

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  void initSuggestions([int suggLimit = 10, int minsugg = 1]) {
    suggestions = ValueNotifier<List<Suggestion>>([]);

    conn = ref.read(connProvider).requireValue;

    textController.addListener(() => autoSuggestReq(suggLimit, minsugg));
    textFieldFocusNode.addListener(updateVisibilityChange);
    suggestions.addListener(updateVisibilityChange);
    textController.addListener(updateVisibilityChange);
    suggestionsFocusNode.addListener(updateVisibilityChange);
  }

  void autoSuggestReq(int suggLimit, int minsugg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (textController.text.isNotEmpty && textFieldFocusNode.hasFocus) {
        if (textController.text == priorText &&
            textController.selection.baseOffset == priorCursor) {
          return;
        }
        setState(() {
          priorText = textController.text;
          priorCursor = textController.selection.baseOffset;
        });
        conn.send(Message.autosuggest, [
          textController.text,
          textController.selection.baseOffset,
          minsugg,
          suggLimit,
        ]);
      }
    });
  }

  void updateVisibilityChange() {
    final tfHasFocus = textFieldFocusNode.hasFocus;
    final sHasFocus = suggestionsFocusNode.hasFocus;
    final hasText = textController.text.isNotEmpty;

    if ((tfHasFocus || sHasFocus) &&
        (suggestions.value.isNotEmpty) &&
        hasText) {
      overlayController.show();
    } else {
      overlayController.hide();
    }
  }

  final link = LayerLink();
  final prior = Queue<String>();
  int priorIndex = 0;

  KeyEventResult handleKeyEvent(
    FocusNode node,
    KeyEvent event, {
    bool query = false,
  }) {
    if (event is KeyDownEvent) {
      if (textFieldFocusNode.hasFocus) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            suggestions.value.isNotEmpty) {
          suggestionsFocusNode.requestFocus();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
            query &&
            prior.isNotEmpty) {
          textController.text = prior.elementAt(priorIndex);
          priorIndex += 1;
          if (priorIndex > prior.length - 1) {
            priorIndex = 0;
          }
          textController.selection = TextSelection.collapsed(
            offset: textController.text.length,
          );
          return KeyEventResult.handled;
        } else if (textFieldFocusNode.hasFocus &&
            query &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          sendInput();
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void sendInput([Message mesType = Message.userquery]) {
    conn.send(mesType, textController.text);
    prior.addFirst(textController.text);
    if (prior.length > 5) {
      prior.removeLast();
    }
    if (mesType == Message.userquery) {
      textController.text = "";
    }
    updateVisibilityChange();
  }
}

class TextInput extends ConsumerStatefulWidget {
  const TextInput({super.key});

  @override
  ConsumerState createState() => _TextInput();
}

class _TextInput extends ConsumerState with WithSuggestions {
  @override
  void initState() {
    super.initState();
    initSuggestions();
  }

  @override
  Widget build(BuildContext context) {
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
            builder: (context, _, _) {
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
          onKeyEvent: (FocusNode node, KeyEvent event) =>
              handleKeyEvent(node, event, query: true),
          child: TextField(
            focusNode: textFieldFocusNode,
            controller: textController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Ex: blue_sky cloud 1girl',
              suffix: IconButton(
                icon: Icon(Icons.search),
                onPressed: sendInput,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SearchBox extends ConsumerStatefulWidget {
  final bool _hydrusEnabled;
  const SearchBox(this._hydrusEnabled, {super.key});

  @override
  ConsumerState<SearchBox> createState() => _SearchBox();
}

class _SearchBox extends ConsumerState<SearchBox> {
  final controller = TextEditingController();
  late final Conn conn;
  var pressed = false;

  @override
  void initState() {
    super.initState();

    conn = ref.read(connProvider).requireValue;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget._hydrusEnabled) ...[
          IconButton(
            tooltip: 'Sort asc/desc',
            icon: pressed == true
                ? Icon(Icons.arrow_upward)
                : Icon(Icons.arrow_downward),
            onPressed: () {
              setState(() {
                pressed = !pressed;
                conn.send(Message.hydrusSortAsc, pressed);
              });
            },
          ),
          PopupMenuButton<HydrusSortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort type',
            onSelected: (HydrusSortOrder criteria) {
              conn.send(Message.hydrusSortOrder, criteria.index);
            },
            itemBuilder: (BuildContext context) =>
                HydrusSortOrder.values.map((value) {
                  return PopupMenuItem(value: value, child: Text(value.label));
                }).toList(),
          ),
          const SizedBox(width: 8),
        ],

        Expanded(child: TextInput()),
      ],
    );
  }
}
