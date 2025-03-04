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

import 'dart:collection';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:path_parsing/path_parsing.dart';
import 'package:vector_math/vector_math_64.dart';

import 'color.dart';
import 'data_types.dart';
import 'font.dart';
import 'graphic_state.dart';
import 'graphic_stream.dart';
import 'image.dart';
import 'page.dart';
import 'pattern.dart';
import 'rect.dart';
import 'shading.dart';
import 'stream.dart';

/// Shape to be used at the corners of paths that are stroked
enum PdfLineJoin {
  /// The outer edges of the strokes for the two segments shall beextended until they meet at an angle, as in a picture frame. If the segments meet at too sharp an angle (as defined by the miter limit parameter, a bevel join shall be used instead.
  miter,

  /// An arc of a circle with a diameter equal to the line width shall be drawn around the point where the two segments meet, connecting the outer edges of the strokes for the two segments. This pieslice-shaped figure shall be filled in, producing a rounded corner.
  round,

  /// The two segments shall be finished with butt caps and the resulting notch beyond the ends of the segments shall be filled with a triangle.
  bevel
}

/// Specify the shape that shall be used at the ends of open subpaths
/// and dashes, when they are stroked.
enum PdfLineCap {
  /// The stroke shall be squared off at the endpoint of the path. There shall be no projection beyond the end of the path.
  butt,

  /// A semicircular arc with a diameter equal to the line width shall be drawn around the endpoint and shall be filled in.
  round,

  /// The stroke shall continue beyond the endpoint of the path for a distance equal to half the line width and shall besquared off.
  square
}

/// Text rendering mode
enum PdfTextRenderingMode {
  /// Fill text
  fill,

  /// Stroke text
  stroke,

  /// Fill, then stroke text
  fillAndStroke,

  /// Neither fill nor stroke text (invisible)
  invisible,

  /// Fill text and add to path for clipping
  fillAndClip,

  /// Stroke text and add to path for clipping
  strokeAndClip,

  /// Fill, then stroke text and add to path for clipping
  fillStrokeAndClip,

  /// Add text to path for clipping
  clip
}

@immutable
class _PdfGraphicsContext {
  const _PdfGraphicsContext({
    required this.ctm,
  });
  final Matrix4 ctm;

  _PdfGraphicsContext copy() => _PdfGraphicsContext(
        ctm: ctm.clone(),
      );
}

/// Pdf drawing operations
class PdfGraphics {
  /// Create a new graphic canvas
  PdfGraphics(this._page, this.buf) {
    _context = _PdfGraphicsContext(ctm: Matrix4.identity());
  }

  /// Ellipse 4-spline magic number
  static const double _m4 = 0.551784;

  /// Graphic context
  late _PdfGraphicsContext _context;
  final Queue<_PdfGraphicsContext> _contextQueue = Queue<_PdfGraphicsContext>();

  final PdfGraphicStream? _page;

  /// Buffer where to write the graphic operations
  final PdfStream buf;

  /// Default font if none selected
  PdfFont? get defaultFont => _page!.getDefaultFont();

  /// Draw a surface on the previously defined shape
  /// set evenOdd to false to use the nonzero winding number rule to determine the region to fill and to true to use the even-odd rule to determine the region to fill
  void fillPath({bool evenOdd = false}) {
    buf.putString('f${evenOdd ? '*' : ''}\n');
  }

  /// Draw the contour of the previously defined shape
  void strokePath({bool close = false}) {
    buf.putString('${close ? 's' : 'S'}\n');
  }

  /// Close the path with a line
  void closePath() {
    buf.putString('h\n');
  }

  /// Create a clipping surface from the previously defined shape,
  /// to prevent any further drawing outside
  void clipPath({bool evenOdd = false, bool end = true}) {
    buf.putString('W${evenOdd ? '*' : ''}${end ? ' n' : ''}\n');
  }

  /// Draw a surface on the previously defined shape and then draw the contour
  /// set evenOdd to false to use the nonzero winding number rule to determine the region to fill and to true to use the even-odd rule to determine the region to fill
  void fillAndStrokePath({bool evenOdd = false, bool close = false}) {
    buf.putString('${close ? 'b' : 'B'}${evenOdd ? '*' : ''}\n');
  }

  /// Apply a shader
  void applyShader(PdfShading shader) {
    // The shader needs to be registered in the page resources
    _page!.addShader(shader);
    buf.putString('${shader.name} sh\n');
  }

  /// This releases any resources used by this Graphics object. You must use
  /// this method once finished with it.
  ///
  /// When using [PdfPage], you can create another fresh Graphics instance,
  /// which will draw over this one.
  void restoreContext() {
    if (_contextQueue.isNotEmpty) {
      // restore graphics context
      buf.putString('Q\n');
      _context = _contextQueue.removeLast();
    }
  }

  /// Save the graphc context
  void saveContext() {
    buf.putString('q\n');
    _contextQueue.addLast(_context.copy());
  }

  /// Draws an image onto the page.
  void drawImage(PdfImage img, double x, double y, [double? w, double? h]) {
    w ??= img.width.toDouble();
    h ??= img.height.toDouble() * w / img.width.toDouble();

    // The image needs to be registered in the page resources
    _page!.addXObject(img);

    // q w 0 0 h x y cm % the coordinate matrix
    buf.putString('q ');
    switch (img.orientation) {
      case PdfImageOrientation.topLeft:
        PdfNumList(<double>[w, 0, 0, h, x, y]).output(buf);
        break;
      case PdfImageOrientation.topRight:
        PdfNumList(<double>[-w, 0, 0, h, w + x, y]).output(buf);
        break;
      case PdfImageOrientation.bottomRight:
        PdfNumList(<double>[-w, 0, 0, -h, w + x, h + y]).output(buf);
        break;
      case PdfImageOrientation.bottomLeft:
        PdfNumList(<double>[w, 0, 0, -h, x, h + y]).output(buf);
        break;
      case PdfImageOrientation.leftTop:
        PdfNumList(<double>[0, -h, -w, 0, w + x, h + y]).output(buf);
        break;
      case PdfImageOrientation.rightTop:
        PdfNumList(<double>[0, -h, w, 0, x, h + y]).output(buf);
        break;
      case PdfImageOrientation.rightBottom:
        PdfNumList(<double>[0, h, w, 0, x, y]).output(buf);
        break;
      case PdfImageOrientation.leftBottom:
        PdfNumList(<double>[0, h, -w, 0, w + x, y]).output(buf);
        break;
    }

    buf.putString(' cm ${img.name} Do Q\n');
  }

  /// Draws a line between two coordinates.
  void drawLine(double? x1, double? y1, double? x2, double? y2) {
    moveTo(x1, y1);
    lineTo(x2, y2);
  }

  /// Draws an ellipse
  void drawEllipse(double x, double y, double r1, double r2) {
    moveTo(x, y - r2);
    curveTo(x + _m4 * r1, y - r2, x + r1, y - _m4 * r2, x + r1, y);
    curveTo(x + r1, y + _m4 * r2, x + _m4 * r1, y + r2, x, y + r2);
    curveTo(x - _m4 * r1, y + r2, x - r1, y + _m4 * r2, x - r1, y);
    curveTo(x - r1, y - _m4 * r2, x - _m4 * r1, y - r2, x, y - r2);
  }

  /// Draws a Rectangle
  void drawRect(
    double? x,
    double? y,
    double? w,
    double? h,
  ) {
    PdfNumList(<double?>[x, y, w, h]).output(buf);
    buf.putString(' re\n');
  }

  /// Draws a Rectangle
  void drawBox(PdfRect box) {
    drawRect(box.x, box.y, box.width, box.height);
  }

  /// Draws a Rounded Rectangle
  void drawRRect(double x, double y, double w, double h, double rv, double rh) {
    moveTo(x, y + rv);
    curveTo(x, y - _m4 * rv + rv, x - _m4 * rh + rh, y, x + rh, y);
    lineTo(x + w - rh, y);
    curveTo(x + _m4 * rh + w - rh, y, x + w, y - _m4 * rv + rv, x + w, y + rv);
    lineTo(x + w, y + h - rv);
    curveTo(x + w, y + _m4 * rv + h - rv, x + _m4 * rh + w - rh, y + h,
        x + w - rh, y + h);
    lineTo(x + rh, y + h);
    curveTo(x - _m4 * rh + rh, y + h, x, y + _m4 * rv + h - rv, x, y + h - rv);
    lineTo(x, y + rv);
  }

  /// Set the current font and size
  void setFont(
    PdfFont font,
    double size, {
    double? charSpace,
    double? wordSpace,
    double? scale,
    PdfTextRenderingMode? mode = PdfTextRenderingMode.fill,
    double? rise,
  }) {
    buf.putString('${font.name} ');
    PdfNum(size).output(buf);
    buf.putString(' Tf\n');
    if (charSpace != null) {
      PdfNum(charSpace).output(buf);
      buf.putString(' Tc\n');
    }
    if (wordSpace != null) {
      PdfNum(wordSpace).output(buf);
      buf.putString(' Tw\n');
    }
    if (scale != null) {
      PdfNum(scale * 100).output(buf);
      buf.putString(' Tz\n');
    }
    if (rise != null) {
      PdfNum(rise).output(buf);
      buf.putString(' Ts\n');
    }
    if (mode != PdfTextRenderingMode.fill) {
      buf.putString('${mode!.index} Tr\n');
    }
  }

  /// This draws a string.
  void drawString(
    PdfFont font,
    double size,
    String s,
    double? x,
    double y, {
    double? charSpace = 0,
    double wordSpace = 0,
    double scale = 1,
    PdfTextRenderingMode? mode = PdfTextRenderingMode.fill,
    double rise = 0,
  }) {
    _page!.addFont(font);

    buf.putString('BT ');
    PdfNumList(<double?>[x, y]).output(buf);
    buf.putString(' Td ');
    setFont(font, size,
        charSpace: charSpace,
        mode: mode,
        rise: rise,
        scale: scale,
        wordSpace: wordSpace);
    buf.putString('[');
    font.putText(buf, s);
    buf.putString(']TJ ET\n');
  }

  void reset() {
    buf.putString('0 Tr\n');
  }

  /// Sets the color for drawing
  void setColor(PdfColor? color) {
    setFillColor(color);
    setStrokeColor(color);
  }

  /// Sets the fill color for drawing
  void setFillColor(PdfColor? color) {
    if (color is PdfColorCmyk) {
      PdfNumList(<double>[color.cyan, color.magenta, color.yellow, color.black])
          .output(buf);
      buf.putString(' k\n');
    } else {
      PdfNumList(<double>[color!.red, color.green, color.blue]).output(buf);
      buf.putString(' rg\n');
    }
  }

  /// Sets the stroke color for drawing
  void setStrokeColor(PdfColor? color) {
    if (color is PdfColorCmyk) {
      PdfNumList(<double>[color.cyan, color.magenta, color.yellow, color.black])
          .output(buf);
      buf.putString(' K\n');
    } else {
      PdfNumList(<double>[color!.red, color.green, color.blue]).output(buf);
      buf.putString(' RG\n');
    }
  }

  /// Sets the fill pattern for drawing
  void setFillPattern(PdfPattern pattern) {
    // The shader needs to be registered in the page resources
    _page!.addPattern(pattern);
    buf.putString('/Pattern cs${pattern.name} scn\n');
  }

  /// Sets the stroke pattern for drawing
  void setStrokePattern(PdfPattern pattern) {
    // The shader needs to be registered in the page resources
    _page!.addPattern(pattern);
    buf.putString('/Pattern CS${pattern.name} SCN\n');
  }

  /// Set the graphic state for drawing
  void setGraphicState(PdfGraphicState state) {
    final name = _page!.stateName(state);
    buf.putString('$name gs\n');
  }

  /// Set the transformation Matrix
  void setTransform(Matrix4 t) {
    final s = t.storage;
    PdfNumList(<double>[s[0], s[1], s[4], s[5], s[12], s[13]]).output(buf);
    buf.putString(' cm\n');
    _context.ctm.multiply(t);
  }

  /// Get the transformation Matrix
  Matrix4 getTransform() {
    return _context.ctm.clone();
  }

  /// This adds a line segment to the current path
  void lineTo(double? x, double? y) {
    PdfNumList(<double?>[x, y]).output(buf);
    buf.putString(' l\n');
  }

  /// This moves the current drawing point.
  void moveTo(double? x, double? y) {
    PdfNumList(<double?>[x, y]).output(buf);
    buf.putString(' m\n');
  }

  /// Draw a cubic bézier curve from the current point to (x3,y3)
  /// using (x1,y1) as the control point at the beginning of the curve
  /// and (x2,y2) as the control point at the end of the curve.
  void curveTo(
      double? x1, double? y1, double? x2, double? y2, double? x3, double? y3) {
    PdfNumList(<double?>[x1, y1, x2, y2, x3, y3]).output(buf);
    buf.putString(' c\n');
  }

  double _vectorAngle(double ux, double uy, double vx, double vy) {
    final d = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
    if (d == 0.0) {
      return 0;
    }
    var c = (ux * vx + uy * vy) / d;
    if (c < -1.0) {
      c = -1.0;
    } else if (c > 1.0) {
      c = 1.0;
    }
    final s = ux * vy - uy * vx;
    c = math.acos(c);
    return c.sign == s.sign ? c : -c;
  }

  void _endToCenterParameters(double x1, double y1, double x2, double y2,
      bool large, bool sweep, double rx, double ry) {
    // See http://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes F.6.5

    rx = rx.abs();
    ry = ry.abs();

    final x1d = 0.5 * (x1 - x2);
    final y1d = 0.5 * (y1 - y2);

    var r = x1d * x1d / (rx * rx) + y1d * y1d / (ry * ry);
    if (r > 1.0) {
      final rr = math.sqrt(r);
      rx *= rr;
      ry *= rr;
      r = x1d * x1d / (rx * rx) + y1d * y1d / (ry * ry);
    } else if (r != 0.0) {
      r = 1.0 / r - 1.0;
    }

    if (-1e-10 < r && r < 0.0) {
      r = 0.0;
    }

    r = math.sqrt(r);
    if (large == sweep) {
      r = -r;
    }

    final cxd = (r * rx * y1d) / ry;
    final cyd = -(r * ry * x1d) / rx;

    final cx = cxd + 0.5 * (x1 + x2);
    final cy = cyd + 0.5 * (y1 + y2);

    final theta = _vectorAngle(1, 0, (x1d - cxd) / rx, (y1d - cyd) / ry);
    var dTheta = _vectorAngle((x1d - cxd) / rx, (y1d - cyd) / ry,
            (-x1d - cxd) / rx, (-y1d - cyd) / ry) %
        (math.pi * 2.0);
    if (sweep == false && dTheta > 0.0) {
      dTheta -= math.pi * 2.0;
    } else if (sweep == true && dTheta < 0.0) {
      dTheta += math.pi * 2.0;
    }
    _bezierArcFromCentre(cx, cy, rx, ry, -theta, -dTheta);
  }

  void _bezierArcFromCentre(double cx, double cy, double rx, double ry,
      double startAngle, double extent) {
    int fragmentsCount;
    double fragmentsAngle;

    if (extent.abs() <= math.pi / 2.0) {
      fragmentsCount = 1;
      fragmentsAngle = extent;
    } else {
      fragmentsCount = (extent.abs() / (math.pi / 2.0)).ceil().toInt();
      fragmentsAngle = extent / fragmentsCount.toDouble();
    }
    if (fragmentsAngle == 0.0) {
      return;
    }

    final halfFragment = fragmentsAngle * 0.5;
    var kappa =
        (4.0 / 3.0 * (1.0 - math.cos(halfFragment)) / math.sin(halfFragment))
            .abs();

    if (fragmentsAngle < 0.0) {
      kappa = -kappa;
    }

    var theta = startAngle;
    final startFragment = theta + fragmentsAngle;

    var c1 = math.cos(theta);
    var s1 = math.sin(theta);
    for (var i = 0; i < fragmentsCount; i++) {
      final c0 = c1;
      final s0 = s1;
      theta = startFragment + i * fragmentsAngle;
      c1 = math.cos(theta);
      s1 = math.sin(theta);
      curveTo(
          cx + rx * (c0 - kappa * s0),
          cy - ry * (s0 + kappa * c0),
          cx + rx * (c1 + kappa * s1),
          cy - ry * (s1 - kappa * c1),
          cx + rx * c1,
          cy - ry * s1);
    }
  }

  /// Draws an elliptical arc from (x1, y1) to (x2, y2).
  /// The size and orientation of the ellipse are defined by two radii (rx, ry)
  /// The center (cx, cy) of the ellipse is calculated automatically to satisfy
  /// the constraints imposed by the other parameters. large and sweep flags
  /// contribute to the automatic calculations and help determine how the arc is drawn.
  void bezierArc(
      double? x1, double? y1, double rx, double ry, double? x2, double? y2,
      {bool large = false, bool sweep = false, double phi = 0.0}) {
    if (x1 == x2 && y1 == y2) {
      // From https://www.w3.org/TR/SVG/implnote.html#ArcImplementationNotes:
      // If the endpoints (x1, y1) and (x2, y2) are identical, then this is
      // equivalent to omitting the elliptical arc segment entirely.
      return;
    }

    if (rx.abs() <= 1e-10 || ry.abs() <= 1e-10) {
      lineTo(x2, y2);
      return;
    }

    if (phi != 0.0) {
      // Our box bézier arcs can't handle rotations directly
      // move to a well known point, eliminate phi and transform the other point
      final mat = Matrix4.identity();
      mat.translate(-x1!, -y1!);
      mat.rotateZ(-phi);
      final tr = mat.transform3(Vector3(x2!, y2!, 0));
      _endToCenterParameters(0, 0, tr[0], tr[1], large, sweep, rx, ry);
    } else {
      _endToCenterParameters(x1!, y1!, x2!, y2!, large, sweep, rx, ry);
    }
  }

  /// Draw an SVG path
  void drawShape(String d) {
    final proxy = _PathProxy(this);
    writeSvgPathDataToPath(d, proxy);
  }

  /// Calculates the bounding box of an SVG path
  static PdfRect shapeBoundingBox(String d) {
    final proxy = _PathBBProxy();
    writeSvgPathDataToPath(d, proxy);
    return proxy.box;
  }

  /// Set line starting and ending cap type
  void setLineCap(PdfLineCap cap) {
    buf.putString('${cap.index} J\n');
  }

  /// Set line join type
  void setLineJoin(PdfLineJoin join) {
    buf.putString('${join.index} j\n');
  }

  /// Set line width
  void setLineWidth(double width) {
    PdfNum(width).output(buf);
    buf.putString(' w\n');
  }

  /// Set line joint miter limit, applies if the
  void setMiterLimit(double limit) {
    assert(limit >= 1.0);
    PdfNum(limit).output(buf);
    buf.putString(' M\n');
  }

  /// The dash array shall be cycled through, adding up the lengths of dashes and gaps.
  /// When the accumulated length equals the value specified by the dash phase
  ///
  /// Example: [2 1] will create a dash pattern with 2 on, 1 off, 2 on, 1 off, ...
  void setLineDashPattern([List<num> array = const <num>[], int phase = 0]) {
    PdfArray.fromNum(array).output(buf);
    buf.putString(' $phase d\n');
  }
}

class _PathProxy extends PathProxy {
  _PathProxy(this.canvas);

  final PdfGraphics canvas;

  @override
  void close() {
    canvas.closePath();
  }

  @override
  void cubicTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    canvas.curveTo(x1, y1, x2, y2, x3, y3);
  }

  @override
  void lineTo(double x, double y) {
    canvas.lineTo(x, y);
  }

  @override
  void moveTo(double x, double y) {
    canvas.moveTo(x, y);
  }
}

class _PathBBProxy extends PathProxy {
  _PathBBProxy();

  var _xMin = double.infinity;
  var _yMin = double.infinity;
  var _xMax = double.negativeInfinity;
  var _yMax = double.negativeInfinity;

  var _pX = 0.0;
  var _pY = 0.0;

  PdfRect get box {
    if (_xMin > _xMax || _yMin > _yMax) {
      return PdfRect.zero;
    }
    return PdfRect.fromLTRB(_xMin, _yMin, _xMax, _yMax);
  }

  @override
  void close() {}

  @override
  void cubicTo(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    final tvalues = <double>[];
    double a, b, c, t, t1, t2, b2ac, sqrtb2ac;

    for (var i = 0; i < 2; ++i) {
      if (i == 0) {
        b = 6 * _pX - 12 * x1 + 6 * x2;
        a = -3 * _pX + 9 * x1 - 9 * x2 + 3 * x3;
        c = 3 * x1 - 3 * _pX;
      } else {
        b = 6 * _pY - 12 * y1 + 6 * y2;
        a = -3 * _pY + 9 * y1 - 9 * y2 + 3 * y3;
        c = 3 * y1 - 3 * _pY;
      }
      if (a.abs() < 1e-12) {
        if (b.abs() < 1e-12) {
          continue;
        }
        t = -c / b;
        if (0 < t && t < 1) {
          tvalues.add(t);
        }
        continue;
      }
      b2ac = b * b - 4 * c * a;
      if (b2ac < 0) {
        if (b2ac.abs() < 1e-12) {
          t = -b / (2 * a);
          if (0 < t && t < 1) {
            tvalues.add(t);
          }
        }
        continue;
      }
      sqrtb2ac = math.sqrt(b2ac);
      t1 = (-b + sqrtb2ac) / (2 * a);
      if (0 < t1 && t1 < 1) {
        tvalues.add(t1);
      }
      t2 = (-b - sqrtb2ac) / (2 * a);
      if (0 < t2 && t2 < 1) {
        tvalues.add(t2);
      }
    }

    for (final t in tvalues) {
      final mt = 1 - t;
      _updateMinMax(
          (mt * mt * mt * _pX) +
              (3 * mt * mt * t * x1) +
              (3 * mt * t * t * x2) +
              (t * t * t * x3),
          (mt * mt * mt * _pY) +
              (3 * mt * mt * t * y1) +
              (3 * mt * t * t * y2) +
              (t * t * t * y3));
    }
    _updateMinMax(_pX, _pY);
    _updateMinMax(x3, y3);

    _pX = x3;
    _pY = y3;
  }

  @override
  void lineTo(double x, double y) {
    _pX = x;
    _pY = y;
    _updateMinMax(x, y);
  }

  @override
  void moveTo(double x, double y) {
    _pX = x;
    _pY = y;
    _updateMinMax(x, y);
  }

  void _updateMinMax(double x, double y) {
    _xMin = math.min(_xMin, x);
    _yMin = math.min(_yMin, y);
    _xMax = math.max(_xMax, x);
    _yMax = math.max(_yMax, y);
  }
}
