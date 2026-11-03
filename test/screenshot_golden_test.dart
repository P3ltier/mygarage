import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygarage/main.dart';

/// Golden screenshot untuk README.
/// Jalan manual:  GOLDENS=1 flutter test --update-goldens test/screenshot_golden_test.dart
/// Di test biasa: dilewati (return awal) agar tidak bergantung mesin.
void main() {
  testWidgets('golden screenshots README', (tester) async {
    if (Platform.environment['GOLDENS'] != '1') return;

    // Satu FontLoader berisi semua varian — memuat per-berkas membuat
    // family Roboto tidak lengkap (teks tombol jadi kotak).
    final loader = FontLoader('Roboto');
    for (final f in [
      'roboto-thin.ttf',
      'roboto-light.ttf',
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
      'roboto-italic.ttf',
    ]) {
      final path = 'C:/dev/flutter/bin/cache/artifacts/material_fonts/$f';
      if (File(path).existsSync()) {
        final bytes = File(path).readAsBytesSync();
        loader.addFont(Future.value(bytes.buffer.asByteData()));
      }
    }
    await loader.load();

    final iconLoader = FontLoader('MaterialIcons');
    final icons = File(
        'C:/dev/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
    iconLoader.addFont(Future.value(icons.readAsBytesSync().buffer.asByteData()));
    await iconLoader.load();

    tester.view.physicalSize = const Size(412, 917);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/login.png'));

    // Login valid → Beranda (merah: seed 12 Jul 2026)
    await tester.enterText(
        find.byKey(const Key('email')), 'aang@mygarage.id');
    await tester.enterText(find.byKey(const Key('sandi')), 'rahasia123');
    await tester.tap(find.byKey(const Key('masuk')));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/beranda.png'));

    // Form Tambah Catatan Servis
    await tester.tap(find.byKey(const Key('tambah')));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/tambah.png'));
    await tester.tap(find.byKey(const Key('batal')));
    await tester.pumpAndSettle();

    // Riwayat Servis
    await tester.tap(find.text('Riwayat Servis'));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/riwayat.png'));
  });
}
