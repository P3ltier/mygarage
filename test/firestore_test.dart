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
      expect(find.text('Mobil Harian · Toyota 2019 · B 1234 XYZ'),
          findsOneWidget);
    });
  });
}
