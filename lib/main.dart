import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

// ============================================================
// Style guide — dari Figma "2201650002 - MyGarage - Wireframe"
// ============================================================
const Color kPrimer = Color(0xFF0D47A1);
const Color kTeksUtama = Color(0xFF212121);
const Color kTeksSekunder = Color(0xFF616161);
const Color kLatar = Color(0xFFFFFFFF);
const Color kCardBg = Color(0xFFF5F5F5);
const Color kGaris = Color(0xFFE0E0E0);
const Color kHijau = Color(0xFF2E7D32);
const Color kOranye = Color(0xFFEF6C00);
const Color kMerah = Color(0xFFC62828);
const Color kNonaktif = Color(0xFFBDBDBD);
const double kRadius = 10;
const double kTinggiTombol = 48;
const double kJarakS = 8;
const double kJarakM = 16;
const double kJarakL = 24;

// ============================================================
// Model & format
// ============================================================
class CatatanServis {
  CatatanServis({
    required this.jenis,
    required this.tanggal,
    this.kilometer,
    required this.biaya,
    int? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch;
  final int id;
  final String jenis;
  final DateTime tanggal;
  final int? kilometer;
  final int biaya;
}

const List<String> _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String formatTanggal(DateTime d) => '${d.day} ${_bulan[d.month - 1]} ${d.year}';

String _titikRibuan(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

String formatRupiah(int n) => 'Rp ${_titikRibuan(n)}';

String formatKilometer(int n) => _titikRibuan(n);

/// Aturan validasi catatan servis (urutan sesuai form):
/// jenis wajib → biaya wajib → angka > 0.
/// Biaya servis tidak diberi plafon — nilai uang nyata tidak dibatasi.
String? periksaCatatan(String jenis, String biayaRaw) {
  final jenisBersih = jenis.trim();
  if (jenisBersih.isEmpty) return 'Jenis perbaikan wajib diisi';
  final biayaStr = biayaRaw.trim().replaceAll('.', '');
  if (biayaStr.isEmpty) return 'Biaya wajib diisi';
  final biaya = double.tryParse(biayaStr);
  if (biaya == null || biaya <= 0) return 'Biaya harus angka lebih dari 0';
  return null;
}

/// K4 — status pengingat: MERAH bila >= 3 bulan sejak servis terakhir.
(bool waktunyaServis, String keterangan) statusPengingat(
    DateTime? terakhir, DateTime hariIni) {
  if (terakhir == null) return (true, 'Belum ada catatan servis');
  int bulan =
      (hariIni.year - terakhir.year) * 12 + hariIni.month - terakhir.month;
  if (hariIni.day < terakhir.day) bulan -= 1;
  if (bulan >= 3) {
    return (true,
        'Terakhir: ${formatTanggal(terakhir)} — sudah $bulan bulan');
  }
  return (false, 'Servis terakhir: ${formatTanggal(terakhir)}');
}

// ============================================================
// Validasi login + terjemahan kode error Firebase Auth
// ============================================================
String? validasiEmail(String? nilai) {
  final email = nilai?.trim() ?? '';
  if (email.isEmpty) return 'Email wajib diisi';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Format email belum benar';
  }
  return null;
}

String? validasiPassword(String? nilai) {
  if (nilai == null || nilai.isEmpty) return 'Password wajib diisi';
  if (nilai.length < 6) return 'Password minimal 6 karakter';
  return null;
}

String pesanKesalahanAuth(String kode) {
  switch (kode) {
    // Disamakan agar orang lain tidak bisa menebak email mana yang terdaftar.
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'Email atau password salah';
    case 'invalid-email':
      return 'Format email belum benar';
    case 'email-already-in-use':
      return 'Email sudah terdaftar. Silakan masuk.';
    case 'weak-password':
      return 'Password terlalu lemah, minimal 6 karakter';
    case 'too-many-requests':
      return 'Terlalu banyak percobaan. Coba lagi nanti.';
    case 'network-request-failed':
      return 'Tidak dapat terhubung. Periksa koneksi internet.';
    case 'operation-not-allowed':
      return 'Login email/password belum diaktifkan di Firebase Console';
    default:
      return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

// ============================================================
// Komponen reusable (dari component Figma)
// ============================================================

/// App Bar Figma: navy, teks putih; varian dengan tombol kembali (←).
class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MyAppBar(
      {super.key, required this.judul, this.tampilkanKembali = false, this.actions});
  final String judul;
  final bool tampilkanKembali;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: kPrimer,
      foregroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: tampilkanKembali
          ? IconButton(
              key: const Key('kembali'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.maybePop(context),
            )
          : null,
      centerTitle: false,
      actions: actions,
      title: Text(judul,
          style: const TextStyle(fontFamily: 'Roboto', 
              fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

/// Input Field Figma: LABEL 14 Semi Bold DI ATAS kolom; hint di dalam;
/// keadaan galat = border merah 2 px + pesan merah 12 px di bawah kolom.
class InputField extends StatelessWidget {
  const InputField({
    super.key,
    this.fieldKey,
    required this.controller,
    required this.label,
    this.hint,
    this.prefix,
    this.suffixIcon,
    this.keyboardType,
    this.pesanGalat,
    this.readOnly = false,
    this.onTap,
    this.obscure = false,
    this.trailing,
    this.validator,
  });

  final Key? fieldKey;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? prefix;
  final Icon? suffixIcon;
  final TextInputType? keyboardType;
  final String? pesanGalat;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool obscure;
  final Widget? trailing;
  final FormFieldValidator<String>? validator;

  OutlineInputBorder _border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: c, width: w),
      );

  @override
  Widget build(BuildContext context) {
    final bool galat = pesanGalat != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontFamily: 'Roboto', 
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTeksUtama)),
            ),
            if (trailing case final Widget t) t,
          ],
        ),
        const SizedBox(height: kJarakS),
        TextFormField(
          key: fieldKey,
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14, color: kTeksUtama),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: kTeksSekunder),
            prefixText: prefix,
            prefixStyle: const TextStyle(fontSize: 14, color: kTeksUtama),
            errorStyle: const TextStyle(fontSize: 12, color: kMerah),
            filled: true,
            fillColor: kLatar,
            suffixIcon: suffixIcon,
            enabledBorder: _border(galat ? kMerah : kGaris, galat ? 2 : 1),
            focusedBorder: _border(galat ? kMerah : kPrimer, 2),
            errorBorder: _border(kMerah, 2),
            focusedErrorBorder: _border(kMerah, 2),
          ),
        ),
        if (galat)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              pesanGalat!,
              key: const Key('pesan-galat'),
              style: const TextStyle(fontSize: 12, color: kMerah),
            ),
          ),
      ],
    );
  }
}

/// Tombol Utama: filled #0D47A1, teks putih 14 Semi Bold, radius 10, tinggi 48.
class TombolUtama extends StatelessWidget {
  const TombolUtama({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed; // null = tombol nonaktif

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kTinggiTombol,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimer,
          foregroundColor: Colors.white,
          textStyle:
              const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// Tombol Sekunder: outline 2 px #0D47A1, teks #0D47A1, tinggi 48.
class TombolSekunder extends StatelessWidget {
  const TombolSekunder(
      {super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kTinggiTombol,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimer,
          side: const BorderSide(color: kPrimer, width: 2),
          textStyle:
              const TextStyle(fontFamily: 'Roboto', fontSize: 14, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// Bottom Nav Figma: Beranda | Riwayat Servis; aktif biru, tidak aktif abu.
class BottomNavMyGarage extends StatelessWidget {
  const BottomNavMyGarage(
      {super.key, required this.tab, required this.gantiTab});
  final int tab;
  final ValueChanged<int> gantiTab;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: tab,
      onTap: gantiTab,
      backgroundColor: kLatar,
      selectedItemColor: kPrimer,
      unselectedItemColor: kTeksSekunder,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), label: 'Beranda'),
        BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined), label: 'Riwayat Servis'),
      ],
    );
  }
}

/// Kartu Riwayat Figma: nama perbaikan + tanggal kiri, biaya kanan, tombol Ubah.
class KartuRiwayat extends StatelessWidget {
  const KartuRiwayat({super.key, required this.catatan, required this.onUbah});
  final CatatanServis catatan;
  final VoidCallback onUbah;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(catatan.jenis,
                        style: const TextStyle(fontFamily: 'Roboto', 
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kTeksUtama)),
                    const SizedBox(height: 2),
                    Text(formatTanggal(catatan.tanggal),
                        style: const TextStyle(
                            fontSize: 12, color: kTeksSekunder)),
                  ],
                ),
              ),
              Text(formatRupiah(catatan.biaya),
                  style: const TextStyle(fontFamily: 'Roboto', 
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTeksUtama)),
            ],
          ),
          const SizedBox(height: kJarakS),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimer,
                side: const BorderSide(color: kPrimer, width: 2),
                textStyle: const TextStyle(fontFamily: 'Roboto', 
                    fontSize: 14, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadius)),
              ),
              onPressed: onUbah,
              child: const Text('Ubah'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Data awal (data simulasi, sesuai wireframe)
// ============================================================
// Demo indikator MERAH: SEMUA tanggal harus >= 3 bulan dari hari ini,
// karena indikator membaca tanggal servis yang PALING BARU.
final List<CatatanServis> seedDefault = [
  CatatanServis(
      jenis: 'Ganti Oli Mesin',
      tanggal: DateTime(2026, 7, 12), // paling baru: sudah 3 bulan
      biaya: 250000),
  CatatanServis(
      jenis: 'Balancing Ban',
      tanggal: DateTime(2026, 6, 20),
      biaya: 100000),
  CatatanServis(
      jenis: 'Ganti Aki', tanggal: DateTime(2026, 5, 5), biaya: 900000),
];

// ============================================================
// MyApp — pemuatan state paling luar (login → shell 2 tab)
// ============================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key, this.seed, this.sudahMasuk});
  final List<CatatanServis>? seed;
  /// Hanya untuk test: lewati Firebase (true = Beranda, false = Login).
  final bool? sudahMasuk;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // GlobalKey: context State ini berada DI ATAS MaterialApp, jadi Navigator
  // dan ScaffoldMessenger harus diakses lewat key, bukan context.
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  late final List<CatatanServis> catatan =
      List.of(widget.seed ?? seedDefault);
  int _tab = 0;

  void _keluar() {
    _tab = 0;
    FirebaseAuth.instance.signOut();
  }

  void _bukaForm({CatatanServis? edit}) async {
    final hasil = await _navigatorKey.currentState!.push(
      MaterialPageRoute(
          builder: (_) => HalamanTambahCatatan(edit: edit)),
    );
    if (!mounted) return; // widget bisa sudah tidak ada setelah await
    if (hasil is CatatanServis) {
      setState(() {
        if (edit == null) {
          catatan.add(hasil);
        } else {
          // Alur Edit: ganti catatan lama dengan hasil ubahan (posisi tetap).
          final i = catatan.indexWhere((c) => c.id == hasil.id);
          if (i >= 0) catatan[i] = hasil;
        }
        _tab = 1; // prototipe Figma: Simpan → Riwayat Servis
      });
      // Pesan status wajib UTS: SnackBar setelah Simpan
      if (!mounted) return; // widget bisa sudah tidak ada setelah await
      _scaffoldKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(edit == null
              ? 'Catatan servis disimpan'
              : 'Catatan servis diperbarui'),
          backgroundColor: kHijau,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyGarage',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimer),
        scaffoldBackgroundColor: kLatar,
        useMaterial3: true,
      ),
      home: switch (widget.sudahMasuk) {
        true => _buildShell(),
        false => const HalamanLogin(),
        null => _cekStatusLogin(),
      },
    );
  }

  /// Cek status login: halaman mengikuti authStateChanges(), tanpa Navigator.
  Widget _cekStatusLogin() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.hasData ? _buildShell() : const HalamanLogin();
      },
    );
  }

  Widget _buildShell() {
    final konten = _tab == 0
        ? KontenBeranda(catatan: catatan, onTambah: () => _bukaForm())
        : KontenRiwayat(
            catatan: catatan,
            onTambah: () => _bukaForm(),
            onUbah: (c) => _bukaForm(edit: c),
          );
    return LayoutBuilder(builder: (context, kotak) {
      final bool mobile = kotak.maxWidth < 900;
      if (mobile) {
        return Scaffold(
          appBar: MyAppBar(
            judul: _tab == 0 ? 'MyGarage' : 'Riwayat Servis',
            actions: [
              IconButton(
                key: const Key('keluar'),
                tooltip: 'Keluar',
                icon: const Icon(Icons.logout),
                onPressed: _keluar,
              ),
            ],
          ),
          body: konten,
          bottomNavigationBar:
              BottomNavMyGarage(tab: _tab, gantiTab: (t) => setState(() => _tab = t)),
        );
      }
      // Web: sidebar kiri 240 px + judul area utama (frame web Figma)
      return Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 240,
              decoration: const BoxDecoration(
                color: kLatar,
                border: Border(right: BorderSide(color: kGaris)),
              ),
              padding: const EdgeInsets.all(kJarakM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MyGarage',
                      style: TextStyle(fontFamily: 'Roboto', 
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kPrimer)),
                  const SizedBox(height: kJarakL),
                  _menuWeb(Icons.home_outlined, 'Beranda', _tab == 0,
                      () => setState(() => _tab = 0)),
                  _menuWeb(Icons.receipt_long_outlined, 'Riwayat Servis',
                      _tab == 1, () => setState(() => _tab = 1)),
                  _menuWeb(Icons.person_outline, 'Profil', false, null),
                  const Spacer(),
                  _menuWeb(Icons.logout, 'Keluar', false, _keluar),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(kJarakL),
                    child: Text(_tab == 0 ? 'Beranda' : 'Riwayat Servis',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: kTeksUtama)),
                  ),
                  Expanded(child: konten),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _menuWeb(IconData ikon, String label, bool aktif, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kJarakS),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: aktif ? kCardBg : null,
            borderRadius: BorderRadius.circular(kRadius),
          ),
          child: Row(
            children: [
              Icon(ikon,
                  size: 20,
                  color: aktif ? kPrimer : kTeksSekunder),
              const SizedBox(width: kJarakS),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: aktif ? FontWeight.w600 : FontWeight.w400,
                      color: aktif ? kPrimer : kTeksSekunder)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// H1 — LOGIN
// ============================================================
class HalamanLogin extends StatefulWidget {
  const HalamanLogin({super.key});

  @override
  State<HalamanLogin> createState() => _HalamanLoginState();
}

/// Satu halaman, dua mode (Masuk/Daftar). Berhasil masuk tidak memanggil
/// Navigator: StreamBuilder di MyApp yang mengganti halaman.
class _HalamanLoginState extends State<HalamanLogin> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _sandi = TextEditingController();
  final _ulangi = TextEditingController();
  bool _modeDaftar = false;
  bool _sedangProses = false;

  @override
  void dispose() {
    _email.dispose();
    _sandi.dispose();
    _ulangi.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    if (!_formKey.currentState!.validate()) return;
    final pesan = ScaffoldMessenger.of(context);
    pesan.hideCurrentSnackBar();
    setState(() => _sedangProses = true);
    final email = _email.text.trim();
    final password = _sandi.text;
    try {
      if (_modeDaftar) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email, password: password);
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      pesan.showSnackBar(SnackBar(
        content: Text(pesanKesalahanAuth(e.code)),
        backgroundColor: kMerah,
      ));
      if (mounted) setState(() => _sedangProses = false);
    }
  }

  /// Lupa kata sandi: kirim tautan reset ke email di kolom Email.
  Future<void> _lupaSandi() async {
    final pesan = ScaffoldMessenger.of(context);
    pesan.hideCurrentSnackBar();
    final email = _email.text.trim();
    final galat = validasiEmail(email);
    if (galat != null) {
      pesan.showSnackBar(SnackBar(
          content: Text('$galat untuk reset kata sandi'),
          backgroundColor: kMerah));
      return;
    }
    setState(() => _sedangProses = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      // Pesan netral: tidak membocorkan apakah email terdaftar.
      pesan.showSnackBar(SnackBar(
          content: Text(
              'Jika $email terdaftar, tautan reset kata sandi sudah dikirim. '
              'Cek kotak masuk atau folder spam.'),
          backgroundColor: kHijau));
    } on FirebaseAuthException catch (e) {
      pesan.showSnackBar(SnackBar(
          content: Text(pesanKesalahanAuth(e.code)), backgroundColor: kMerah));
    }
    if (mounted) setState(() => _sedangProses = false);
  }

  void _gantiMode() {
    _formKey.currentState?.reset();
    _ulangi.clear();
    setState(() => _modeDaftar = !_modeDaftar);
  }

  Widget _isi(double lebar) {
    return Container(
      width: lebar,
      padding: const EdgeInsets.all(kJarakM),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_modeDaftar ? 'Buat Akun' : 'Selamat Datang',
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: kTeksUtama)),
            const SizedBox(height: 4),
            Text(
                _modeDaftar
                    ? 'Daftar untuk mulai mencatat servis mobil Anda.'
                    : 'Masuk untuk mengelola catatan servis mobil Anda.',
                style: const TextStyle(fontSize: 14, color: kTeksSekunder)),
            const SizedBox(height: kJarakL),
            InputField(
              fieldKey: const Key('email'),
              controller: _email,
              label: 'Email',
              hint: 'nama@email.com',
              keyboardType: TextInputType.emailAddress,
              validator: validasiEmail,
            ),
            const SizedBox(height: kJarakM),
            InputField(
              fieldKey: const Key('sandi'),
              controller: _sandi,
              label: 'Kata Sandi',
              hint: 'Masukkan kata sandi',
              obscure: true,
              validator: validasiPassword,
              trailing: _modeDaftar
                  ? null
                  : TextButton(
                      key: const Key('lupa'),
                      onPressed: _sedangProses ? null : _lupaSandi,
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(48, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Lupa kata sandi?',
                          style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kPrimer)),
                    ),
            ),
            if (_modeDaftar) ...[
              const SizedBox(height: kJarakM),
              InputField(
                fieldKey: const Key('ulangi'),
                controller: _ulangi,
                label: 'Ulangi Kata Sandi',
                hint: 'Ketik ulang kata sandi',
                obscure: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ulangi password';
                  if (v != _sandi.text) return 'Password tidak sama';
                  return null;
                },
              ),
            ],
            const SizedBox(height: kJarakL),
            if (_sedangProses)
              const SizedBox(
                  height: kTinggiTombol,
                  child: Center(child: CircularProgressIndicator()))
            else
              TombolUtama(
                  key: const Key('masuk'),
                  label: _modeDaftar ? 'Daftar' : 'Masuk',
                  onPressed: _kirim),
            const SizedBox(height: kJarakM),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_modeDaftar ? 'Sudah punya akun? ' : 'Belum punya akun? ',
                    style: const TextStyle(fontSize: 14, color: kTeksSekunder)),
                TextButton(
                  key: const Key('ganti-mode'),
                  onPressed: _sedangProses ? null : _gantiMode,
                  child: Text(_modeDaftar ? 'Masuk' : 'Daftar sekarang',
                      style: const TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kPrimer)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, kotak) {
      if (kotak.maxWidth >= 900) {
        // Web: tanpa sidebar (pre-auth), kartu 480 px di tengah
        return Scaffold(
          backgroundColor: kCardBg,
          body: Center(
            child: Card(
              elevation: 0,
              color: kLatar,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadius),
                  side: const BorderSide(color: kGaris)),
              child: Padding(
                padding: const EdgeInsets.all(kJarakL),
                child: _isi(400),
              ),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: kLatar,
        appBar: const MyAppBar(judul: 'MyGarage'),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(kJarakM),
            child: _isi(double.infinity),
          ),
        ),
      );
    });
  }
}

// ============================================================
// H2 — BERANDA (indikator merah/hijau)
// ============================================================
class KontenBeranda extends StatelessWidget {
  const KontenBeranda(
      {super.key, required this.catatan, required this.onTambah});
  final List<CatatanServis> catatan;
  final VoidCallback onTambah;

  @override
  Widget build(BuildContext context) {
    final DateTime? terakhir = catatan.isEmpty
        ? null
        : catatan.map((c) => c.tanggal).reduce((a, b) => a.isAfter(b) ? a : b);
    final (waktunya, ket) = statusPengingat(terakhir, DateTime.now());
    final bool web = MediaQuery.of(context).size.width >= 900;

    final kartuStatus = Container(
      padding: const EdgeInsets.all(kJarakM),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: waktunya ? kMerah : kHijau,
              borderRadius: BorderRadius.circular(kRadius),
            ),
            alignment: Alignment.center,
            child: Text(
              waktunya ? 'Waktunya Servis' : 'Sudah Servis',
              style: const TextStyle(fontFamily: 'Roboto', 
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: kJarakS),
          Text(ket,
              style: const TextStyle(fontSize: 12, color: kTeksSekunder)),
        ],
      ),
    );

    if (web) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(kJarakL),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    kartuStatus,
                    const SizedBox(height: kJarakM),
                    TombolUtama(
                        key: const Key('tambah'),
                        label: 'Tambah Servis',
                        onPressed: onTambah),
                  ],
                ),
              ),
              const SizedBox(width: kJarakL),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(kJarakM),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(kRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Servis Terbaru',
                          style: TextStyle(fontFamily: 'Roboto', 
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: kTeksUtama)),
                      const SizedBox(height: kJarakS),
                      for (final c in catatan.take(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: kJarakS),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(c.jenis,
                                    style: const TextStyle(
                                        fontSize: 14, color: kTeksUtama)),
                              ),
                              Text(formatTanggal(c.tanggal),
                                  style: const TextStyle(
                                      fontSize: 12, color: kTeksSekunder)),
                              const SizedBox(width: kJarakM),
                              Text(formatRupiah(c.biaya),
                                  style: const TextStyle(fontFamily: 'Roboto', 
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: kTeksUtama)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(kJarakM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            kartuStatus,
            const SizedBox(height: kJarakM),
            TombolUtama(
                key: const Key('tambah'), label: 'Tambah Servis', onPressed: onTambah),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// H4 — RIWAYAT SERVIS (+ keadaan kosong)
// ============================================================
class KontenRiwayat extends StatelessWidget {
  const KontenRiwayat(
      {super.key,
      required this.catatan,
      required this.onTambah,
      required this.onUbah});
  final List<CatatanServis> catatan;
  final VoidCallback onTambah;
  final ValueChanged<CatatanServis> onUbah;

  @override
  Widget build(BuildContext context) {
    if (catatan.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car_outlined,
                size: 48, color: kTeksSekunder),
            const SizedBox(height: kJarakM),
            const Text('Belum ada catatan servis',
                style: TextStyle(fontFamily: 'Roboto', 
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: kTeksUtama)),
            const SizedBox(height: 4),
            const Text('Catat servis pertamamu di sini',
                style: TextStyle(fontSize: 12, color: kTeksSekunder)),
            const SizedBox(height: kJarakL),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kJarakM),
              child: TombolUtama(
                  key: const Key('tambah'),
                  label: 'Tambah Servis',
                  onPressed: onTambah),
            ),
          ],
        ),
      );
    }

    final urutTerbaru = [...catatan]
      ..sort((a, b) => b.tanggal.compareTo(a.tanggal));

    final bool web = MediaQuery.of(context).size.width >= 900;
    if (web) {
      // Web: kartu menjadi tabel (header #F5F5F5), data sama dengan mobile
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(kJarakL),
          child: Table(
            border: TableBorder.all(color: kGaris),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            children: [
              const TableRow(
                decoration: BoxDecoration(color: kCardBg),
                children: [
                  _SelHeader('Tanggal'),
                  _SelHeader('Nama Perbaikan'),
                  _SelHeader('Biaya'),
                  _SelHeader('Aksi'),
                ],
              ),
              for (final c in urutTerbaru)
                TableRow(children: [
                  _SelIsi(formatTanggal(c.tanggal)),
                  _SelIsi(c.jenis),
                  _SelIsi(formatRupiah(c.biaya)),
                  Padding(
                    padding: const EdgeInsets.all(kJarakS),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 32,
                        width: 96,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimer,
                            side: const BorderSide(color: kPrimer, width: 2),
                            textStyle: const TextStyle(fontSize: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(kRadius)),
                          ),
                          onPressed: () => onUbah(c),
                          child: const Text('Ubah'),
                        ),
                      ),
                    ),
                  ),
                ]),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(kJarakM),
      itemCount: urutTerbaru.length,
      separatorBuilder: (_, _) => const SizedBox(height: kJarakM),
      itemBuilder: (_, i) =>
          KartuRiwayat(catatan: urutTerbaru[i], onUbah: () => onUbah(urutTerbaru[i])),
    );
  }
}

class _SelHeader extends StatelessWidget {
  const _SelHeader(this.teks);
  final String teks;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(kJarakS),
        child: Text(teks,
            style: const TextStyle(fontFamily: 'Roboto', 
                fontSize: 14, fontWeight: FontWeight.w600, color: kTeksUtama)),
      );
}

class _SelIsi extends StatelessWidget {
  const _SelIsi(this.teks);
  final String teks;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(kJarakS),
        child: Text(teks,
            style: const TextStyle(fontSize: 14, color: kTeksUtama)),
      );
}

// ============================================================
// H3 — TAMBAH CATATAN SERVIS (frame Figma + varian kesalahan)
// ============================================================
class HalamanTambahCatatan extends StatefulWidget {
  const HalamanTambahCatatan({super.key, this.edit});
  final CatatanServis? edit;

  @override
  State<HalamanTambahCatatan> createState() => _HalamanTambahCatatanState();
}

class _HalamanTambahCatatanState extends State<HalamanTambahCatatan> {
  final _jenis = TextEditingController();
  final _kilometer = TextEditingController();
  final _biaya = TextEditingController();
  DateTime? _tanggal;
  String? _galatJenis;
  String? _galatBiaya;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      // Mode "Ubah Catatan": memakai ulang frame yang sama dengan data terisi.
      _jenis.text = e.jenis;
      _kilometer.text = e.kilometer == null ? '' : formatKilometer(e.kilometer!);
      _biaya.text = e.biaya.toString();
      _tanggal = e.tanggal;
    }
  }

  @override
  void dispose() {
    _jenis.dispose();
    _kilometer.dispose();
    _biaya.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final kini = DateTime.now();
    final pilih = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? kini,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pilih != null) setState(() => _tanggal = pilih);
  }

  void _simpan() {
    setState(() {
      final error = periksaCatatan(_jenis.text, _biaya.text);
      _galatJenis = error == 'Jenis perbaikan wajib diisi' ? error : null;
      _galatBiaya = (error == 'Biaya wajib diisi' ||
              error == 'Biaya harus angka lebih dari 0')
          ? error
          : null;
      if (error != null) return; // tetap di form, persis frame kesalahan
      final biaya = int.parse(_biaya.text.trim().replaceAll('.', ''));
      final catatan = CatatanServis(
        jenis: _jenis.text.trim(),
        tanggal: _tanggal ?? DateTime.now(),
        kilometer: int.tryParse(_kilometer.text.trim().replaceAll('.', '')),
        biaya: biaya,
        id: widget.edit?.id, // mode ubah: pertahankan identitas catatan
      );
      Navigator.pop(context, catatan);
    });
  }

  void _batal() => Navigator.pop(context); // kembali tanpa menyimpan

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppBar(
        judul: widget.edit == null
            ? 'Tambah Catatan Servis'
            : 'Ubah Catatan Servis',
        tampilkanKembali: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(kJarakM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InputField(
                fieldKey: const Key('jenis'),
                controller: _jenis,
                label: 'Nama Perbaikan',
                hint: 'cth: Ganti oli mesin',
                pesanGalat: _galatJenis,
              ),
              const SizedBox(height: kJarakM),
              InputField(
                fieldKey: const Key('tanggal'),
                controller: TextEditingController(
                    text: _tanggal == null ? '' : formatTanggal(_tanggal!)),
                label: 'Tanggal',
                hint: 'Pilih tanggal',
                readOnly: true,
                onTap: _pilihTanggal,
                suffixIcon:
                    const Icon(Icons.calendar_today, size: 20, color: kTeksSekunder),
              ),
              const SizedBox(height: kJarakM),
              InputField(
                fieldKey: const Key('kilometer'),
                controller: _kilometer,
                label: 'Kilometer',
                hint: '78.678',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: kJarakM),
              InputField(
                fieldKey: const Key('biaya'),
                controller: _biaya,
                label: 'Biaya',
                prefix: 'Rp ',
                keyboardType: TextInputType.number,
                pesanGalat: _galatBiaya,
              ),
              const SizedBox(height: kJarakL),
              Row(
                children: [
                  Expanded(
                    child: TombolUtama(
                        key: const Key('simpan'), label: 'Simpan', onPressed: _simpan),
                  ),
                  const SizedBox(width: kJarakM),
                  Expanded(
                    child: TombolSekunder(
                        key: const Key('batal'), label: 'Batal', onPressed: _batal),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
