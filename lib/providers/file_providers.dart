import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/file_models.dart';
import '../data/repositories/file_repository.dart';
import 'providers.dart';

final fileRepositoryProvider = Provider<FileRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return FileRepository(dioClient);
});

final authorizedDirsProvider = FutureProvider<List<AuthDir>>((ref) async {
  final repository = ref.read(fileRepositoryProvider);
  return repository.getAuthorizedDirs();
});

final filesByPathProvider = FutureProvider.family<List<ServerPathResponse>, String>((ref, path) async {
  final repository = ref.read(fileRepositoryProvider);
  return repository.getFilesByServerPath(path);
});
