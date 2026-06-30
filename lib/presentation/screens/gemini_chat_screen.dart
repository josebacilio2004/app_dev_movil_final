import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestor_invetarios_pedidos_app/core/theme/app_theme.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/providers/auth_provider.dart';
import 'package:gestor_invetarios_pedidos_app/data/services/gemini_service.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/app_drawer.dart';
import 'package:gestor_invetarios_pedidos_app/presentation/widgets/common/glass_container.dart';

class GeminiChatScreen extends ConsumerStatefulWidget {
  const GeminiChatScreen({super.key});

  @override
  ConsumerState<GeminiChatScreen> createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends ConsumerState<GeminiChatScreen> {
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  final List<String> _examplePrompts = [
    '🔧 Calcular torque para perno de 1/2"',
    '📐 ¿Cómo calibro mi nivelador digital?',
    '⚡ Recomendar rotomartillo para concreto',
    '📦 ¿Qué marcas de EPP distribuyen?'
  ];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  String _getUserChatKey() {
    final user = ref.read(authStateProvider);
    final userId = user?.id ?? 'guest';
    return 'gemini_chat_history_$userId';
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString(_getUserChatKey());
      if (historyStr != null && historyStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(historyStr);
        setState(() {
          _messages.clear();
          for (var item in decoded) {
            _messages.add({
              'role': item['role']?.toString() ?? '',
              'text': item['text']?.toString() ?? '',
            });
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error al cargar historial de chat: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_getUserChatKey(), jsonEncode(_messages));
    } catch (e) {
      debugPrint('Error al guardar historial de chat: $e');
    }
  }

  Future<void> _clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getUserChatKey());
      setState(() {
        _messages.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Historial de conversación vaciado.'),
            backgroundColor: AppTheme.accentOrange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al vaciar historial de chat: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();
    await _saveChatHistory();

    try {
      final response = await _geminiService.chat(history: _messages);
      setState(() {
        _messages.add({'role': 'model', 'text': response});
      });
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'model',
          'text': '⚠️ Ocurrió un error al contactar al servidor de inteligencia artificial.'
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
      await _saveChatHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      title: Text(
        'ASISTENTE TÉCNICO IA',
        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5),
      ),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppTheme.accentOrange, size: 28),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        if (_messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.surfaceDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Vaciar Conversación', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    '¿Estás seguro de que deseas eliminar todo el historial de chat con la IA? Esta acción no se puede deshacer.',
                    style: TextStyle(color: AppTheme.textGray, fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCELAR', style: TextStyle(color: AppTheme.textGray)),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _clearChatHistory();
                      },
                      child: const Text('VACIAR', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Vaciar Historial',
          ),
        const SizedBox(width: 8),
      ],
    );

    final mainContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            // Banner Superior
            _buildBanner(),

            // Zona de Mensajes
            Expanded(
              child: _messages.isEmpty 
                  ? _buildWelcomeState() 
                  : _buildMessageList(),
            ),

            // Cargador IA escribiendo
            if (_isLoading) _buildWritingIndicator(),

            // Input de Mensaje
            _buildInputBar(),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.primaryDark,
      drawer: const AppDrawer(currentRoute: 'gemini_chat'),
      appBar: appBar,
      body: mainContent,
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark.withOpacity(0.4),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: const Row(
        children: [
          Text('🤖', style: TextStyle(fontSize: 20)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODELO GEMINI 2.5 FLASH',
                  style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                Text(
                  'Consultas industriales, de torque, nivelación y stock en vivo.',
                  style: TextStyle(color: AppTheme.textGray, fontSize: 9),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.accentOrange.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accentOrange.withOpacity(0.2), width: 1.5),
            ),
            child: const Text('🤖', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Hola! Soy tu Asistente Técnico IA Aly',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Puedo ayudarte a calcular torques y conversiones, explicarte cómo usar nuestras herramientas de nivelación y resolver tus dudas técnicas en obra.',
            style: TextStyle(color: AppTheme.textGray, fontSize: 12, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PREGUNTAS SUGERIDAS',
              style: GoogleFonts.outfit(
                color: AppTheme.textGray,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._examplePrompts.map((prompt) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: InkWell(
              onTap: () => _sendMessage(prompt.replaceFirst(RegExp(r'^[^\s]+\s'), '')),
              borderRadius: BorderRadius.circular(12),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                borderRadius: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        prompt,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.accentOrange, size: 12),
                  ],
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser 
                  ? AppTheme.accentOrange.withOpacity(0.15) 
                  : AppTheme.surfaceDark,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser 
                    ? AppTheme.accentOrange.withOpacity(0.3) 
                    : Colors.white.withOpacity(0.06),
                width: 1,
              ),
            ),
            child: Text(
              msg['text'] ?? '',
              style: TextStyle(
                color: isUser ? Colors.white : Colors.white.withOpacity(0.9),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWritingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentOrange),
          ),
          const SizedBox(width: 12),
          Text(
            'El Asistente está escribiendo...',
            style: GoogleFonts.outfit(color: AppTheme.textGray, fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Pregunta sobre torque, plomo, nivelación...',
                  hintStyle: const TextStyle(color: AppTheme.textGray, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.primaryDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _sendMessage(_messageController.text),
              child: Container(
                height: 44,
                width: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.accentOrange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
