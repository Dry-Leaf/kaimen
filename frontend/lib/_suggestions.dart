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
    widget._suggestionsFocusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (widget._suggestionsFocusNode.hasFocus) {
      _highlightIndex = 0;
    } else {
      _highlightIndex = -1;
    }
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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
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
      case LogicalKeyboardKey.tab:
      case LogicalKeyboardKey.enter:
        _returnFocus(_highlightIndex);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        node.unfocus();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.backspace:
        String newtxt = widget._textController.text.substring(
          0,
          widget._textController.text.length - 1,
        );
        widget._textController.text = newtxt;
        widget._textFieldFocusNode.requestFocus();
        return KeyEventResult.handled;
      default:
        if (event.character != null && event.character!.isNotEmpty) {
          widget._textController.text += event.character!;
          widget._textController.selection = TextSelection.collapsed(
            offset: widget._textController.text.length,
          );
        }
        widget._textFieldFocusNode.requestFocus();
        setState(() {
          _highlightIndex = 0;
        });
        return KeyEventResult.handled;
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

  Widget _buildSuggestionList(ThemeData theme) {
    return ListView.builder(
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
            onExit: (_) => {
              setState(() {
                _highlightIndex = -1;
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
            child: _buildSuggestionList(theme),
          ),
        );
      },
    );
  }
}
