import 'package:test/test.dart';

import 'dart:io';

import 'package:dmi_read/src/png_reader.dart';

const helloWorldPng = 'test/samples/hello-world.png';

main() async{

  test('zTXt chunk is extracted and decompressed', () async {

    var pngFile = new File(helloWorldPng);
    var pngBytes = await pngFile.readAsBytes();

    expect(getZtxt(pngBytes), equals('Hello, world!'));
  });
}
