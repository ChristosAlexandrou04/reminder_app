import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_settings.dart';

const _smsChannel = MethodChannel('com.example.reminder_app/sms');

class AlarmScreen extends StatefulWidget {
  final String title;
  final String dosage;
  final VoidCallback onDismiss;

  const AlarmScreen({
    super.key,
    required this.title,
    required this.dosage,
    required this.onDismiss,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  // Caretaker countdown
  Timer? _caretakerTimer;
  int _secondsRemaining = 300; // 5 minutes
  bool _caretakerEnabled = false;
  String _caretakerName = '';
  String _caretakerPhone = '';

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _caretakerEnabled = AppSettings.caretakerEnabled.value;
    _caretakerName = AppSettings.caretakerName.value;
    _caretakerPhone = AppSettings.caretakerPhone.value;

    if (_caretakerEnabled && _caretakerPhone.isNotEmpty) {
      _caretakerTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _secondsRemaining--);
        if (_secondsRemaining <= 0) {
          t.cancel();
          _alertCaretaker();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _caretakerTimer?.cancel();
    super.dispose();
  }

  Future<void> _alertCaretaker() async {
    final phone = _caretakerPhone.replaceAll(' ', '');
    final name = _caretakerName.isNotEmpty ? _caretakerName : 'your caretaker';
    final message =
        'Hi $name, a medication alarm for "${widget.title}" has not been '
        'dismissed. Please check on them.';

    try {
      await _smsChannel.invokeMethod('sendSMS', {
        'phone': phone,
        'message': message,
      });
    } catch (_) {
      _showSmsDialog(phone, message);
    }
  }

  void _showSmsDialog(String phone, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Caretaker alert'),
        content: Text('SMS to $phone:\n\n$message'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatCountdown() {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return FadeTransition(
      opacity: _fadeAnim,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B5E),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Time
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 20,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 48),

                // Pulsing alarm icon
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.alarm,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Medication name
                const Text(
                  'Time to take',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (widget.dosage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.dosage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 60),

                // Dismiss button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0D1B5E),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),

                // Caretaker countdown
                if (_caretakerEnabled &&
                    _caretakerPhone.isNotEmpty &&
                    _secondsRemaining > 0) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Caretaker alert in ${_formatCountdown()}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Dismiss to cancel',
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
