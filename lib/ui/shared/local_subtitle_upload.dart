import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/log/app_talker.dart';
import '../../data/models/movie_detail_models.dart';
import '../../data/storage/local_subtitle_picker_store.dart';
import '../../providers/file_providers.dart';
import '../../providers/providers.dart';
import 'toast.dart';

/// Top-level function for [compute]: reads a file's bytes on a worker isolate
/// so the UI thread is never blocked by filesystem I/O.
Uint8List readLocalSubtitleFileBytesSync(String path) =>
    File(path).readAsBytesSync();

/// Maximum number of local subtitle files that can be uploaded at once,
/// matching the web player's limit.
const int kMaxUploadableLocalSubtitles = 20;

const MethodChannel _localSubtitlePickerChannel =
    MethodChannel('fly_narwhal/local_subtitle_picker');

/// 字幕选择面板的关闭动画时长之后才弹出系统文件选择器，
/// 避免面板关闭动画与原生面板同帧出现时的视觉抖动（播放器中还有
/// media_kit 主线程等帧的问题，此处保持同样的时序）。
const int _localSubtitlePickerOpenDelayMs = 250;

Future<({List<XFile> files, String? directory})> openLocalSubtitleFiles(
  String initialDirectory, {
  required String userGuid,
}) async {
  // Windows and macOS both use the native picker channel instead of
  // file_selector: on Windows the plugin runs the dialog on the platform
  // thread, and on macOS it presents the panel as a window sheet whose
  // slide-in/out animation blocks the main thread — media_kit waits on the
  // main thread for every video frame, so both freeze the picture. The
  // native channels avoid that (worker thread on Windows, standalone
  // non-sheet panel on macOS).
  if (Platform.isWindows || Platform.isMacOS) {
    final response = await _localSubtitlePickerChannel.invokeMethod<Object?>(
      'openLocalSubtitles',
      {
        'initialDirectory': initialDirectory,
        if (Platform.isWindows) 'userGuid': userGuid,
      },
    );
    // macOS returns {paths, directory}; Windows returns a plain path list
    // because its native side persists the folder and Shell view state by
    // user GUID without exposing that state through the method channel.
    if (response is Map) {
      final paths =
          (response['paths'] as List?)?.cast<String>() ?? const <String>[];
      final directory = response['directory'] as String?;
      return (
        files: paths.map(XFile.new).toList(growable: false),
        directory:
            (directory != null && directory.isNotEmpty) ? directory : null,
      );
    }
    final paths = (response as List?)?.cast<String>() ?? const <String>[];
    return (
      files: paths.map(XFile.new).toList(growable: false),
      directory: null,
    );
  }

  const subtitleTypeGroup = XTypeGroup(
    label: '字幕文件',
    extensions: ['ass', 'srt', 'vtt', 'sub', 'ssa', 'sup'],
  );
  final files = await openFiles(
    acceptedTypeGroups: [subtitleTypeGroup],
    initialDirectory: initialDirectory,
    confirmButtonText: '选择',
  );
  return (
    files: files,
    directory: files.isEmpty ? null : File(files.first.path).parent.path,
  );
}

/// 共享的"添加电脑字幕文件"流程：等待面板关闭动画 → 选择文件 →
/// 校验扩展名 → 逐个上传。成功/失败 toast 在此统一处理。
///
/// 返回最后一个成功上传的字幕（全部失败或用户取消时为 null），
/// 由调用方决定刷新列表与切换选中的方式（播放器切换播放字幕，
/// 详情页仅同步选中状态）。
Future<SubtitleStream?> pickAndUploadLocalSubtitles({
  required WidgetRef ref,
  required String mediaGuid,
  ToastStyle toastStyle = ToastStyle.fluent,
}) async {
  final toastCategory = 'local-subtitle:$mediaGuid';
  final toastManager = ref.read(toastManagerProvider.notifier);

  List<XFile> files = const <XFile>[];
  try {
    // Let the subtitle flyout's dismiss animation finish before the native
    // open panel attaches, so the two don't animate on the same frames.
    await Future<void>.delayed(
      const Duration(milliseconds: _localSubtitlePickerOpenDelayMs),
    );
    final currentUser = ref.read(userInfoProvider).valueOrNull;
    final userGuid = currentUser?.guid.trim() ?? '';
    if (Platform.isWindows && userGuid.isEmpty) {
      throw StateError('当前用户信息缺失，无法恢复文件选择器状态');
    }
    final pickerStore = LocalSubtitlePickerStore(
      ref.read(sharedPreferencesProvider),
      userGuid: userGuid,
    );
    final pickerSelection = await openLocalSubtitleFiles(
      pickerStore.resolveInitialDirectory(),
      userGuid: userGuid,
    );
    files = pickerSelection.files;
    // Remember the shown directory for the next open (recorded by the
    // native side even when the user browsed and cancelled).
    final rememberedDirectory = pickerSelection.directory;
    if (rememberedDirectory != null) {
      unawaited(pickerStore.saveLastDirectory(rememberedDirectory));
    }
  } catch (error) {
    toastManager.showToast(
      style: toastStyle,
      '选择字幕文件失败: $error',
      type: ToastType.failed,
      category: toastCategory,
    );
    return null;
  }
  if (files.isEmpty) return null;

  if (files.length > kMaxUploadableLocalSubtitles) {
    toastManager.showToast(
      style: toastStyle,
      '最多选择 $kMaxUploadableLocalSubtitles 个文件',
      type: ToastType.warning,
      category: toastCategory,
    );
    return null;
  }

  const allowedExtensions = ['ass', 'srt', 'vtt', 'sub', 'ssa', 'sup'];
  final hasInvalid = files.any((file) {
    final dot = file.name.lastIndexOf('.');
    if (dot < 0) return true;
    return !allowedExtensions.contains(
      file.name.substring(dot + 1).toLowerCase(),
    );
  });
  if (hasInvalid) {
    toastManager.showToast(
      style: toastStyle,
      '只能选择 ${allowedExtensions.join(', ')} 格式的文件',
      type: ToastType.warning,
      category: toastCategory,
    );
    return null;
  }

  var successCount = 0;
  var failureCount = 0;
  SubtitleStream? lastUploaded;
  for (final file in files) {
    try {
      final bytes = await compute(readLocalSubtitleFileBytesSync, file.path);
      final uploaded = await ref.read(fileRepositoryProvider).uploadSubtitle(
            mediaGuid: mediaGuid,
            bytes: bytes,
            fileName: file.name,
          );
      successCount++;
      lastUploaded = uploaded;
    } catch (error) {
      AppTalker.warning(
        'LocalSubtitleUpload',
        'Failed to upload subtitle ${file.name}: $error',
      );
      failureCount++;
    }
  }

  if (successCount == 0) {
    toastManager.showToast(
      style: toastStyle,
      '添加字幕失败，请重试',
      type: ToastType.failed,
      category: toastCategory,
    );
  } else if (failureCount > 0) {
    toastManager.showToast(
      style: toastStyle,
      '部分字幕添加成功，其中 $failureCount 个失败',
      type: ToastType.warning,
      category: toastCategory,
    );
  } else {
    toastManager.showToast(
      style: toastStyle,
      '添加字幕成功',
      type: ToastType.success,
      category: toastCategory,
    );
  }
  return successCount > 0 ? lastUploaded : null;
}
