import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/location_service.dart';
import '../core/app_theme.dart';
import '../core/snackbar_utils.dart';
import '../models/reminder_model.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/notification_service.dart';

class AIChatScreen extends StatefulWidget {
  final List<String> tasks;
  const AIChatScreen({super.key, required this.tasks});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  ChatSession? _chatSession;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // ── Storage ───────────────────────────────────────────────────────────────

  Future<String> get _storageKey async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? 'guest';
    return 'ai_chat_history_$username';
  }

  Future<List<ChatMessage>> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _storageKey;
      final jsonStr = prefs.getString(key);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Chat] Error loading history: $e');
      return [];
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _storageKey;
      // Batasi 100 pesan agar storage tidak membengkak
      final toSave = _messages.length > 100
          ? _messages.sublist(_messages.length - 100)
          : _messages;
      await prefs.setString(
        key,
        jsonEncode(toSave.map((m) => m.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('[Chat] Error saving history: $e');
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Riwayat Chat?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Semua percakapan sebelumnya akan dihapus dan chat dimulai dari awal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKey;
    await prefs.remove(key);

    setState(() {
      _messages.clear();
      _chatSession = null;
    });
    _initChat();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  void _initChat() async {
    setState(() => _isLoading = true);

    // Ambil lokasi saat ini
    String? currentLocationStr;
    try {
      final pos = await LocationService.getCurrentLocation();
      if (pos != null) {
        final address = await LocationService.getAddressFromLatLng(pos);
        currentLocationStr =
            '$address (Lat: ${pos.latitude}, Lng: ${pos.longitude})';
      }
    } catch (e) {
      debugPrint('Gagal mendapatkan lokasi: $e');
    }

    // Load history dari storage
    final savedMessages = await _loadHistory();

    // Bangun konteks percakapan sebelumnya untuk Gemini.
    // Skip index 0 (greeting) karena sudah ada di history awal Gemini.
    final previousForAI = savedMessages.length > 1
        ? savedMessages
            .skip(1)
            .map((m) => {'text': m.text, 'isUser': m.isUser})
            .toList()
        : <Map<String, dynamic>>[];

    _chatSession = AIService.startChat(
      widget.tasks,
      userLocation: currentLocationStr,
      previousMessages: previousForAI,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (savedMessages.isNotEmpty) {
        // Tampilkan history yang tersimpan
        _messages.addAll(savedMessages);
      } else {
        // Sesi baru — tampilkan greeting
        if (_chatSession == null) {
          _messages.add(ChatMessage(
            text:
                'API Key belum dikonfigurasi. Tambahkan --dart-define=GEMINI_API_KEY=kunci_anda '
                'saat menjalankan aplikasi.',
            isUser: false,
          ));
        } else {
          _messages.add(ChatMessage(
            text: 'Halo! Aku asisten AI dari RemindMe+. '
                '${currentLocationStr != null ? "\nAku sudah mencatat lokasimu sekarang. " : ""}'
                'Ada yang bisa aku bantu untuk menyelesaikan tugasmu hari ini?',
            isUser: false,
          ));
          _saveHistory();
        }
      }
    });

    _scrollToBottom();
  }

  // ── Send message ──────────────────────────────────────────────────────────

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatSession == null) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _messageController.clear();
    await _saveHistory(); // Simpan pesan user segera
    _scrollToBottom();

    try {
      final response = await _chatSession!.sendMessage(Content.text(text));
      final responseText = response.text ?? 'Gagal memuat respons.';
      final scheduleDraft = _extractScheduleDraft(responseText);

      setState(() {
        _messages.add(ChatMessage(
          text: responseText,
          isUser: false,
          scheduleDraft: scheduleDraft,
        ));
        _isLoading = false;
      });
      await _saveHistory(); // Simpan respons AI
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: 'Terjadi kesalahan: $e', isUser: false));
        _isLoading = false;
      });
      await _saveHistory();
      _scrollToBottom();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ScheduleDraft? _extractScheduleDraft(String responseText) {
    final jsonBlockPattern =
        RegExp(r'```json\s*([\s\S]*?)\s*```', caseSensitive: false);
    final match = jsonBlockPattern.firstMatch(responseText);
    if (match == null) return null;

    try {
      final rawJson = match.group(1)?.trim();
      if (rawJson == null || rawJson.isEmpty) return null;
      final decoded = json.decode(rawJson);
      if (decoded is! Map<String, dynamic>) return null;

      final title = (decoded['title'] ?? '').toString().trim();
      final description = (decoded['description'] ?? '').toString().trim();
      final date = (decoded['date'] ?? '').toString().trim();
      final time = (decoded['time'] ?? '').toString().trim();
      final category = (decoded['category'] ?? '').toString().trim();
      final location = (decoded['location'] ?? '').toString().trim();

      if (title.isEmpty || date.isEmpty || time.isEmpty || category.isEmpty) {
        return null;
      }
      final dateTime = DateTime.tryParse('${date}T$time:00');
      if (dateTime == null) return null;

      return ScheduleDraft(
        title: title,
        description: description,
        scheduledAt: dateTime,
        category: category,
        location: location,
      );
    } catch (_) {
      return null;
    }
  }

  String _cleanAssistantText(String responseText) {
    return responseText
        .replaceAll(
            RegExp(r'```json\s*[\s\S]*?\s*```', caseSensitive: false), '')
        .trim();
  }

  Future<void> _saveScheduleDraft(ScheduleDraft draft) async {
    final pengguna =
        Provider.of<AuthProvider>(context, listen: false).penggunaSaatIni;
    if (pengguna?.id == null) {
      SnackBarUtils.showError(context, 'Sesi pengguna tidak ditemukan.');
      return;
    }
    if (draft.scheduledAt.isBefore(DateTime.now())) {
      SnackBarUtils.showError(
          context, 'Jadwal dari AI berada di masa lalu. Minta AI buat ulang.');
      return;
    }

    final resolvedLocation = draft.location.trim().isEmpty
        ? null
        : await LocationService.resolveLocationLabel(draft.location);

    final pengingat = Pengingat(
      idPengguna: pengguna!.id!,
      judul: draft.title,
      deskripsi: draft.description.isEmpty
          ? 'Dibuat dari rekomendasi AI.'
          : draft.description,
      waktu: DateTime.now(),
      deadline: draft.scheduledAt,
      kategori: draft.category,
      lokasi: resolvedLocation,
    );

    if (!mounted) return;
    await Provider.of<PengingatProvider>(context, listen: false)
        .tambahPengingat(pengingat);

    try {
      if (draft.scheduledAt.isAfter(DateTime.now())) {
        final msg = await NotificationService.scheduleDeadlineNotifications(
          id: Random().nextInt(1000) + 2000,
          title: draft.title,
          deadline: draft.scheduledAt,
        );
        if (mounted) SnackBarUtils.showSuccess(context, msg);
      } else {
        if (mounted) SnackBarUtils.showSuccess(context, 'Jadwal AI berhasil ditambahkan ke beranda.');
      }
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi: $e');
      if (mounted) SnackBarUtils.showSuccess(context, 'Jadwal AI berhasil ditambahkan ke beranda.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppTheme.primary),
            const SizedBox(width: 10),
            Text(
              'AI Asisten',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          // Tombol hapus riwayat
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Hapus Riwayat Chat',
              icon: Icon(Icons.delete_sweep_outlined,
                  color: AppTheme.outline.withValues(alpha: 0.6)),
              onPressed: _confirmClearHistory,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Banner "riwayat dimuat" jika ada history
          _HistoryBanner(messageCount: _messages.length),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment: msg.isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color:
                          msg.isUser ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: msg.isUser
                            ? const Radius.circular(0)
                            : const Radius.circular(20),
                        bottomLeft: msg.isUser
                            ? const Radius.circular(20)
                            : const Radius.circular(0),
                      ),
                      border: msg.isUser
                          ? null
                          : Border.all(
                              color: AppTheme.outline.withValues(alpha: 0.1),
                              width: 1.5,
                            ),
                    ),
                    child: _buildMessageContent(msg),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2),
              ),
            ),

          // Input bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                  top: BorderSide(
                      color: AppTheme.outline.withValues(alpha: 0.1))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Tanya seputar tugasmu...',
                        hintStyle: TextStyle(
                            color: AppTheme.onSurface.withValues(alpha: 0.5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg) {
    if (!msg.isUser &&
        msg.text.contains('https://www.google.com/maps/')) {
      final urlRegExp =
          RegExp(r'(https://www\.google\.com/maps/[^\s]+)');
      final match = urlRegExp.firstMatch(msg.text);
      if (match != null) {
        final url = match.group(0)!;
        final textBefore = msg.text.substring(0, match.start);
        final textAfter = msg.text.substring(match.end);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (textBefore.trim().isNotEmpty)
              SelectableText(
                textBefore.trim(),
                style: const TextStyle(
                    color: AppTheme.onSurface, fontSize: 15, height: 1.4),
              ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('Buka di Peta (Interaktif)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (textAfter.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                textAfter.trim(),
                style: const TextStyle(
                    color: AppTheme.onSurface, fontSize: 15, height: 1.4),
              ),
            ],
          ],
        );
      }
    }

    if (!msg.isUser && msg.scheduleDraft != null) {
      final cleanText = _cleanAssistantText(msg.text);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cleanText.isNotEmpty)
            MarkdownBody(
              data: cleanText,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                    color: AppTheme.onSurface, fontSize: 15, height: 1.4),
              ),
              selectable: true,
            ),
          if (cleanText.isNotEmpty) const SizedBox(height: 12),
          _ScheduleDraftCard(
            draft: msg.scheduleDraft!,
            onSave: () => _saveScheduleDraft(msg.scheduleDraft!),
          ),
        ],
      );
    }

    return MarkdownBody(
      data: msg.text,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          color: msg.isUser ? Colors.white : AppTheme.onSurface,
          fontSize: 15,
          height: 1.4,
        ),
        strong: TextStyle(
          color: msg.isUser ? Colors.white : AppTheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        listBullet: TextStyle(
          color: msg.isUser ? Colors.white : AppTheme.onSurface,
        ),
      ),
      selectable: true,
    );
  }
}

// ── Banner riwayat ────────────────────────────────────────────────────────────

class _HistoryBanner extends StatelessWidget {
  final int messageCount;
  const _HistoryBanner({required this.messageCount});

  @override
  Widget build(BuildContext context) {
    if (messageCount <= 1) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      color: AppTheme.secondary.withValues(alpha: 0.07),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 14,
              color: AppTheme.secondary.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            'Melanjutkan percakapan sebelumnya',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.secondary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final ScheduleDraft? scheduleDraft;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.scheduleDraft,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'scheduleDraft': scheduleDraft?.toJson(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        scheduleDraft: json['scheduleDraft'] != null
            ? ScheduleDraft.fromJson(
                json['scheduleDraft'] as Map<String, dynamic>)
            : null,
      );
}

class ScheduleDraft {
  final String title;
  final String description;
  final DateTime scheduledAt;
  final String category;
  final String location;

  ScheduleDraft({
    required this.title,
    required this.description,
    required this.scheduledAt,
    required this.category,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'scheduledAt': scheduledAt.toIso8601String(),
        'category': category,
        'location': location,
      };

  factory ScheduleDraft.fromJson(Map<String, dynamic> json) => ScheduleDraft(
        title: json['title'] as String,
        description: json['description'] as String,
        scheduledAt: DateTime.parse(json['scheduledAt'] as String),
        category: json['category'] as String,
        location: json['location'] as String,
      );
}

// ── Schedule draft card ───────────────────────────────────────────────────────

class _ScheduleDraftCard extends StatelessWidget {
  final ScheduleDraft draft;
  final VoidCallback onSave;

  const _ScheduleDraftCard({required this.draft, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_note, color: AppTheme.secondary),
              SizedBox(width: 8),
              Text(
                'Draft Jadwal dari AI',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.secondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(draft.title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          if (draft.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(draft.description,
                style: TextStyle(
                    color: AppTheme.onSurface.withValues(alpha: 0.75))),
          ],
          const SizedBox(height: 10),
          Text('Kategori: ${draft.category}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          if (draft.location.trim().isNotEmpty) ...[
            Text('Lokasi: ${draft.location}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
          ],
          Text(
            'Jadwal: ${DateFormat('dd MMM yyyy, HH:mm').format(draft.scheduledAt)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Tambahkan ke Beranda'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary),
            ),
          ),
        ],
      ),
    );
  }
}