import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert' show jsonDecode;
import 'dart:async' show StreamController;

import 'dart:io' show exit;

enum Message {
  counter,
  autosuggest,
  updateconf,
  userquery,
  qcomplete,
  createsource,
  editsource,
  reordersources,
}

final messageByTypeProvider =
    StreamProvider.family<Map<String, dynamic>, Message>((ref, type) async* {
      final conn = await ref.watch(connProvider.future);
      yield* conn.messages.where((msg) => msg['Type'] == type.index);
    });

final connProvider = FutureProvider<Conn>((ref) async {
  final conn = Conn();
  await conn.connect();
  ref.onDispose(conn.dispose);
  return conn;
});

class Conn {
  late final WebSocketChannel channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> connect() async {
    final socketPort = "49152"; //Replace with zeroconf
    channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:$socketPort/ws'),
    );

    channel.stream.listen(
      (data) {
        debugPrint("HEARD FROM BACKEND");
        final message = jsonDecode(data);
        debugPrint(message.toString());
        _controller.add(message);
      },
      onError: (error) {
        debugPrint('Terminating app: $error');
        exit(1);
      },
      onDone: () {
        debugPrint('Connection closed');
        exit(1);
      },
    );
  }

  void send(String message) {
    debugPrint("About to send");
    debugPrint(message);
    channel.sink.add(message);
  }

  void dispose() {
    channel.sink.close();
    _controller.close();
  }
}
