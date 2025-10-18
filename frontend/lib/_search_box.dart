import 'dart:convert' show jsonEncode;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';

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

  void _sendQuery() {
    final message = {"Type": "query", "Value": controller.text};
    widget._channel?.sink.add(jsonEncode(message));
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Ex: blue_sky cloud 1girl',
          suffix: IconButton(icon: Icon(Icons.search), onPressed: _sendQuery),
        ),
      ),
    );
  }
}
