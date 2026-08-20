import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/person_models.dart';
import '../../../providers/global_refresh.dart';
import '../../shared/common/fn_cached_image.dart';
import '../../shared/common/app_loading_progress_ring.dart';
import '../../shared/dialogs/app_dialog.dart';
import '../../shared/movie_poster.dart';
import 'person_detail_view_model.dart';
import 'package:fly_narwhal/ui/shared/app_button.dart';

/// Person detail page: avatar, name, biography and works grouped by job.
/// Built to mirror Compose PersonDetailScreen.
class PersonDetailScreen extends ConsumerWidget {
  final String guid;

  const PersonDetailScreen({super.key, required this.guid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Consume each global refresh request once for the current person detail page.
    ref.listen<GlobalRefreshRequest?>(
      currentGlobalRefreshRequestProvider,
      (_, next) {
        unawaited(
          ref.read(globalRefreshManagerProvider).handleRefresh(
                consumerId: 'person-detail:$guid',
                request: next,
                onRefresh: () => ref
                    .read(personDetailNotifierProvider(guid).notifier)
                    .refresh(),
              ),
        );
      },
    );
    final detailState = ref.watch(personDetailNotifierProvider(guid));
    final theme = FluentTheme.of(context);
    final scaffoldBackgroundColor = theme.brightness == Brightness.dark
        ? const Color(0xFF282828)
        : theme.scaffoldBackgroundColor;

    return FluentTheme(
      data: theme.copyWith(scaffoldBackgroundColor: scaffoldBackgroundColor),
      child: ScaffoldPage(
        padding: EdgeInsets.zero,
        content: detailState.when(
          data: (state) => _PersonDetailContent(state: state),
          loading: () => const Center(child: AppLoadingProgressRing()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('加载失败: $error'),
                const SizedBox(height: 16),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AppButton(
                    child: const Text('重试'),
                    onPressed: () => ref
                        .read(personDetailNotifierProvider(guid).notifier)
                        .refresh(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonDetailContent extends ConsumerWidget {
  final PersonDetailState state;

  const _PersonDetailContent({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = state.person;
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 56, 48, 24),
                child: _PersonHeader(person: person),
              ),
            ),
            if (state.actorWorks.isNotEmpty)
              _buildSection(context, ref, '作为演员', state.actorWorks),
            if (state.directorWorks.isNotEmpty)
              _buildSection(context, ref, '作为导演', state.directorWorks),
            if (state.screenplayWorks.isNotEmpty)
              _buildSection(context, ref, '作为编剧', state.screenplayWorks),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<PersonItemList> works,
  ) {
    final theme = FluentTheme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(48, 8, 48, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.typography.subtitle,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final work in works)
                  MoviePoster(
                    posterPath: work.poster,
                    title: work.title,
                    subtitle: _takeYear(work.releaseDate),
                    score: work.voteAverage,
                    resolutions: work.mediaStream?.resolutions,
                    isFavorite: work.isFavorite == 1,
                    isWatched: work.watched == 1,
                    type: work.type,
                    guid: work.guid,
                    width: 130,
                    height: 195,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _takeYear(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final t = value.trim();
    return t.length >= 4 ? t.substring(0, 4) : t;
  }
}

class _PersonHeader extends StatelessWidget {
  final PersonResponse person;

  const _PersonHeader({required this.person});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hasBiography =
        person.biography != null && person.biography!.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar, 2:3 ratio
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 180,
            height: 270,
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: person.profile != null && person.profile!.isNotEmpty
                ? FnCachedImage(
                    posterPath: person.profile!,
                    width: 180,
                    placeholderSize: 28,
                  )
                : Icon(
                    FluentIcons.contact,
                    size: 64,
                    color: theme.resources.textFillColorTertiary,
                  ),
          ),
        ),
        const SizedBox(width: 32),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.name,
                style: theme.typography.title,
              ),
              if (person.originalName != null &&
                  person.originalName!.trim().isNotEmpty &&
                  person.originalName != person.name) ...[
                const SizedBox(height: 4),
                Text(
                  person.originalName!,
                  style: theme.typography.body?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
              if (hasBiography) ...[
                const SizedBox(height: 16),
                _BiographyText(biography: person.biography!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Biography truncated to a fixed number of visual lines like the web person
/// page: when the text overflows, a blue "更多" link is inlined at the end of
/// the last visible line (its width reserved) and tapping it opens the full
/// text in a dialog. No expand/collapse in place.
class _BiographyText extends StatefulWidget {
  final String biography;

  const _BiographyText({required this.biography});

  // Mirrors the web person page (lines: 7, 15px/23px).
  static const _maxLines = 7;
  static const _textStyle = TextStyle(fontSize: 14, height: 20 / 14);
  static const _moreStyle = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    color: appDialogPrimaryColor,
  );

  @override
  State<_BiographyText> createState() => _BiographyTextState();
}

class _BiographyTextState extends State<_BiographyText> {
  String? _visibleText;
  bool _overflowed = false;

  @override
  void didUpdateWidget(_BiographyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.biography != widget.biography) {
      _visibleText = null;
      _overflowed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _measure(constraints.maxWidth);
        return Text.rich(
          TextSpan(
            style: _BiographyText._textStyle,
            children: [
              TextSpan(text: _visibleText ?? widget.biography),
              if (_overflowed)
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: const ValueKey('person-biography-more'),
                      onTap: () => _showFullBiography(context),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('更多', style: _BiographyText._moreStyle),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Measures the biography against [maxWidth] and computes the truncated
  /// text that fits [_BiographyText._maxLines] lines including the inline
  /// "更多" link on the last line.
  void _measure(double maxWidth) {
    if (maxWidth <= 0 || !maxWidth.isFinite) return;
    final painter = TextPainter(
      text: TextSpan(text: widget.biography, style: _BiographyText._textStyle),
      textDirection: TextDirection.ltr,
      maxLines: _BiographyText._maxLines,
    )..layout(maxWidth: maxWidth);
    if (!painter.didExceedMaxLines) {
      _visibleText = widget.biography;
      _overflowed = false;
      return;
    }

    final morePainter = TextPainter(
      text: const TextSpan(text: '更多', style: _BiographyText._moreStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final reserved = morePainter.width + 4; // 4px gap before the link.

    final lines = painter.computeLineMetrics();
    final lastLine = lines.last;
    final lastLineEnd = painter.getPositionForOffset(
      Offset(lastLine.left + lastLine.width, lastLine.baseline),
    ).offset;

    // If the last rendered line still has room for the link, keep it whole;
    // otherwise cut the last line so text + link fit.
    var end = lastLineEnd;
    if (lastLine.left + lastLine.width + reserved > maxWidth) {
      final target = maxWidth - reserved;
      var lo = 0, hi = lastLineEnd;
      final probe = TextPainter(textDirection: TextDirection.ltr);
      while (lo < hi) {
        final mid = (lo + hi + 1) ~/ 2;
        probe.text = TextSpan(
          text: widget.biography.substring(0, mid),
          style: _BiographyText._textStyle,
        );
        probe.layout(maxWidth: maxWidth);
        final probeLines = probe.computeLineMetrics();
        final probeLast = probeLines.last;
        final lastWidth = probeLast.left + probeLast.width;
        if (probeLines.length <= _BiographyText._maxLines &&
            lastWidth <= target) {
          lo = mid;
        } else {
          hi = mid - 1;
        }
      }
      end = lo;
    }
    _visibleText = widget.biography.substring(0, end);
    _overflowed = true;
  }

  void _showFullBiography(BuildContext context) {
    // Like the changelog dialog: build AppDialog directly so the close button
    // pops with the dialog's own context (showAppDialog's builder discards it).
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog<void>(
        title: '演员简介',
        constraints: const BoxConstraints(
          minWidth: 560,
          maxWidth: 744,
          maxHeight: 720,
        ),
        onClose: () => Navigator.of(dialogContext).pop(),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 640),
          child: SingleChildScrollView(
            child: Text(widget.biography, style: _BiographyText._textStyle),
          ),
        ),
      ),
    );
  }
}
