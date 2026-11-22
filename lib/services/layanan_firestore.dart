import 'dart:async';

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

  /// Dokumen users/{uid}; null bila belum ada (akun dibuat sebelum Firestore).
  Stream<Pengguna?> streamPengguna({required String uid});

  Future<void> isiKendaraanAwalJikaKosong();

  Stream<List<Kendaraan>> streamKendaraan();
}

/// Profil baru; nama kosong diganti awalan email agar sapaan tetap terisi.
Pengguna _profilBaru(String uid, String email, String? namaLengkap) {
  final nama = (namaLengkap ?? '').trim();
  return Pengguna(
    idPengguna: uid,
    namaLengkap: nama.isNotEmpty ? nama : email.split('@').first,
    email: email,
  );
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
    await ref.set({
      ..._profilBaru(uid, email, namaLengkap).toMap(),
      'dibuat_pada': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<Pengguna?> streamPengguna({required String uid}) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.exists ? Pengguna.fromMap(d.data()!) : null);

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
  final _pengguna = <String, Pengguna>{};
  final _berubah = StreamController<void>.broadcast();

  // Seperti snapshots(): tiap listener baru (StreamBuilder dibangun ulang)
  // langsung menerima data terkini, lalu setiap perubahan.
  Stream<T> _pantau<T>(T Function() ambil) => Stream.multi((s) {
        s.add(ambil());
        final sub = _berubah.stream.listen((_) => s.add(ambil()));
        s.onCancel = sub.cancel;
      });

  @override
  Future<void> simpanPenggunaSaatLogin({
    required String uid,
    required String email,
    String? namaLengkap,
  }) async {
    _pengguna.putIfAbsent(uid, () => _profilBaru(uid, email, namaLengkap));
    _berubah.add(null);
  }

  @override
  Stream<Pengguna?> streamPengguna({required String uid}) =>
      _pantau(() => _pengguna[uid]);

  @override
  Future<void> isiKendaraanAwalJikaKosong() async {}

  @override
  Stream<List<Kendaraan>> streamKendaraan() =>
      _pantau(() => List.of(_kendaraan));
}
