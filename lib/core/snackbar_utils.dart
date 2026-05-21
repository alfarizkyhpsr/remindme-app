import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SnackBarUtils {
  static void showSuccess(BuildContext context, String message) {
    _showSnackBar(context, message, type: _SnackBarType.success);
  }

  static void showError(BuildContext context, String message) {
    _showSnackBar(context, message, type: _SnackBarType.error);
  }
  
  static void showInfo(BuildContext context, String message) {
    _showSnackBar(context, message, type: _SnackBarType.info);
  }

  static void _showSnackBar(BuildContext context, String message, {required _SnackBarType type}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    Color backgroundColor;
    IconData icon;
    
    switch (type) {
      case _SnackBarType.success:
        backgroundColor = const Color(0xFF2E7D32); // Modern green
        icon = Icons.auto_awesome_rounded; // Replaced standard success icon
        break;
      case _SnackBarType.error:
        backgroundColor = const Color(0xFFC62828); // Modern red
        icon = Icons.warning_amber_rounded;
        break;
      case _SnackBarType.info:
        backgroundColor = const Color(0xFF1565C0); // Modern blue
        icon = Icons.info_outline_rounded;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }
}

enum _SnackBarType { success, error, info }
