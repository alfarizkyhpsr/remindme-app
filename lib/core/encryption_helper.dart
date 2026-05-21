import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionHelper {
  static final _key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1'); // 32 chars
    static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  static String encryptText(String text) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(text, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decryptText(String encryptedText) {
    final parts = encryptedText.split(':');
    if (parts.length != 2) return '';
    final iv = encrypt.IV.fromBase64(parts[0]);
    return _encrypter.decrypt64(parts[1], iv: iv);
  }
}
