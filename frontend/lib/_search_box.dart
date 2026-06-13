import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_suggestions.dart' show Suggestion, SuggestionList;

import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;

mixin WithSuggestions on ConsumerState {
  final textController = TextEditingController();
  String priorText = "";
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
    textFieldFocusNode.addListener(handleFocusAndCaret);
    suggestions.addListener(updateVisibilityChange);
    textController.addListener(updateVisibilityChange);
    suggestionsFocusNode.addListener(updateVisibilityChange);
  }

  void autoSuggestReq(int suggLimit, int minsugg) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (textController.text.isNotEmpty) {
        if (textController.text == priorText) {
          return;
        }
        setState(() {
          priorText = textController.text;
        });
        conn.send(Message.autosuggest, [
          textController.text,
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

  void handleFocusAndCaret() {
    if (textFieldFocusNode.hasFocus) {
      Future.microtask(() {
        final int textLength = textController.text.length;
        textController.selection = TextSelection.fromPosition(
          TextPosition(offset: textLength),
        );
      });
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
        if (event.logicalKey == LogicalKeyboardKey.tab &&
            suggestions.value.isNotEmpty) {
          textController.text += suggestions.value[0].remainder;
          textController.selection = TextSelection.collapsed(
            offset: textController.text.length,
          );
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
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

class SearchBox extends StatefulWidget {
  const SearchBox({super.key});

  @override
  State<SearchBox> createState() => _SearchBox();
}

class _SearchBox extends State<SearchBox> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextInput();
  }
}
