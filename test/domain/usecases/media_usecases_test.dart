import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/core/network/api_result.dart';
import 'package:fly_narwhal/domain/entities/media_library_entity.dart';
import 'package:fly_narwhal/domain/entities/action_result.dart';
import 'package:fly_narwhal/domain/usecases/media_usecases.dart';
import 'package:fly_narwhal/domain/repositories/i_media_repository.dart';
import 'package:mocktail/mocktail.dart';

// Mock repository
class MockMediaRepository extends Mock implements IMediaRepository {}

void main() {
  late GetMediaDbListUseCase getMediaDbListUseCase;
  late ToggleFavoriteUseCase toggleFavoriteUseCase;
  late MockMediaRepository mockRepository;

  setUp(() {
    mockRepository = MockMediaRepository();
    getMediaDbListUseCase = GetMediaDbListUseCase(mockRepository);
    toggleFavoriteUseCase = ToggleFavoriteUseCase(mockRepository);
  });

  group('GetMediaDbListUseCase', () {
    test('should return list of MediaLibraryEntity on success', () async {
      final libraries = [
        const MediaLibraryEntity(
          guid: '1',
          title: 'Movies',
          posters: [],
          category: 'movies',
        ),
      ];

      when(() => mockRepository.getMediaDbList())
          .thenAnswer((_) async => Success(libraries));

      final result = await getMediaDbListUseCase();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, equals(1));
      expect(result.dataOrNull?.first.title, equals('Movies'));
    });
  });

  group('ToggleFavoriteUseCase', () {
    test('should return ActionResult on success', () async {
      const actionResult = ActionResult(
        guid: 'test-guid',
        success: true,
        message: 'Added to favorites',
        previousState: false,
      );

      when(() => mockRepository.toggleFavorite('test-guid', false))
          .thenAnswer((_) async => const Success(actionResult));

      final result = await toggleFavoriteUseCase(
        const ToggleFavoriteParams(guid: 'test-guid', currentState: false),
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.success, isTrue);
      expect(result.dataOrNull?.message, equals('Added to favorites'));
    });
  });
}