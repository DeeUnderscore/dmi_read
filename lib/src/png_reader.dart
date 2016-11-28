import 'dart:typed_data';
import 'dart:convert' show ASCII;

import 'package:archive/archive.dart';

import 'package:dmi_read/src/exceptions.dart';

const _pngMagicNumbers = const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/// Find a zTXt in a PNG and return its decompressed contents
///
/// This function goes through all the chunks in the supplied PNG bytes, finds
/// the first zTXt chunk, decompresses it and returns the string inside.
///
/// By default, it looks for the zTXt chunk with the keword 'Description'. Other
/// chunks can be fetched using [targetKeyword]. The default is what dmi uses.
///
/// It will throw [DmiParseError] if either it encouters a problem going through
/// the chunks or fails to find a zTXt chunk.
String getZtxt(List<int> png, [String targetKeyword = 'Description']) {
  var bytePos = 0;
  final bytes = new Uint8List.fromList(png);
  final bytesData = new ByteData.view(bytes.buffer);

  // dmis are valid PNGs, so we check for a valid PNG header first
  for (var number in _pngMagicNumbers) {
    if (number != bytes[bytePos++]) {
      throw new PNGParseError('PNG header does not match');
    }
  }

  // Now we go through all the chunks and figure out what they are
  while (bytePos < bytes.length) {
    // Length of the chunk payload, 4 bytes, unsigned int
    final chunkLength = bytesData.getUint32(bytePos);
    bytePos += 4;

    // Chunk type, 4 bytes, ASCII
    final chunkType = ASCII.decode(bytes.sublist(bytePos, bytePos + 4));
    bytePos += 4;

    if (chunkType == 'zTXt') {
      final startPos = bytePos;
      while (bytes[bytePos] != 0) bytePos++;

      final keywordString = ASCII.decode(bytes.sublist(startPos, bytePos));

      if (keywordString == targetKeyword) {
        if (bytes[++bytePos] != 0) {
          // The only valid compression method is 0, but we check in case BYOND
          // does something really weird
          throw new DmiParseError(
              'zTXt chunk with unknown compression method.');
        }

        return ASCII.decode(new ZLibDecoder()
            .decodeBytes(bytes.sublist(++bytePos, (startPos + chunkLength))));
      } else {
        // some other zTXt chunk. Skip it and its CRC.
        bytePos = startPos + chunkLength + 4;
      }
    } else {
      // Non-zTXt chunk, skip it and the CRC
      bytePos += chunkLength + 4; // skip 4 byte CRC that follows data
    }
  }

  throw new DmiParseError("Did not find a zTXt chunk");
}
