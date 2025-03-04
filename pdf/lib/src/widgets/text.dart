/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';

import 'annotations.dart';
import 'document.dart';
import 'geometry.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

enum TextAlign { left, right, center, justify }

enum TextDirection { ltr, rtl }

abstract class _Span {
  _Span(this.style);

  final TextStyle? style;

  PdfPoint offset = PdfPoint.zero;

  late double left;
  late double top;
  double? width;
  double? height;

  @override
  String toString() {
    return 'Span "offset:$offset';
  }

  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect? globalBox,
  ) {}

  void paint(
    Context context,
    TextStyle? style,
    double textScaleFactor,
    PdfPoint point,
  );
}

class _TextDecoration {
  _TextDecoration(this.style, this.annotation, this.startSpan, this.endSpan)
      : assert(startSpan <= endSpan);

  static const double _space = -0.15;

  final TextStyle style;

  final AnnotationBuilder? annotation;

  final int startSpan;

  final int endSpan;

  PdfRect? _box;

  PdfRect? _getBox(List<_Span> spans) {
    if (_box != null) {
      return _box;
    }
    final x1 = spans[startSpan].offset.x + spans[startSpan].left;
    final x2 =
        spans[endSpan].offset.x + spans[endSpan].left + spans[endSpan].width!;
    var y1 = spans[startSpan].offset.y + spans[startSpan].top;
    var y2 = y1 + spans[startSpan].height!;

    for (var n = startSpan + 1; n <= endSpan; n++) {
      final ny1 = spans[n].offset.y + spans[n].top;
      final ny2 = ny1 + spans[n].height!;
      y1 = math.min(y1, ny1);
      y2 = math.max(y2, ny2);
    }

    _box = PdfRect.fromLTRB(x1, y1, x2, y2);
    return _box;
  }

  _TextDecoration copyWith({int? endSpan}) =>
      _TextDecoration(style, annotation, startSpan, endSpan ?? this.endSpan);

  void backgroundPaint(
    Context context,
    double textScaleFactor,
    PdfRect? globalBox,
    List<_Span> spans,
  ) {
    final box = _getBox(spans);

    if (annotation != null) {
      final spanBox = PdfRect(
        globalBox!.x + box!.left,
        globalBox.top + box.bottom,
        box.width,
        box.height,
      );
      annotation!.build(context, spanBox);
    }

    if (style.background != null) {
      final boundingBox = PdfRect(
        globalBox!.x + box!.left,
        globalBox.top + box.bottom,
        box.width,
        box.height,
      );
      style.background!.paint(context, boundingBox);
      context.canvas.setFillColor(style.color);
    }
  }

  void foregroundPaint(
    Context context,
    double textScaleFactor,
    PdfRect? globalBox,
    List<_Span> spans,
  ) {
    if (style.decoration == null) {
      return;
    }

    final box = _getBox(spans);

    final font = style.font!.getFont(context);
    final space =
        _space * style.fontSize! * textScaleFactor * style.decorationThickness!;

    context.canvas
      ..setStrokeColor(style.decorationColor ?? style.color)
      ..setLineWidth(style.decorationThickness! *
          style.fontSize! *
          textScaleFactor *
          0.05);

    if (style.decoration!.contains(TextDecoration.underline)) {
      final base = -font!.descent * style.fontSize! * textScaleFactor / 2;

      context.canvas.drawLine(
        globalBox!.x + box!.left,
        globalBox.top + box.bottom + base,
        globalBox.x + box.right,
        globalBox.top + box.bottom + base,
      );
      if (style.decorationStyle == TextDecorationStyle.double) {
        context.canvas.drawLine(
          globalBox.x + box.left,
          globalBox.top + box.bottom + base + space,
          globalBox.x + box.right,
          globalBox.top + box.bottom + base + space,
        );
      }
      context.canvas.strokePath();
    }

    if (style.decoration!.contains(TextDecoration.overline)) {
      final base = style.fontSize! * textScaleFactor;
      context.canvas.drawLine(
        globalBox!.x + box!.left,
        globalBox.top + box.bottom + base,
        globalBox.x + box.right,
        globalBox.top + box.bottom + base,
      );
      if (style.decorationStyle == TextDecorationStyle.double) {
        context.canvas.drawLine(
          globalBox.x + box.left,
          globalBox.top + box.bottom + base - space,
          globalBox.x + box.right,
          globalBox.top + box.bottom + base - space,
        );
      }
      context.canvas.strokePath();
    }

    if (style.decoration!.contains(TextDecoration.lineThrough)) {
      final base = (1 - font!.descent) * style.fontSize! * textScaleFactor / 2;
      context.canvas.drawLine(
        globalBox!.x + box!.left,
        globalBox.top + box.bottom + base,
        globalBox.x + box.right,
        globalBox.top + box.bottom + base,
      );
      if (style.decorationStyle == TextDecorationStyle.double) {
        context.canvas.drawLine(
          globalBox.x + box.left,
          globalBox.top + box.bottom + base + space,
          globalBox.x + box.right,
          globalBox.top + box.bottom + base + space,
        );
      }
      context.canvas.strokePath();
    }
  }

  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect globalBox,
    List<_Span> spans,
  ) {
    final box = _getBox(spans)!;

    context.canvas
      ..setLineWidth(.5)
      ..drawRect(
          globalBox.x + box.x, globalBox.top + box.y, box.width, box.height)
      ..setStrokeColor(PdfColors.yellow)
      ..strokePath();
  }
}

class _Word extends _Span {
  _Word(
    this.text,
    TextStyle? style,
    this.metrics,
  ) : super(style);

  final String text;

  final PdfFontMetrics metrics;

  @override
  double get left => metrics.left;

  @override
  double get top => metrics.descent;

  @override
  double get width => metrics.width;

  @override
  double get height => metrics.maxHeight;

  @override
  String toString() {
    return 'Word "$text" offset:$offset metrics:$metrics style:$style';
  }

  @override
  void paint(
    Context context,
    TextStyle? style,
    double textScaleFactor,
    PdfPoint point,
  ) {
    context.canvas.drawString(
      style!.font!.getFont(context)!,
      style.fontSize! * textScaleFactor,
      text,
      point.x + offset.x,
      point.y + offset.y,
      mode: style.renderingMode,
      charSpace: style.letterSpacing,
    );
  }

  @override
  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect? globalBox,
  ) {
    const deb = 5;

    context.canvas
      ..setLineWidth(.5)
      ..drawRect(globalBox!.x + offset.x + metrics.left,
          globalBox.top + offset.y + metrics.top, metrics.width, metrics.height)
      ..setStrokeColor(PdfColors.orange)
      ..strokePath()
      ..drawLine(
          globalBox.x + offset.x - deb,
          globalBox.top + offset.y,
          globalBox.x + offset.x + metrics.right + deb,
          globalBox.top + offset.y)
      ..setStrokeColor(PdfColors.deepPurple)
      ..strokePath();
  }
}

class _WidgetSpan extends _Span {
  _WidgetSpan(this.widget, TextStyle style) : super(style);

  final Widget widget;

  @override
  double get left => 0;

  @override
  double get top => 0;

  @override
  double? get width => widget.box!.width;

  @override
  double? get height => widget.box!.height;

  @override
  PdfPoint get offset => widget.box!.offset;

  @override
  set offset(PdfPoint value) {
    widget.box = PdfRect.fromPoints(value, widget.box!.size);
  }

  @override
  String toString() {
    return 'Widget "$widget" offset:$offset';
  }

  @override
  void paint(
    Context context,
    TextStyle? style,
    double textScaleFactor,
    PdfPoint point,
  ) {
    widget.box = PdfRect.fromPoints(
        PdfPoint(
            point.x + widget.box!.offset.x, point.y + widget.box!.offset.y),
        widget.box!.size);
    widget.paint(context);
  }

  @override
  void debugPaint(
    Context context,
    double textScaleFactor,
    PdfRect? globalBox,
  ) {
    context.canvas
      ..setLineWidth(.5)
      ..drawRect(
          globalBox!.x + offset.x, globalBox.top + offset.y, width, height)
      ..setStrokeColor(PdfColors.orange)
      ..strokePath();
  }
}

typedef _VisitorCallback = bool Function(
  InlineSpan span,
  TextStyle? parentStyle,
  AnnotationBuilder? annotation,
);

@immutable
abstract class InlineSpan {
  const InlineSpan({this.style, this.baseline, this.annotation});

  final TextStyle? style;

  final double? baseline;

  final AnnotationBuilder? annotation;

  String toPlainText() {
    final buffer = StringBuffer();
    visitChildren((
      InlineSpan span,
      TextStyle? style,
      AnnotationBuilder? annotation,
    ) {
      if (span is TextSpan) {
        buffer.write(span.text);
      }
      return true;
    }, null, null);
    return buffer.toString();
  }

  bool visitChildren(
    _VisitorCallback visitor,
    TextStyle? parentStyle,
    AnnotationBuilder? annotation,
  );
}

class WidgetSpan extends InlineSpan {
  /// Creates a [WidgetSpan] with the given values.
  const WidgetSpan({
    required this.child,
    double baseline = 0,
    TextStyle? style,
    AnnotationBuilder? annotation,
  }) : super(style: style, baseline: baseline, annotation: annotation);

  /// The widget to embed inline within text.
  final Widget child;

  /// Calls `visitor` on this [WidgetSpan]. There are no children spans to walk.
  @override
  bool visitChildren(
    _VisitorCallback visitor,
    TextStyle? parentStyle,
    AnnotationBuilder? annotation,
  ) {
    final _style = parentStyle?.merge(style);
    final _a = this.annotation ?? annotation;

    return visitor(this, _style, _a);
  }
}

class TextSpan extends InlineSpan {
  const TextSpan({
    TextStyle? style,
    this.text,
    double baseline = 0,
    this.children,
    AnnotationBuilder? annotation,
  }) : super(style: style, baseline: baseline, annotation: annotation);

  final String? text;

  final List<InlineSpan>? children;

  @override
  bool visitChildren(
    _VisitorCallback visitor,
    TextStyle? parentStyle,
    AnnotationBuilder? annotation,
  ) {
    final _style = parentStyle?.merge(style);
    final _a = this.annotation ?? annotation;

    if (text != null) {
      if (!visitor(this, _style, _a)) {
        return false;
      }
    }
    if (children != null) {
      for (var child in children!) {
        if (!child.visitChildren(visitor, _style, _a)) {
          return false;
        }
      }
    }
    return true;
  }
}

class _Line {
  const _Line(
    this.parent,
    this.firstSpan,
    this.countSpan,
    this.baseline,
    this.wordsWidth,
    this.textDirection,
  );

  final RichText parent;

  final int firstSpan;
  final int countSpan;

  TextAlign get textAlign => parent.textAlign;

  final double baseline;

  final double wordsWidth;

  final TextDirection textDirection;

  @override
  String toString() =>
      '$runtimeType $firstSpan-${firstSpan + countSpan} baseline: $baseline width:$wordsWidth';

  void realign(double totalWidth, bool isLast) {
    final spans = parent._spans.sublist(firstSpan, firstSpan + countSpan);

    var delta = 0.0;
    switch (textAlign) {
      case TextAlign.left:
        break;
      case TextAlign.right:
        delta = totalWidth - wordsWidth;
        break;
      case TextAlign.center:
        delta = (totalWidth - wordsWidth) / 2.0;
        break;
      case TextAlign.justify:
        if (isLast) {
          totalWidth = wordsWidth;
          break;
        }
        delta = (totalWidth - wordsWidth) / (spans.length - 1);
        var x = 0.0;
        for (var span in spans) {
          span.offset = span.offset.translate(x, -baseline);
          x += delta;
        }
        return;
    }

    if (textDirection == TextDirection.rtl) {
      for (var span in spans) {
        span.offset = PdfPoint(
          totalWidth - (span.offset.x + span.width!) - delta,
          span.offset.y - baseline,
        );
      }

      return;
    }

    for (var span in spans) {
      span.offset = span.offset.translate(delta, -baseline);
    }

    return;
  }
}

class RichText extends Widget {
  RichText({
    required this.text,
    TextAlign? textAlign,
    this.textDirection,
    bool? softWrap,
    this.tightBounds = false,
    this.textScaleFactor = 1.0,
    int? maxLines,
  })  : _textAlign = textAlign,
        _softWrap = softWrap,
        _maxLines = maxLines;

  static bool debug = false;

  final InlineSpan text;

  TextAlign get textAlign => _textAlign!;
  TextAlign? _textAlign;

  final TextDirection? textDirection;

  final double textScaleFactor;

  bool get softWrap => _softWrap!;
  bool? _softWrap;

  final bool tightBounds;

  int? get maxLines => _maxLines;
  int? _maxLines;

  final List<_Span> _spans = <_Span>[];

  final List<_TextDecoration> _decorations = <_TextDecoration>[];

  void _appendDecoration(bool append, _TextDecoration td) {
    if (append && _decorations.isNotEmpty) {
      final last = _decorations.last;
      if (last.style == td.style && last.annotation == td.annotation) {
        _decorations[_decorations.length - 1] =
            last.copyWith(endSpan: td.endSpan);
        return;
      }
    }

    _decorations.add(td);
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    _spans.clear();
    _decorations.clear();

    final theme = Theme.of(context);
    final defaultstyle = theme.defaultTextStyle;
    _softWrap ??= theme.softWrap;
    _maxLines ??= theme.maxLines;
    _textAlign ??= theme.textAlign;
    final _textDirection = textDirection ?? Directionality.of(context);

    final constraintWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth();
    final constraintHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight();

    var offsetX = 0.0;
    var offsetY = 0.0;

    double? top;
    double? bottom;

    final lines = <_Line>[];
    var spanCount = 0;
    var spanStart = 0;
    var overflow = false;

    text.visitChildren((
      InlineSpan span,
      TextStyle? style,
      AnnotationBuilder? annotation,
    ) {
      if (span is TextSpan) {
        if (span.text == null) {
          return true;
        }

        final font = style!.font!.getFont(context)!;

        final space =
            font.stringMetrics(' ') * (style.fontSize! * textScaleFactor);

        final spanLines = (_textDirection == TextDirection.rtl
                ? PdfArabic.convert(span.text!)
                : span.text)!
            .split('\n');

        for (var line = 0; line < spanLines.length; line++) {
          for (var word in spanLines[line].split(RegExp(r'\s'))) {
            if (word.isEmpty) {
              offsetX += space.advanceWidth * style.wordSpacing! +
                  style.letterSpacing!;
              continue;
            }

            final metrics = font.stringMetrics(word,
                    letterSpacing: style.letterSpacing! /
                        (style.fontSize! * textScaleFactor)) *
                (style.fontSize! * textScaleFactor);

            if (offsetX + metrics.width > constraintWidth && spanCount > 0) {
              overflow = true;
              lines.add(_Line(
                this,
                spanStart,
                spanCount,
                bottom ?? 0,
                offsetX -
                    space.advanceWidth * style.wordSpacing! -
                    style.letterSpacing!,
                _textDirection,
              ));

              spanStart += spanCount;
              spanCount = 0;

              if (maxLines != null && lines.length >= maxLines!) {
                return false;
              }

              offsetX = 0.0;
              offsetY += bottom! - top! + style.lineSpacing!;
              top = null;
              bottom = null;

              if (offsetY > constraintHeight) {
                return false;
              }
            }

            final baseline = span.baseline! * textScaleFactor;
            final mt = tightBounds ? metrics.top : metrics.descent;
            final mb = tightBounds ? metrics.bottom : metrics.ascent;
            top = math.min(top ?? mt + baseline, mt + baseline);
            bottom = math.max(bottom ?? mb + baseline, mb + baseline);

            final wd = _Word(
              word,
              style,
              metrics,
            );
            wd.offset = PdfPoint(offsetX, -offsetY + baseline);
            _spans.add(wd);
            spanCount++;

            _appendDecoration(
              spanCount > 1,
              _TextDecoration(
                style,
                annotation,
                _spans.length - 1,
                _spans.length - 1,
              ),
            );

            offsetX += metrics.advanceWidth +
                space.advanceWidth * style.wordSpacing! +
                style.letterSpacing!;
          }

          if (softWrap && line < spanLines.length - 1) {
            lines.add(_Line(
                this,
                spanStart,
                spanCount,
                bottom ?? 0,
                offsetX -
                    space.advanceWidth * style.wordSpacing! -
                    style.letterSpacing!,
                _textDirection));

            spanStart += spanCount;

            if (maxLines != null && lines.length >= maxLines!) {
              spanCount = 0;
              return false;
            }

            offsetX = 0.0;
            if (spanCount > 0) {
              offsetY += bottom! - top! + style.lineSpacing!;
            } else {
              offsetY += space.ascent + space.descent + style.lineSpacing!;
            }
            top = null;
            bottom = null;
            spanCount = 0;

            if (offsetY > constraintHeight) {
              return false;
            }
          }
        }

        offsetX -=
            space.advanceWidth * style.wordSpacing! - style.letterSpacing!;
      } else if (span is WidgetSpan) {
        span.child.layout(
            context,
            BoxConstraints.tight(PdfPoint(
              double.infinity,
              style!.fontSize! * textScaleFactor,
            )));
        final ws = _WidgetSpan(
          span.child,
          style,
        );

        if (offsetX + ws.width! > constraintWidth && spanCount > 0) {
          overflow = true;
          lines.add(_Line(
            this,
            spanStart,
            spanCount,
            bottom ?? 0,
            offsetX,
            _textDirection,
          ));

          spanStart += spanCount;
          spanCount = 0;

          if (maxLines != null && lines.length > maxLines!) {
            return false;
          }

          offsetX = 0.0;
          offsetY += bottom! - top! + style.lineSpacing!;
          top = null;
          bottom = null;

          if (offsetY > constraintHeight) {
            return false;
          }
        }

        final baseline = span.baseline! * textScaleFactor;
        top = math.min(top ?? baseline, baseline);
        bottom = math.max(
          bottom ?? ws.height! + baseline,
          ws.height! + baseline,
        );

        ws.offset = PdfPoint(offsetX, -offsetY + baseline);
        _spans.add(ws);
        spanCount++;

        _appendDecoration(
          spanCount > 1,
          _TextDecoration(
            style,
            annotation,
            _spans.length - 1,
            _spans.length - 1,
          ),
        );

        offsetX += ws.left + ws.width!;
      }

      return true;
    }, defaultstyle, null);

    if (spanCount > 0) {
      lines.add(_Line(
        this,
        spanStart,
        spanCount,
        bottom ?? 0,
        offsetX,
        _textDirection,
      ));
    }

    assert(!overflow || constraintWidth.isFinite);
    var width = overflow ? constraintWidth : constraints.minWidth;

    if (lines.isNotEmpty) {
      if (!overflow) {
        // Calculate the final width
        for (final line in lines) {
          width = math.max(width, line.wordsWidth);
        }
      }

      // Realign all the lines
      for (final line in lines.sublist(0, lines.length - 1)) {
        line.realign(width, false);
      }
      lines.last.realign(width, true);
    }

    box = PdfRect(0, 0, constraints.constrainWidth(width),
        constraints.constrainHeight(offsetY + (bottom ?? 0) - (top ?? 0)));
  }

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.blue)
      ..setLineWidth(1)
      ..drawRect(
        box!.x,
        box!.y,
        box!.width == double.infinity ? 1000 : box!.width,
        box!.height == double.infinity ? 1000 : box!.height,
      )
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);
    TextStyle? currentStyle;
    PdfColor? currentColor;

    for (var decoration in _decorations) {
      assert(() {
        if (Document.debug && RichText.debug) {
          decoration.debugPaint(context, textScaleFactor, box!, _spans);
        }
        return true;
      }());

      decoration.backgroundPaint(
        context,
        textScaleFactor,
        box,
        _spans,
      );
    }

    for (var span in _spans) {
      assert(() {
        if (Document.debug && RichText.debug) {
          span.debugPaint(context, textScaleFactor, box);
        }
        return true;
      }());

      if (span.style != currentStyle) {
        currentStyle = span.style;
        if (currentStyle!.color != currentColor) {
          currentColor = currentStyle.color;
          context.canvas.setFillColor(currentColor);
        }
      }

      span.paint(
        context,
        currentStyle,
        textScaleFactor,
        PdfPoint(box!.left, box!.top),
      );
    }

    for (var decoration in _decorations) {
      decoration.foregroundPaint(
        context,
        textScaleFactor,
        box,
        _spans,
      );
    }
  }
}

class Text extends RichText {
  Text(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
    TextDirection? textDirection,
    bool? softWrap,
    bool tightBounds = false,
    double textScaleFactor = 1.0,
    int? maxLines,
  }) : super(
            text: TextSpan(text: text, style: style),
            textAlign: textAlign,
            softWrap: softWrap,
            tightBounds: tightBounds,
            textDirection: textDirection,
            textScaleFactor: textScaleFactor,
            maxLines: maxLines);
}
