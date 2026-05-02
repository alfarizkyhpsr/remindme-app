import 'package:flutter/material.dart';
import '../core/db_helper.dart';
import '../models/reminder_model.dart';

class PengingatProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  List<Pengingat> _daftarPengingat = [];
  bool _sedangMemuat = false;

  PengingatProvider({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  List<Pengingat> get daftarPengingat => _daftarPengingat;
  bool get sedangMemuat => _sedangMemuat;

  Future<void> ambilPengingat(int idPengguna) async {
    _sedangMemuat = true;
    notifyListeners();

    final db = await _dbHelper.database;
    final result = await db.query('reminders', where: 'userId = ?', whereArgs: [idPengguna]);
    
    _daftarPengingat = result.map((json) => Pengingat.fromMap(json)).toList();
    _sedangMemuat = false;
    notifyListeners();
  }

  Future<void> tambahPengingat(Pengingat pengingat) async {
    final db = await _dbHelper.database;
    await db.insert('reminders', pengingat.toMap());
    await ambilPengingat(pengingat.idPengguna);
  }

  Future<void> perbaruiPengingat(Pengingat pengingat) async {
    final db = await _dbHelper.database;
    await db.update(
      'reminders',
      pengingat.toMap(),
      where: 'id = ?',
      whereArgs: [pengingat.id],
    );
    await ambilPengingat(pengingat.idPengguna);
  }

  Future<void> hapusPengingat(int id, int idPengguna) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
    await ambilPengingat(idPengguna);
  }
}
