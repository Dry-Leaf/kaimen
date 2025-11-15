import 'dart:convert' show jsonEncode;
import 'package:flutter/material.dart';
import 'dart:io' show exit;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;
//import '_search_box.dart' show SearchBox;
import '_suggestions.dart' show Suggestion;
import '_digit_row.dart' show DigitRow;

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, required this.title});

  final String title;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _counter = "0";
  final _suggestions = ValueNotifier<List<Suggestion>>([]);
  late final AsyncValue<Conn> conn;

  @override
  void initState() {
    super.initState();

    ref.listenManual<AsyncValue<Conn>>(connProvider, (prev, next) {
      next.whenData((conn) {
        debugPrint("connProvider heard");
        final msg = {"Type": Message.counter.index};
        debugPrint(jsonEncode(msg));
        conn.send(jsonEncode(msg));
      });
    });
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();
  //   channel = context.read<WebSocketChannel?>();
  // }

  // Future<void> _listen() async {
  //   channel!.stream.listen(
  //     (data) {
  //       final message = jsonDecode(data);
  //       switch (message['Type']) {
  //         case 'counter':
  //           setState(() {
  //             _counter = message['Value'];
  //           });
  //         case 'autosuggest':
  //           if (message['Value'] != null) {
  //             final suggestions = (message['Value'] as List)
  //                 .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
  //                 .toList();
  //             _suggestions.value = suggestions;
  //           } else {
  //             _suggestions.value = [];
  //           }
  //       }
  //     },
  //     onError: (error) {
  //       setState(() {
  //         debugPrint('Terminating app: $error');
  //         exit(1);
  //       });
  //     },
  //     onDone: () {
  //       setState(() {
  //         debugPrint('Connection closed');
  //         exit(1);
  //       });
  //     },
  //   );

  @override
  Widget build(BuildContext context) {
    final counterMessage = ref.watch(messageByTypeProvider(Message.counter));

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
      body: counterMessage.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('Error: $err'),
        data: (msg) {
          _counter = msg['Value'];
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                //SizedBox(width: 550, child: SearchBox(_suggestions)),
                SizedBox(height: 40),
                SizedBox(height: 150, child: DigitRow(_counter.toString())),
                SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/settings');
        },
        tooltip: 'Settings',
        child: const Icon(Icons.settings),
      ),
    );
  }
}
