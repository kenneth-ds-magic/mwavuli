import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class CachedTrees extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedTrees])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'mwavuli_trees');
  }

  Future<void> upsertTree(String id, String payload) {
    return into(cachedTrees).insertOnConflictUpdate(
      CachedTreesCompanion.insert(
        id: id,
        payload: payload,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<List<String>> allPayloads() async {
    final rows = await select(cachedTrees).get();
    return rows.map((r) => r.payload).toList();
  }

  Future<String?> payloadById(String id) async {
    final row = await (select(cachedTrees)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.payload;
  }

  Future<void> clearAll() => delete(cachedTrees).go();
}
