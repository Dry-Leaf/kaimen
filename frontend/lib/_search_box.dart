import 'dart:convert' show jsonEncode;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';

class Suggestion {
  final String name;
  final int freq;
  final int category;

  Suggestion({required this.name, required this.freq, required this.category});

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      name: json['Name'],
      freq: json['Freq'],
      category: json['Category'],
    );
  }
}

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
  final FocusNode _overlayFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _textController.addListener(_autoSuggestReq);
    _textFieldFocusNode.addListener(_updateVisibilityChange);
    widget._suggestions.addListener(_updateVisibilityChange);
    _overlayFocusNode.addListener(_updateVisibilityChange);
    _textController.addListener(_updateVisibilityChange);
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
    final oHasFocus = _overlayFocusNode.hasFocus;
    //final hasText = _textController.text.isNotEmpty;

    if ((tfHasFocus || oHasFocus) &&
        (widget._suggestions.value.isNotEmpty) &&
        _textController.text.isNotEmpty) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) => UnconstrainedBox(
        child: CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          child: const SizedBox(width: 550, height: 200, child: Placeholder()),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: TextField(
          focusNode: _textFieldFocusNode,
          controller: _textController,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Ex: blue_sky cloud 1girl',
            suffix: IconButton(icon: Icon(Icons.search), onPressed: _sendQuery),
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
    return Focus(
      onKeyEvent: (node, event) {
        return KeyEventResult.ignored;
      },
      child: TextInput(widget._channel, widget._suggestions),
    );
  }
}
