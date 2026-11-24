import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'local_database_factory.dart'
    if (dart.library.js_interop) 'local_database_factory_web.dart'
    as database_factory;

final class LocalDatabase {
  LocalDatabase({
    DatabaseFactory? factory,
    Future<String> Function()? databasePathProvider,
  }) : _factory = factory ?? _databaseFactory,
       _databasePathProvider = databasePathProvider ?? _defaultDatabasePath;

  static final instance = LocalDatabase();

  static const databaseName = 'kapis.db';
  static const schemaVersion = 1;
  static const listingCacheTable = 'listing_cache';

  final DatabaseFactory _factory;
  final Future<String> Function() _databasePathProvider;
  Future<Database>? _opening;
  static final DatabaseFactory _databaseFactory = database_factory
      .createLocalDatabaseFactory();

  Future<Database> initialize() async {
    final existing = _opening;
    if (existing != null) {
      return existing;
    }

    final opening = _open();
    _opening = opening;
    try {
      return await opening;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening == null) {
      return;
    }
    final database = await opening;
    await database.close();
    if (identical(_opening, opening)) {
      _opening = null;
    }
  }

  Future<Database> _open() async {
    return _factory.openDatabase(
      await _databasePathProvider(),
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE $listingCacheTable (
              id TEXT PRIMARY KEY NOT NULL,
              donor_id TEXT NOT NULL,
              title TEXT NOT NULL,
              description TEXT NOT NULL,
              pickup_area TEXT NOT NULL,
              category TEXT NOT NULL,
              item_condition TEXT NOT NULL,
              tags_json TEXT NOT NULL,
              approximate_latitude REAL NOT NULL,
              approximate_longitude REAL NOT NULL,
              status TEXT NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          await database.execute('''
            CREATE INDEX listing_cache_status_created_idx
            ON $listingCacheTable (status, created_at DESC)
          ''');
          await database.execute('''
            CREATE INDEX listing_cache_donor_created_idx
            ON $listingCacheTable (donor_id, created_at DESC)
          ''');
        },
      ),
    );
  }

  static Future<String> _defaultDatabasePath() async {
    if (kIsWeb) {
      return databaseName;
    }
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, databaseName);
  }
}
