import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';

/// Satu pintu ke database. Widget tidak menyentuh FirebaseFirestore.instance
/// langsung, supaya widget test memakai LayananMemori (tanpa Firebase).
abstract class LayananData {
  Future<void> simpanPenggunaSaatLogin({
    required String uid,
    required String email,
    String? namaLengkap,
  });

  Future<void> isiKendaraanAwalJikaKosong();

  Stream<List<Kendaraan>> streamKendaraan();
}

class LayananFirestore implements LayananData {
  LayananFirestore({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Future<void> simpanPenggunaSaatLogin({
    required String uid,
    required String email,
    String? namaLengkap,
  }) async {
    final ref = _db.collection('users').doc(uid);
    if ((await ref.get()).exists) return;
    final nama = (namaLengkap ?? '').trim();
    await ref.set({
      ...Pengguna(
        idPengguna: uid,
        namaLengkap: nama.isNotEmpty ? nama : email.split('@').first,
        email: email,
      ).toMap(),
      'dibuat_pada': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> isiKendaraanAwalJikaKosong() async {
    final cek = await _db.collection('kendaraan').limit(1).get();
    if (cek.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final k in daftarKendaraanAwal) {
      batch.set(_db.collection('kendaraan').doc(k.idKendaraan), k.toMap());
    }
    await batch.commit();
  }

  @override
  Stream<List<Kendaraan>> streamKendaraan() => _db
      .collection('kendaraan')
      .snapshots()
      .map((s) => s.docs.map((d) => Kendaraan.fromMap(d.data())).toList());
}

/// Pengganti Firestore saat widget test: semua data di memori.
class LayananMemori implements LayananData {
  LayananMemori({List<Kendaraan>? kendaraan})
      : _kendaraan = List.of(kendaraan ?? daftarKendaraanAwal);

  final List<Kendaraan> _kendaraan;

  @override
  Future<void> simpanPenggunaSaatLogin({
    required String uid,
    required String email,
    String? namaLengkap,
  }) async {}

  @override
  Future<void> isiKendaraanAwalJikaKosong() async {}

  @override
  Stream<List<Kendaraan>> streamKendaraan() async* {
    yield List.of(_kendaraan);
  }
}
