import 'package:test/test.dart';
import 'package:webdav/webdav.dart' show FileInfo;

void main() {
  // https://datatracker.ietf.org/doc/html/rfc4918#section-9.1.5
  final xmlStr = '''
<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/container/</D:href>
    <D:propstat>
      <D:prop xmlns:R="http://ns.example.com/boxschema/">
        <R:bigbox><R:BoxType>Box type A</R:BoxType></R:bigbox>
        <R:author><R:Name>Hadrian</R:Name></R:author>
        <D:creationdate>1997-12-01T17:42:21-08:00</D:creationdate>
        <D:displayname>Example collection</D:displayname>
        <D:resourcetype><D:collection/></D:resourcetype>
        <D:supportedlock>
          <D:lockentry>
            <D:lockscope><D:exclusive/></D:lockscope>
            <D:locktype><D:write/></D:locktype>
          </D:lockentry>
          <D:lockentry>
            <D:lockscope><D:shared/></D:lockscope>
            <D:locktype><D:write/></D:locktype>
          </D:lockentry>
        </D:supportedlock>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/container/front.html</D:href>
    <D:propstat>
      <D:prop xmlns:R="http://ns.example.com/boxschema/">
        <R:bigbox><R:BoxType>Box type B</R:BoxType>
        </R:bigbox>
        <D:creationdate>1997-12-01T18:27:21-08:00</D:creationdate>
        <D:displayname>Example HTML resource</D:displayname>
        <D:getcontentlength>4525</D:getcontentlength>
        <D:getcontenttype>text/html</D:getcontenttype>
        <D:getetag>"zzyzx"</D:getetag>
        <D:getlastmodified
          >Mon, 12 Jan 1998 09:25:56 GMT</D:getlastmodified>
        <D:resourcetype/>
        <D:supportedlock>
          <D:lockentry>
            <D:lockscope><D:exclusive/></D:lockscope>
            <D:locktype><D:write/></D:locktype>
          </D:lockentry>
          <D:lockentry>
            <D:lockscope><D:shared/></D:lockscope>
            <D:locktype><D:write/></D:locktype>
          </D:lockentry>
        </D:supportedlock>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>
''';

  test('FileInfo.parseXmlList() parses the Xml', () {
    final items = FileInfo.parseXmlList(xmlStr).toList();
    expect(items.length, 2);
    // first
    expect(items.first.href, '/container/');
    expect(items.first.isDirectory, true);
    expect(items.first.created,
        DateTime.utc(1997, 12, 1, 17, 42, 21).add(Duration(hours: 8)));
    expect(items.first.hasDisplayName, true);
    expect(items.first.displayName, 'Example collection');
    expect(items.first.hasContentType, false);
    expect(items.first.hasEtag, false);
    // last
    expect(items.last.href, '/container/front.html');
    expect(items.last.isDirectory, false);
    expect(items.last.created,
        DateTime.utc(1997, 12, 1, 18, 27, 21).add(Duration(hours: 8)));
    expect(items.last.displayName, 'Example HTML resource');
    expect(items.last.name, 'Example HTML resource');
    expect(items.last.bytes, 4525);
    expect(items.last.hasContentType, true);
    expect(items.last.contentType, 'text/html');
    expect(items.last.hasEtag, true);
    expect(items.last.etag, '"zzyzx"');
    expect(items.last.modified, DateTime.utc(1998, 1, 12, 9, 25, 56));
  });

  test('FileInfo late path values to compute', () {
    final last = FileInfo.parseXmlList(xmlStr).last;
    expect(last.basename, 'front.html');
    expect(last.ext, '.html');
    expect(last.nameWithoutExt, 'front');
    expect(last.dirname, '/container');
  });

  test('FileInfo instances to match by props if no etag is set', () {
    final first1 = FileInfo.parseXmlList(xmlStr).first;
    final first2 = FileInfo.parseXmlList(xmlStr).first;
    expect(first1.etag, null);
    expect(first1.hashCode, isNot(first1.etag.hashCode));
    expect(first1, first2);
    expect(identical(first1, first2), false);
  });

  test('FileInfo instances to match by etag when one is set', () {
    final last1 = FileInfo.parseXmlList(xmlStr).last;
    final last2 = FileInfo.parseXmlList(xmlStr).last;
    expect(last1.etag, last2.etag);
    expect(last1.hashCode, last1.etag.hashCode);
    expect(last1, last2);
    expect(identical(last1, last2), false);
  });
}
