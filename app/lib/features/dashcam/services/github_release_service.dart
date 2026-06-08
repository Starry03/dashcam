import 'dart:convert';

import 'package:http/http.dart' as http;

class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.apkUrl,
    required this.htmlUrl,
    required this.tag,
  });

  final String version;
  final String apkUrl;
  final String htmlUrl;
  final String tag;
}

class GithubReleaseService {
  static const String _owner = 'Starry03';
  static const String _repo = 'dashcam';

  static Future<ReleaseInfo?> fetchLatestRelease() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$_owner/$_repo/releases/latest',
    );

    final response = await http.get(
      uri,
      headers: const {'Accept': 'application/vnd.github+json'},
    );

    if (response.statusCode != 200) return null;

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return null;

    final tag = (decoded['tag_name'] as String? ?? '').trim();
    final htmlUrl = (decoded['html_url'] as String? ?? '').trim();
    final assets = decoded['assets'];

    String? apkUrl;
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final url = (asset['browser_download_url'] as String? ?? '').trim();
        if (url.toLowerCase().endsWith('.apk')) {
          apkUrl = url;
          break;
        }
      }
    }

    if (tag.isEmpty || htmlUrl.isEmpty || apkUrl == null || apkUrl.isEmpty) {
      return null;
    }

    return ReleaseInfo(
      version: _normalizeVersion(tag),
      apkUrl: apkUrl,
      htmlUrl: htmlUrl,
      tag: tag,
    );
  }

  static String _normalizeVersion(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      return trimmed.substring(1);
    }
    return trimmed;
  }
}
