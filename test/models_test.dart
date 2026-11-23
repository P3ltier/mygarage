import 'package:flutter_test/flutter_test.dart';
import 'package:mygarage/models.dart';

void main() {
  test('model 3 collection: toMap/fromMap bolak-balik utuh', () {
    final p = Pengguna(
        idPengguna: 'uid1', namaLengkap: 'Aang', email: 'a@b.c');
    expect(Pengguna.fromMap(p.toMap()).toMap(), p.toMap());
    expect(Pengguna.fromMap(p.toMap()).peran, 'pemilik');

    final k = daftarKendaraanAwal.first;
    expect(Kendaraan.fromMap(k.toMap()).toMap(), k.toMap());

    final c = CatatanServis(
        jenis: 'Ganti Oli',
        tanggal: DateTime(2026, 7, 12),
        kilometer: 45000,
        biaya: 250000,
        id: 7);
    final c2 = CatatanServis.fromMap(c.toMap());
    expect(c2.id, 7);
    expect(c2.jenis, 'Ganti Oli');
    expect(c2.tanggal, DateTime(2026, 7, 12));
    expect(c2.kilometer, 45000);
    expect(c2.biaya, 250000);
  });
}
