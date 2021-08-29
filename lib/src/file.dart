import 'package:hashcodes/hashcodes.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p show url;
import 'package:xml/xml.dart' as xml;

import 'rfc1123datetime.dart';

final _context = p.url;

@immutable
class FileInfo {
  /// Contains an HTTP URL pointing to a WebDAV file or directory item
  ///
  /// NOTE: all href values from [parseXmlList] will be unique and will never
  /// be empty.
  final String rawHref;

  final String rootPath;

  /// Contains the [rawHref], but without the [rootPath] (if set)
  late final String href = rootPath.isNotEmpty && rawHref.startsWith(rootPath)
      ? rawHref.substring(rootPath.length)
      : rawHref;

  /// Contains the Content-Type of the instance
  ///
  /// Use [hasContentType] getter to check if it is set and not empty.
  final String contentType;

  /// Contains a name that is suitable for presentation to a user
  ///
  /// Use [hasDisplayName] getter to check if it is set and not empty.
  final String? displayName;

  /// Contains the ETag
  ///
  /// Use [hasEtag] getter to check if it is set and not empty.
  final String? etag;

  /// Will be `true` if the instance is considered a directory
  late final bool isDirectory = _isCollection ||
      href.endsWith('/') ||
      contentType == 'httpd/unix-directory';

  /// Contains the size of the file or 0 if a directory
  late final int bytes = _contentLength.isEmpty || isDirectory
      ? 0
      : int.tryParse(_contentLength) ?? 0;

  /// The part of [href] after the last separator
  late final String basename = _context.basename(href);

  /// The part of [href] before the last separator
  late final String dirname = _context.dirname(href);

  /// The file extension of [href]: the portion of [basename] from the last
  /// `.` to the end (including the `.` itself)
  late final String ext = _context.extension(href);

  /// The part of [href] after the last separator, without any trailing file
  /// extension
  late final String nameWithoutExt = _context.basenameWithoutExtension(href);

  /// Contains the time and date the item was created
  late final DateTime created = DateTime.tryParse(_creationDate) ?? _nullDate;

  /// Contains the Last-Modified time and date of the item
  late final DateTime modified = tryParseRFC1123Date(_lastModified) ?? created;

  /// Alias of [href]
  String get path => href;

  /// Either the [displayName] or falls-back to [basename]
  String get name => hasDisplayName ? displayName! : basename;

  /// Returns `true` if there is non-empty [contentType]
  bool get hasContentType => contentType.isNotEmpty;

  /// Returns `true` if there is non-empty [displayName]
  bool get hasDisplayName => displayName?.isNotEmpty == true;

  /// Returns `true` if there is non-empty [etag]
  bool get hasEtag => etag?.isNotEmpty == true;

  @Deprecated('Use bytes')
  String get size => _contentLength;

  @Deprecated('Use created')
  DateTime get creationTime => created;

  @Deprecated('Use modified')
  String get modificationTime => _lastModified;

  final bool _isCollection;
  final String _contentLength;
  final String _creationDate;
  final String _lastModified;

  FileInfo._(
    this.rawHref,
    this._creationDate,
    this.displayName,
    this._contentLength,
    this.contentType,
    this.etag,
    this._lastModified,
    this._isCollection,
    this.rootPath,
  );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FileInfo &&
            other.rawHref == rawHref &&
            other._creationDate == _creationDate &&
            other.displayName == displayName &&
            other._contentLength == _contentLength &&
            other.contentType == contentType &&
            other.etag == etag &&
            other._lastModified == _lastModified &&
            other._isCollection == _isCollection;
  }

  @override
  int get hashCode => hasEtag
      ? etag!.hashCode
      : hashValues(rawHref, _creationDate, displayName, _contentLength,
          contentType, etag, _lastModified, _isCollection);

  @override
  String toString() {
    final buf = ['name: $name'];
    if (isDirectory) {
      buf.add('isDirectory: true');
    } else {
      buf.add('bytes: $bytes');
    }
    buf.add('dirname: $dirname');
    if (identical(created, _nullDate)) {
      buf.add('created: [$created]');
    } else {
      buf.add('created: $created');
    }
    if (identical(modified, created)) {
      buf.add('modified: [$modified]');
    } else {
      buf.add('modified: $modified');
    }
    buf.add('contentType: $contentType');
    buf.add('etag: $etag');
    return '$runtimeType{${buf.join(', ')}}';
  }

  static final _nullDate = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  static final _200pattern = RegExp(r'\b200\b');

  /// Returns a [FileInfo] instance after parsing the element's stats
  static FileInfo? fromXmlElement(xml.XmlElement element,
      {String rootPath = ''}) {
    String href = _findSingle(element, 'href')?.text ?? '';
    if (href.isEmpty) {
      // If there's no href we bail early
      return null;
    }

    // Decode the url from any percent-encodings
    // CHECK: should we split the href (path + basename) before decoding or leave it to FileInfo to late decode?
    // WebDav RFC 4918: https://datatracker.ietf.org/doc/html/rfc4918#section-14.7
    href = Uri.decodeComponent(href);

    for (final propstat in _findChildren(element, 'propstat')) {
      // NOTE: a propstat element MUST contain one 'prop' one 'status' and one
      //       'resourcetype'.

      final status = _findSingle(propstat, 'status')?.text ?? '';
      // Ignore non 200 OK status
      if (!status.contains(_200pattern)) {
        continue;
      }

      // Get all the props
      final prop = _findSingle(propstat, 'prop');
      if (prop == null) {
        continue;
      }

      // WebDav RFC 4918: https://datatracker.ietf.org/doc/html/rfc4918#section-15.1
      // DateTime RFC 3339: https://datatracker.ietf.org/doc/html/rfc3339#section-5.6
      final creationDate = _findSingle(prop, 'creationdate')?.text ?? '';

      // WebDav RFC 4918: https://datatracker.ietf.org/doc/html/rfc4918#section-15.2
      final displayName = _findSingle(prop, 'displayname')?.text;

      // WebDav RFC 4918: https://datatracker.ietf.org/doc/html/rfc4918#section-15.4
      final contentLength = _findSingle(prop, 'getcontentlength')?.text ?? '';

      // WebDav RFC 4918: https://datatracker.ietf.org/doc/html/rfc4918#section-15.5
      final contentType = _findSingle(prop, 'getcontenttype')?.text ?? '';

      // WebDav RFC 4918: https://datatracker.ietf.org/doc/html/rfc4918#section-15.6
      final etag = _findSingle(prop, 'getetag')?.text;

      // WebDav RFC 4918: https://datatracker.ietf.org/doc/html/rfc4918#section-15.7
      // HTTP RFC 2616: https://datatracker.ietf.org/doc/html/rfc2616#section-3.3.1
      final lastModified = _findSingle(prop, 'getlastmodified')?.text ?? '';

      // WebDav RFC 4918: https://datatracker.ietf.org/doc/html/rfc4918#section-15.9
      final isCollection =
          _findSingle(_findSingle(prop, 'resourcetype')!, 'collection') != null;

      return FileInfo._(
        href,
        creationDate,
        displayName,
        contentLength,
        contentType,
        etag,
        lastModified,
        isCollection,
        rootPath,
      );
    }

    return null;
  }

  /// Parses given XML [String] and returns a lazy [Iterable] with all the
  /// available [FileInfo] items
  static Iterable<FileInfo> parseXmlList(String xmlStr,
      {String rootPath = ''}) sync* {
    // Parse the XML document
    final xmlDocument = xml.XmlDocument.parse(xmlStr);

    final set = <String>{};

    // Iterate over the responses and create FileInfo instances
    for (final response in _findAll(xmlDocument, 'response')) {
      final item = fromXmlElement(response, rootPath: rootPath);
      if (item != null && !set.contains(item.rawHref)) {
        set.add(item.rawHref);
        yield item;
      }
    }
  }

  static Iterable<xml.XmlElement> _findAll(xml.XmlNode document, String tag) =>
      document.findAllElements(tag, namespace: '*');

  static Iterable<xml.XmlElement> _findChildren(
          xml.XmlNode element, String tag) =>
      element.findElements(tag, namespace: '*');

  static xml.XmlElement? _findSingle(xml.XmlElement element, String tag) {
    final el = _findChildren(element, tag).toList();
    return el.isEmpty ? null : el.single;
  }
}
