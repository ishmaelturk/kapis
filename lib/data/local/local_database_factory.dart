import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory createLocalDatabaseFactory() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return databaseFactoryFfi;
}
