/// Library for parsing and reading dmi files used by the BYOND platform.
///
/// ## Structure
/// * [DmiSheet] objects represent the whole sprite sheet and associated metadata. They contain `DmiState`s, which can be either [PixmapState]s or [MovieState]s.
/// * [PixmapState] represents a single, unmoving icon state (what DM calls a 'pixmap')
/// * [MovieState] represents an animation, possibly in different directions (what DM calls a 'movie')
/// * [DmiIcon] represents a single icon. These can be found in the states, either alone or as a single frame in an animation
///
/// Generally, working with dmi sheets will require instantiating a new DmiSheet with [new DmiSheet.fromBytes()]. The sheet object will then provide things like [DmiSheet.states] and [DmiSheet.getStateNamed()] for getting individual states, which then provide members with both metadata and actual [Image] objects for individual icons.
///
/// [Image] is provided by the [image package](https:///pub.dartlang.org/packages/image). Functions provided by the package such as `encodePng()` can be used for saving [Image] objects to disk.
library dmi_read;

export 'src/dmi_sheet.dart';
export 'src/exceptions.dart';
