import '../../domain/models/reading_session.dart';
import '../local/json_store.dart';
import '../sync/sync_service.dart';

class SessionRepository {
  SessionRepository({
    required JsonStore<ReadingSession> store,
    required KeyValueStore meta,
    required SyncService sync,
  })  : _store = store,
        _meta = meta,
        _sync = sync;

  final JsonStore<ReadingSession> _store;
  final KeyValueStore _meta;
  final SyncService _sync;

  static const String _draftKey = 'sessionDraft';

  List<ReadingSession> get all => _store.all;
  Stream<List<ReadingSession>> watchAll() => _store.watch();

  Future<void> add(ReadingSession session) async {
    await _store.put(session);
    _sync.pushSession(session);
  }

  SessionDraft? get draft {
    final json = _meta.getJson(_draftKey);
    return json == null ? null : SessionDraft.fromJson(json);
  }

  Future<void> saveDraft(SessionDraft draft) => _meta.putJson(_draftKey, draft.toJson());

  Future<void> clearDraft() => _meta.remove(_draftKey);
}
