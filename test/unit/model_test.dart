import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/models/user_model.dart';
import 'package:remindme/models/reminder_model.dart';

void main() {
  group('Model Pengguna (Serialization)', () {
    test('Harus mengonversi map ke objek Pengguna', () {
      final map = {
        'id': 1,
        'username': 'admin',
        'password': 'hashed_password',
        'profile_image': 'path/to/img.png'
      };
      final pengguna = Pengguna.fromMap(map);
      
      expect(pengguna.id, 1);
      expect(pengguna.namaPengguna, 'admin');
      expect(pengguna.kataSandi, 'hashed_password');
      expect(pengguna.fotoProfil, 'path/to/img.png');
    });

    test('Harus mengonversi objek Pengguna ke map', () {
      final pengguna = Pengguna(id: 1, namaPengguna: 'admin', kataSandi: 'hashed_password');
      final map = pengguna.toMap();
      
      expect(map['id'], 1);
      expect(map['username'], 'admin');
      expect(map['password'], 'hashed_password');
    });
  });

  group('Model Pengingat (Serialization)', () {
    test('Harus mengonversi map ke objek Pengingat', () {
      final map = {
        'id': 10,
        'userId': 1,
        'title': 'Selesaikan Lab TPM',
        'description': 'Deadline besok',
        'dateTime': '2026-04-30T10:00:00.000',
        'location': 'Kampus',
        'isCompleted': 0
      };
      final pengingat = Pengingat.fromMap(map);
      
      expect(pengingat.id, 10);
      expect(pengingat.judul, 'Selesaikan Lab TPM');
      expect(pengingat.sudahSelesai, false);
    });

    test('Harus mengonversi objek Pengingat ke map', () {
      final pengingat = Pengingat(
        id: 10,
        idPengguna: 1,
        judul: 'Selesaikan Lab TPM',
        deskripsi: 'Deadline besok',
        waktu: DateTime.parse('2026-04-30T10:00:00.000'),
        sudahSelesai: true
      );
      final map = pengingat.toMap();
      
      expect(map['id'], 10);
      expect(map['isCompleted'], 1);
    });
  });
}
