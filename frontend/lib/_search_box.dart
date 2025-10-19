import 'dart:convert' show jsonEncode;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class SuggestionList extends StatefulWidget {
  final ValueNotifier<List<Suggestion>> _suggestions;
  const SuggestionList(this._suggestions, {super.key});

  @override
  State<SuggestionList> createState() => _SuggestionList();
}

class _SuggestionList extends State<SuggestionList> {
  String formatNumber(int number) {
    final formatter = NumberFormat.compact(locale: 'en_US');
    return formatter.format(number);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color backgroundColor = theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: backgroundColor,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        itemCount: widget._suggestions.value.length,
        itemBuilder: (BuildContext context, int index) {
          final Color textColor;
          switch (widget._suggestions.value[index].category) {
            case 1:
              textColor = Colors.red[700]!;
            case 3:
              textColor = Colors.purple;
            case 4:
              textColor = Colors.green[600]!;
            case 5:
              textColor = Colors.amber[800]!;
            default:
              textColor = Colors.blue[600]!;
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SizedBox(
                height: 27,
                child: Text(
                  widget._suggestions.value[index].name,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
              ),
              SizedBox(
                height: 27,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 0, 10, 0),
                  child: Text(
                    formatNumber(widget._suggestions.value[index].freq),
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, .5),
          child: SizedBox(
            width: 550,
            height: widget._suggestions.value.length * 27 + 18,
            child: SuggestionList(widget._suggestions),
          ),
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
