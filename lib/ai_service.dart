import 'package:firebase_ai/firebase_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AiService {
  ChatSession? _chat;

  // -------------------------------------------------------
  // System prompt – tells the AI how to behave
  // -------------------------------------------------------
  static String _buildSystemPrompt(
    List<Map<String, dynamic>> reminders,
    String city,
  ) {
    final buf = StringBuffer()
      ..writeln('You are a helpful AI health assistant built into a medicine '
          'reminder app.')
      ..writeln()
      ..writeln('Your role:')
      ..writeln('• Answer general questions about medications (uses, common '
          'side effects, timing advice).')
      ..writeln('• Provide general health information about common conditions.')
      ..writeln('• Help users understand their medication schedule.')
      ..writeln('• Suggest nearby pharmacies or doctors when the user asks '
          '(use their city if provided).')
      ..writeln()
      ..writeln('Rules you MUST follow:')
      ..writeln('1. Always end every response with exactly this line:')
      ..writeln('   "⚠️ This is general information only — always follow your '
          'doctor or pharmacist\'s advice."')
      ..writeln('2. Be concise and friendly. Keep responses under 150 words '
          'unless the user asks for more detail.')
      ..writeln('3. Never diagnose conditions or prescribe medication.')
      ..writeln('4. If you are unsure, say so honestly.')
      ..writeln('5. You may reference the user\'s existing reminders (listed '
          'below) when relevant.')
      ..writeln('6. NEVER recommend specific medicines to buy. If the user '
          'asks what medicine they should get or buy, respond with something '
          'like: "I can\'t recommend specific medicines, but I can help you '
          'find nearby pharmacies where a pharmacist can advise you." Then '
          'suggest pharmacies in their city if you know it.')
      ..writeln();

    // City context
    if (city.isNotEmpty) {
      buf.writeln('USER\'S CITY: $city');
      buf.writeln('When the user asks about pharmacies or doctors, suggest '
          'well-known ones in or near $city.');
      buf.writeln();
    }

    // Reminders context
    if (reminders.isEmpty) {
      buf.writeln('The user has no reminders set up yet.');
    } else {
      buf.writeln('USER\'S CURRENT REMINDERS:');
      for (final r in reminders) {
        final title = r['title'] ?? '';
        final time = r['time'] ?? '';
        final dosage = r['dosage'] ?? '';
        final repeat = r['repeatType'] ?? 'daily';
        buf.writeln(
          '• $title at $time'
          '${dosage.toString().trim().isNotEmpty ? ' ($dosage)' : ''}'
          ' [$repeat]',
        );
      }
    }

    return buf.toString();
  }

  // -------------------------------------------------------
  // Initialise the Gemini model + chat session
  // -------------------------------------------------------
  void initialise(
    List<Map<String, dynamic>> reminders, {
    String city = '',
    List<Content>? history,
  }) {
    final model = FirebaseAI.googleAI(auth: FirebaseAuth.instance)
        .generativeModel(
          model: 'gemini-2.5-flash',
          systemInstruction: Content.system(
            _buildSystemPrompt(reminders, city),
          ),
        );

    _chat = model.startChat(history: history ?? []);
  }

  // -------------------------------------------------------
  // Send a message and receive a streaming response
  // -------------------------------------------------------
  Stream<String> sendMessage(String userMessage) async* {
    if (_chat == null) {
      throw StateError('AiService has not been initialised — call initialise() first.');
    }

    final response = _chat!.sendMessageStream(Content.text(userMessage));

    await for (final chunk in response) {
      final text = chunk.text;
      if (text != null && text.isNotEmpty) {
        yield text;
      }
    }
  }

  // -------------------------------------------------------
  // Chat history persistence  (signed-in users only)
  // -------------------------------------------------------
  static CollectionReference<Map<String, dynamic>>? _historyRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('ai_chat_history');
  }

  /// Load the most recent 50 messages (oldest → newest).
  static Future<List<Map<String, dynamic>>> loadHistory() async {
    final ref = _historyRef();
    if (ref == null) return [];

    final snap = await ref
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    // Reverse so oldest messages come first.
    return snap.docs.reversed.map((d) => d.data()).toList();
  }

  /// Persist a single message.
  static Future<void> saveMessage(String role, String text) async {
    final ref = _historyRef();
    if (ref == null) return;

    await ref.add({
      'role': role,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Delete all saved messages for the current user.
  static Future<void> clearHistory() async {
    final ref = _historyRef();
    if (ref == null) return;

    final snap = await ref.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
