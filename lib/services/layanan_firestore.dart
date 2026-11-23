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

  /// Kendaraan milik pengguna ini (koleksinya per pengguna, bukan master global).
  Future<void> isiKendaraanAwalJikaKosong({required String uid});

  Stream<List<Kendaraan>> streamKendaraan({required String uid});

  Future<void> simpanKendaraan(Kendaraan k, {required String uid});

  /// Isi contoh sekali per pengguna agar demo indikator merah tetap bisa
  /// diperagakan pada akun baru.
  Future<void> isiCatatanAwalJikaKosong({
    required String uid,
    required List<CatatanServis> awal,
  });

  /// Melempar [CatatanDuplikatException] tanpa menulis apa pun bila duplikat.
  /// Catatan dengan id yang sudah ada (mode Ubah) menimpa dokumennya.
  Future<void> simpanCatatan(CatatanServis c, {required String uid});

  Stream<List<CatatanServis>> streamCatatanSaya({required String uid});
}

class CatatanDuplikatException implements Exception {
  const CatatanDuplikatException();
}

bool _hariSama(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// Adaptasi aturan modul "tolak jadwal bentrok": satu jenis servis per tanggal
// per pengguna. Catatan yang sama (mode Ubah) tidak bentrok dengan dirinya.
bool adaDuplikat(Iterable<CatatanServis> milikSaya, CatatanServis baru) =>
    milikSaya.any((c) =>
        c.id != baru.id &&
        _hariSama(c.tanggal, baru.tanggal) &&
        c.jenis.trim().toLowerCase() == baru.jenis.trim().toLowerCase());

List<CatatanServis> _urutkan(List<CatatanServis> daftar) =>
    daftar..sort((a, b) => b.tanggal.compareTo(a.tanggal));

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

  CollectionReference<Map<String, dynamic>> get _servis =>
      _db.collection('servis');
  CollectionReference<Map<String, dynamic>> get _kendaraan =>
      _db.collection('kendaraan');

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
  Future<void> isiKendaraanAwalJikaKosong({required String uid}) async {
    final cek =
        await _kendaraan.where('id_pengguna', isEqualTo: uid).limit(1).get();
    if (cek.docs.isNotEmpty) return;
    final awal = Kendaraan.awal(uid);
    await _kendaraan.doc(awal.idKendaraan).set({
      ...awal.toMap(),
      'dibuat_pada': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<Kendaraan>> streamKendaraan({required String uid}) => _kendaraan
      .where('id_pengguna', isEqualTo: uid)
      .snapshots()
      .map((s) => s.docs.map((d) => Kendaraan.fromMap(d.data())).toList());

  @override
  Future<void> simpanKendaraan(Kendaraan k, {required String uid}) =>
      _kendaraan.doc(k.idKendaraan).set({
        ...k.denganPemilik(uid).toMap(),
        'dibuat_pada': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> isiCatatanAwalJikaKosong({
    required String uid,
    required List<CatatanServis> awal,
  }) async {
    final cek =
        await _servis.where('id_pengguna', isEqualTo: uid).limit(1).get();
    if (cek.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final c in awal) {
      batch.set(_servis.doc('${c.id}'), {
        ...c.denganPemilik(uid).toMap(),
        'dibuat_pada': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> simpanCatatan(CatatanServis c, {required String uid}) async {
    // Cukup satu where (tanpa composite index); tanggal & jenis disaring di Dart.
    final milik = (await _servis.where('id_pengguna', isEqualTo: uid).get())
        .docs
        .map((d) => CatatanServis.fromMap(d.data()))
        .toList();
    if (adaDuplikat(milik, c)) throw const CatatanDuplikatException();
    final sudahAda = milik.any((x) => x.id == c.id);
    await _servis.doc('${c.id}').set({
      ...c.denganPemilik(uid).toMap(),
      // Mode Ubah: jangan timpa waktu dibuat yang lama.
      if (!sudahAda) 'dibuat_pada': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Stream<List<CatatanServis>> streamCatatanSaya({required String uid}) =>
      _servis
          .where('id_pengguna', isEqualTo: uid)
          .snapshots()
          .map((s) => _urutkan(
              s.docs.map((d) => CatatanServis.fromMap(d.data())).toList()));
}

/// Pengganti Firestore saat widget test: semua data di memori.
class LayananMemori implements LayananData {
  LayananMemori({List<Kendaraan>? kendaraan})
      : _kendaraanAwal = kendaraan;

  final List<Kendaraan>? _kendaraanAwal;
  final _kendaraan = <String, List<Kendaraan>>{}; // per uid
  final _pengguna = <String, Pengguna>{};
  final _catatan = <String, List<CatatanServis>>{}; // per uid
  final _berubah = StreamController<void>.broadcast();

  // Seperti snapshots(): tiap listener baru (StreamBuilder dibangun ulang)
  // langsung menerima data terkini, lalu setiap perubahan.
  Stream<T> _pantau<T>(T Function() ambil) => Stream.multi((s) {
        s.add(ambil());
        final sub = _berubah.stream.listen((_) => s.add(ambil()));
        s.onCancel = sub.cancel;
      });

  List<Kendaraan> _milik(String uid) => _kendaraan.putIfAbsent(
      uid, () => List.of(_kendaraanAwal ?? [Kendaraan.awal(uid)]));

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
  Future<void> isiKendaraanAwalJikaKosong({required String uid}) async {
    _milik(uid);
    _berubah.add(null);
  }

  @override
  Stream<List<Kendaraan>> streamKendaraan({required String uid}) =>
      _pantau(() => List.of(_milik(uid)));

  @override
  Future<void> simpanKendaraan(Kendaraan k, {required String uid}) async {
    final daftar = _milik(uid);
    final i = daftar.indexWhere((x) => x.idKendaraan == k.idKendaraan);
    if (i >= 0) {
      daftar[i] = k.denganPemilik(uid);
    } else {
      daftar.add(k.denganPemilik(uid));
    }
    _berubah.add(null);
  }

  @override
  Future<void> isiCatatanAwalJikaKosong({
    required String uid,
    required List<CatatanServis> awal,
  }) async {
    _catatan.putIfAbsent(
        uid, () => awal.map((c) => c.denganPemilik(uid)).toList());
    _berubah.add(null);
  }

  @override
  Future<void> simpanCatatan(CatatanServis c, {required String uid}) async {
    final milik = _catatan.putIfAbsent(uid, () => []);
    if (adaDuplikat(milik, c)) throw const CatatanDuplikatException();
    final i = milik.indexWhere((x) => x.id == c.id);
    if (i >= 0) {
      milik[i] = c.denganPemilik(uid); // mode Ubah: posisi tetap
    } else {
      milik.add(c.denganPemilik(uid));
    }
    _berubah.add(null);
  }

  @override
  Stream<List<CatatanServis>> streamCatatanSaya({required String uid}) =>
      _pantau(() => _urutkan(List.of(_catatan[uid] ?? const <CatatanServis>[])));
}
