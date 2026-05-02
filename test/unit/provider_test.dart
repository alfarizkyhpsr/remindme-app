import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:remindme/providers/auth_provider.dart';
import 'package:remindme/providers/reminder_provider.dart';
import 'package:remindme/core/db_helper.dart';
import 'package:remindme/core/encryption_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockDatabase extends Mock implements Database {}

void main() {
  late AuthProvider authProvider;
  late PengingatProvider reminderProvider;
  late MockDatabaseHelper mockDbHelper;
  late MockDatabase mockDb;

  setUp(() {
    mockDbHelper = MockDatabaseHelper();
    mockDb = MockDatabase();
    authProvider = AuthProvider(dbHelper: mockDbHelper);
    reminderProvider = PengingatProvider(dbHelper: mockDbHelper);
    
    // Default stub for database access
    when(() => mockDbHelper.database).thenAnswer((_) async => mockDb);
    
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthProvider Tests', () {
    test('Daftar baru harus berhasil memasukkan data ke database', () async {
      when(() => mockDb.insert('users', any())).thenAnswer((_) async => 1);
      
      final result = await authProvider.daftar('testuser', 'password123');
      
      expect(result, true);
      verify(() => mockDb.insert('users', any())).called(1);
    });

    test('Masuk dengan password benar harus mengubah status login', () async {
      final userMap = {
        'id': 1,
        'username': 'testuser',
        'password': '' // to be filled
      };
      
      final enc = EncryptionHelper.encryptText('correct_pass');
      userMap['password'] = enc;

      when(() => mockDb.query('users', where: any(named: 'where'), whereArgs: any(named: 'whereArgs')))
          .thenAnswer((_) async => [userMap]);

      final result = await authProvider.masuk('testuser', 'correct_pass');
      
      expect(result, true);
      expect(authProvider.sudahMasuk, true);
      expect(authProvider.penggunaSaatIni?.namaPengguna, 'testuser');
    });
  });

  group('PengingatProvider Tests', () {
    test('ambilPengingat harus mengisi daftar dari database', () async {
      final reminderList = [
        {
          'id': 1,
          'userId': 1,
          'title': 'Test 1',
          'description': 'Desc 1',
          'dateTime': DateTime.now().toIso8601String(),
          'isCompleted': 0
        }
      ];

      when(() => mockDb.query('reminders', where: any(named: 'where'), whereArgs: any(named: 'whereArgs')))
          .thenAnswer((_) async => reminderList);

      await reminderProvider.ambilPengingat(1);
      
      expect(reminderProvider.daftarPengingat.length, 1);
      expect(reminderProvider.daftarPengingat.first.judul, 'Test 1');
      expect(reminderProvider.sedangMemuat, false);
    });
  });
}
