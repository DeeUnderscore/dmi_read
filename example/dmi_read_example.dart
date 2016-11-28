import 'dart:io';

import 'package:dmi_read/dmi_read.dart';
import 'package:image/image.dart';

main() async {
  var fileBytes = await new File('test/samples/anim.dmi').readAsBytes();

  DmiSheet sheet;

  try {
    sheet = new DmiSheet.fromBytes(fileBytes);
  } on DmiParseError catch (e) {
    // Problems with loading the DMI file will result in `DmiParseError` or its
    // subclasses getting thrown
    print('Something went wrong with loading. ' + e.toString());
    exit(1);
  }

  // Print some information about the whole sheet
  print('Icon size: ${sheet.iconWidth} × ${sheet.iconHeight}');
  print('States:');

  // Go through all the states in this dmi sheet and print some metadata
  for (var state in sheet.states) {
    // PixmapState and MovieState are the two possible things a state can be
    if (state is PixmapState) {
      print('• ${state.name}, pixmap');
    } else if (state is MovieState) {
      print(
          '• ${state.name}, movie, ${state.framesCount} frames in ${state.directionsCount} directions');
    }
  }

  // Save an image from the sheet
  MovieState state =
      sheet.getStateNamed('anim'); // 'anim' is the name of the state set in DM
  DmiIcon icon =
      state.icons[IconDirection.north][0]; // first icon in the north direction

  // We use the `image` library's `encodePng` to save the icon as PNG
  var outFile =
      await new File('first-frame.png').writeAsBytes(encodePng(icon.image));

  // We can also find the icon's hotspot
  print('Wrote icon with hotspot ${icon.hotspot} to $outFile');
}
