import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

const int _maximumReleaseNotesLength = 256 * 1024;

typedef UpdateExternalLinkOpener = Future<bool> Function(Uri uri);
typedef UpdateLinkFailureCallback = void Function(Uri uri);

/// Renders untrusted release notes without loading remote embedded content.
class UpdateMarkdownView extends StatelessWidget {
  const UpdateMarkdownView({
    super.key,
    required this.markdown,
    required this.releaseUrl,
    this.onOpenLink,
    this.onOpenLinkFailed,
  });

  final String markdown;
  final Uri releaseUrl;
  final UpdateExternalLinkOpener? onOpenLink;
  final UpdateLinkFailureCallback? onOpenLinkFailed;

  @override
  Widget build(BuildContext context) {
    final normalizedMarkdown = _normalizeMarkdown(markdown);
    if (normalizedMarkdown.trim().isEmpty) {
      return const SelectableText(
        '本次更新未提供更新说明',
        key: ValueKey('update-markdown-empty'),
      );
    }

    final scrollController = ScrollController();
    return SizedBox(
      key: const ValueKey('update-markdown'),
      height: 290,
      child: Scrollbar(
        key: const ValueKey('update-markdown-scrollbar'),
        controller: scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: scrollController,
          primary: false,
          padding: const EdgeInsets.only(right: 12),
          child: SelectionArea(
            child: MarkdownBody(
              data: normalizedMarkdown,
              selectable: true,
              softLineBreak: true,
              sizedImageBuilder: (configuration) => _RemoteImagePlaceholder(
                altText: configuration.alt ?? '远程图片',
              ),
              onTapLink: (text, href, title) => _openLink(href),
              styleSheet: _buildStyleSheet(context),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLink(String? href) async {
    final uri = Uri.tryParse(href ?? '');
    if (!_isSafeExternalUri(uri)) {
      return;
    }
    final opener = onOpenLink ?? _launchExternalLink;
    try {
      final opened = await opener(uri!);
      if (!opened) {
        onOpenLinkFailed?.call(uri);
      }
    } catch (_) {
      onOpenLinkFailed?.call(uri!);
    }
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bodyStyle = theme.typography.body?.copyWith(fontSize: 16);
    // The package default paints blockquotes/code blocks with a fixed light
    // blue/card background, which is unreadable under the dark theme; derive
    // both from the fluent palette instead.
    final quoteSurface = theme.brightness == Brightness.dark
        ? theme.resources.cardBackgroundFillColorSecondary
        : theme.resources.cardBackgroundFillColorDefault;
    return MarkdownStyleSheet(
      p: bodyStyle,
      a: bodyStyle?.copyWith(
        color: theme.accentColor,
        decoration: TextDecoration.underline,
      ),
      code: bodyStyle?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: theme.resources.cardBackgroundFillColorSecondary,
      ),
      blockquote: bodyStyle,
      blockquoteDecoration: BoxDecoration(
        color: quoteSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      codeblockDecoration: BoxDecoration(
        color: quoteSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      listBullet: bodyStyle,
      tableBody: bodyStyle,
      tableHead: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
    );
  }
}

class _RemoteImagePlaceholder extends StatelessWidget {
  const _RemoteImagePlaceholder({required this.altText});

  final String altText;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '远程图片已阻止：$altText',
      child: Container(
        key: const ValueKey('update-markdown-remote-image-placeholder'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color:
            FluentTheme.of(context).resources.cardBackgroundFillColorSecondary,
        child: Text('远程图片已阻止：$altText'),
      ),
    );
  }
}

String _normalizeMarkdown(String source) {
  final boundedSource = source.length > _maximumReleaseNotesLength
      ? '${source.substring(0, _maximumReleaseNotesLength)}\n\n更新说明过长，已截断显示。'
      : source;

  // Display raw HTML as inert text instead of allowing embedded HTML behavior.
  return boundedSource.replaceAllMapped(
    RegExp(r'<[^>]*>', multiLine: true),
    (match) => '`${match.group(0)!.replaceAll('`', r'\`')}`',
  );
}

bool _isSafeExternalUri(Uri? uri) {
  return uri != null &&
      uri.scheme.toLowerCase() == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
}

Future<bool> _launchExternalLink(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
