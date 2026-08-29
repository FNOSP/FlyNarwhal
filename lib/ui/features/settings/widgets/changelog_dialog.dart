import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/dialogs/app_dialog.dart';

/// Opens the changelog dialog, rendering the bundled CHANGELOG.md content
/// (preamble stripped) as scrollable markdown.
Future<void> showChangelogDialog(BuildContext context) async {
  final markdown = await _loadChangelogMarkdown();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AppDialog<void>(
      key: const ValueKey('changelog-dialog'),
      title: '更新日志',
      constraints: const BoxConstraints(
        minWidth: 520,
        maxWidth: 600,
        maxHeight: 720,
      ),
      onClose: () => Navigator.of(dialogContext).pop(),
      content: _ChangelogMarkdownView(markdown: markdown),
    ),
  );
}

Future<String> _loadChangelogMarkdown() async {
  final raw = await rootBundle.loadString('CHANGELOG.md');
  return _stripPreamble(raw);
}

/// Drops the title/description/comment preamble and the empty `[Unreleased]`
/// placeholder, keeping only the released-version sections.
String _stripPreamble(String source) {
  final match = RegExp(r'^## (?!\[Unreleased\])', multiLine: true)
      .firstMatch(source);
  return match == null ? '' : source.substring(match.start);
}

class _ChangelogMarkdownView extends StatelessWidget {
  const _ChangelogMarkdownView({required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    return SizedBox(
      height: 500,
      child: Scrollbar(
        key: const ValueKey('changelog-scrollbar'),
        controller: scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: scrollController,
          primary: false,
          padding: const EdgeInsets.only(right: 12, bottom: 24),
          child: SelectionArea(
            child: MarkdownBody(
              data: markdown,
              selectable: true,
              softLineBreak: true,
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
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignore link-open failures in the changelog.
    }
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bodyStyle = theme.typography.body?.copyWith(fontSize: 14);
    final quoteSurface = theme.brightness == Brightness.dark
        ? theme.resources.cardBackgroundFillColorSecondary
        : theme.resources.cardBackgroundFillColorDefault;
    return MarkdownStyleSheet(
      p: bodyStyle,
      blockSpacing: 10,
      h2Padding: const EdgeInsets.only(top: 36, bottom: 12),
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
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
    );
  }
}
