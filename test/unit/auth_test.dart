import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Auth Provider Logic Tests', () {
    late AuthProvider authProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authProvider = AuthProvider();
    });

    test('Initial state should be logged out', () {
      expect(authProvider.sudahMasuk, false);
      expect(authProvider.penggunaSaatIni, isNull);
    });

    test('Logout should clear session', () async {
      await authProvider.keluar();
      expect(authProvider.sudahMasuk, false);
      expect(authProvider.penggunaSaatIni, isNull);
    });

    test('Biometric setting should persist in memory', () async {
      await authProvider.setelBiometrik(true);
      expect(authProvider.biometrikAktif, true);
      
      await authProvider.setelBiometrik(false);
      expect(authProvider.biometrikAktif, false);
    });
  });
}
