import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:family_tree/features/profile/photo_crop_sheet.dart';

/// A wide picture with a distinctly coloured centre, so a crop can be checked
/// by reading pixels rather than by eye.
Uint8List _wideTestImage() {
  final image = img.Image(width: 400, height: 200);
  img.fill(image, color: img.ColorRgb8(20, 40, 200)); // blue field
  img.fillRect(
    image,
    x1: 150,
    y1: 50,
    x2: 249,
    y2: 149,
    color: img.ColorRgb8(220, 30, 30), // red square, dead centre
  );
  return Uint8List.fromList(img.encodePng(image));
}

Widget _harness(Uint8List bytes, void Function(Uint8List?) onResult) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            onResult(await PhotoCropSheet.show(context, bytes: bytes));
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('crops to a square centred on the framed area', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Uint8List? result;
    await tester.pumpWidget(_harness(_wideTestImage(), (r) => result = r));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use this photo'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    final cropped = img.decodeImage(result!)!;

    // Square, whatever the source aspect ratio was.
    expect(cropped.width, cropped.height,
        reason: 'a profile photo is drawn in a circle, so it must be square');

    // Untouched, the frame sits on the middle of the image — the red square.
    final centre = cropped.getPixel(cropped.width ~/ 2, cropped.height ~/ 2);
    expect(centre.r, greaterThan(150));
    expect(centre.g, lessThan(100));
  });

  testWidgets('never returns anything larger than the display size',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A photo far larger than anything the tree ever renders.
    final big = img.Image(width: 3000, height: 2000);
    img.fill(big, color: img.ColorRgb8(80, 120, 60));

    Uint8List? result;
    await tester.pumpWidget(
      _harness(Uint8List.fromList(img.encodePng(big)), (r) => result = r),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this photo'));
    await tester.pumpAndSettle();

    final cropped = img.decodeImage(result!)!;
    expect(cropped.width, lessThanOrEqualTo(512),
        reason: 'a multi-megapixel upload for an 88px card is waste');
  });

  testWidgets('cancelling returns nothing', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var called = false;
    Uint8List? result;
    await tester.pumpWidget(_harness(_wideTestImage(), (r) {
      called = true;
      result = r;
    }));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(result, isNull);
  });

  testWidgets('says so when the bytes are not an image', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(Uint8List.fromList([1, 2, 3, 4, 5]), (_) {}),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text('That file could not be read as an image'),
      findsOneWidget,
    );
    expect(find.text('Use this photo'), findsNothing);
  });
}
