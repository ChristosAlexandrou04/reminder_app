import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppSettings {
  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);

  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);
  static final ValueNotifier<bool> largeButtons = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> highContrast = ValueNotifier<bool>(false);

  /// User's city (used to give the AI local context).
  static final ValueNotifier<String> city = ValueNotifier<String>('');

  /// Caretaker alert — if enabled, an SMS is sent to the caretaker
  /// when an alarm is not dismissed within the grace period.
  static final ValueNotifier<bool> caretakerEnabled =
      ValueNotifier<bool>(false);
  static final ValueNotifier<String> caretakerName =
      ValueNotifier<String>('');
  static final ValueNotifier<String> caretakerPhone =
      ValueNotifier<String>('');

  static final Listenable listenable = Listenable.merge([
    isDarkMode,
    textScale,
    largeButtons,
    highContrast,
  ]);

  static void reset() {
    isDarkMode.value = false;
    textScale.value = 1.0;
    largeButtons.value = false;
    highContrast.value = false;
    city.value = '';
    caretakerEnabled.value = false;
    caretakerName.value = '';
    caretakerPhone.value = '';
  }

  static Future<void> loadFromFirestore(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final s = doc.data()?['settings'] as Map<String, dynamic>?;
    if (s == null) return;
    city.value = (s['city'] as String?) ?? '';
    caretakerEnabled.value = (s['caretakerEnabled'] as bool?) ?? false;
    caretakerName.value = (s['caretakerName'] as String?) ?? '';
    caretakerPhone.value = (s['caretakerPhone'] as String?) ?? '';
  }

  static Future<void> saveToFirestore(String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({
      'settings': {
        'city': city.value,
        'caretakerEnabled': caretakerEnabled.value,
        'caretakerName': caretakerName.value,
        'caretakerPhone': caretakerPhone.value,
      },
    }, SetOptions(merge: true));
  }
}
