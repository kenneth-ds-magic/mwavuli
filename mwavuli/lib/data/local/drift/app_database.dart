import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class CachedTrees extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  BoolColumn get fromServer => boolean().withDefault(const Constant(true))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedUsers extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get username => text()();
  TextColumn get displayName => text()();
  TextColumn get role => text().withDefault(const Constant('user'))();
  TextColumn get payload => text()();
  BoolColumn get fromServer => boolean().withDefault(const Constant(true))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedTrees, CachedUsers])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(cachedTrees, cachedTrees.fromServer);
          await m.createTable(cachedUsers);
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'mwavuli_trees');
  }

  // --- Tree Queries & Upserts ---
  Future<void> upsertTree(String id, String payload, {bool fromServer = true}) {
    return into(cachedTrees).insertOnConflictUpdate(
      CachedTreesCompanion.insert(
        id: id,
        payload: payload,
        fromServer: Value(fromServer),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<List<CachedTree>> allTrees() async {
    return select(cachedTrees).get();
  }

  Future<List<String>> allPayloads({bool? fromServerFilter}) async {
    final query = select(cachedTrees);
    if (fromServerFilter != null) {
      query.where((t) => t.fromServer.equals(fromServerFilter));
    }
    final rows = await query.get();
    return rows.map((r) => r.payload).toList();
  }

  Future<String?> payloadById(String id) async {
    final row = await (select(cachedTrees)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.payload;
  }

  Future<void> markTreeSynced(String id, String newPayload) async {
    await (update(cachedTrees)..where((t) => t.id.equals(id))).write(
      CachedTreesCompanion(
        payload: Value(newPayload),
        fromServer: const Value(true),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteTree(String id) =>
      (delete(cachedTrees)..where((t) => t.id.equals(id))).go();

  Future<void> clearAllTrees() => delete(cachedTrees).go();

  // --- User Queries & Upserts ---
  Future<void> upsertUser({
    required String id,
    required String email,
    required String username,
    required String displayName,
    required String role,
    required String payload,
    bool fromServer = true,
  }) {
    return into(cachedUsers).insertOnConflictUpdate(
      CachedUsersCompanion.insert(
        id: id,
        email: email,
        username: username,
        displayName: displayName,
        role: Value(role),
        payload: payload,
        fromServer: Value(fromServer),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<CachedUser?> latestCachedUser() async {
    final query = select(cachedUsers)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<void> clearUser(String id) =>
      (delete(cachedUsers)..where((u) => u.id.equals(id))).go();

  Future<void> clearAllUsers() => delete(cachedUsers).go();
}
