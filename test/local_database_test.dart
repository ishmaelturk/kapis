import 'package:flutter_test/flutter_test.dart';
import 'package:kapis/data/local/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactory, databaseFactoryFfi, inMemoryDatabasePath;

void main() {
  test(
    'registers the bundled SQLite factory and initializes the database',
    () async {
      final localDatabase = LocalDatabase(
        databasePathProvider: () async => inMemoryDatabasePath,
      );
      addTearDown(localDatabase.close);

      expect(identical(databaseFactory, databaseFactoryFfi), isTrue);

      final databases = await Future.wait([
        localDatabase.initialize(),
        localDatabase.initialize(),
      ]);

      expect(identical(databases[0], databases[1]), isTrue);
      final version = await databases.first.rawQuery('PRAGMA user_version');
      expect(version.single['user_version'], LocalDatabase.schemaVersion);

      final tables = await databases.first.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = '${LocalDatabase.listingCacheTable}'",
      );
      expect(tables, hasLength(1));

      final columns = await databases.first.rawQuery(
        'PRAGMA table_info(${LocalDatabase.listingCacheTable})',
      );
      final columnNames = columns.map((column) => column['name']).toSet();
      expect(
        columnNames,
        containsAll([
          'id',
          'title',
          'tags_json',
          'status',
          'approximate_latitude',
          'approximate_longitude',
        ]),
      );
      expect(columnNames, isNot(contains('pickup_latitude')));
      expect(columnNames, isNot(contains('pickup_longitude')));

      final indexes = await databases.first.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND tbl_name = '${LocalDatabase.listingCacheTable}'",
      );
      final indexNames = indexes.map((index) => index['name']).toSet();
      expect(
        indexNames,
        containsAll([
          'listing_cache_status_created_idx',
          'listing_cache_donor_created_idx',
        ]),
      );
    },
  );
}
