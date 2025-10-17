import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:collection' show Queue;
import 'dart:io' show exit;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const UI());
}

class UI extends StatelessWidget {
  const UI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const SearchPage(title: 'Search Page'),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.title});

  final String title;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class DigitRow extends StatelessWidget {
  final String counter;
  const DigitRow(this.counter, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: counter
          .split('')
          .map((digit) => Image.asset('counters/$digit.png'))
          .toList(),
    );
  }
}

class SearchBox extends StatelessWidget {
  //String query;
  final WebSocketChannel? _channel;

  const SearchBox(this._channel, {super.key});

  void _requestCounter() {
    final message = {"test": "0"};
    _channel?.sink.add(jsonEncode(message));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Ex: blue_sky cloud 1girl',
        suffix: IconButton(
          icon: Icon(Icons.search),
          onPressed: _requestCounter,
        ),
      ),
    );
  }
}

class _SearchPageState extends State<SearchPage> {
  WebSocketChannel? _channel;
  String _counter = "0";

  void _requestCounter() {
    final message = {'counter': _counter};
    _channel?.sink.add(jsonEncode(message));
  }

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(
          'ws://localhost:8080/ws',
        ), // Use ws://10.0.2.2:8080/ws for Android emulator
      );
      await _channel!.ready;
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
      exit(1);
    }

    _channel!.stream.listen(
      (data) {
        String message = jsonDecode(data as String);
        setState(() {
          _counter = message;
        });
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
    final counter_girls = Queue<Widget>();
    final counter = _counter.toString().split('');
    for (final digit in counter) {
      counter_girls.addLast(Image(image: AssetImage('counters/${digit}.png')));
    }

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
            SizedBox(width: 550, child: SearchBox(_channel)),
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
