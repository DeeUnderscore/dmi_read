import 'dart:collection' show Queue, LinkedHashMap, UnmodifiableListView;

import 'package:image/image.dart';

import 'package:dmi_read/src/png_reader.dart';
import 'package:dmi_read/src/description_parser.dart';
import 'package:dmi_read/src/exceptions.dart';

/// An object representing a Dmi spritesheet
class DmiSheet {
  List<int> _bytes;

  /// Width of each icon in the sheet
  int iconWidth;

  /// Height of each icon in the sheet
  int iconHeight;

  int _imageHeight;
  int _imageWidth;

  /// Height of the whole sprite sheet
  int get imageHeight => _imageHeight ?? (_imageHeight = image.height);

  /// Width of the whole sprite sheet
  int get imageWidth => _imageWidth ?? (_imageWidth = image.width);

  Image _image;

  /// Whole sprite sheet as image
  ///
  /// Images are lazily evaluated. Although the sheet object expects the whole
  /// image to be loaded into memory, it does not actually process the image
  /// as a PNG until it is necessary to do so
  Image get image {
    if (_image == null) {
      _image = decodeImage(_bytes);
      _bytes = null;
    }

    return _image;
  }

  /// Number of icons horizontally in one row of the sprite sheet
  int get columnCount => imageWidth ~/ iconWidth;

  /// Number of icons vertically in one column of the sprite sheet
  int get rowCount => imageHeight ~/ iconHeight;

  /// Icon states defined for this dmi sheet
  UnmodifiableListView<DmiState> get states =>
      new UnmodifiableListView(_states);

  List<DmiState> _states = [];
  Map<String, DmiState> _statesByName = {};

  /// Return state with the given name or `null` if not present
  DmiState getStateNamed(String name) => _statesByName[name];

  /// Get the coordinates for the upper left of an icon in the spritesheet
  ///
  /// `index` starts at 0 and advances row first. Note that this function will
  /// **not** throw a [RangeError] if the last row isn't full and it's asked
  /// coordinates for an icon that would have been there, had the row been full.
  /// It will throw a [RangeError] for indices that couldn't possibly be on the
  /// sheet.
  Point getIconCoords(int index) {
    if (index < 0) {
      throw new RangeError('Icon index cannot be less than 0');
    }

    var row = index ~/ columnCount;

    if (row > rowCount) {
      throw new RangeError('Index $index is outside of sheet');
    }
    var col = index % columnCount;

    return new Point((col * iconWidth), (row * iconHeight));
  }

  /// Load from a dmi file loaded into a list of bytes
  DmiSheet.fromBytes(List<int> bytes) {
    _bytes = bytes;

    Queue<Block> blocks = new Queue.from(parseDmiDescription(getZtxt(bytes)));

    // The first block contains info about the whole sheet, so we parse it
    // separately. It always starts with a 'version' header.
    Block firstBlock = blocks.removeFirst();
    if (firstBlock.header.key != 'version') {
      throw new DescriptionParseError(
          'Description does not open with a version header '
          '(opened with $firstBlock.header)');
    }

    // We assume that we're incompatible with other versions, although who knows
    // if the version number is a useful indicator of anything
    int majorVersion = int.parse(new RegExp(r'(\d+).(\d+)')
        .firstMatch(firstBlock.header.value)
        .group(1));

    if (majorVersion != 4) {
      throw new DmiParseError('Incompatible major dmi version');
    }

    for (var statement in firstBlock.children) {
      if (statement.key == 'width') {
        iconWidth = int.parse(statement.value);
      } else if (statement.key == 'height') {
        iconHeight = int.parse(statement.value);
      }
    }

    // We could default to 32×32, but it seems like descriptions always specify
    // dimensions, so we consider otherwise to be an error.
    if (iconWidth == null || iconHeight == null) {
      throw new DmiParseError('Description does not specify icon dimensions');
    }

    var iconCount = 0;

    for (var block in blocks) {
      var state = new DmiState._fromBlock(block, this, iconCount);
      iconCount += state.iconCount;
      _states.add(state);
      _statesByName[state.name] = state;
    }
  }
}

/// An object representing a Dmi sheet state
///
/// Entries in a Dmi sheet (called 'states' in BYOND) can be either 'pixmaps',
/// in which case [PixmapState] should be used, or 'movies', in which case
/// [MovieState] should be used.
abstract class DmiState {
  /// State name, the string which is used to refer to the state in DM code
  final String name;
  bool movement;

  DmiState(this.name, this.movement);

  /// Total number of icons in the state
  int get iconCount;

  /// Convenience function for getting a representative icon for this state
  Image get thumbnail;

  /// Parse a description [Block] describing a state and instantiate that state
  ///
  /// [iconCount] is used to determine the index offset for the new icons
  factory DmiState._fromBlock(Block block, DmiSheet sheet, int iconCount) {
    int dirCount;
    int frameCount;
    String name;
    List<int> delays;
    bool movement = false;
    Map<int, Point> hotspots = {}; // frame number to x,y

    if (block.header.key != 'state') {
      throw new DmiParseError('Invalid state header $block.header');
    }

    name = stripQuotes(block.header.value);

    for (var child in block.children) {
      if (child.key == 'dirs') {
        dirCount = int.parse(child.value);
      } else if (child.key == 'frames') {
        frameCount = int.parse(child.value);
      } else if (child.key == 'movement') {
        movement = child.value == '1';
      } else if (child.key == 'delay') {
        delays = stringToIntList(child.value);
      } else if (child.key == 'hotspot') {
        // hotspots are specified as [x,y,index]
        var hotspot = stringToIntList(child.value);
        hotspots[hotspot[2]] = new Point(hotspot[0], hotspot[1]);
      }
      // We silently ignore entries we don't recognize
    }

    if (dirCount == null || frameCount == null || name == null) {
      throw new DmiParseError('Incomplete specification for $block.header');
    }

    if (dirCount * frameCount == 1) {
      return new PixmapState(name, new DmiIcon(sheet, iconCount, hotspots[1]),
          movement: movement);
    } else {
      List<IconDirection> availableDirs;
      if (dirCount == 1) {
        availableDirs = [IconDirection.none];
      } else {
        availableDirs = IconDirection.values.sublist(1, dirCount + 1);
      }

      // For each of dirCount directions, make a list of icons of length frameCount
      LinkedHashMap<IconDirection, List<DmiIcon>> icons =
          new LinkedHashMap.fromIterable(availableDirs,
              key: (dir) => dir, value: (_) => new List(frameCount));

      // Images are stored direction first. For a movie like this:
      //  Frame: 1 2
      //  North: a b
      //  South: c d
      //
      // The sheet would be arranged in this order: a c b d
      var hotspotIndex = 1;
      var globalIndex = iconCount;

      for (var frameIndex = 0; frameIndex < frameCount; frameIndex++) {
        for (var dir in availableDirs) {
          icons[dir][frameIndex] =
              new DmiIcon(sheet, globalIndex, hotspots[hotspotIndex]);

          globalIndex++;
          hotspotIndex++;
        }
      }

      // dmi files will happily include any number of items in the delays list,
      // but the meaningful values are only the 0 to frameCount-1, so for the sake
      // of sanity we discard the extra information
      if(delays != null) {
        delays = delays.sublist(0, frameCount);
      }

      return new MovieState(
        name,
        icons,
        delays,
        directionsCount: dirCount,
        framesCount: frameCount,
        movement: movement,
      );
    }
  }
}

/// A pixmap Dmi state
///
/// This is a state representing a single image only.
class PixmapState extends DmiState {
  final DmiIcon icon;

  int get iconCount => 1; // Pixmap is always one icon

  Image get thumbnail => icon.image;

  PixmapState(name, this.icon, {movement: false}) : super(name, movement);
}

/// A movie Dmi state
///
/// This state can consist of a number of animations, each with the same number
/// of frames and the same delay between each frame.
///
/// A movie can contain a single animation, or a number of animations
/// corresponding to different facing directions of the object. The number of
/// directions will either be 4 (cardinal directions) or 8 (cardinal directions
/// and diagonals).
class MovieState extends DmiState {
  final int framesCount;
  final int directionsCount;

  int get iconCount => framesCount * directionsCount;

  /// Get first icon in first direction, for use as thumbnail
  Image get thumbnail => icons.values.first.first.image;

  /// List mapping directions to lists of animation frames
  final LinkedHashMap<IconDirection, List<DmiIcon>> icons;

  /// Animation delays for each frame of the animation.
  ///
  /// These delays are the same for every direction. The list will always have
  /// as many items as [framesCount], even if the delays list defined in the dmi
  /// itself is longer.
  List<int> delays;

  MovieState(name, this.icons, this.delays,
      {this.framesCount: 1, this.directionsCount: 1, movement: false})
      : super(name, movement);
}

/// Possible directions for movie states
///
/// `none` is used for single direction icons. Remaining directions are in the
/// order they are saved in.
enum IconDirection {
  none,
  south,
  north,
  east,
  west,
  southeast,
  southwest,
  northeast,
  northwest,
}

/// A single icon in a Dmi sheet
///
/// The description format optionally specifies hotspot coordinates with
/// reference to the upper left corner of the whole sheet. These are provided
/// via [hotspot], which will be `null` if they were not specified.
class DmiIcon {
  final DmiSheet _sheet;

  /// Index of this icon within the sheet
  final int _index;

  Image _image;

  /// Hotspot global coordinates (with reference to the upper left corner of the
  /// icon
  final Point hotspot;

  /// Coordinates for this icon in the sprite sheet
  ///
  /// Coordinates are the upper left corner pixel of the icon, 0-indexed, with
  /// the origin in the upper left of the sheet and all numbers positve.
  Point get sheetPosition => _sheet.getIconCoords(_index);

  Image get image {
    if (_image == null) {
      _image = copyCrop(_sheet.image, sheetPosition.x, sheetPosition.y,
          _sheet.iconWidth, _sheet.iconHeight);
    }

    return _image;
  }

  /// Create an image, optionally specifying a hotspot
  ///
  /// [_sheet] is the sheet in which this icon can be found, [_index] is the
  /// index of the icon within the sheet
  DmiIcon(this._sheet, this._index, [this.hotspot]);
}

/// A generic (x,y) point
class Point {
  final int x;
  final int y;

  Point(this.x, this.y);

  bool operator ==(other) => other is Point && x == other.x && y == other.y;

  int get hashCode {
    // http://stackoverflow.com/a/113600/333814

    var result = 503;
    result = 37 * result + x;
    return 37 * result + y;
  }

  String toString() => '$x,$y';
}
