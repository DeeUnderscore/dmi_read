import 'dart:collection' show Queue;

import 'package:string_scanner/string_scanner.dart';

import 'exceptions.dart';

/// A single key-value pair in a dmi description. Both key and value are always
/// strings
class Statement {
  final String key;
  final String value;

  Statement(this.key, this.value);

  String toString() => '$key = $value';
}

/// A single block in a dmi description, along with the header
class Block {
  final Statement header;
  Queue<Statement> children = new Queue();

  Block(this.header);

  String toString() =>
      header.toString() +
      children.map((i) => "\t" + i.toString() + "\n").join('');
}

/// Lex a dmi description
///
/// This is a parser which parses the descriptions contained in dmi files. This
/// function returns a list of blocks. Each block consists of a heading (a
/// key-value pair), and any number of key-value pairs inside the block.
Queue<Block> parseDmiDescription(String source) {
  Queue<Block> blocks = new Queue();
  var scanner = new StringScanner(source);

  if (!scanner.scan(new RegExp(r'.*# BEGIN DMI\n'))) {
    throw new DescriptionParseError(
        'Could not find opening tag in description.');
  }

  Block currentBlock;

  final headerRegex = new RegExp(r'(\w+)\s+=\s+(.*)\n');
  final blockRegex = new RegExp(r'\t(\w+)\s+=\s+(.*)\n');
  final endMarkerRegex = new RegExp(r'# END DMI');

  do {
    if (scanner.scan(headerRegex)) {
      if (currentBlock != null) {
        blocks.add(currentBlock);
      }

      currentBlock =
          new Block(new Statement(scanner.lastMatch[1], scanner.lastMatch[2]));
    } else if (scanner.scan(blockRegex)) {
      if (currentBlock == null) {
        throw new DescriptionParseError(
            'Found indented section "${scanner.lastMatch[0]}", but no block header');
      }

      currentBlock.children
          .add(new Statement(scanner.lastMatch[1], scanner.lastMatch[2]));
    } else if (scanner.scan(endMarkerRegex)) {
      if (currentBlock != null) {
        blocks.add(currentBlock);
      }
      return blocks;
    } else {
      throw new DescriptionParseError('Encountered unexpected characters.');
    }
  } while (!scanner.isDone);

  throw new DescriptionParseError(
      'Encountered the end of the description string without finding an "# END DMI" line.');
}

/// Trim quotes off a quoted string in a DMI description
///
/// Warning: Doesn't actually strip quotes, just trims spaces and chomps the two
/// outermost characters
String stripQuotes(String input) => input.trim().substring(1, input.length - 1);

List<int> stringToIntList(String input, [String separator=',']) =>
    input.split(separator).map((i) => int.parse(i)).toList();
