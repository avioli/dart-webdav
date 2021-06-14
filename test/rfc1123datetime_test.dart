import 'package:test/test.dart';
import 'package:webdav/src/rfc1123datetime.dart';

void main() {
  test('parseRFC1123Date() parses a formatted date', () {
    expect(
      parseRFC1123Date('Mon, 12 Jan 1998 09:25:56 GMT'),
      DateTime.utc(1998, 1, 12, 9, 25, 56),
    );
    // Zero-padded day
    expect(
      parseRFC1123Date('Fri, 09 Jan 1998 09:25:56 GMT'),
      DateTime.utc(1998, 1, 9, 9, 25, 56),
    );
  });

  test('parseRFC1123Date() parses a formatted date with in case', () {
    expect(
      parseRFC1123Date('mon, 12 JAN 1998 09:25:56 GmT'),
      DateTime.utc(1998, 1, 12, 9, 25, 56),
    );
  });

  test('parseRFC1123Date() throws when bad format', () {
    // Timezone format
    expect(
      () => parseRFC1123Date('Mon, 12 Jan 1998 09:25:56 +00:00'),
      throwsFormatException,
    );
    // Extra spaces
    expect(
      () => parseRFC1123Date('Mon,  12 Jan 1998 09:25:56 GMT'),
      throwsFormatException,
    );
    // Non-matching weekday
    expect(
      () => parseRFC1123Date('Wed, 12 Jan 1998 09:25:56 GMT'),
      allOf(
        throwsFormatException,
        throwsA(ToStringMatches(contains('weekday'))),
      ),
    );
    // Missing weekday
    expect(
      () => parseRFC1123Date('12 Jan 1998 09:25:56 GMT'),
      throwsFormatException,
    );
    // Single-digit day
    expect(
      () => parseRFC1123Date('Fri, 9 Jan 1998 09:25:56 GMT'),
      throwsFormatException,
    );
  });
}

class ToStringMatches extends CustomMatcher {
  ToStringMatches(matcher)
      : super('Object.toString() value that', 'toString', matcher);
  featureValueOf(actual) => (actual as Object).toString();
}
