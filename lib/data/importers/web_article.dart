import 'package:http/http.dart' as http;

import '../../core/errors/app_failure.dart';

/// Pulls readable text out of a public web page. Many sites refuse browser
/// requests; those failures stay friendly and never expose the raw error.
class WebArticle {
  const WebArticle._();

  static const int _maxBytes = 2 * 1024 * 1024;

  static Future<({String title, String text})> fetch(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw const AppFailure('Enter a full link that starts with https://.');
    }
    final client = http.Client();
    try {
      final response = await client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AppFailure("That page didn't open. Paste the article text instead.");
      }
      if (response.bodyBytes.length > _maxBytes) {
        throw const AppFailure('That page is too large to import. Paste the article text instead.');
      }
      final extracted = extract(response.body);
      final words = extracted.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (words < 40) {
        throw const AppFailure("We couldn't find enough article text on that page. Paste it instead.");
      }
      return extracted;
    } on AppFailure {
      rethrow;
    } on Object {
      throw const AppFailure(
        "We couldn't open that link. Some sites block this from the browser — paste the article text instead.",
      );
    } finally {
      client.close();
    }
  }

  static ({String title, String text}) extract(String html) {
    final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
    final title = _decode(_strip(titleMatch?.group(1) ?? '')).trim();
    var body = html.replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ');
    body = body.replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ');
    body = body.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    body = body.replaceAll(RegExp(r'</p>|</div>|</h[1-6]>|</li>', caseSensitive: false), '\n');
    body = _decode(_strip(body));
    body = body.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return (title: title, text: body);
  }

  static String _strip(String value) => value.replaceAll(RegExp(r'<[^>]+>'), ' ');

  static String _decode(String value) => value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
}
