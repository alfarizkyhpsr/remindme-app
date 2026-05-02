class Pengguna {
  final int? id;
  final String namaPengguna;
  final String kataSandi;
  final String? fotoProfil;

  Pengguna({this.id, required this.namaPengguna, required this.kataSandi, this.fotoProfil});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': namaPengguna,
      'password': kataSandi,
      'profile_image': fotoProfil,
    };
  }

  factory Pengguna.fromMap(Map<String, dynamic> map) {
    return Pengguna(
      id: map['id'],
      namaPengguna: map['username'],
      kataSandi: map['password'],
      fotoProfil: map['profile_image'],
    );
  }
}
