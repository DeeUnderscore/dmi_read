import 'package:test/test.dart';

import 'dart:io';

import 'package:image/image.dart';

import 'package:dmi_read/src/dmi_sheet.dart';

var _animFile = 'test/samples/anim.dmi';
var _twoStaticFile = 'test/samples/two-static.dmi';
var _leftPngFile = 'test/samples/left.png';

main() async {
  var animBytes = await new File(_animFile).readAsBytes();
  var twoStaticBytes = await new File(_twoStaticFile).readAsBytes();
  var leftPngBytes = await new File(_leftPngFile).readAsBytes();

  test('Point equality checking works', () {
    expect(new Point(1, 1), equals(new Point(1, 1)));
    expect(
        new Point(1, 1),
        isNot(anyOf(equals(new Point(1, 0)), equals(new Point(0, 1)),
            equals(new Point(0, 0)))));
  });

  group('Animation states', () {
    DmiSheet sheet;
    MovieState anim;

    setUp(() {
      sheet = new DmiSheet.fromBytes(animBytes);
      anim = sheet.states[0];
    });

    test('are properly instantiated as MovieState', () {
      expect(sheet.states[0], new isInstanceOf<MovieState>());
    });

    test('Icon size is correct', () {
      expect(sheet.iconWidth, equals(32));
      expect(sheet.iconHeight, equals(32));
    });

    test('have correct number of frames', () {
      expect(anim.framesCount, equals(2));
      anim.icons.forEach((_, frames) {
        expect(frames.length, equals(2));
      });
    });

    test('have the correct number of directions', () {
      expect(anim.directionsCount, equals(4));
      expect(anim.icons.length, equals(4));
    });

    test('Hotspots are parsed correctly', () {
      expect(
          anim.icons[IconDirection.south][0].hotspot, equals(new Point(0, 0)));
      expect(anim.icons[IconDirection.north][0].hotspot,
          equals(new Point(31, 31)));
    });

    test('report correct number of icons', () {
      expect(anim.iconCount, equals(8));
    });

    test('return correct thumbnail', () {
      expect(anim.thumbnail.getBytes(),
          equals(anim.icons[IconDirection.south][0].image.getBytes()));
    });
  });

  group('Static icons', () {
    DmiSheet sheet;

    setUp(() {
      sheet = new DmiSheet.fromBytes(twoStaticBytes);
    });

    test('Image width is correct', () {
      expect(sheet.imageWidth, equals(64));

      // Again, to fetch cached
      expect(sheet.imageWidth, equals(64));
    });

    test('Image height is correct', () {
      expect(sheet.imageHeight, equals(32));
      expect(sheet.imageHeight, equals(32));
    });

    test('Number of rows is reported correctly', () {
      expect(sheet.rowCount, equals(1));
    });

    test('Number of columns is reported correctly', () {
      expect(sheet.columnCount, equals(2));
    });

    test('Coordinates of icons are calculated correctly', () {
      expect(sheet.getIconCoords(0), equals(new Point(0, 0)));
      expect(sheet.getIconCoords(1), equals(new Point(32, 0)));
    });

    test('Bad indices in getIconCoords() are caught', () {
      expect(() => sheet.getIconCoords(-1),
          throwsA(new isInstanceOf<RangeError>()));
      expect(() => sheet.getIconCoords(10),
          throwsA(new isInstanceOf<RangeError>()));
    });
  });

  group('Image processing', () {
    Image leftPng;
    DmiSheet sheet;

    setUp(() {
      leftPng = decodePng(leftPngBytes);
      sheet = new DmiSheet.fromBytes(twoStaticBytes);
    });

    test('Icon is properly extracted to separate image', () {
      DmiState state = sheet.getStateNamed('left');
      DmiIcon icon;

      if (state is PixmapState) {
        icon = state.icon;
      } else {
        fail('Problem fetching state, cannot extract icon');
      }

      expect(icon.image.getBytes(), equals(leftPng.getBytes()));
    });
  });
}
