import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:retry/retry.dart';

import 'file.dart';

class WebDavException implements Exception {
  String cause;
  int statusCode;
  String method;
  String path;
  List<int> expectedCodes;

  WebDavException(
      this.cause, this.statusCode, this.method, this.path, this.expectedCodes);

  String toString() => '$runtimeType - $cause, statusCode: $statusCode';
}

const _redirects = {301, 302, 303, 307, 308};

class WebDavRedirect implements Exception {
  HttpClientResponse response;

  WebDavRedirect(this.response);
}

class Client {
  HttpClient httpClient = new HttpClient();
  int maxAttempts;
  int maxRedirects;

  /// Construct a new [Client].
  /// [path] will should be the root path you want to access.
  Client(
    String host,
    String user,
    String password, {
    String? path,
    String? protocol,
    int? port,
    this.maxAttempts = 5,
    this.maxRedirects = 5,
  })  : assert((host.startsWith('https://') ||
            host.startsWith('http://') ||
            protocol != null)),
        assert(maxAttempts > 0),
        assert(maxRedirects >= 0) {
    _baseUrl = (protocol != null
            ? '$protocol://$host${port != null ? ':$port' : ''}'
            : host) +
        (path ?? '');
    httpClient.addCredentials(
        Uri.parse(_baseUrl), '', HttpClientBasicCredentials(user, password));
  }

  late String _baseUrl;
  String _cwd = '/';

  /// get url from given [path]
  String getUrl(String path) =>
      path.startsWith('/') ? _baseUrl + path : '$_baseUrl$_cwd$path';

  /// change current dir to the given [path], you should make sure the dir exist
  void cd(String path) {
    path = path.trim();
    if (path.isEmpty) {
      return;
    }
    List tmp = path.split("/");
    tmp.removeWhere((value) => value == null || value == '');
    String strippedPath = tmp.join('/') + '/';
    if (strippedPath == '/') {
      _cwd = strippedPath;
    } else if (path.startsWith("/")) {
      _cwd = '/' + strippedPath;
    } else {
      _cwd += strippedPath;
    }
  }

  /// send the request with given [method] and [path]
  ///
  Future<HttpClientResponse> _send(
      String method, String path, List<int> expectedCodes,
      {Uint8List? data, Map? headers}) async {
    final _httpClient = httpClient;
    final _maxRedirects = maxRedirects;
    final _maxAttempts = maxAttempts;
    return await retry(
        () => __send(_httpClient, method, path, expectedCodes,
            data: data, headers: headers, maxRedirects: _maxRedirects),
        retryIf: (e) =>
            e is WebDavException && !_redirects.contains(e.statusCode),
        maxAttempts: _maxAttempts);
  }

  /// send the request with given [method] and [path]
  Future<HttpClientResponse> __send(HttpClient httpClient, String method,
      String path, List<int> expectedCodes,
      {Uint8List? data, Map? headers, int maxRedirects = 5}) async {
    Uri uri = Uri.parse(getUrl(path));

    Future<HttpClientResponse> _worker() async {
      print('[webdav] $method: $uri');

      HttpClientRequest request = await httpClient.openUrl(method, uri);
      request
        ..followRedirects = false
        ..persistentConnection = true;

      if (data != null) {
        request.add(data);
      }
      if (headers != null) {
        headers.forEach((k, v) => request.headers.add(k, v));
      }

      return request.close();
    }

    HttpClientResponse response;

    final _retry = RetryOptions(maxAttempts: maxRedirects);
    int attempt = 0;
    while (true) {
      attempt++;

      response = await _worker();

      if (_redirects.contains(response.statusCode)) {
        if (attempt > maxRedirects) {
          break;
        }

        // Get the redirect location
        String? newLocation = response.headers.value('location');

        if (newLocation != null && newLocation.isNotEmpty) {
          Uri parsed = Uri.parse(newLocation);
          if (parsed.hasScheme && parsed.origin != uri.origin) {
            throw WebDavException('redirect origin change - $newLocation',
                response.statusCode, method, path, expectedCodes);
          }

          // Update uri
          uri = Uri.parse(getUrl(parsed.path));

          // Sleep for a delay
          await Future.delayed(_retry.delay(attempt));
        } else {
          throw WebDavException('redirect with no location',
              response.statusCode, method, path, expectedCodes);
        }
      } else {
        break;
      }
    }

    if (!expectedCodes.contains(response.statusCode)) {
      throw WebDavException(
          "operation failed", response.statusCode, method, path, expectedCodes);
    }
    return response;
  }

  /// make a dir with [path] under current dir
  Future<HttpClientResponse> mkdir(String path, [bool safe = true]) {
    List<int> expectedCodes = [201];
    if (safe) {
      expectedCodes.addAll([405]);
    }
    return _send('MKCOL', path, expectedCodes);
  }

  /// just like mkdir -p
  Future mkdirs(String path) async {
    path = path.trim();
    List<String> dirs = path.split("/");
    dirs.removeWhere((value) => value == '');
    if (dirs.isEmpty) {
      return;
    }
    if (path.startsWith("/")) {
      dirs[0] = '/' + dirs[0];
    }
    String oldCwd = _cwd;
    try {
      for (String dir in dirs) {
        try {
          await mkdir(dir, true);
        } finally {
          cd(dir);
        }
      }
    } catch (e) {} finally {
      cd(oldCwd);
    }
  }

  /// remove dir with given [path]
  Future rmdir(String path, [bool safe = true]) async {
    path = path.trim();
    if (!path.endsWith('/')) {
      // Apache is unhappy when directory to be deleted
      // does not end with '/'
      path += '/';
    }
    List<int> expectedCodes = [204];
    if (safe) {
      expectedCodes.addAll([204, 404]);
    }
    await _send('DELETE', path, expectedCodes);
  }

  /// remove dir with given [path]
  Future delete(String path) async {
    await _send('DELETE', path, [204]);
  }

  /// upload a new file with [localData] as content to [remotePath]
  Future _upload(Uint8List localData, String remotePath) async {
    await _send('PUT', remotePath, [200, 201, 204], data: localData);
  }

  /// upload a new file with [localData] as content to [remotePath]
  Future upload(Uint8List data, String remotePath) async {
    await _upload(data, remotePath);
  }

  /// upload local file [path] to [remotePath]
  Future uploadFile(String path, String remotePath) async {
    await _upload(await File(path).readAsBytes(), remotePath);
  }

  /// download [remotePath] to local file [localFilePath]
  Future download(String remotePath, String localFilePath) async {
    HttpClientResponse response = await _send('GET', remotePath, [200]);
    await response.pipe(new File(localFilePath).openWrite());
  }

  /// download [remotePath] and store the response file contents to String
  Future<String> downloadToBinaryString(String remotePath) async {
    HttpClientResponse response = await _send('GET', remotePath, [200]);
    return response.transform(utf8.decoder).join();
  }

  /// Returns a [Stream] of the directories and files under given [path]
  ///
  /// [depth] should be either 0 or 1. A depth of 1 will cause a request to be
  /// made to the server to also return all child resources. When depth is 0
  /// only one item will be streamed.
  ///
  /// [skip] will skip a specific number of items.
  /// Only used when depth is not 0. Defaults to 1 - skips the path itself.
  /// No matter the skip value - the request and response will include all
  /// items, based on depth.
  Stream<FileInfo> propFindStream(
      {String? path, int depth = 1, int skip = 1}) async* {
    HttpClientResponse response =
        await _send('PROPFIND', path ?? '/', [207], headers: {'Depth': depth});
    final xml = await response.transform(utf8.decoder).join();
    final iterator = FileInfo.parseXmlList(xml);
    if (depth == 0) {
      yield iterator.first;
    } else {
      for (final item in iterator.skip(skip)) {
        yield item;
      }
    }
  }

  /// Returns a [List] of the directories and files under given [path]
  ///
  /// [depth] should be either 0 or 1. A depth of 1 will cause a request to be
  /// made to the server to also return all child resources. When depth is 0
  /// only one item will be returned.
  ///
  /// [skip] will skip a specific number of items.
  /// Only used when depth is not 0. Defaults to 1 - skips the path itself.
  /// No matter the skip value - the request and response will include all
  /// items, based on depth.
  Future<List<FileInfo>> propFind(
      {String? path, int depth = 1, int skip = 1}) async {
    return propFindStream(path: path, depth: depth, skip: skip).toList();
  }

  /// List the directories and files under given [path]
  ///
  /// [depth] should be either 0 or 1. A depth of 1 will cause a request to be
  /// made to the server to also return all child resources. When depth is 0
  /// only one item will be returned.
  @Deprecated('Use propFind')
  Future<List<FileInfo>> ls({String? path, int depth = 1}) async {
    return propFind(path: path, depth: depth);
  }
}
