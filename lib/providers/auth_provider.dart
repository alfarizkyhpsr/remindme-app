import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/db_helper.dart';
import '../core/encryption_helper.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  final LocalAuthentication _autentikasiLocal;
  
  Pengguna? _penggunaSaatIni;
  bool _sudahMasuk = false;
  bool _biometrikAktif = false;

  AuthProvider({
    DatabaseHelper? dbHelper,
    LocalAuthentication? auth,
  }) : _dbHelper = dbHelper ?? DatabaseHelper.instance,
       _autentikasiLocal = auth ?? LocalAuthentication();

  Pengguna? get penggunaSaatIni => _penggunaSaatIni;
  bool get sudahMasuk => _sudahMasuk;
  bool get biometrikAktif => _biometrikAktif;

  Future<void> perbaruiFotoProfil(String imagePath) async {
    if (_penggunaSaatIni == null) return;
    
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {'profile_image': imagePath},
      where: 'id = ?',
      whereArgs: [_penggunaSaatIni!.id],
    );
    
    _penggunaSaatIni = Pengguna(
      id: _penggunaSaatIni!.id,
      namaPengguna: _penggunaSaatIni!.namaPengguna,
      kataSandi: _penggunaSaatIni!.kataSandi,
      fotoProfil: imagePath,
    );
    notifyListeners();
  }

  Future<void> periksaSesi() async {
    final prefs = await SharedPreferences.getInstance();
    _biometrikAktif = prefs.getBool('biometrik_aktif') ?? false;
    
    final username = prefs.getString('username');
    if (username != null) {
      final db = await _dbHelper.database;
      final maps = await db.query('users', where: 'username = ?', whereArgs: [username]);
      if (maps.isNotEmpty) {
        _penggunaSaatIni = Pengguna.fromMap(maps.first);
        _sudahMasuk = true;
        notifyListeners();
      }
    }
  }

  Future<void> setelBiometrik(bool aktif) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrik_aktif', aktif);
    _biometrikAktif = aktif;
    
    if (aktif && _penggunaSaatIni != null) {
      await prefs.setString('biometric_username', _penggunaSaatIni!.namaPengguna);
    } else if (!aktif) {
      await prefs.remove('biometric_username');
    }
    notifyListeners();
  }

  Future<bool> daftar(String username, String password) async {
    final passwordTerkripsi = EncryptionHelper.encryptText(password);
    final pengguna = Pengguna(namaPengguna: username, kataSandi: passwordTerkripsi);
    
    try {
      final db = await _dbHelper.database;
      await db.insert('users', pengguna.toMap());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> masuk(String username, String password) async {
    final db = await _dbHelper.database;
    final maps = await db.query('users', where: 'username = ?', whereArgs: [username]);
    
    if (maps.isNotEmpty) {
      final pengguna = Pengguna.fromMap(maps.first);
      final passwordTerdekripsi = EncryptionHelper.decryptText(pengguna.kataSandi);
      
      if (passwordTerdekripsi == password) {
        _penggunaSaatIni = pengguna;
        _sudahMasuk = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  Future<bool> autentikasiBiometrik() async {
    if (kIsWeb) return false;
    
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('biometrik_aktif') ?? false;
    if (!isEnabled) return false;
    
    try {
      final bool bisaBiometrik = await _autentikasiLocal.canCheckBiometrics;
      final bool didukung = bisaBiometrik || await _autentikasiLocal.isDeviceSupported();
      if (!didukung) return false;

      final bool berhasil = await _autentikasiLocal.authenticate(
        localizedReason: 'Silakan autentikasi untuk masuk',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (berhasil) {
        final bioUsername = prefs.getString('biometric_username');
        if (bioUsername != null) {
          final db = await _dbHelper.database;
          final maps = await db.query('users', where: 'username = ?', whereArgs: [bioUsername]);
          if (maps.isNotEmpty) {
            _penggunaSaatIni = Pengguna.fromMap(maps.first);
            _sudahMasuk = true;
            await prefs.setString('username', bioUsername);
            notifyListeners();
            return true;
          }
        }
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<void> keluar() async {
    _penggunaSaatIni = null;
    _sudahMasuk = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('last_active_time');
    notifyListeners();
  }

  Future<void> catatWaktuAktif() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_active_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> periksaPerluAutentikasi() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActive = prefs.getInt('last_active_time');
    if (lastActive == null) return false;

    final diff = DateTime.now().millisecondsSinceEpoch - lastActive;
    return diff > 15000; // Lebih dari 15 detik
  }
}
