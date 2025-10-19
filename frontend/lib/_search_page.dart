import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:flutter/material.dart';
import 'dart:io' show exit;
import 'package:web_socket_channel/web_socket_channel.dart';

import '_search_box.dart' show SearchBox, Suggestion;
import '_digit_row.dart' show DigitRow;

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.title});

  final String title;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  WebSocketChannel? _channel;
  String _counter = "0";
  ValueNotifier<List<Suggestion>> _suggestions =
      ValueNotifier<List<Suggestion>>([]);

  void _requestCounter() {
    final message = {'Type': "counter"};
    _channel?.sink.add(jsonEncode(message));
  }

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://localhost:8080/ws'));
      await _channel!.ready;
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      exit(1);
    }

    _channel!.stream.listen(
      (data) {
        final message = jsonDecode(data);
        switch (message['Type']) {
          case 'counter':
            setState(() {
              _counter = message['Value'];
            });
          case 'autosuggest':
            if (message['Value'] != null) {
              final suggestions = (message['Value'] as List)
                  .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
                  .toList();
              _suggestions.value = suggestions;
            } else {
              _suggestions.value = [];
            }
        }
      },
      onError: (error) {
        setState(() {
          debugPrint('Terminating app: $error');
          exit(1);
        });
      },
      onDone: () {
        setState(() {
          debugPrint('Connection closed');
          exit(1);
        });
      },
    );

    _requestCounter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Kaimen'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              exit(0);
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(width: 550, child: SearchBox(_channel, _suggestions)),
            SizedBox(height: 40),
            SizedBox(height: 150, child: DigitRow(_counter.toString())),
            SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _requestCounter,
        tooltip: 'Sync',
        child: const Icon(Icons.sync),
      ),
    );
  }
}
