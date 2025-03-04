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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vector_math/vector_math_64.dart';

import 'data.dart';

final _cache = <String, Uint8List>{};

Future<Uint8List> _download(String url) async {
  if (!_cache.containsKey(url)) {
    print('Downloading $url');
    final response = await http.get(Uri.parse(url));
    final data = response.bodyBytes;
    _cache[url] = Uint8List.fromList(data);
  }

  return _cache[url]!;
}

Future<pw.Font> _downloadFont(String url) async {
  final data = await _download(url);
  return pw.Font.ttf(data.buffer.asByteData());
}

Future<Uint8List> generateCertificate(
    PdfPageFormat pageFormat, CustomData data) async {
  final lorem = pw.LoremText();
  final pdf = pw.Document();

  final libreBaskerville = await _downloadFont(
      'https://fonts.gstatic.com/s/librebaskerville/v9/kmKnZrc3Hgbbcjq75U4uslyuy4kn0pNe.ttf');
  final libreBaskervilleItalic = await _downloadFont(
      'https://fonts.gstatic.com/s/librebaskerville/v9/kmKhZrc3Hgbbcjq75U4uslyuy4kn0qNcaxY.ttf');
  final libreBaskervilleBold = await _downloadFont(
      'https://fonts.gstatic.com/s/librebaskerville/v9/kmKiZrc3Hgbbcjq75U4uslyuy4kn0qviTjYw.ttf');
  final robotoLight = pw.Font.ttf(await rootBundle.load('assets/roboto3.ttf'));
  final medail = await rootBundle.loadString('assets/medail.svg');
  final swirls = await rootBundle.loadString('assets/swirls.svg');
  final swirls1 = await rootBundle.loadString('assets/swirls1.svg');
  final swirls2 = await rootBundle.loadString('assets/swirls2.svg');
  final swirls3 = await rootBundle.loadString('assets/swirls3.svg');
  final garland = await rootBundle.loadString('assets/garland.svg');

  pdf.addPage(
    pw.Page(
      build: (context) => pw.Column(
        children: [
          pw.Spacer(flex: 2),
          pw.RichText(
            text: pw.TextSpan(
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 25,
                ),
                children: [
                  pw.TextSpan(text: 'CERTIFICATE '),
                  pw.TextSpan(
                    text: 'of',
                    style: pw.TextStyle(
                      fontStyle: pw.FontStyle.italic,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                  pw.TextSpan(text: ' ACHIEVEMENT'),
                ]),
          ),
          pw.Spacer(),
          pw.Text(
            'THIS ACKNOWLEDGES THAT',
            style: pw.TextStyle(
              font: robotoLight,
              fontSize: 10,
              letterSpacing: 2,
              wordSpacing: 2,
            ),
          ),
          pw.SizedBox(
            width: 300,
            child: pw.Divider(color: PdfColors.grey, thickness: 1.5),
          ),
          pw.Text(
            data.name,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 20,
            ),
          ),
          pw.SizedBox(
            width: 300,
            child: pw.Divider(color: PdfColors.grey, thickness: 1.5),
          ),
          pw.Text(
            'HAS SUCCESSFULLY COMPLETED THE',
            style: pw.TextStyle(
              font: robotoLight,
              fontSize: 10,
              letterSpacing: 2,
              wordSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.SvgImage(
                svg: swirls,
                height: 10,
              ),
              pw.Padding(
                padding: pw.EdgeInsets.symmetric(horizontal: 10),
                child: pw.Text(
                  'Flutter PDF Demo',
                  style: pw.TextStyle(
                    fontSize: 10,
                  ),
                ),
              ),
              pw.Transform(
                transform: Matrix4.diagonal3Values(-1, 1, 1),
                adjustLayout: true,
                child: pw.SvgImage(
                  svg: swirls,
                  height: 10,
                ),
              ),
            ],
          ),
          pw.Spacer(),
          pw.SvgImage(
            svg: swirls2,
            width: 150,
          ),
          pw.Spacer(),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Flexible(
                child: pw.Text(
                  lorem.paragraph(40),
                  style: pw.TextStyle(fontSize: 6),
                  textAlign: pw.TextAlign.justify,
                ),
              ),
              pw.SizedBox(width: 100),
              pw.SvgImage(
                svg: medail,
                width: 100,
              ),
            ],
          ),
        ],
      ),
      pageTheme: pw.PageTheme(
        pageFormat: pageFormat,
        theme: pw.ThemeData.withFont(
          base: libreBaskerville,
          italic: libreBaskervilleItalic,
          bold: libreBaskervilleBold,
        ),
        buildBackground: (context) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(
            margin: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border:
                  pw.Border.all(color: PdfColor.fromInt(0xffe435), width: 1),
            ),
            child: pw.Container(
              margin: pw.EdgeInsets.all(5),
              decoration: pw.BoxDecoration(
                border:
                    pw.Border.all(color: PdfColor.fromInt(0xffe435), width: 5),
              ),
              width: double.infinity,
              height: double.infinity,
              child: pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  pw.Positioned(
                    top: 5,
                    child: pw.SvgImage(
                      svg: swirls1,
                      height: 60,
                    ),
                  ),
                  pw.Positioned(
                    bottom: 5,
                    child: pw.Transform(
                      transform: Matrix4.diagonal3Values(1, -1, 1),
                      adjustLayout: true,
                      child: pw.SvgImage(
                        svg: swirls1,
                        height: 60,
                      ),
                    ),
                  ),
                  pw.Positioned(
                    top: 5,
                    left: 5,
                    child: pw.SvgImage(
                      svg: swirls3,
                      height: 160,
                    ),
                  ),
                  pw.Positioned(
                    top: 5,
                    right: 5,
                    child: pw.Transform(
                      transform: Matrix4.diagonal3Values(-1, 1, 1),
                      adjustLayout: true,
                      child: pw.SvgImage(
                        svg: swirls3,
                        height: 160,
                      ),
                    ),
                  ),
                  pw.Positioned(
                    bottom: 5,
                    left: 5,
                    child: pw.Transform(
                      transform: Matrix4.diagonal3Values(1, -1, 1),
                      adjustLayout: true,
                      child: pw.SvgImage(
                        svg: swirls3,
                        height: 160,
                      ),
                    ),
                  ),
                  pw.Positioned(
                    bottom: 5,
                    right: 5,
                    child: pw.Transform(
                      transform: Matrix4.diagonal3Values(-1, -1, 1),
                      adjustLayout: true,
                      child: pw.SvgImage(
                        svg: swirls3,
                        height: 160,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: pw.EdgeInsets.only(
                      top: 120,
                      left: 80,
                      right: 80,
                      bottom: 80,
                    ),
                    child: pw.SvgImage(
                      svg: garland,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  return pdf.save();
}
