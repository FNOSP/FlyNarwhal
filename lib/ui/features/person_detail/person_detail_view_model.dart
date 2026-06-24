import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_result.dart';
import '../../../data/models/person_models.dart';
import '../../../providers/providers.dart';

part 'person_detail_view_model.g.dart';

/// Aggregated state for the person detail page.
class PersonDetailState {
  final PersonResponse person;
  final List<PersonItemList> actorWorks;
  final List<PersonItemList> directorWorks;
  final List<PersonItemList> screenplayWorks;

  const PersonDetailState({
    required this.person,
    this.actorWorks = const [],
    this.directorWorks = const [],
    this.screenplayWorks = const [],
  });

  PersonDetailState copyWith({
    PersonResponse? person,
    List<PersonItemList>? actorWorks,
    List<PersonItemList>? directorWorks,
    List<PersonItemList>? screenplayWorks,
  }) {
    return PersonDetailState(
      person: person ?? this.person,
      actorWorks: actorWorks ?? this.actorWorks,
      directorWorks: directorWorks ?? this.directorWorks,
      screenplayWorks: screenplayWorks ?? this.screenplayWorks,
    );
  }
}

@riverpod
class PersonDetailNotifier extends _$PersonDetailNotifier {
  @override
  FutureOr<PersonDetailState> build(String guid) async {
    final remote = ref.read(mediaRemoteDataSourceProvider);

    Future<List<PersonItemList>> worksByJob(String job) async {
      final result = await remote.getPersonItemList(
        PersonItemListRequest(personGuid: guid, job: job),
      );
      return result.dataOrNull ?? const <PersonItemList>[];
    }

    final results = await Future.wait([
      remote.getPerson(guid),
      worksByJob('Actor'),
      worksByJob('Director'),
      worksByJob('Screenplay'),
    ]);

    final person = (results[0] as ApiResult<PersonResponse>).getOrThrow();
    return PersonDetailState(
      person: person,
      actorWorks: results[1] as List<PersonItemList>,
      directorWorks: results[2] as List<PersonItemList>,
      screenplayWorks: results[3] as List<PersonItemList>,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
