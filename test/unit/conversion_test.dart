import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

// Karena logika konversi ada di dalam State ConversionScreen, 
// idealnya kita ekstrak logika tersebut ke helper class untuk unit testing.
// Untuk keperluan TDD, saya akan buat helper class darurat untuk ditest.

class ConversionHelper {
  static final Map<String, double> rates = {
    'USD_IDR': 15500.0,
    'IDR_USD': 1 / 15500.0,
    'USD_EUR': 0.92,
    'EUR_USD': 1 / 0.92,
    'USD_JPY': 148.0,
    'JPY_USD': 1 / 148.0,
  };

  static double convert(double amount, String from, String to) {
    if (from == to) return amount;
    String key = '${from}_$to';
    if (rates.containsKey(key)) {
      return amount * rates[key]!;
    } else {
      double amountInUsd = from == 'USD' ? amount : amount * rates['${from}_USD']!;
      return amountInUsd * rates['USD_$to']!;
    }
  }

  static String formatTime(String locationName, DateTime now) {
    switch (locationName) {
      case 'WIB': return DateFormat('HH:mm').format(now.toUtc().add(const Duration(hours: 7)));
      case 'WITA': return DateFormat('HH:mm').format(now.toUtc().add(const Duration(hours: 8)));
      case 'WIT': return DateFormat('HH:mm').format(now.toUtc().add(const Duration(hours: 9)));
      case 'London': return DateFormat('HH:mm').format(now.toUtc().add(const Duration(hours: 0))); 
      default: return '';
    }
  }
}

void main() {
  group('ConversionHelper Logic', () {
    test('Konversi Mata Uang: USD ke IDR harus benar', () {
      final hasil = ConversionHelper.convert(100, 'USD', 'IDR');
      expect(hasil, 1550000.0);
    });

    test('Konversi Mata Uang: EUR ke JPY harus melalui USD', () {
      // 100 EUR -> USD -> JPY
      final hasil = ConversionHelper.convert(100, 'EUR', 'JPY');
      final expected = (100 * (1 / 0.92)) * 148.0;
      expect(hasil, closeTo(expected, 0.001));
    });

    test('Konversi Waktu: WIB harus UTC+7', () {
      final now = DateTime.utc(2026, 4, 30, 10, 0); // 10:00 UTC
      final wib = ConversionHelper.formatTime('WIB', now);
      expect(wib, '17:00'); // 17:00 WIB
    });
  });
}
