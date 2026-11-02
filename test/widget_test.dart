import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygarage/main.dart';

/// Harness: pumps a HOME screen that pushes the form, and records what the
/// form returns. Lets the widget tests exercise HalamanTambahCatatan inside a
/// real Navigator (Simpan pops with a CatatanServis; Batal pops with null).
class _Harness extends StatefulWidget {
  const _Harness();
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String _result = '';

  void _openForm() async {
    final r = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HalamanTambahCatatan()),
    );
    if (r is CatatanServis) {
      setState(() => _result = 'Tersimpan: ${r.jenis}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('HOME', key: Key('home')),
            FilledButton(
              key: const Key('open-form'),
              onPressed: _openForm,
              child: const Text('Open form'),
            ),
            if (_result.isNotEmpty) Text(_result, key: const Key('saved')),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Unit test aturan validasi (periksaCatatan)', () {
    test('jenis kosong ditolak', () {
      expect(periksaCatatan('', '50000'), 'Jenis perbaikan wajib diisi');
    });
    test('biaya kosong ditolak (sesuai frame Figma)', () {
      expect(periksaCatatan('Ganti Oli', ''), 'Biaya wajib diisi');
    });
    test('biaya nol/negatif ditolak', () {
      expect(periksaCatatan('Ganti Oli', '0'), 'Biaya harus angka lebih dari 0');
      expect(periksaCatatan('Ganti Oli', '-1000'),
          'Biaya harus angka lebih dari 0');
    });
    test('biaya bukan angka ditolak', () {
      expect(periksaCatatan('Ganti Oli', 'abc'),
          'Biaya harus angka lebih dari 0');
    });
    test('biaya besar tanpa plafon diterima (servis nyata tidak dibatasi)', () {
      expect(periksaCatatan('Ganti Aki', '900000'), isNull);
      expect(periksaCatatan('Overhaul Mesin', '5000000'), isNull);
    });
  });

  group('Login — frame "Login – Kesalahan"', () {
    testWidgets('L01 kredensial salah menampilkan pesan dan tetap di Login',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.enterText(find.byKey(const Key('email')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('sandi')), 'short');
      await tester.tap(find.byKey(const Key('masuk')));
      await tester.pump();
      expect(find.text('Email atau password salah'), findsNWidgets(2));
      expect(find.text('Selamat Datang'), findsOneWidget); // masih di Login
    });

    testWidgets('L02 login valid → Beranda → tap Tambah Servis membuka form',
        (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.enterText(
          find.byKey(const Key('email')), 'aang@mygarage.id');
      await tester.enterText(find.byKey(const Key('sandi')), 'rahasia123');
      await tester.tap(find.byKey(const Key('masuk')));
      await tester.pumpAndSettle();
      expect(find.text('Tambah Servis'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tambah')));
      await tester.pumpAndSettle();
      // Form harus terbuka (label kolom pertama terlihat)
      expect(find.text('Nama Perbaikan'), findsOneWidget);
    });
  });

  group('Unit test statusPengingat (K4 — ambang 3 bulan)', () {
    test('data terakhir >= 3 bulan → MERAH waktunya servis', () {
      final (merah, ket) =
          statusPengingat(DateTime(2026, 7, 12), DateTime(2026, 11, 2));
      expect(merah, isTrue);
      expect(ket, 'Terakhir: 12 Jul 2026 — sudah 3 bulan');
    });
    test('data terakhir < 3 bulan → HIJAU sudah servis', () {
      final (merah, ket) =
          statusPengingat(DateTime(2026, 10, 12), DateTime(2026, 11, 2));
      expect(merah, isFalse);
      expect(ket, 'Servis terakhir: 12 Okt 2026');
    });
    test('tidak ada data → MERAH belum ada catatan', () {
      final (merah, ket) = statusPengingat(null, DateTime(2026, 11, 2));
      expect(merah, isTrue);
      expect(ket, 'Belum ada catatan servis');
    });
  });

  group('Widget test — form Tambah Catatan Servis (frame Figma H3)', () {
    Future<void> bukaDanIsi(WidgetTester tester,
        {String jenis = '', String biaya = ''}) async {
      await tester.pumpWidget(const MaterialApp(home: _Harness()));
      await tester.tap(find.byKey(const Key('open-form')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('jenis')), jenis);
      await tester.enterText(find.byKey(const Key('biaya')), biaya);
    }

    testWidgets('K01 semua kosong → pesan jenis muncul', (tester) async {
      await bukaDanIsi(tester);
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Jenis perbaikan wajib diisi'), findsOneWidget);
      expect(find.text('HOME'), findsNothing); // masih di form
    });

    testWidgets('K02 jenis kosong, biaya terisi → pesan jenis', (tester) async {
      await bukaDanIsi(tester, biaya: '50000');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Jenis perbaikan wajib diisi'), findsOneWidget);
    });

    testWidgets('K03 jenis terisi, biaya kosong → pesan biaya (frame Figma)',
        (tester) async {
      await bukaDanIsi(tester, jenis: 'Ganti Oli');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Biaya wajib diisi'), findsOneWidget);
    });

    testWidgets('K04 biaya 0 → pesan biaya', (tester) async {
      await bukaDanIsi(tester, jenis: 'Ganti Oli', biaya: '0');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Biaya harus angka lebih dari 0'), findsOneWidget);
    });

    testWidgets('K05 biaya negatif → pesan biaya', (tester) async {
      await bukaDanIsi(tester, jenis: 'Ganti Oli', biaya: '-1000');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Biaya harus angka lebih dari 0'), findsOneWidget);
    });

    testWidgets('K06 biaya huruf → pesan biaya', (tester) async {
      await bukaDanIsi(tester, jenis: 'Ganti Oli', biaya: 'abc');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Biaya harus angka lebih dari 0'), findsOneWidget);
    });

    testWidgets('K07 biaya besar (900000) → tersimpan, tanpa plafon',
        (tester) async {
      await bukaDanIsi(tester, jenis: 'Ganti Aki', biaya: '900000');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Tersimpan: Ganti Aki'), findsOneWidget);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('K08 biaya 500000 → tersimpan dan kembali',
        (tester) async {
      await bukaDanIsi(tester, jenis: 'Ganti Oli', biaya: '500000');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Tersimpan: Ganti Oli'), findsOneWidget);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('K09 biaya 150000 → tersimpan', (tester) async {
      await bukaDanIsi(tester, jenis: 'Balancing Ban', biaya: '150000');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Tersimpan: Balancing Ban'), findsOneWidget);
    });

    testWidgets('K10 jenis dengan spasi saja → pesan jenis', (tester) async {
      await bukaDanIsi(tester, jenis: '   ', biaya: '50000');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(find.text('Jenis perbaikan wajib diisi'), findsOneWidget);
    });

    testWidgets('K11 Batal → kembali tanpa menyimpan', (tester) async {
      await bukaDanIsi(tester, jenis: 'Ganti Oli', biaya: '50000');
      await tester.tap(find.byKey(const Key('batal')));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      expect(find.byKey(const Key('saved')), findsNothing);
    });

    testWidgets('K12 mode Ubah: form terisi data lama, Simpan mengembalikan '
        'catatan yang diperbarui dengan id sama', (tester) async {
      final lama = CatatanServis(
          jenis: 'Ganti Oli Mesin',
          tanggal: DateTime(2026, 10, 12),
          biaya: 250000,
          id: 42);
      CatatanServis? hasil;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => FilledButton(
                key: const Key('open-edit'),
                onPressed: () async {
                  final r = await Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => HalamanTambahCatatan(edit: lama)),
                  );
                  if (r is CatatanServis) hasil = r;
                },
                child: const Text('Open edit'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.byKey(const Key('open-edit')));
      await tester.pumpAndSettle();
      // Data lama terisi di form
      expect(find.text('Ubah Catatan Servis'), findsOneWidget);
      final jenisField = tester.widget<TextField>(find.byKey(const Key('jenis')));
      final biayaField = tester.widget<TextField>(find.byKey(const Key('biaya')));
      expect(jenisField.controller!.text, 'Ganti Oli Mesin');
      expect(biayaField.controller!.text, '250000');
      // Ubah biaya lalu simpan
      await tester.enterText(find.byKey(const Key('biaya')), '300000');
      await tester.tap(find.byKey(const Key('simpan')));
      await tester.pumpAndSettle();
      expect(hasil, isNotNull);
      expect(hasil!.id, 42); // identitas catatan tetap
      expect(hasil!.biaya, 300000);
      expect(hasil!.jenis, 'Ganti Oli Mesin');
    });
  });
}
