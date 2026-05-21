import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:remindme/screens/home_screen.dart';
import 'package:remindme/providers/auth_provider.dart';
import 'package:remindme/providers/reminder_provider.dart';

void main() {
  testWidgets('HomeScreen should display greeting and search bar', (WidgetTester tester) async {
    // Setup Mock Providers
    final authProvider = AuthProvider();
    final reminderProvider = PengingatProvider();

    // Mock Login
    // final testUser = Pengguna(id: 1, namaPengguna: 'Alfa', kataSandi: 'pass');
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<PengingatProvider>.value(value: reminderProvider),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    // Verify Greeting (Initial state might show "Pengguna" if not injected correctly)
    expect(find.text('Halo,'), findsOneWidget);
    
    // Verify Search Bar
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cari fokusmu...'), findsOneWidget);

    // Verify Empty State
    expect(find.text('Belum ada tugas yang difokuskan.'), findsOneWidget);
  });
}
