import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/services/ai_service.dart';

void main() {
  group('AIService', () {
    test('getTaskSummary returns error message if no tasks provided', () async {
      final summary = await AIService.getTaskSummary([]);
      expect(summary, 'Belum ada tugas untuk dirangkum.');
    });

    test('getTaskSummary returns API Key error if not set', () async {
      final summary = await AIService.getTaskSummary(['Makan']);
      expect(summary, contains('API Key belum dikonfigurasi'));
    });

    test('startChat returns null if no API key is set', () {
      final session = AIService.startChat(['Belanja']);
      expect(session, isNull);
    });
  });
}
