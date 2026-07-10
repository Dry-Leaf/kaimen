import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:window_manager/window_manager.dart';

import '_backend_conn.dart'
    show Conn, Message, messageByTypeProvider, connProvider;
import '_search_box.dart' show SearchBox;
import '_digit_row.dart' show DigitRow;

class QueueNotif extends ConsumerStatefulWidget {
  const QueueNotif({super.key, required this.queueSize});

  final int queueSize;

  @override
  ConsumerState<QueueNotif> createState() => _QueueNotifState();
}

class _QueueNotifState extends ConsumerState<QueueNotif> {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("${widget.queueSize.toString()} new file(s) being processed"),
        SizedBox(width: 8),
        SpinKitThreeBounce(color: Colors.grey, size: 10.0),
      ],
    );
  }
}

class ResultCounter extends ConsumerStatefulWidget {
  const ResultCounter({super.key});

  @override
  ConsumerState<ResultCounter> createState() => _ResultCounterState();
}

class _ResultCounterState extends ConsumerState<ResultCounter> {
  double _opacity = 1.0;
  Timer? _timer;

  String? _lastKey;

  void _startFade(String key) {
    if (_lastKey == key) return;
    _lastKey = key;

    _timer?.cancel();

    const duration = Duration(seconds: 2);
    const tick = Duration(milliseconds: 16); // ~60fps

    final startTime = DateTime.now();

    _timer = Timer.periodic(tick, (timer) {
      final elapsed = DateTime.now().difference(startTime);
      final t = elapsed.inMilliseconds / duration.inMilliseconds;
      final eased = Curves.ease.transform(t.clamp(0.0, 1.0));

      if (t >= 1.0) {
        setState(() => _opacity = 0.0);
        timer.cancel();
        return;
      }

      setState(() {
        _opacity = 1.0 - eased;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultCounter = ref.watch(messageByTypeProvider(Message.qcomplete));

    return resultCounter.when(
      loading: () => const SizedBox.shrink(),
      error: (err, _) => Text('Error: $err'),
      data: (msg) {
        _startFade(msg[1].toString());

        return Opacity(opacity: _opacity, child: Text("${msg[0]} Results"));
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
tagged with blonde hair and blue eyes

-blonde_hair -blue_eyes
tagged with blonde hair or blue eyes

*_shirt
Wildcard search
e.g. matches tags with any or no text,
followed by _shirt

ignored
tags were not found for online

limit:50
limit results to 50

ignored name:ex limit:50 blue_eyes
filter on ignored, metadata and tags""";
  final String meta_documentation = """name:ex
includes 'ex' in their file name

width:5
has a width of 5 pixels

height:>5
has a height of at least 5 pixels

duration:<5s
videos that are at most 5 seconds
valid units: s(seconds), m(minutes) and h(hours)

date:2007-01-01
timestamp within 2007-01-01

date:2007-01-01..2010-01-01
timestamp between 2007-01-01 and 2010-01-01

age:2w..1y
timestamp between 2 weeks and 1 year ago
valid units: d(days), w(weeks), mo(months), y(years)""";

  final String title;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final Conn conn;
  int _counter = 0;

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

    ref.listen(messageByTypeProvider(Message.updatestatus), (previous, next) {
      next.whenData((status) {
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
        if (!isCurrentRoute) return;

        if (!status[0]) {
          final String msg;
          msg = "Hydrus connection failed. Integration has been disabled.";
          showDialog(
            context: context,
            builder: (context) => AlertDialog(content: Text(msg)),
          );
        }
      });
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Kaimen'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Open Search Results',
            icon: const Icon(Icons.folder),
            onPressed: () {
              final connAsync = ref.read(connProvider);

              connAsync.whenData((c) {
                c.send(Message.openresults, '');
              });

              if (connAsync.isLoading) {
                debugPrint("Connection is still initializing...");
              }
            },
          ),
          IconButton(
            tooltip: 'Search Syntax',
            icon: const Icon(Icons.question_mark),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  content: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          textScaler: const TextScaler.linear(.8),
                          widget.documentation,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          textScaler: const TextScaler.linear(.8),
                          widget.meta_documentation,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Edit Tags',
            icon: const Icon(Icons.sell),
            onPressed: () {
              Navigator.pushNamed(context, '/tagedit');
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
              windowManager.hide();
            },
          ),
        ],
      ),
      body: counterMessage.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (err, _) => Text('Error: $err'),
        data: (msg) {
          _counter = msg[0];
          if (_counter == -1) {
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Database creation in progress"),
                  SizedBox(width: 8),
                  SpinKitThreeBounce(color: Colors.grey, size: 10.0),
                ],
              ),
            );
          } else {
            return Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(width: 550, child: SearchBox()),
                      SizedBox(height: 40),
                      SizedBox(
                        height: 150,
                        child: DigitRow(_counter.toString()),
                      ),
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
                          child: IndexingBox(
                            indexingList: msg[1].cast<String>(),
                          ),
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
                  if (msg[1] == null && msg[3] != null && msg[3] != 0)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Transform.translate(
                        offset: const Offset(0, -16),
                        child: SizedBox(
                          height: 120,
                          child: QueueNotif(queueSize: msg[3]),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
