import 'package:book_app/data/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Testler için bellek-içi bir veritabanı açar ve [AppDatabase]'e bağlar.
///
/// Gerçek şemayı ([AppDatabase.createSchema]) kullanır; böylece testler
/// uygulamanın gerçekten çalıştığı tablo yapısını doğrular.
Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: AppDatabase.schemaVersion,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, _) => AppDatabase.createSchema(d),
    ),
  );
  AppDatabase.instance.overrideForTests(db);
  return db;
}
