import 'package:flutter_test/flutter_test.dart';
import 'package:fly_narwhal/data/mappers/media_mapper.dart';
import 'package:fly_narwhal/data/models/home_models.dart';
import 'package:fly_narwhal/domain/entities/media_entity.dart';

void main() {
  group('MediaMapper', () {
    test('toEntity should convert MediaItem to MediaEntity', () {
      final model = MediaItem(
        guid: 'test-guid',
        title: 'Test Movie',
        type: 'Movie',
        poster: 'https://example.com/poster.jpg',
        isFavorite: 1,
        watched: 0,
        voteAverage: '8.5',
        releaseDate: '2023-01-01',
        seasonNumber: 0,
        episodeNumber: 0,
      );

      final entity = MediaMapper.toEntity(model);

      expect(entity.guid, equals('test-guid'));
      expect(entity.title, equals('Test Movie'));
      expect(entity.type, equals(MediaType.movie));
      expect(entity.poster, equals('https://example.com/poster.jpg'));
      expect(entity.isFavorite, isTrue);
      expect(entity.isWatched, isFalse);
      expect(entity.voteAverage, equals('8.5'));
      expect(entity.releaseDate, equals('2023-01-01'));
    });

    test('toLibraryEntity should convert MediaDbListResponse to MediaLibraryEntity', () {
      final model = MediaDbListResponse(
        guid: 'lib-guid',
        title: 'My Library',
        posters: ['https://example.com/poster1.jpg', 'https://example.com/poster2.jpg'],
        category: 'movies',
        viewType: 1,
      );

      final entity = MediaMapper.toLibraryEntity(model);

      expect(entity.guid, equals('lib-guid'));
      expect(entity.title, equals('My Library'));
      expect(entity.posters.length, equals(2));
      expect(entity.category, equals('movies'));
      expect(entity.viewType, equals(1));
    });

    test('toPlayDetailEntity should convert PlayDetailResponse to PlayDetailEntity', () {
      final model = PlayDetailResponse(
        guid: 'play-guid',
        title: 'Test Episode',
        type: 'Episode',
        poster: 'https://example.com/poster.jpg',
        isFavorite: 0,
        watched: 1,
        seasonNumber: 1,
        episodeNumber: 5,
        tvTitle: 'Test TV Show',
      );

      final entity = MediaMapper.toPlayDetailEntity(model);

      expect(entity.guid, equals('play-guid'));
      expect(entity.title, equals('Test Episode'));
      expect(entity.type, equals(MediaType.episode));
      expect(entity.isFavorite, isFalse);
      expect(entity.isWatched, isTrue);
      expect(entity.seasonNumber, equals(1));
      expect(entity.episodeNumber, equals(5));
      expect(entity.tvTitle, equals('Test TV Show'));
    });

    test('toEntityList should convert list of models', () {
      final models = [
        MediaItem(guid: '1', title: 'Movie 1', type: 'Movie', seasonNumber: 0, episodeNumber: 0),
        MediaItem(guid: '2', title: 'Movie 2', type: 'TV', seasonNumber: 0, episodeNumber: 0),
      ];

      final entities = MediaMapper.toEntityList(models);

      expect(entities.length, equals(2));
      expect(entities[0].guid, equals('1'));
      expect(entities[1].guid, equals('2'));
    });
  });
}