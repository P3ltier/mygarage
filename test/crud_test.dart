import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygarage/main.dart';
import 'package:mygarage/services/layanan_firestore.dart';

/// Pertemuan 11 — aturan kepemilikan, ubah(), dan hapus dengan konfirmasi.
void main() {
  group('Aturan bisnis ubah/hapus (lapisan layanan)', () {
    final catatan = CatatanServis(
        id: 1,
        idPengguna: 'u1',
        jenis: 'Ganti Oli',
        tanggal: DateTime(2026, 7, 12),
        biaya: 250000);

    test('U01 pastikanBolehDiubah: pemilik diterima, akun lain ditolak',
        () {
      expect(
          () => pastikanBolehDiubah(
              catatan: catatan, uidAktif: 'u1', aksi: 'diubah'),
          returnsNormally);
      expect(
          () => pastikanBolehDiubah(
              catatan: catatan, uidAktif: 'u2', aksi: 'dihapus'),
          throwsA(isA<OperasiDitolakException>()));
      expect(catatan.bisaDiubahOleh('u1'), isTrue);
      expect(catatan.bisaDiubahOleh('u2'), isFalse);
    });

    test('U02 ubah ke jenis+tanggal yang sudah ada ditolak, data lama utuh',
        () async {
      final l = LayananMemori();
      await l.isiCatatanAwalJikaKosong(uid: 'u1', awal: seedDefault);
      final bentrok = CatatanServis(
          id: 20260620, // Balancing Ban 20 Jun
          jenis: 'ganti oli mesin',
          tanggal: DateTime(2026, 7, 12), // tanggal Ganti Oli Mesin
          biaya: 1);
      await expectLater(
          l.ubahCatatan(bentrok, uid: 'u1'),
          throwsA(isA<CatatanDuplikatException>()));
      final isi = await l.streamCatatanSaya(uid: 'u1').first;
      expect(isi.firstWhere((c) => c.id == 20260620).jenis, 'Balancing Ban');
    });

    test('U03 ubah/hapus catatan akun lain ditolak sebelum menulis', () async {
      final l = LayananMemori();
      await l.isiCatatanAwalJikaKosong(uid: 'u1', awal: seedDefault);
      final c = seedDefault.first;
      await expectLater(
          l.ubahCatatan(
              CatatanServis(
                  id: c.id, jenis: 'X', tanggal: c.tanggal, biaya: 1),
              uid: 'u2'),
          throwsA(isA<OperasiDitolakException>()));
      await expectLater(
          l.hapusCatatan(c, uid: 'u2'),
          throwsA(isA<OperasiDitolakException>()));
      expect(await l.streamCatatanSaya(uid: 'u1').first, hasLength(3));
    });

    test('U04 seed hanya sekali per akun: setelah dihapus tidak muncul lagi',
        () async {
      final l = LayananMemori();
      await l.isiCatatanAwalJikaKosong(uid: 'u1', awal: seedDefault);
      for (final c in seedDefault) {
        await l.hapusCatatan(c, uid: 'u1');
      }
      await l.isiCatatanAwalJikaKosong(uid: 'u1', awal: seedDefault);
      expect(await l.streamCatatanSaya(uid: 'u1').first, isEmpty);
    });

    test('U05 ubah mempertahankan id dan pemilik, hanya biaya berubah',
        () async {
      final l = LayananMemori();
      await l.isiCatatanAwalJikaKosong(uid: 'u1', awal: seedDefault);
      final lama = (await l.streamCatatanSaya(uid: 'u1').first)
          .firstWhere((c) => c.id == 20260712);
      await l.ubahCatatan(
          CatatanServis(
              id: lama.id,
              jenis: lama.jenis,
              tanggal: lama.tanggal,
              biaya: 300000),
          uid: 'u1');
      final baru = (await l.streamCatatanSaya(uid: 'u1').first)
          .firstWhere((c) => c.id == 20260712);
      expect(baru.biaya, 300000);
      expect(baru.id, 20260712);
      expect(baru.idPengguna, 'u1');
      expect(baru.jenis, 'Ganti Oli Mesin');
    });
  });

  group('Widget — Ubah dan Hapus dari daftar Riwayat', () {
    Future<LayananMemori> bukaRiwayat(WidgetTester tester) async {
      final l = LayananMemori();
      await tester.pumpWidget(
          MyApp(sudahMasuk: true, layanan: l, seed: seedDefault));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.receipt_long_outlined));
      await tester.pumpAndSettle();
      return l;
    }

    testWidgets('U06 Ubah membuka form terisi data lama dan menyimpan biaya '
        'baru', (tester) async {
      await bukaRiwayat(tester);
      await tester.tap(find.byKey(const Key('ubah-20260712')));
      await tester.pumpAndSettle();
      expect(find.text('Ubah Catatan Servis'), findsOneWidget);
      final biayaField =
          tester.widget<TextFormField>(find.byKey(const Key('biaya')));
      expect(biayaField.controller!.text, '250000'); // data lama terisi
      await tester.enterText(find.byKey(const Key('biaya')), '300000');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Catatan servis diperbarui'), findsOneWidget);
      expect(find.text('Rp 300.000'), findsOneWidget); // kartu ikut berubah
      // Timer SnackBar yang masih hidup menggantungkan teardown testWidgets.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('U07 Hapus selalu lewat dialog; Batal tidak mengubah data',
        (tester) async {
      await bukaRiwayat(tester);
      await tester.tap(find.byKey(const Key('hapus-20260712')));
      await tester.pumpAndSettle();
      expect(find.text('Hapus catatan servis?'), findsOneWidget);
      expect(find.textContaining('akan dihapus permanen'), findsOneWidget);
      await tester.tap(find.byKey(const Key('batal-hapus')));
      await tester.pumpAndSettle();
      expect(find.text('Ganti Oli Mesin'), findsOneWidget);
    });

    testWidgets('U08 setujui dialog: kartu hilang dan SnackBar berhasil',
        (tester) async {
      await bukaRiwayat(tester);
      await tester.tap(find.byKey(const Key('hapus-20260712')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('yakin-hapus')));
      await tester.pumpAndSettle();
      expect(find.text('Ganti Oli Mesin'), findsNothing);
      expect(find.text('Catatan servis dihapus'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });
}
