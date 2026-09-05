import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_constants.dart';
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

/// The server has no record for this person guid (business code -6). The web
/// client renders its generic empty state instead of an error, so the page
/// does the same.
class PersonNotFoundException implements Exception {
  const PersonNotFoundException();
}

@riverpod
class PersonDetailNotifier extends _$PersonDetailNotifier {
  Future<PersonDetailState> _load(String guid) async {
    final remote = ref.read(mediaRemoteDataSourceProvider);

    Future<List<PersonItemList>> worksByJob(String job) async {
      final result = await remote.getPersonItemList(
        PersonItemListRequest(personGuid: guid, job: job),
      );
      return result.dataOrNull ?? const <PersonItemList>[];
    }

    final personResult = await remote.getPerson(guid);
    if (personResult.isFailure) {
      final failure = personResult.failureOrNull;
      if (failure?.code == ResponseCodes.notFoundBusiness) {
        throw const PersonNotFoundException();
      }
      throw failure ?? const PersonNotFoundException();
    }
    final person = personResult.getOrThrow();

    final works = await Future.wait([
      worksByJob('Actor'),
      worksByJob('Director'),
      worksByJob('Screenplay'),
    ]);

    return PersonDetailState(
      person: person,
      actorWorks: works[0],
      directorWorks: works[1],
      screenplayWorks: works[2],
    );
  }

  @override
  FutureOr<PersonDetailState> build(String guid) async {
    return _load(guid);
  }

  Future<void> refresh() async {
    // Show an explicit loading state while refreshing person details.
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(guid));
  }
}
