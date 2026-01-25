import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:async' show StreamController;

import 'package:path/path.dart' as path;

enum Message {
  counter,
  autosuggest,
  updateconf,
  updatestatus,
  userquery,
  qcomplete,
  createsource,
  editsource,
  reordersources,
  newdirectory,
  deletedirectory,
  editdirectory,
  getconf,
}

final messageByTypeProvider = StreamProvider.family<dynamic, Message>((
  ref,
  type,
) async* {
  final conn = await ref.watch(connProvider.future);
  yield* conn.messages
      .where((msg) => msg['Type'] == type.index)
      .map((msg) => msg['Value']);
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
    final directory = await getTemporaryDirectory();
    final portLocation = path.join(directory.path, 'kaimen_port');

    final socketPort = await File(portLocation).readAsString();
    debugPrint("PORT: $socketPort");

    channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:$socketPort/ws'),
    );

    await channel.ready;

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

  void send(Message type, dynamic value) {
    debugPrint("About to send");
    final toSend = {'Type': type.index, 'Value': value};
    final jsonString = jsonEncode(toSend);
    debugPrint(jsonString);
    channel.sink.add(jsonString);
  }

  void dispose() {
    channel.sink.close();
    _controller.close();
  }
}
