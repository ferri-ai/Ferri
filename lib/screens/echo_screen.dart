import 'package:flutter/material.dart';
import '../engine/ferri_engine.dart';
import '../engine/token_stream.dart';
import '../theme/colors.dart';

class EchoScreen extends StatefulWidget {
  const EchoScreen({super.key});

  @override
  State<EchoScreen> createState() => _EchoScreenState();
}

class _EchoScreenState extends State<EchoScreen> {
  final _controller = TextEditingController();
  final _engine = FerriEngine();
  final _messages = <String>[];
  String _status = 'uninitialized';

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  void _initEngine() {
    _engine.init(
      configJson: '{}',
      onToken: (TokenMessage token) {
        setState(() {
          if (token.isToken) {
            _messages.add('\u2190 ${token.content}');
          } else if (token.isDone) {
            _messages.add('\u2500\u2500 done \u2500\u2500');
          } else if (token.isError) {
            _messages.add('\u2717 Error: ${token.content}');
          }
        });
      },
    );
    setState(() {
      _status = _engine.status.name;
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add('\u2192 $text');
    });
    _engine.sendMessage(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _engine.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FerriColors.bg,
      appBar: AppBar(
        title: const Text('Ferri Bridge Test',
            style: TextStyle(color: FerriColors.text, fontSize: 16)),
        backgroundColor: FerriColors.bgCard,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _status == 'ready'
                      ? FerriColors.success.withAlpha(40)
                      : FerriColors.danger.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 11,
                    color: _status == 'ready'
                        ? FerriColors.success
                        : FerriColors.danger,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isOutgoing = msg.startsWith('\u2192');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    msg,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: isOutgoing
                          ? FerriColors.primary
                          : FerriColors.text,
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: FerriColors.bgCard,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: FerriColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type something...',
                      hintStyle: const TextStyle(color: FerriColors.textFaint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: FerriColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: FerriColors.border),
                      ),
                      filled: true,
                      fillColor: FerriColors.bgInput,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: FerriColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
