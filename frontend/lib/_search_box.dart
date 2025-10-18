import 'dart:convert' show jsonEncode;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';

class TextInput extends StatelessWidget {
  final _textController = TextEditingController();
  final WebSocketChannel? _channel;
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();

  final FocusNode _textFieldFocusNode = FocusNode();
  final FocusNode _overlayFocusNode = FocusNode();

  TextInput(this._channel, {super.key});

  void _sendQuery() {
    final message = {"Type": "query", "Value": _textController.text};
    _channel?.sink.add(jsonEncode(message));
    _textController.text = "";
    _updateVisibilityChange();
  }

  void _updateVisibilityChange() {
    final tfHasFocus = _textFieldFocusNode.hasFocus;
    final oHasFocus = _overlayFocusNode.hasFocus;
    final hasText = _textController.text.isNotEmpty;

    if ((tfHasFocus || oHasFocus) && hasText) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    _textFieldFocusNode.addListener(_updateVisibilityChange);
    _overlayFocusNode.addListener(_updateVisibilityChange);
    _textController.addListener(_updateVisibilityChange);

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
  const SearchBox(this._channel, {super.key});

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
      child: TextInput(widget._channel),
    );
  }
}
