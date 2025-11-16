import 'dart:convert' show jsonEncode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_suggestions.dart' show Suggestion, SuggestionList;

import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;

class TextInput extends ConsumerStatefulWidget {
  const TextInput({super.key});

  @override
  ConsumerState<TextInput> createState() => _TextInput();
}

class _TextInput extends ConsumerState<TextInput> {
  final _textController = TextEditingController();
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();
  late final ValueNotifier<List<Suggestion>> _suggestions;
  late final Conn conn;
  String _priorText = "";

  final FocusNode _textFieldFocusNode = FocusNode();
  final FocusNode _suggestionsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _suggestions = ValueNotifier<List<Suggestion>>([]);

    conn = ref
        .read(connProvider)
        .maybeWhen(
          data: (conn) => conn,
          orElse: () => throw Exception('Connection not ready'),
        );

    _textController.addListener(_autoSuggestReq);
    _textFieldFocusNode.addListener(_updateVisibilityChange);
    _textFieldFocusNode.addListener(_handleFocusAndCaret);
    _suggestions.addListener(_updateVisibilityChange);
    _textController.addListener(_updateVisibilityChange);
    _suggestionsFocusNode.addListener(_updateVisibilityChange);
  }

  void _handleFocusAndCaret() {
    if (_textFieldFocusNode.hasFocus) {
      Future.microtask(() {
        final int textLength = _textController.text.length;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: textLength),
        );
      });
    }
  }

  void _autoSuggestReq() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_textController.text.isNotEmpty) {
        if (_textController.text == _priorText) {
          return;
        }
        setState(() {
          _priorText = _textController.text;
        });
        conn.send(Message.autosuggest, _textController.text);
      }
    });
  }

  void _sendQuery() {
    conn.send(Message.userquery, _textController.text);
    _textController.text = "";
    _updateVisibilityChange();
  }

  void _updateVisibilityChange() {
    final tfHasFocus = _textFieldFocusNode.hasFocus;
    final sHasFocus = _suggestionsFocusNode.hasFocus;
    final hasText = _textController.text.isNotEmpty;

    if ((tfHasFocus || sHasFocus) &&
        (_suggestions.value.isNotEmpty) &&
        hasText) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_textFieldFocusNode.hasFocus) {
        if (event.logicalKey == LogicalKeyboardKey.tab &&
            _suggestions.value.isNotEmpty) {
          _textController.text += '${_suggestions.value[0].remainder} ';
          _textController.selection = TextSelection.collapsed(
            offset: _textController.text.length,
          );
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
            _suggestions.value.isNotEmpty) {
          _suggestionsFocusNode.requestFocus();
          return KeyEventResult.handled;
        } else if (_textFieldFocusNode.hasFocus &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          _sendQuery();
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final autosuggestMessage = ref.watch(
      messageByTypeProvider(Message.autosuggest),
    );

    autosuggestMessage.when(
      data: (msg) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (msg['Value'] != null) {
            final parsed = (msg['Value'] as List)
                .map((e) => Suggestion.fromJson(e))
                .toList();

            _suggestions.value = parsed;
          } else {
            _suggestions.value = [];
          }
        });
      },
      loading: () {},
      error: (_, __) {},
    );

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) => UnconstrainedBox(
        child: CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, .5),
          child: ValueListenableBuilder<List<Suggestion>>(
            valueListenable: _suggestions,
            builder: (context, suggestions, _) {
              return SizedBox(
                width: 550,
                height: _suggestions.value.length * 27 + 2,
                child: SuggestionList(
                  _suggestions,
                  _textController,
                  _textFieldFocusNode,
                  _suggestionsFocusNode,
                ),
              );
            },
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: Focus(
          onKeyEvent: _handleKeyEvent,
          child: TextField(
            focusNode: _textFieldFocusNode,
            controller: _textController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Ex: blue_sky cloud 1girl',
              suffix: IconButton(
                icon: Icon(Icons.search),
                onPressed: _sendQuery,
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
