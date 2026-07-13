// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedTreesTable extends CachedTrees
    with TableInfo<$CachedTreesTable, CachedTree> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTreesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_trees';
  @override
  VerificationContext validateIntegrity(Insertable<CachedTree> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedTree map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTree(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CachedTreesTable createAlias(String alias) {
    return $CachedTreesTable(attachedDatabase, alias);
  }
}

class CachedTree extends DataClass implements Insertable<CachedTree> {
  final String id;
  final String payload;
  final int updatedAt;
  const CachedTree(
      {required this.id, required this.payload, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  CachedTreesCompanion toCompanion(bool nullToAbsent) {
    return CachedTreesCompanion(
      id: Value(id),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedTree.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTree(
      id: serializer.fromJson<String>(json['id']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  CachedTree copyWith({String? id, String? payload, int? updatedAt}) =>
      CachedTree(
        id: id ?? this.id,
        payload: payload ?? this.payload,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CachedTree copyWithCompanion(CachedTreesCompanion data) {
    return CachedTree(
      id: data.id.present ? data.id.value : this.id,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTree(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTree &&
          other.id == this.id &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class CachedTreesCompanion extends UpdateCompanion<CachedTree> {
  final Value<String> id;
  final Value<String> payload;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const CachedTreesCompanion({
    this.id = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedTreesCompanion.insert({
    required String id,
    required String payload,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        payload = Value(payload),
        updatedAt = Value(updatedAt);
  static Insertable<CachedTree> custom({
    Expression<String>? id,
    Expression<String>? payload,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedTreesCompanion copyWith(
      {Value<String>? id,
      Value<String>? payload,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return CachedTreesCompanion(
      id: id ?? this.id,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTreesCompanion(')
          ..write('id: $id, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedTreesTable cachedTrees = $CachedTreesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedTrees];
}

typedef $$CachedTreesTableCreateCompanionBuilder = CachedTreesCompanion
    Function({
  required String id,
  required String payload,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$CachedTreesTableUpdateCompanionBuilder = CachedTreesCompanion
    Function({
  Value<String> id,
  Value<String> payload,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$CachedTreesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTreesTable> {
  $$CachedTreesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CachedTreesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTreesTable> {
  $$CachedTreesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CachedTreesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTreesTable> {
  $$CachedTreesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedTreesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedTreesTable,
    CachedTree,
    $$CachedTreesTableFilterComposer,
    $$CachedTreesTableOrderingComposer,
    $$CachedTreesTableAnnotationComposer,
    $$CachedTreesTableCreateCompanionBuilder,
    $$CachedTreesTableUpdateCompanionBuilder,
    (CachedTree, BaseReferences<_$AppDatabase, $CachedTreesTable, CachedTree>),
    CachedTree,
    PrefetchHooks Function()> {
  $$CachedTreesTableTableManager(_$AppDatabase db, $CachedTreesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTreesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTreesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTreesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedTreesCompanion(
            id: id,
            payload: payload,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String payload,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedTreesCompanion.insert(
            id: id,
            payload: payload,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedTreesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedTreesTable,
    CachedTree,
    $$CachedTreesTableFilterComposer,
    $$CachedTreesTableOrderingComposer,
    $$CachedTreesTableAnnotationComposer,
    $$CachedTreesTableCreateCompanionBuilder,
    $$CachedTreesTableUpdateCompanionBuilder,
    (CachedTree, BaseReferences<_$AppDatabase, $CachedTreesTable, CachedTree>),
    CachedTree,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedTreesTableTableManager get cachedTrees =>
      $$CachedTreesTableTableManager(_db, _db.cachedTrees);
}
