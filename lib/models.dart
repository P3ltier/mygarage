import 'package:cloud_firestore/cloud_firestore.dart';

/// Model 3 collection MyGarage — padanan users / rooms / reservations di modul.
/// Doc ID: users = uid Auth · kendaraan = id_kendaraan · servis = auto-ID.
class Pengguna {
  Pengguna({
    required this.idPengguna,
    required this.namaLengkap,
    required this.email,
    this.nomorTelepon = '',
    this.peran = 'pemilik',
  });

  final String idPengguna;
  final String namaLengkap;
  final String email;
  final String nomorTelepon;
  final String peran;

  /// `dibuat_pada` diisi serverTimestamp() di layanan, bukan di sini.
  Map<String, dynamic> toMap() => {
        'id_pengguna': idPengguna,
        'nama_lengkap': namaLengkap,
        'email': email,
        'nomor_telepon': nomorTelepon,
        'peran': peran,
      };

  factory Pengguna.fromMap(Map<String, dynamic> m) => Pengguna(
        idPengguna: m['id_pengguna'] as String? ?? '',
        namaLengkap: m['nama_lengkap'] as String? ?? '',
        email: m['email'] as String? ?? '',
        nomorTelepon: m['nomor_telepon'] as String? ?? '',
        peran: m['peran'] as String? ?? 'pemilik',
      );
}

class Kendaraan {
  Kendaraan({
    required this.idKendaraan,
    required this.namaKendaraan,
    required this.merek,
    required this.tahun,
    required this.platNomor,
  });

  final String idKendaraan;
  final String namaKendaraan;
  final String merek;
  final int tahun;
  final String platNomor;

  Map<String, dynamic> toMap() => {
        'id_kendaraan': idKendaraan,
        'nama_kendaraan': namaKendaraan,
        'merek': merek,
        'tahun': tahun,
        'plat_nomor': platNomor,
      };

  factory Kendaraan.fromMap(Map<String, dynamic> m) => Kendaraan(
        idKendaraan: m['id_kendaraan'] as String? ?? '',
        namaKendaraan: m['nama_kendaraan'] as String? ?? '',
        merek: m['merek'] as String? ?? '',
        tahun: (m['tahun'] as num?)?.toInt() ?? 0,
        platNomor: m['plat_nomor'] as String? ?? '',
      );
}

class CatatanServis {
  CatatanServis({
    required this.jenis,
    required this.tanggal,
    this.kilometer,
    required this.biaya,
    int? id,
    this.idDokumen,
    this.idPengguna,
    this.idKendaraan,
    this.namaKendaraan,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch;

  final int id;

  /// Doc ID Firestore. Null untuk catatan baru (dipakai `id`), diisi dari
  /// snapshot agar seed ber-ID per pengguna tetap bisa diubah/dihapus.
  final String? idDokumen;
  String get refId => idDokumen ?? '$id';
  final String jenis;
  final DateTime tanggal;
  final int? kilometer;
  final int biaya;

  /// Pemilik catatan (uid Auth); null untuk data seed/demo di memori.
  final String? idPengguna;

  /// Kendaraan = referensi collection `kendaraan`; `namaKendaraan` sengaja
  /// disalin (denormalisasi) karena Firestore tidak punya JOIN.
  final String? idKendaraan;
  final String? namaKendaraan;

  /// Doc ID di Firestore = id.toString() (id int dipertahankan agar mode Ubah
  /// dan test lama tidak berubah).
  Map<String, dynamic> toMap() => {
        'id_catatan': id,
        if (idPengguna != null) 'id_pengguna': idPengguna,
        if (idKendaraan != null) 'id_kendaraan': idKendaraan,
        if (namaKendaraan != null) 'nama_kendaraan': namaKendaraan,
        'jenis': jenis,
        'tanggal': Timestamp.fromDate(tanggal),
        'kilometer': kilometer,
        'biaya': biaya,
      };

  factory CatatanServis.fromMap(Map<String, dynamic> m, {String? idDokumen}) =>
      CatatanServis(
        id: (m['id_catatan'] as num?)?.toInt(),
        idDokumen: idDokumen,
        idPengguna: m['id_pengguna'] as String?,
        idKendaraan: m['id_kendaraan'] as String?,
        namaKendaraan: m['nama_kendaraan'] as String?,
        jenis: m['jenis'] as String? ?? '',
        tanggal: (m['tanggal'] as Timestamp?)?.toDate() ?? DateTime(2000),
        kilometer: (m['kilometer'] as num?)?.toInt(),
        biaya: (m['biaya'] as num?)?.toInt() ?? 0,
      );

  /// Padanan `bisaDiubah` modul: MyGarage tidak punya status persetujuan,
  /// jadi yang menentukan catatan boleh diubah/dihapus adalah kepemilikannya.
  bool bisaDiubahOleh(String uidAktif) => idPengguna == uidAktif;

  CatatanServis denganPemilik(String uid) => CatatanServis(
        id: id,
        idDokumen: idDokumen,
        idPengguna: uid,
        idKendaraan: idKendaraan,
        namaKendaraan: namaKendaraan,
        jenis: jenis,
        tanggal: tanggal,
        kilometer: kilometer,
        biaya: biaya,
      );
}

/// Master data kendaraan yang di-seed sekali saat collection kosong.
final List<Kendaraan> daftarKendaraanAwal = [
  Kendaraan(
    idKendaraan: 'mobil-utama',
    namaKendaraan: 'Mobil Harian',
    merek: 'Toyota',
    tahun: 2019,
    platNomor: 'B 1234 XYZ',
  ),
];
