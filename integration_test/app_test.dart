import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';
import 'package:smart_content_creator/main.dart' as app;
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App UI & Buttons Test', () {
    testWidgets('Basic screens and buttons flow', (WidgetTester tester) async {
      // Start the app and wait for it to initialize
      app.main();
      await tester.pumpAndSettle();

      // Check if app started (GetMaterialApp is used in main.dart)
      expect(find.byType(GetMaterialApp), findsOneWidget);

      // انتظار الشاشة الرئيسية
      await tester.pumpAndSettle();

      // التحقق من Chat Screen
      // Note: If the app starts with Login, this might fail unless bypass or login logic is added.
      // Assuming it lands on Chat for now or splash settles to chat.
      
      // Check for send message text field or button to confirm we are in chat
      expect(find.byType(TextField), findsWidgets); 

      // اختبار زر إرسال رسالة
      final sendButton = find.byIcon(Icons.send);
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton);
        await tester.pumpAndSettle();
      }

      // تحقق من وجود زر إعدادات / Dashboard
      final dashboardButton = find.byIcon(Icons.admin_panel_settings);
      if (dashboardButton.evaluate().isNotEmpty) {
        await tester.tap(dashboardButton);
        await tester.pumpAndSettle();

        // تحقق من وجود لوحة الإدارة
        expect(find.textContaining('المدير'), findsWidgets);
      }

      // تحقق من زر Permissions
      final permissionButton = find.byIcon(Icons.settings);
      if (permissionButton.evaluate().isNotEmpty) {
        await tester.tap(permissionButton);
        await tester.pumpAndSettle();
        expect(find.textContaining('صلاحيات'), findsWidgets);
      }
    });
  });
}
