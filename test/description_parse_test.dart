import 'package:test/test.dart';

import 'package:dmi_read/src/description_parser.dart';

var _sample = """# BEGIN DMI
version = 4.0
\twidth = 32
\theight = 32
state = "someone"
\tdirs = 4
\tframes = 1
# END DMI""";

main () {
  test('DMI description is parsed into blocks', () {
    var parsed = parseDmiDescription(_sample).toList();

    expect(parsed[0].header.key, equals('version'));
    expect(parsed[0].header.value, equals('4.0'));

    // Normally, we don't need random access to children, so it's a queue
    expect(parsed[1].children.toList()[0].key, equals('dirs'));
    expect(parsed[1].children.toList()[1].value, equals('1'));
  });

  test('stripQuotes() strips quotes', () {
    expect(stripQuotes('"Test quote"'), equals('Test quote'));
  });

  test('stringToIntList() parses a comma-separated list', () {
    expect(stringToIntList('1,2,5'), equals([1,2,5]));
  });
}
