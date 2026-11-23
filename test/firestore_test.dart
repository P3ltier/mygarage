import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygarage/main.dart';
import 'package:mygarage/services/layanan_firestore.dart';

/// Test lapisan Firestore memakai LayananMemori (tanpa Firebase).
void main() {
  group('Latihan 2 — users dan kendaraan', () {
    testWidgets('F01 kolom Nama Lengkap hanya ada di mode Daftar',
        (tester) async {
      await tester.pumpWidget(const MyApp(sudahMasuk: false));
      expect(find.byKey(const Key('nama')), findsNothing);
      await tester.tap(find.byKey(const Key('ganti-mode')));
      await tester.pump();
      expect(find.byKey(const Key('nama')), findsOneWidget);
    });

    test('F02 profil baru: nama kosong diganti awalan email, profil lama '
        'tidak ditimpa', () async {
      final l = LayananMemori();
      await l.simpanPenggunaSaatLogin(
          uid: 'u1', email: 'aang@mygarage.id', namaLengkap: '  ');
      expect((await l.streamPengguna(uid: 'u1').first)!.namaLengkap, 'aang');
      await l.simpanPenggunaSaatLogin(
          uid: 'u1', email: 'aang@mygarage.id', namaLengkap: 'Jannes');
      expect((await l.streamPengguna(uid: 'u1').first)!.namaLengkap, 'aang');
    });

    testWidgets('F03 Beranda menyapa dengan nama dari users/{uid} dan '
        'menampilkan kendaraan', (tester) async {
      final l = LayananMemori();
      await l.simpanPenggunaSaatLogin(
          uid: uidUji, email: 'aang@mygarage.id', namaLengkap: 'Jannes');
      await tester.pumpWidget(MyApp(sudahMasuk: true, layanan: l));
      await tester.pumpAndSettle();
      expect(find.text('Halo, Jannes'), findsOneWidget);
      expect(find.text('Kendaraan Saya · Mobil'),
          findsOneWidget);
    });
  });

  group('Latihan 3 — simpan catatan dan tolak duplikat', () {
    test('F04 jenis sama (beda huruf/spasi) di tanggal sama ditolak; '
        'tanggal lain dan pengguna lain boleh', () async {
      final l = LayananMemori();
      await l.simpanCatatan(
          CatatanServis(
              jenis: 'Ganti Oli', tanggal: DateTime(2026, 7, 12), biaya: 1),
          uid: 'u1');
      await expectLater(
          () => l.simpanCatatan(
              CatatanServis(
                  jenis: '  ganti OLI ',
                  tanggal: DateTime(2026, 7, 12),
                  biaya: 2),
              uid: 'u1'),
          throwsA(isA<CatatanDuplikatException>()));
      await l.simpanCatatan(
          CatatanServis(
              jenis: 'Ganti Oli', tanggal: DateTime(2026, 7, 13), biaya: 3),
          uid: 'u1');
      await l.simpanCatatan(
          CatatanServis(
              jenis: 'Ganti Oli', tanggal: DateTime(2026, 7, 12), biaya: 4),
          uid: 'u2');
      expect(await l.streamCatatanSaya(uid: 'u1').first, hasLength(2));
      expect(await l.streamCatatanSaya(uid: 'u2').first, hasLength(1));
    });

    test('F05 mode Ubah: id sama menimpa dokumen, bukan duplikat', () async {
      final l = LayananMemori();
      await l.simpanCatatan(
          CatatanServis(
              id: 7,
              jenis: 'Ganti Oli',
              tanggal: DateTime(2026, 7, 12),
              biaya: 1),
          uid: 'u1');
      await l.simpanCatatan(
          CatatanServis(
              id: 7,
              jenis: 'Ganti Oli',
              tanggal: DateTime(2026, 7, 12),
              biaya: 2),
          uid: 'u1');
      final isi = await l.streamCatatanSaya(uid: 'u1').first;
      expect(isi, hasLength(1));
      expect(isi.single.biaya, 2);
    });

    test('F06 toMap/fromMap membawa pemilik + kendaraan; seed tanpa pemilik '
        'tidak menulis field itu', () async {
      final c = CatatanServis(
          id: 7,
          idPengguna: 'u1',
          idKendaraan: 'mobil-utama',
          namaKendaraan: 'Mobil Harian',
          jenis: 'Ganti Oli',
          tanggal: DateTime(2026, 7, 12),
          biaya: 1);
      final kembali = CatatanServis.fromMap(c.toMap());
      expect(kembali.idPengguna, 'u1');
      expect(kembali.idKendaraan, 'mobil-utama');
      expect(kembali.namaKendaraan, 'Mobil Harian');
      expect(kembali.id, 7);
      final seed = CatatanServis(
          jenis: 'Ganti Oli', tanggal: DateTime(2026, 7, 12), biaya: 1);
      expect(seed.toMap().containsKey('id_pengguna'), isFalse);
    });

    testWidgets('F07 simpan kedua dengan jenis+tanggal sama ditolak, '
        'form tetap terbuka', (tester) async {
      final l = LayananMemori();
      await tester.pumpWidget(MyApp(
          sudahMasuk: true, layanan: l, seed: const <CatatanServis>[]));
      await tester.pumpAndSettle(); // frame pertama masih keadaan loading

      Future<void> isiDanSimpan(String jenis) async {
        await tester.tap(find.byKey(const Key('tambah')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('jenis')), jenis);
        await tester.enterText(find.byKey(const Key('biaya')), '150000');
        await tester.tap(find.byKey(const Key('simpan')));
        await tester.pumpAndSettle();
      }

      await isiDanSimpan('Ganti Oli');
      expect(find.text('Catatan servis disimpan'), findsOneWidget);
      // SnackBar hijau menutupi bottom nav: biarkan menutup sendiri dulu.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Tambah Servis'), findsOneWidget);
      await isiDanSimpan('  ganti oli ');
      expect(find.text('Catatan servis untuk tanggal ini sudah ada'),
          findsOneWidget);
      expect(find.byKey(const Key('simpan')), findsOneWidget); // form terbuka
      // Bukti UI: form ditutup → Riwayat hanya punya SATU kartu (doc tidak bertambah).
      await tester.tap(find.byKey(const Key('batal')));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Ubah'), findsOneWidget);
    });
  });

  group('Latihan 4 — StreamBuilder tiga keadaan', () {
    testWidgets('F08 loading: indikator muncul selagi stream belum mengirim',
        (tester) async {
      final menunggu = StreamController<List<CatatanServis>>();
      addTearDown(menunggu.close);
      await tester.pumpWidget(
          MyApp(sudahMasuk: true, layanan: _LayananUji(menunggu.stream)));
      await tester.pump(); // satu frame: pumpAndSettle akan menggantung
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('F09 galat: pesan ramah, bukan stack trace', (tester) async {
      await tester.pumpWidget(MyApp(
          sudahMasuk: true,
          layanan: _LayananUji(
              Stream<List<CatatanServis>>.error(Exception('offline')))));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Riwayat servis gagal dimuat'), findsOneWidget);
    });

    testWidgets('F10 daftar kosong: keadaan kosong tampil', (tester) async {
      await tester.pumpWidget(MyApp(
          sudahMasuk: true,
          layanan: _LayananUji(Stream.value(const <CatatanServis>[]))));
      await tester.pumpAndSettle();
      expect(find.text('Belum ada catatan servis'), findsOneWidget);
    });
  });

  group('Kendaraan: nama bebas + tipe Mobil/Motor + plat', () {
    testWidgets('F13 kendaraan baru dibuat dari form dan bisa dipilih lagi',
        (tester) async {
      final l = LayananMemori();
      await tester.pumpWidget(MyApp(
          sudahMasuk: true, layanan: l, seed: const <CatatanServis>[]));
      await tester.pumpAndSettle();
      await plihKendaraanBaru(tester);

      await tester.enterText(
          find.byKey(const Key('kendaraan-nama')), 'Beat harian');
      await tester.tap(find.byKey(const Key('kendaraan-tipe')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Motor').last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('kendaraan-plat')), 'AB 123 CD');
      await tester.enterText(find.byKey(const Key('jenis')), 'Ganti Oli');
      await tester.enterText(find.byKey(const Key('biaya')), '75000');
      await tester.ensureVisible(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();

      expect(find.text('Ganti Oli'), findsOneWidget); // kartu di Riwayat
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // kendaraan baru ikut tersimpan: muncul lagi sebagai pilihan dropdown
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tambah')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kendaraan')));
      await tester.pumpAndSettle();
      expect(find.text('Beat harian · Motor · AB 123 CD'), findsWidgets);
      await tester.tap(find.text('Beat harian · Motor · AB 123 CD').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('batal')));
      await tester.pumpAndSettle();
    });
  });

  group('Regresi dari uji Chrome', () {
    test('F11 seedDefault punya id unik (dulu 3 catatan menulis ke dokumen yang sama)', () {
      expect(seedDefault.map((c) => c.id).toSet(), hasLength(seedDefault.length));
      expect(seedDefault, hasLength(3));
    });

    testWidgets('F12 Beranda tetap menampilkan kendaraan walau stream hanya boleh satu listener', (tester) async {
      // .snapshots() Firestore single-subscription; dulu stream yang sama
      // didengarkan dua kali sehingga baris kendaraan hilang.
      await tester.pumpWidget(MyApp(
          sudahMasuk: true, layanan: _LayananSatuListener([Kendaraan.awal(uidUji)])));
      await tester.pumpAndSettle();
      expect(find.text('Kendaraan Saya · Mobil'),
          findsOneWidget);
    });
  });
}

/// LayananData palsu untuk menguji keadaan loading/galat/kosong.
class _LayananUji implements LayananData {
  _LayananUji(this._stream);
  final Stream<List<CatatanServis>> _stream;

  @override
  Future<void> simpanPenggunaSaatLogin(
      {required String uid,
      required String email,
      String? namaLengkap}) async {}

  @override
  Stream<Pengguna?> streamPengguna({required String uid}) =>
      Stream.value(null);

  @override
  Future<void> isiKendaraanAwalJikaKosong({required String uid}) async {}

  @override
  Stream<List<Kendaraan>> streamKendaraan({required String uid}) =>
      Stream.value([Kendaraan.awal(uid)]);

  @override
  Future<void> simpanKendaraan(Kendaraan k, {required String uid}) async {}

  @override
  Future<void> isiCatatanAwalJikaKosong(
      {required String uid, required List<CatatanServis> awal}) async {}

  @override
  Future<void> simpanCatatan(CatatanServis c, {required String uid}) async {}

  @override
  Stream<List<CatatanServis>> streamCatatanSaya({required String uid}) =>
      _stream;
}

/// Meniru .snapshots() Firestore: satu stream hanya boleh satu listener.
class _LayananSatuListener implements LayananData {
  _LayananSatuListener(this._kendaraan);
  final List<Kendaraan> _kendaraan;

  @override
  Future<void> simpanPenggunaSaatLogin(
      {required String uid,
      required String email,
      String? namaLengkap}) async {}

  @override
  Stream<Pengguna?> streamPengguna({required String uid}) =>
      Stream.value(Pengguna(idPengguna: uid, namaLengkap: 'Test', email: 'a@b.c'));

  @override
  Future<void> isiKendaraanAwalJikaKosong({required String uid}) async {}

  @override
  Stream<List<Kendaraan>> streamKendaraan({required String uid}) {
    // single-subscription: listen kedua akan melempar StateError bila stream sama
    final c = StreamController<List<Kendaraan>>();
    c.add(_kendaraan);
    return c.stream;
  }

  @override
  Future<void> simpanKendaraan(Kendaraan k, {required String uid}) async {}

  @override
  Future<void> isiCatatanAwalJikaKosong(
      {required String uid, required List<CatatanServis> awal}) async {}

  @override
  Future<void> simpanCatatan(CatatanServis c, {required String uid}) async {}

  @override
  Stream<List<CatatanServis>> streamCatatanSaya({required String uid}) =>
      Stream.value(const <CatatanServis>[]);
}

/// Buka form lalu pilih '+ Tambah kendaraan...' pada dropdown.
Future<void> plihKendaraanBaru(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tambah')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('kendaraan')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('+ Tambah kendaraan...').last);
  await tester.pumpAndSettle();
}
