import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/local/local_database.dart';

final localDatabaseProvider = FutureProvider<Database>(
  (ref) => LocalDatabase.instance.initialize(),
);
