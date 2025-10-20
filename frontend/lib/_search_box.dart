import 'dart:convert' show jsonEncode;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '_suggestions.dart' show Suggestion, SuggestionList;

class TextInput extends StatefulWidget {
  final WebSocketChannel? _channel;
  final ValueNotifier<List<Suggestion>> _suggestions;
  const TextInput(this._channel, this._suggestions, {super.key});

  @override
  State<TextInput> createState() => _TextInput();
}

class _TextInput extends State<TextInput> {
  final _textController = TextEditingController();
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();
  String _priorText = "";

  final FocusNode _textFieldFocusNode = FocusNode();
  final FocusNode _suggestionsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _textController.addListener(_autoSuggestReq);
    _textFieldFocusNode.addListener(_updateVisibilityChange);
    _textFieldFocusNode.addListener(_handleFocusAndCaret);
    widget._suggestions.addListener(_updateVisibilityChange);
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
    if (_textController.text.isNotEmpty) {
      if (_textController.text == _priorText) {
        return;
      }
      setState(() {
        _priorText = _textController.text;
      });

      final message = {"Type": "auto_suggest", "Value": _textController.text};
      widget._channel?.sink.add(jsonEncode(message));
    }
  }

  void _sendQuery() {
    final message = {"Type": "query", "Value": _textController.text};
    widget._channel?.sink.add(jsonEncode(message));
    _textController.text = "";
    _updateVisibilityChange();
  }

  void _updateVisibilityChange() {
    final tfHasFocus = _textFieldFocusNode.hasFocus;
    final sHasFocus = _suggestionsFocusNode.hasFocus;
    final hasText = _textController.text.isNotEmpty;

    if ((tfHasFocus || sHasFocus) &&
        (widget._suggestions.value.isNotEmpty) &&
        hasText) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_textFieldFocusNode.hasFocus &&
          widget._suggestions.value.isNotEmpty) {
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          _textController.text += '${widget._suggestions.value[0].remainder} ';
          _textController.selection = TextSelection.collapsed(
            offset: _textController.text.length,
          );
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _suggestionsFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) => UnconstrainedBox(
        child: CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, .5),
          child: SizedBox(
            width: 550,
            height: widget._suggestions.value.length * 27 + 2,
            child: SuggestionList(
              widget._suggestions,
              _textController,
              _textFieldFocusNode,
              _suggestionsFocusNode,
            ),
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
  final WebSocketChannel? _channel;
  final ValueNotifier<List<Suggestion>> _suggestions;
  const SearchBox(this._channel, this._suggestions, {super.key});

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
    return TextInput(widget._channel, widget._suggestions);
  }
}
