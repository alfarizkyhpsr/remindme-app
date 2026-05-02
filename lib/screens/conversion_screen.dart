import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'mini_game_screen.dart';
import '../core/app_theme.dart';

class ConversionScreen extends StatefulWidget {
  const ConversionScreen({super.key});

  @override
  State<ConversionScreen> createState() => _ConversionScreenState();
}

class _ConversionScreenState extends State<ConversionScreen> {
  final _amountController = TextEditingController();
  double _convertedAmount = 0;
  String _fromCurrency = 'USD';
  String _toCurrency = 'IDR';

  final Map<String, double> _rates = {
    'USD_IDR': 15500.0,
    'IDR_USD': 1 / 15500.0,
    'USD_EUR': 0.92,
    'EUR_USD': 1 / 0.92,
    'USD_JPY': 148.0,
    'JPY_USD': 1 / 148.0,
  };

  void _convertCurrency() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (_fromCurrency == _toCurrency) {
      setState(() => _convertedAmount = amount);
      return;
    }
    String key = '${_fromCurrency}_${_toCurrency}';
    if (_rates.containsKey(key)) {
      setState(() => _convertedAmount = amount * _rates[key]!);
    } else {
      double amountInUsd = _fromCurrency == 'USD' ? amount : amount * _rates['${_fromCurrency}_USD']!;
      setState(() => _convertedAmount = amountInUsd * _rates['USD_${_toCurrency}']!);
    }
  }

  String _formatTime(String locationName) {
    switch (locationName) {
      case 'WIB': 
        return DateFormat('HH:mm').format(tz.TZDateTime.now(tz.getLocation('Asia/Jakarta')));
      case 'WITA': 
        return DateFormat('HH:mm').format(tz.TZDateTime.now(tz.getLocation('Asia/Makassar')));
      case 'WIT': 
        return DateFormat('HH:mm').format(tz.TZDateTime.now(tz.getLocation('Asia/Jayapura')));
      case 'London': 
        return DateFormat('HH:mm').format(tz.TZDateTime.now(tz.getLocation('Europe/London')));
      default: 
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Fitur & Produktivitas', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildCard(
              'Konversi Mata Uang',
              Icons.currency_exchange,
              AppTheme.primary,
              Column(
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Masukkan jumlah',
                      prefixIcon: Icon(Icons.attach_money, color: AppTheme.primary),
                    ),
                    onChanged: (_) => _convertCurrency(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildCurrencyPicker(_fromCurrency, (val) => setState(() { _fromCurrency = val!; _convertCurrency(); })),
                      const Icon(Icons.swap_horiz, color: AppTheme.outline),
                      _buildCurrencyPicker(_toCurrency, (val) => setState(() { _toCurrency = val!; _convertCurrency(); })),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('Hasil Konversi', style: TextStyle(color: AppTheme.onSurface.withOpacity(0.5), fontSize: 12)),
                        const SizedBox(height: 5),
                        Text(
                          '${NumberFormat.currency(symbol: '').format(_convertedAmount)} $_toCurrency',
                          style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            _buildCard(
              'Waktu Dunia',
              Icons.schedule,
              AppTheme.secondary,
              Column(
                children: [
                  _timeRow('WIB (Jakarta)', _formatTime('WIB')),
                  _divider(),
                  _timeRow('WITA (Makassar)', _formatTime('WITA')),
                  _divider(),
                  _timeRow('WIT (Jayapura)', _formatTime('WIT')),
                  _divider(),
                  _timeRow('London (UTC)', _formatTime('London')),
                ],
              ),
            ),
            const SizedBox(height: 25),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MiniGameScreen())),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: AppTheme.secondary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.sports_esports, color: Colors.white),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Pengumpul Fokus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('Istirahat sejenak dan tingkatkan fokusmu!', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyPicker(String value, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.outline.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: ['USD', 'IDR', 'EUR', 'JPY'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _timeRow(String label, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(time, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: AppTheme.secondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _divider() => Divider(color: AppTheme.outline.withOpacity(0.05), height: 1);

  Widget _buildCard(String title, IconData icon, Color color, Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }
}
