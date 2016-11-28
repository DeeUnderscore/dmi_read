/// Exception indicating something went wrong parsing a DMI file
class DmiParseError implements Exception {
  final String detail;

  DmiParseError([this.detail]);

  toString() => detail;
}


/// Error trying to load the dmi as a PNG
class PNGParseError extends DmiParseError {
  PNGParseError([String detail]) : super(detail);
}

/// Error trying to parse the dmi description
class DescriptionParseError extends DmiParseError {
  DescriptionParseError([String detail]) : super(detail);
}
