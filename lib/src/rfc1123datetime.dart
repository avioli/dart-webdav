/// Constructs a new [DateTime] instance based on [formattedString].
///
/// Throws a [FormatException] if the input string cannot be parsed.
///
/// The function parses a subset accepted by RFC 1123 in the following format:
///
/// `"$weekdayName, $day $monthName $years $hours:$minutes:$seconds GMT"`
///
/// * weekday name, month name and GMT can be in any case
///
/// Current restrictions:
/// * weekday name is required
/// * negative years are not supported
/// * only GMT is supported
///
/// Examples of accepted strings:
/// * `"Fri, 31 Dec 2021 23:59:59 GMT"`
/// * `"Thu, 01 Jan 1970 00:00:00 GMT"`
DateTime parseRFC1123Date(String formattedString) {
  final re = _rfc1123ParseFormat;
  Match? match = re.firstMatch(formattedString);
  if (match != null) {
    int weekday = _weekdaysMap[match[1]!.toLowerCase()]!;
    int day = int.parse(match[2]!);
    int month = _monthsMap[match[3]!.toLowerCase()]!;
    int years = int.parse(match[4]!);
    int hours = int.parse(match[5]!);
    int minutes = int.parse(match[6]!);
    int seconds = int.parse(match[7]!);
    final date = DateTime.utc(years, month, day, hours, minutes, seconds);
    if (date.weekday == weekday) {
      return date;
    }
    throw FormatException('Non-matching weekday', formattedString);
  }
  throw FormatException('Unsupported or invalid date format', formattedString);
}

DateTime? tryParseRFC1123Date(String formattedString) {
  try {
    return parseRFC1123Date(formattedString);
  } on FormatException {
    return null;
  }
}

// extension RFC1123DateTime on DateTime {
//   toRFC1123String() {
//     final utc = this.toUtc();
//     if (utc.year < 0) {
//       throw FormatException('Negative years are not supported');
//     }
//     final y = _fourDigits(utc.year);
//     final d = _twoDigits(utc.day);
//     final h = _twoDigits(utc.hour);
//     final min = _twoDigits(utc.minute);
//     final sec = _twoDigits(utc.second);
//     final weekdayName = _weekdaysReverseMap[utc.weekday];
//     final monthName = _monthsReverseMap[utc.month];
//     return '$weekdayName, $d $monthName $y $h:$min:$sec GMT';
//   }
// }

/// A pattern that parses a subset accepted by RFC 1123 formatted date
///
/// e.g. Sun, 06 Nov 1994 08:49:37 GMT
///
///     value     ::=  day ',' date time            ; dd mm yy
///                                                 ;  hh:mm:ss zzz
///     day       ::=  'Mon'  / 'Tue' /  'Wed'  / 'Thu'
///                 /  'Fri'  / 'Sat' /  'Sun'
///     date      ::=  1*2DIGIT month 1*4DIGIT      ; day month year
///                                                 ;  e.g. 20 Jun 1982
///     month     ::=  'Jan'  /  'Feb' /  'Mar'  /  'Apr'
///                 /  'May'  /  'Jun' /  'Jul'  /  'Aug'
///                 /  'Sep'  /  'Oct' /  'Nov'  /  'Dec'
///     time      ::=  hour zone
///     hour      ::=  2DIGIT ':' 2DIGIT ':' 2DIGIT ; 00:00:00 - 23:59:59
///     zone      ::=  'GMT'                        ; Greenwich Mean Time
///
/// Based on RFC 822: https://datatracker.ietf.org/doc/html/rfc822#section-5
///
/// Test playground: https://regex101.com/r/j7FoIL/1
final _rfc1123ParseFormat = RegExp(
    r'^(sun|mon|tue|wed|thu|fri|sat), ' // Day of the week part
    r'(\d{2}) (jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec) (\d{4}) ' // Date part
    r'(\d{2}):(\d{2}):(\d{2}) ' // Time part
    r'GMT$', // Timezone part
    caseSensitive: false);

final _weekdaysMap = {
  'mon': DateTime.monday,
  'tue': DateTime.tuesday,
  'wed': DateTime.wednesday,
  'thu': DateTime.thursday,
  'fri': DateTime.friday,
  'sat': DateTime.saturday,
  'sun': DateTime.sunday,
};

final _monthsMap = {
  'jan': DateTime.january,
  'feb': DateTime.february,
  'mar': DateTime.march,
  'apr': DateTime.april,
  'may': DateTime.may,
  'jun': DateTime.june,
  'jul': DateTime.july,
  'aug': DateTime.august,
  'sep': DateTime.september,
  'oct': DateTime.october,
  'nov': DateTime.november,
  'dec': DateTime.december,
};

// final _weekdaysReverseMap = {
//   DateTime.monday: 'Mon',
//   DateTime.tuesday: 'Tue',
//   DateTime.wednesday: 'Wed',
//   DateTime.thursday: 'Thu',
//   DateTime.friday: 'Fri',
//   DateTime.saturday: 'Sat',
//   DateTime.sunday: 'Sun',
// };

// final _monthsReverseMap = {
//   DateTime.january: 'jan',
//   DateTime.february: 'feb',
//   DateTime.march: 'mar',
//   DateTime.april: 'apr',
//   DateTime.may: 'may',
//   DateTime.june: 'jun',
//   DateTime.july: 'jul',
//   DateTime.august: 'aug',
//   DateTime.september: 'sep',
//   DateTime.october: 'oct',
//   DateTime.november: 'nov',
//   DateTime.december: 'dec',
// };

// String _fourDigits(int n) {
//   if (n >= 1000) return '$n';
//   if (n >= 100) return '0$n';
//   if (n >= 10) return '00$n';
//   return '000$n';
// }

// String _twoDigits(int n) {
//   if (n >= 10) return '${n}';
//   return '0${n}';
// }
