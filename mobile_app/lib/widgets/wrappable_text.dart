import 'package:flutter/material.dart';

/// Text that wraps to multiple lines instead of overflowing.
/// Use this for dynamic/long content to avoid overflow indicators.
class WrappableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  const WrappableText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      textAlign: textAlign,
      softWrap: true,
      maxLines: maxLines,
      overflow: TextOverflow.clip,
    );
  }
}
