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

  /// Isi contoh sekali per pengguna agar demo indikator merah tetap bisa
  /// diperagakan pada akun baru.
  Future<void> isiCatatanAwalJikaKosong({
    required String uid,
    required List<CatatanServis> awal,
  });

  /// Melempar [CatatanDuplikatException] tanpa menulis apa pun bila duplikat.
  /// Khusus Create; mode Ubah memakai [ubahCatatan].
  Future<void> simpanCatatan(CatatanServis c, {required String uid});

  /// `update()` hanya field yang berubah: `dibuat_pada` dan `id_pengguna`
  /// tetap, `diubah_pada` diisi server.
  Future<void> ubahCatatan(CatatanServis c, {required String uid});

  Future<void> hapusCatatan(CatatanServis c, {required String uid});

  Stream<List<CatatanServis>> streamCatatanSaya({required String uid});
}

class CatatanDuplikatException implements Exception {
  const CatatanDuplikatException();
}

/// Operasi ubah/hapus ditolak aturan bisnis (bukan pemilik / data hilang).
class OperasiDitolakException implements Exception {
  const OperasiDitolakException(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}

/// Lapis kedua modul: aturan bisnis di kode, cermin Security Rules kepemilikan.
void pastikanBolehDiubah({
  required CatatanServis catatan,
  required String uidAktif,
  required String aksi,
}) {
  if (!catatan.bisaDiubahOleh(uidAktif)) {
    throw OperasiDitolakException(
        'Catatan servis ini bukan milikmu, tidak bisa $aksi.');
  }
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

  @override
  Future<void> isiCatatanAwalJikaKosong({
    required String uid,
    required List<CatatanServis> awal,
  }) async {
    // Penanda sekali-per-akun: tanpa ini, menghapus semua catatan lalu
    // refresh akan memunculkan lagi 3 catatan contoh (fitur Hapus tampak rusak).
    final userRef = _db.collection('users').doc(uid);
    if ((await userRef.get()).data()?['sudah_ditanam'] == true) return;
    final cek =
        await _servis.where('id_pengguna', isEqualTo: uid).limit(1).get();
    if (cek.docs.isEmpty) {
      final batch = _db.batch();
      for (final c in awal) {
        // Doc ID memuat uid: id seed sama untuk semua akun, jadi tanpa uid
        // akun kedua menimpa seed akun pertama (doc ID Firestore global).
        batch.set(_servis.doc('${uid}_${c.id}'), {
          ...c.denganPemilik(uid).toMap(),
          'dibuat_pada': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
    await userRef.set({'sudah_ditanam': true}, SetOptions(merge: true));
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
    await _servis.doc(c.refId).set({
      ...c.denganPemilik(uid).toMap(),
      // Mode Ubah: jangan timpa waktu dibuat yang lama.
      if (!sudahAda) 'dibuat_pada': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> ubahCatatan(CatatanServis c, {required String uid}) async {
    final docRef = _servis.doc(c.refId);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw const OperasiDitolakException('Catatan servis tidak ditemukan.');
    }
    pastikanBolehDiubah(
      catatan: CatatanServis.fromMap(snap.data()!, idDokumen: snap.id),
      uidAktif: uid,
      aksi: 'diubah',
    );
    final milik = (await _servis.where('id_pengguna', isEqualTo: uid).get())
        .docs
        .map((d) => CatatanServis.fromMap(d.data(), idDokumen: d.id))
        .toList();
    // Catatan ini sendiri tidak dihitung bentrok (padanan abaikanIdReservasi).
    if (adaDuplikat(milik, c)) throw const CatatanDuplikatException();
    await docRef.update({
      'jenis': c.jenis,
      'tanggal': Timestamp.fromDate(c.tanggal),
      'kilometer': c.kilometer,
      'biaya': c.biaya,
      // Jangan kirim null: kendaraan tidak boleh terhapus bila cache form
      // belum terisi saat mode Ubah dibuka.
      if (c.idKendaraan != null) 'id_kendaraan': c.idKendaraan,
      if (c.namaKendaraan != null) 'nama_kendaraan': c.namaKendaraan,
      'diubah_pada': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> hapusCatatan(CatatanServis c, {required String uid}) async {
    final docRef = _servis.doc(c.refId);
    final snap = await docRef.get();
    if (!snap.exists) {
      throw const OperasiDitolakException('Catatan servis sudah tidak ada.');
    }
    pastikanBolehDiubah(
      catatan: CatatanServis.fromMap(snap.data()!, idDokumen: snap.id),
      uidAktif: uid,
      aksi: 'dihapus',
    );
    await docRef.delete();
  }

  @override
  Stream<List<CatatanServis>> streamCatatanSaya({required String uid}) =>
      _servis
          .where('id_pengguna', isEqualTo: uid)
          .snapshots()
          .map((s) => _urutkan(s.docs
              .map((d) => CatatanServis.fromMap(d.data(), idDokumen: d.id))
              .toList()));
}

/// Pengganti Firestore saat widget test: semua data di memori.
class LayananMemori implements LayananData {
  LayananMemori({List<Kendaraan>? kendaraan})
      : _kendaraan = List.of(kendaraan ?? daftarKendaraanAwal);

  final List<Kendaraan> _kendaraan;
  final _pengguna = <String, Pengguna>{};
  final _catatan = <String, List<CatatanServis>>{}; // per uid
  final _sudahDitanam = <String>{};
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

  @override
  Future<void> isiCatatanAwalJikaKosong({
    required String uid,
    required List<CatatanServis> awal,
  }) async {
    if (!_sudahDitanam.add(uid)) return; // sekali per akun, termasuk setelah dihapus
    _catatan.putIfAbsent(
        uid, () => awal.map((c) => c.denganPemilik(uid)).toList());
    _berubah.add(null);
  }

  /// Cari lintas uid: meniru Firestore, dokumen milik akun lain tetap ketemu
  /// lalu ditolak [pastikanBolehDiubah].
  CatatanServis? _cari(int id) {
    for (final daftar in _catatan.values) {
      for (final c in daftar) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  @override
  Future<void> ubahCatatan(CatatanServis c, {required String uid}) async {
    final lama = _cari(c.id);
    if (lama == null) {
      throw const OperasiDitolakException('Catatan servis tidak ditemukan.');
    }
    pastikanBolehDiubah(catatan: lama, uidAktif: uid, aksi: 'diubah');
    final milik = _catatan[uid]!;
    if (adaDuplikat(milik, c)) throw const CatatanDuplikatException();
    milik[milik.indexWhere((x) => x.id == c.id)] = c.denganPemilik(uid);
    _berubah.add(null);
  }

  @override
  Future<void> hapusCatatan(CatatanServis c, {required String uid}) async {
    final lama = _cari(c.id);
    if (lama == null) {
      throw const OperasiDitolakException('Catatan servis sudah tidak ada.');
    }
    pastikanBolehDiubah(catatan: lama, uidAktif: uid, aksi: 'dihapus');
    _catatan[uid]!.removeWhere((x) => x.id == c.id);
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
