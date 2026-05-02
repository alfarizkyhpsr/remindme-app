import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/core/encryption_helper.dart';

void main() {
  group('EncryptionHelper Logic', () {
    test('Harus bisa melakukan enkripsi dan dekripsi kembali ke teks asli', () {
      const teksAsli = 'SecretPassword123';
      final terkripsi = EncryptionHelper.encryptText(teksAsli);
      final terdekripsi = EncryptionHelper.decryptText(terkripsi);
      
      expect(terkripsi, isNot(teksAsli));
      expect(terdekripsi, teksAsli);
    });

    test('Enkripsi teks yang sama harus menghasilkan output yang berbeda (IV randomization)', () {
      const teks = 'SameText';
      final e1 = EncryptionHelper.encryptText(teks);
      final e2 = EncryptionHelper.encryptText(teks);
      
      expect(e1, isNot(e2));
      expect(EncryptionHelper.decryptText(e1), EncryptionHelper.decryptText(e2));
    });
  });
}
