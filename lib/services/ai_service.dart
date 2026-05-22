import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'task_priority_service.dart';

class AIService {
  static const String _apiKey = 'AIzaSyBtHD-Q2tobjR6BjrQ4SkNoyUnHopQ_r_4';

  static Future<String> getTaskSummary(List<String> tasks) async {
    if (tasks.isEmpty) return 'Belum ada tugas untuk dirangkum.';
    if (_apiKey.isEmpty) return 'API Key belum dikonfigurasi.';
    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      final prompt =
          'Rangkum tugas-tugas berikut dalam Bahasa Indonesia yang santai dan bersih '
          '(tanpa format markdown yang berlebihan) dan berikan satu tips produktivitas singkat: '
          '${tasks.join(', ')}';
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Gagal menghasilkan rangkuman.';
    } catch (e) {
      return 'Terjadi kesalahan saat menghubungi AI: $e';
    }
  }

  static Future<TaskPriorityResult> analyzePriority({
    required String title,
    required String description,
    required String category,
    DateTime? deadline,
  }) async {
    if (_apiKey.isEmpty) {
      return TaskPriorityService.analyze(
          title: title, description: description, category: category, deadline: deadline);
    }
    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
      final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      final deadlineStr = deadline != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(deadline)
          : 'Tidak ada deadline';
      final prompt =
          'Kamu adalah sistem analisis prioritas tugas akademik. Waktu sekarang: $now. '
          'Judul: "$title". Deskripsi: "${description.isEmpty ? "Tidak ada" : description}". '
          'Kategori: "$category". Deadline: "$deadlineStr". '
          '\n\n'
          'ATURAN PENILAIAN SKOR (0-100):\n'
          '1. DEADLINE (bobot terbesar):\n'
          '   - Tidak ada deadline: +10\n'
          '   - Lebih dari 2 minggu: +8\n'
          '   - 8-14 hari lagi: +18\n'
          '   - 4-7 hari lagi: +30\n'
          '   - 2-3 hari lagi: +45\n'
          '   - Besok atau dalam 24 jam: +55\n'
          '\n'
          '2. KATEGORI (bobot tambahan):\n'
          '   - Ujian/Kuis: +22\n'
          '   - Presentasi: +20\n'
          '   - Revisi/Laporan: +18\n'
          '   - Rapat/Kegiatan: +15\n'
          '   - Tugas Kuliah: +14\n'
          '   - Administrasi: +12\n'
          '   - Umum: +10\n'
          '   - Pribadi: +8\n'
          '\n'
          '3. KEYWORD di judul/deskripsi (maks +20):\n'
          '   - Kata "darurat", "hari ini", "skripsi", "sidang", "ujian", "submit": tambah skor\n'
          '\n'
          '4. KOMPLEKSITAS deskripsi (maks +8):\n'
          '   - Deskripsi >120 karakter: +8\n'
          '   - 60-120 karakter: +5\n'
          '   - 20-60 karakter: +3\n'
          '\n'
          'LABEL PRIORITAS:\n'
          '- Skor 75-100 = "Tinggi" (deadline sangat dekat ATAU kategori kritis dengan deadline <3 hari)\n'
          '- Skor 45-74 = "Sedang" (deadline 3-7 hari, atau kategori penting dengan deadline menengah)\n'
          '- Skor 0-44 = "Rendah" (deadline jauh, tidak ada deadline, atau kategori ringan)\n'
          '\n'
          'CONTOH:\n'
          '- "Presentasi Skripsi" deadline besok → ~75-85 (Tinggi)\n'
          '- "Presentasi TPM" deadline 4 hari lagi → ~50-55 (Sedang)\n'
          '- "Beli cemilan" tanpa deadline, kategori Pribadi → ~18-25 (Rendah)\n'
          '\n'
          'Hitung skor berdasarkan SEMUA faktor di atas, lalu balas HANYA dengan JSON:\n'
          '{"score": <0-100>, "label": "<Tinggi|Sedang|Rendah>"}';
      final response = await model.generateContent([Content.text(prompt)]);
      final match = RegExp(r'\{[^}]+\}').firstMatch(response.text ?? '');
      if (match != null) {
        final decoded = json.decode(match.group(0)!);
        final score = (decoded['score'] as num).toInt().clamp(0, 100);
        final label = decoded['label']?.toString() ?? 'Rendah';
        return TaskPriorityResult(score: score, label: label);
      }
    } catch (e) {
      debugPrint('AI Priority fallback ke rule-based: $e');
    }
    return TaskPriorityService.analyze(
        title: title, description: description, category: category, deadline: deadline);
  }

  /// [previousMessages] — daftar pesan sebelumnya dari chat yang tersimpan.
  /// Format tiap item: {'text': String, 'isUser': bool}
  /// Item pertama (greeting awal) dilewati karena sudah ada di history Gemini.
  static ChatSession? startChat(
    List<String> tasks, {
    String? userLocation,
    List<Map<String, dynamic>> previousMessages = const [],
  }) {
    if (_apiKey.isEmpty) return null;
    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

    String prompt =
        'Kamu adalah asisten produktivitas di aplikasi RemindMe+. Berbicaralah dalam bahasa '
        'Indonesia yang ramah, santai, dan membantu. Berikut adalah daftar tugas penggunaku '
        'saat ini: ${tasks.isEmpty ? "Belum ada tugas." : tasks.join(', ')}. '
        'Setiap tugas bisa memuat kategori, label prioritas, skor prioritas, dan deadline. '
        'Perlakukan prioritas tinggi sebagai tugas yang lebih mendesak, lalu gunakan itu '
        'saat memberi saran urutan pengerjaan. Jawab singkat, solutif, dan hindari penggunaan '
        'format Markdown yang berlebihan seperti simbol pagar (#) atau daftar yang terlalu '
        'panjang. Gunakan gaya bahasa manusia yang normal dan bersih.';

    prompt +=
        '\n\nJika pengguna meminta dibuatkan jadwal, reminder, atau tugas baru, berikan '
        'jawaban singkat yang manusiawi lalu akhiri dengan blok JSON valid di dalam fenced '
        'code block ```json. JSON itu harus punya format persis seperti ini: '
        '{"title":"...", "description":"...", "date":"YYYY-MM-DD", "time":"HH:mm", '
        '"category":"Tugas Kuliah", "location":"..."}. '
        'Field "location" boleh dikosongkan jika pengguna tidak menyebut tempat. '
        'Gunakan hanya salah satu kategori berikut: Tugas Kuliah, Ujian/Kuis, Presentasi, '
        'Revisi/Laporan, Rapat/Kegiatan, Pribadi, Administrasi, Umum. '
        'Jika informasi tanggal atau jam belum cukup jelas, jangan buat JSON dan minta '
        'klarifikasi singkat.';

    if (userLocation != null && userLocation.isNotEmpty) {
      prompt +=
          '\n\nINFO LOKASI: Lokasi pengguna saat ini adalah $userLocation. Jika pengguna '
          'menyebutkan suatu tempat, berikan panduan rute atau saran tempat terdekat. '
          'Berikan tautan Google Maps: '
          'https://www.google.com/maps/search/?api=1&query=[NAMA+TEMPAT].';
    }

    // History awal: system prompt + greeting
    final history = <Content>[
      Content.text(prompt),
      Content.model([
        TextPart(
          'Siap! Aku siap membantumu mengelola tugas-tugas tersebut dan '
          'siap membantu mencari lokasi terdekat.',
        )
      ]),
    ];

    // Restore konteks percakapan sebelumnya ke Gemini session.
    // Skip item pertama (index 0) karena itu greeting yang sudah ada di history awal.
    for (final msg in previousMessages) {
      final text = (msg['text'] as String?) ?? '';
      final isUser = (msg['isUser'] as bool?) ?? true;
      if (text.trim().isEmpty) continue;
      if (isUser) {
        history.add(Content.text(text));
      } else {
        history.add(Content.model([TextPart(text)]));
      }
    }

    return model.startChat(history: history);
  }
}