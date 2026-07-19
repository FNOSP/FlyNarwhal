import 'dart:convert';

import '../../../core/version/semantic_version.dart';
import '../../../core/version/version_parser.dart';
import '../entities/update_models.dart';

/// A safely formatted release-note fragment.
final class FormattedUpdateReleaseNotes {
  const FormattedUpdateReleaseNotes({
    required this.markdown,
    required this.wasTruncated,
    required this.originalUtf8Length,
  });

  final String markdown;
  final bool wasTruncated;
  final int originalUtf8Length;
}

/// Collects and safely formats target and intermediate release notes.
final class UpdateReleaseNotesService {
  const UpdateReleaseNotesService();

  static const int maximumNotesBytes = 256 * 1024;
  static const String emptyNotesText = '暂无更新说明。';

  List<UpdateReleaseNotesFragment> collectFragments({
    required List<UpdateRelease> releases,
    required SemanticVersion currentVersion,
    required SemanticVersion targetVersion,
  }) {
    final fragments = <UpdateReleaseNotesFragment>[];

    // Include versions newer than current through the selected target.
    for (final release in releases) {
      final parseResult = VersionParser.parseReleaseVersionResult(
        tagName: release.tagName,
        displayName: release.displayName,
      );
      if (parseResult is! ReleaseVersionParseSuccess) {
        continue;
      }
      final version = parseResult.version;
      if (version.compareTo(currentVersion) <= 0 ||
          version.compareTo(targetVersion) > 0 ||
          !_isHttpsUrl(release.htmlUrl)) {
        continue;
      }
      fragments.add(
        UpdateReleaseNotesFragment(
          version: version,
          markdown: release.releaseNotes,
          releasePageUrl: release.htmlUrl,
          isTargetVersion: version.compareTo(targetVersion) == 0,
        ),
      );
    }

    fragments.sort((left, right) => right.version.compareTo(left.version));
    return List<UpdateReleaseNotesFragment>.unmodifiable(fragments);
  }

  FormattedUpdateReleaseNotes formatFragment(
    UpdateReleaseNotesFragment fragment,
  ) {
    final markdown = fragment.markdown;
    if (markdown.trim().isEmpty) {
      return const FormattedUpdateReleaseNotes(
        markdown: emptyNotesText,
        wasTruncated: false,
        originalUtf8Length: 0,
      );
    }
    if (!_isHttpsUrl(fragment.releasePageUrl)) {
      throw ArgumentError.value(
        fragment.releasePageUrl,
        'fragment.releasePageUrl',
        'Release notes require an HTTPS release URL.',
      );
    }

    final encodedNotes = utf8.encode(markdown);
    if (encodedNotes.length <= maximumNotesBytes) {
      return FormattedUpdateReleaseNotes(
        markdown: markdown,
        wasTruncated: false,
        originalUtf8Length: encodedNotes.length,
      );
    }

    // Removing trailing continuation bytes alone is insufficient when the
    // leading byte is retained, so decode with progressively shorter slices.
    var safeLength = maximumNotesBytes;
    String truncatedNotes;
    while (true) {
      try {
        truncatedNotes = utf8.decode(
          encodedNotes.sublist(0, safeLength),
          allowMalformed: false,
        );
        break;
      } on FormatException {
        safeLength--;
      }
    }
    final releaseUrl = fragment.releasePageUrl.toString();
    return FormattedUpdateReleaseNotes(
      markdown: '$truncatedNotes\n\n'
          '> 更新说明已截断。请前往 [Release 页面]($releaseUrl) 查看完整内容。',
      wasTruncated: true,
      originalUtf8Length: encodedNotes.length,
    );
  }
}

bool _isHttpsUrl(Uri url) {
  return url.scheme.toLowerCase() == 'https' && url.host.isNotEmpty;
}
