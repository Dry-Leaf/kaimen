import 'package:flutter/material.dart';

class DigitRow extends StatefulWidget {
  final String _counter;
  const DigitRow(this._counter, {super.key});

  @override
  State<DigitRow> createState() => _DigitRow();
}

class _DigitRow extends State<DigitRow> {
  bool _imagesPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_imagesPrecached) {
      for (int i = 0; i <= 9; i++) {
        precacheImage(AssetImage('counters/$i.png'), context);
      }
      _imagesPrecached = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget._counter
          .split('')
          .map((digit) => Image.asset('counters/$digit.png'))
          .toList(),
    );
  }
}
