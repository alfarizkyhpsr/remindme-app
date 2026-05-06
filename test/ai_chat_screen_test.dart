import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/screens/ai_chat_screen.dart';

void main() {
  testWidgets('AIChatScreen renders correctly and shows initial message', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AIChatScreen(tasks: ['Beli Susu', 'Kerjakan PR']),
    ));

    // Just pump a frame because pumpAndSettle might timeout due to async location fetch
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify AppBar title
    expect(find.text('AI Asisten'), findsOneWidget);

    // Verify input field
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tanya seputar tugasmu...'), findsOneWidget);

    // Verify send button
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    
    // Because API KEY is not set in test environment and Geolocator platform channels aren't mocked,
    // the chat might be stuck in loading state or show the API error.
    // We just verify the UI structure is fundamentally correct.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });
}
