import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  final String senderEmail = 'vcupla14@gmail.com'; // Gmail address
  final String senderPassword = 'xucf pkhu plyh qrad'; // Gmail App Password

  /// Generate random 6-digit code
  String generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Insert verification code into Supabase, then get latest record
  Future<Map<String, dynamic>?> storeAndGetLatestCode(String email, String code) async {
    final expiration = DateTime.now().add(const Duration(minutes: 5));

    // Insert into Supabase
    await Supabase.instance.client.from('email_verification').insert({
      'email': email,
      'verification_code': code,
      'created_at': DateTime.now().toIso8601String(),
      'expiration_time': expiration.toIso8601String(),
    });

    // Get latest record (verification_id DESC)
    final latest = await Supabase.instance.client
        .from('email_verification')
        .select()
        .order('verification_id', ascending: false)
        .limit(1)
        .maybeSingle();

    print('🗄 Latest inserted verification record: $latest');
    return latest;
  }

  /// Send email and log results
  Future<bool> sendVerificationEmail(String recipientEmail, String code) async {
    try {
      final smtpServer = gmail(senderEmail, senderPassword);

      final message = Message()
        ..from = Address(senderEmail, 'Avoid Capstone Project')
        ..recipients.add(recipientEmail)
        ..subject = 'Your Verification Code'
        ..text =
            'Your verification code is: $code\n\nThis code will expire in 5 minutes.';

      final sendReport = await send(message, smtpServer);

      print('📨 Email send report: $sendReport');
      print('✅ Email sending process finished.');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error sending email: $e');
      print('📜 Stack trace: $stackTrace');
      return false;
    }
  }

  /// Main function: generate code, store, get latest, then send
  Future<void> sendAndStoreCode(String email) async {
    final code = generateVerificationCode();

    final latestRecord = await storeAndGetLatestCode(email, code);

    if (latestRecord != null) {
      await sendVerificationEmail(email, latestRecord['verification_code']);
    } else {
      print('⚠ No record found after insert.');
    }
  }
}
