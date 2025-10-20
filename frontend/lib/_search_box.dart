import 'dart:convert' show jsonEncode;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class Suggestion {
  final String name;
  final int freq;
  final int category;
  final String remainder;

  Suggestion({
    required this.name,
    required this.freq,
    required this.category,
    required this.remainder,
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      name: json['Name'],
      freq: json['Freq'],
      category: json['Category'],
      remainder: json['Remainder'],
    );
  }
}

class SuggestionList extends StatefulWidget {
  final ValueNotifier<List<Suggestion>> _suggestions;
  final TextEditingController _textController;
  final FocusNode _textFieldFocusNode;
  final FocusNode _suggestionsFocusNode;
  const SuggestionList(
    this._suggestions,
    this._textController,
    this._textFieldFocusNode,
    this._suggestionsFocusNode, {
    super.key,
  });

  @override
  State<SuggestionList> createState() => _SuggestionList();
}

class _SuggestionList extends State<SuggestionList> {
  int _highlightIndex = -1;

  @override
  void initState() {
    super.initState();
    widget._suggestionsFocusNode.addListener(_initialFocus);
  }

  void _initialFocus() {
    _highlightIndex = 0;
  }

  void _returnFocus(int index) {
    widget._textController.text +=
        '${widget._suggestions.value[index].remainder} ';
    widget._textController.selection = TextSelection.collapsed(
      offset: widget._textController.text.length,
    );
    widget._textFieldFocusNode.requestFocus();
  }

  String formatNumber(int number) {
    final formatter = NumberFormat.compact(locale: 'en_US');
    return formatter.format(number);
  }

  Color _getTextColor(int category) {
    switch (category) {
      case 1:
        return Colors.red[700]!;
      case 3:
        return Colors.purple;
      case 4:
        return Colors.green[600]!;
      case 5:
        return Colors.amber[800]!;
      default:
        return Colors.blue[600]!;
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final suggestions = widget._suggestions.value;
    if (suggestions.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;

    switch (key) {
      case LogicalKeyboardKey.arrowDown:
        setState(() {
          _highlightIndex = (_highlightIndex + 1) % suggestions.length;
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        setState(() {
          _highlightIndex =
              (_highlightIndex - 1 + suggestions.length) % suggestions.length;
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
        _returnFocus(_highlightIndex);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        node.unfocus();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  Widget _buildSuggestionItem(
    BuildContext context,
    int index,
    ThemeData theme,
  ) {
    final textColor = _getTextColor(widget._suggestions.value[index].category);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          widget._suggestions.value[index].name,
          style: TextStyle(fontSize: 15, color: textColor),
        ),
        Text(
          formatNumber(widget._suggestions.value[index].freq),
          style: TextStyle(fontSize: 15, color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final ThemeData theme = Theme.of(context);
        Color backgroundColor = theme.colorScheme.surface;

        return Focus(
          focusNode: widget._suggestionsFocusNode,
          canRequestFocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(0, 0, .1, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: backgroundColor,
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: ListView.builder(
              itemExtent: 27.0,
              physics: const ClampingScrollPhysics(),
              itemCount: widget._suggestions.value.length,
              itemBuilder: (context, index) {
                Color bgColor = theme.colorScheme.surface;
                if (index == _highlightIndex) {
                  bgColor = theme.colorScheme.primary.withValues(alpha: 0.15);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    _returnFocus(index);
                  },
                  child: MouseRegion(
                    onEnter: (_) => {
                      setState(() {
                        _highlightIndex = index;
                      }),
                    },
                    child: Container(
                      color: bgColor,
                      padding: const EdgeInsets.fromLTRB(10, 0, 18, 0),
                      child: _buildSuggestionItem(context, index, theme),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
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
  final FocusNode _suggestionsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _textController.addListener(_autoSuggestReq);
    _textFieldFocusNode.addListener(_updateVisibilityChange);
    _textFieldFocusNode.addListener(_handleFocusAndCaret);
    widget._suggestions.addListener(_updateVisibilityChange);
    _textController.addListener(_updateVisibilityChange);
    _suggestionsFocusNode.addListener(_updateVisibilityChange);
  }

  void _handleFocusAndCaret() {
    if (_textFieldFocusNode.hasFocus) {
      Future.microtask(() {
        final int textLength = _textController.text.length;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: textLength),
        );
      });
    }
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
    final sHasFocus = _suggestionsFocusNode.hasFocus;
    final hasText = _textController.text.isNotEmpty;

    if ((tfHasFocus || sHasFocus) &&
        (widget._suggestions.value.isNotEmpty) &&
        hasText) {
      _overlayController.show();
    } else {
      _overlayController.hide();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_textFieldFocusNode.hasFocus &&
          widget._suggestions.value.isNotEmpty) {
        _suggestionsFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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
            height: widget._suggestions.value.length * 27 + 2,
            child: SuggestionList(
              widget._suggestions,
              _textController,
              _textFieldFocusNode,
              _suggestionsFocusNode,
            ),
          ),
        ),
      ),
      child: CompositedTransformTarget(
        link: _link,
        child: Focus(
          onKeyEvent: _handleKeyEvent,
          child: TextField(
            focusNode: _textFieldFocusNode,
            controller: _textController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Ex: blue_sky cloud 1girl',
              suffix: IconButton(
                icon: Icon(Icons.search),
                onPressed: _sendQuery,
              ),
            ),
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
