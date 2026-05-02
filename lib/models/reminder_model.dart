class Pengingat {
  final int? id;
  final int idPengguna;
  final String judul;
  final String deskripsi;
  final DateTime waktu;
  final DateTime? deadline; // Tambahkan ini
  final String? lokasi;
  final bool sudahSelesai;

  Pengingat({
    this.id,
    required this.idPengguna,
    required this.judul,
    required this.deskripsi,
    required this.waktu,
    this.deadline,
    this.lokasi,
    this.sudahSelesai = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': idPengguna,
      'title': judul,
      'description': deskripsi,
      'dateTime': waktu.toIso8601String(),
      'deadline': deadline?.toIso8601String(), // Simpan ISO string
      'location': lokasi,
      'isCompleted': sudahSelesai ? 1 : 0,
    };
  }

  factory Pengingat.fromMap(Map<String, dynamic> map) {
    return Pengingat(
      id: map['id'],
      idPengguna: map['userId'],
      judul: map['title'],
      deskripsi: map['description'],
      waktu: DateTime.parse(map['dateTime']),
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      lokasi: map['location'],
      sudahSelesai: map['isCompleted'] == 1,
    );
  }
}
