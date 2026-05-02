import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static Future<String> getTaskSummary(List<String> tasks) async {
    if (tasks.isEmpty) return 'Belum ada tugas untuk dirangkum.';
    if (_apiKey.isEmpty) return 'API Key belum dikonfigurasi. Tambahkan --dart-define=GEMINI_API_KEY=kunci_anda saat menjalankan aplikasi.';

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final prompt = 'Rangkum tugas-tugas berikut dalam Bahasa Indonesia yang santai dan berikan satu tips produktivitas singkat: ${tasks.join(', ')}';
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text ?? 'Gagal menghasilkan rangkuman.';
    } catch (e) {
      return 'Terjadi kesalahan saat menghubungi AI: $e';
    }
  }
}
