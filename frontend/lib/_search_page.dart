import 'package:flutter/material.dart';
import 'dart:io' show exit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;
import '_search_box.dart' show SearchBox;
import '_digit_row.dart' show DigitRow;

class ResultCounter extends ConsumerStatefulWidget {
  const ResultCounter({super.key});

  @override
  ConsumerState<ResultCounter> createState() => _ResultCounterState();
}

class _ResultCounterState extends ConsumerState<ResultCounter> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final resultCounter = ref.watch(messageByTypeProvider(Message.qcomplete));

    return resultCounter.when(
      loading: () => SizedBox.shrink(),
      error: (err, _) => Text('Error: $err'),
      data: (msg) {
        return TweenAnimationBuilder<double>(
          key: ValueKey(msg[1]),
          tween: Tween<double>(begin: 1.0, end: 0.0),
          curve: Curves.ease,
          duration: const Duration(seconds: 2),
          builder: (BuildContext context, double opacity, Widget? child) {
            return Opacity(opacity: opacity, child: Text("${msg[0]} Results"));
          },
        );
      },
    );
  }
}

class IndexingBox extends ConsumerStatefulWidget {
  const IndexingBox({super.key, required this.indexingList});

  final List<String> indexingList;

  @override
  ConsumerState<IndexingBox> createState() => _IndexingBoxState();
}

class _IndexingBoxState extends ConsumerState<IndexingBox> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 550,
      child: ListView(
        shrinkWrap: true,
        children: [
          Align(
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Indexing"),
                SizedBox(width: 8),
                SpinKitThreeBounce(color: Colors.grey, size: 10.0),
              ],
            ),
          ),
          ...widget.indexingList.map((e) {
            return Padding(padding: const EdgeInsets.all(8.0), child: Text(e));
          }),
        ],
      ),
    );
  }
}

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, required this.title});
  final String documentation = """blonde_hair blue_eyes
Search for posts that have both blonde hair and blue eyes.

-blonde_hair -blue_eyes
Search for posts that don't have blonde hair or blue eyes.

%_shirt
Wildcard pattern search.
This example will match tag names with any or no text,
followed by _shirt, effectively returning many tags
that have something to do with shirts.""";

  final String title;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _counter = "0";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final counterMessage = ref.watch(messageByTypeProvider(Message.counter));

    ref.listen<AsyncValue<Conn>>(connProvider, (prev, next) {
      next.whenData((c) => c.send(Message.counter, ''));
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Kaimen'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Search Syntax',
            icon: const Icon(Icons.question_mark),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) =>
                    AlertDialog(content: Text(widget.documentation)),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
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
          _counter = msg[0];
          debugPrint(_counter);
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(width: 550, child: SearchBox()),
                    SizedBox(height: 40),
                    SizedBox(height: 150, child: DigitRow(_counter.toString())),
                    SizedBox(height: 60),
                  ],
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(0, 180),
                    child: ResultCounter(),
                  ),
                ),
                if (msg[1] != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: const Offset(0, -16),
                      child: SizedBox(
                        height: 120,
                        child: IndexingBox(indexingList: msg[1].cast<String>()),
                      ),
                    ),
                  ),
                if (!msg[2])
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Transform.translate(
                      offset: const Offset(0, -16),
                      child: SizedBox(
                        height: 120,
                        child: Text(
                          "No directories being watched. Add one in the settings.",
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
