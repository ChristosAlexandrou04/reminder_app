import 'package:flutter/material.dart';
import 'app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void _save() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) AppSettings.saveToFirestore(uid);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;

  late final TextEditingController _cityController;
  late final TextEditingController _caretakerNameController;
  late final TextEditingController _caretakerPhoneController;

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: AppSettings.city.value);
    _caretakerNameController =
        TextEditingController(text: AppSettings.caretakerName.value);
    _caretakerPhoneController =
        TextEditingController(text: AppSettings.caretakerPhone.value);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _caretakerNameController.dispose();
    _caretakerPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ACCOUNT
          const Text(
            'Account',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Account details'),
                  onTap: () {
                    final user = FirebaseAuth.instance.currentUser;

                    final username =
                        (user?.displayName?.trim().isNotEmpty ?? false)
                            ? user!.displayName!
                            : (user?.isAnonymous == true
                                ? 'Anonymous user'
                                : 'User');

                    final email =
                        (user?.email?.trim().isNotEmpty ?? false)
                            ? user!.email!
                            : (user?.isAnonymous == true
                                ? 'No email (anonymous)'
                                : 'No email');

                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Account details'),
                          backgroundColor: isDark ? Colors.grey[900] : null,
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DetailRow(label: 'Username', value: username),
                              const SizedBox(height: 8),
                              _DetailRow(label: 'Email', value: email),
                              const SizedBox(height: 8),
                              Text(
                                user?.isAnonymous == true
                                    ? 'You are using an anonymous account. Data is stored only on this device unless you create a permanent account.'
                                    : 'You are using a signed-in account. Your data can sync across devices.',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const Divider(height: 1),

                // LOG OUT (REAL)
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Log out'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder:
                          (c) => AlertDialog(
                            title: const Text('Log out?'),
                            content: const Text(
                              'Are you sure you want to log out?\n\n'
                              'Your app settings will be reset on this device.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Log out'),
                              ),
                            ],
                          ),
                    );

                    if (confirm != true) return;

                    // 1) Reset settings
                    AppSettings.reset();

                    // 2) Sign out
                    try {
                      if (!kIsWeb) {
                        await GoogleSignIn.instance.signOut();
                      }
                    } catch (_) {}

                    await FirebaseAuth.instance.signOut();

                    // 3) IMPORTANT: remove SettingsPage and go back to AuthGate
                    if (!mounted) return;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // APPEARANCE
          const Text(
            'Appearance',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: AppSettings.isDarkMode,
                  builder: (context, value, _) {
                    return SwitchListTile(
                      secondary: const Icon(Icons.dark_mode),
                      title: const Text('Dark mode'),
                      value: value,
                      onChanged:
                          (v) =>
                              setState(() => AppSettings.isDarkMode.value = v),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ACCESSIBILITY
          const Text(
            'Accessibility',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  // Text size slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.text_fields),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Text size',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        ValueListenableBuilder<double>(
                          valueListenable: AppSettings.textScale,
                          builder: (context, value, _) {
                            return Text('${(value * 100).round()}%');
                          },
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: AppSettings.textScale,
                    builder: (context, value, _) {
                      return Slider(
                        min: 1.0,
                        max: 1.4,
                        divisions: 4,
                        value: value,
                        onChanged:
                            (v) =>
                                setState(() => AppSettings.textScale.value = v),
                      );
                    },
                  ),

                  const Divider(height: 1),

                  // Large buttons
                  ValueListenableBuilder<bool>(
                    valueListenable: AppSettings.largeButtons,
                    builder: (context, value, _) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.touch_app),
                        title: const Text('Large buttons'),
                        subtitle: const Text(
                          'Bigger tap targets (easier to press)',
                        ),
                        value: value,
                        onChanged:
                            (v) => setState(
                              () => AppSettings.largeButtons.value = v,
                            ),
                      );
                    },
                  ),

                  const Divider(height: 1),

                  // High contrast
                  ValueListenableBuilder<bool>(
                    valueListenable: AppSettings.highContrast,
                    builder: (context, value, _) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.contrast),
                        title: const Text('High contrast'),
                        subtitle: const Text('Stronger text and dividers'),
                        value: value,
                        onChanged:
                            (v) => setState(
                              () => AppSettings.highContrast.value = v,
                            ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // NOTIFICATIONS
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_active),
              title: const Text('Medication reminders'),
              value: _notificationsEnabled,
              onChanged:
                  (value) => setState(() => _notificationsEnabled = value),
            ),
          ),

          const SizedBox(height: 24),

          // CARETAKER ALERT
          const Text(
            'Caretaker Alert',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: AppSettings.caretakerEnabled,
                    builder: (context, enabled, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            secondary: const Icon(Icons.people_alt_outlined),
                            title: const Text('Enable caretaker alerts'),
                            subtitle: const Text(
                              'Send an SMS if an alarm is not dismissed in time',
                            ),
                            value: enabled,
                            onChanged: (v) {
                              setState(
                                () => AppSettings.caretakerEnabled.value = v,
                              );
                              _save();
                            },
                          ),
                          if (enabled) ...[
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                'If a medication alarm is not dismissed within '
                                '5 minutes, an SMS will be sent to the contact '
                                'below.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: TextField(
                                controller: _caretakerNameController,
                                decoration: InputDecoration(
                                  labelText: 'Caretaker name',
                                  prefixIcon:
                                      const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                textCapitalization:
                                    TextCapitalization.words,
                                onChanged: (v) {
                                  AppSettings.caretakerName.value = v.trim();
                                  _save();
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                              child: TextField(
                                controller: _caretakerPhoneController,
                                decoration: InputDecoration(
                                  labelText: 'Caretaker phone number',
                                  hintText: '+44 7911 123456',
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                keyboardType: TextInputType.phone,
                                onChanged: (v) {
                                  AppSettings.caretakerPhone.value = v.trim();
                                  _save();
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text(
                                'Include your country code, e.g. +44 for UK, '
                                '+1 for USA.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // AI ASSISTANT
          const Text(
            'AI Assistant',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your city',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used by the AI assistant to suggest nearby pharmacies '
                    'and doctors. This is optional.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      hintText: 'e.g. London',
                      prefixIcon: const Icon(Icons.location_city),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) {
                      AppSettings.city.value = v.trim();
                      _save();
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // HELP
          const Text(
            'Help',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('How to use this app'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('How to use this app'),
                        backgroundColor: isDark ? Colors.grey[900] : null,
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _HelpSection(
                                icon: Icons.alarm,
                                title: 'Adding a reminder',
                                body:
                                    'Tap the + button on the home screen. Enter your medication name, dosage, time, and how often it repeats (daily, weekly, or once). Tap Save — you will get a notification at that time even if the app is closed.',
                              ),
                              SizedBox(height: 16),
                              _HelpSection(
                                icon: Icons.notifications_active,
                                title: 'Dismissing an alarm',
                                body:
                                    'When a reminder fires, an alarm screen appears. Tap "I\'ve taken it" to confirm you have taken your medication, or "Snooze" to be reminded again in a few minutes.',
                              ),
                              SizedBox(height: 16),
                              _HelpSection(
                                icon: Icons.people_alt_outlined,
                                title: 'Caretaker alerts',
                                body:
                                    'If an alarm is not dismissed within 5 minutes, an SMS is automatically sent to your caretaker. Set up your caretaker\'s name and phone number in the Caretaker Alert section above. Include the country code (e.g. +44 for UK).',
                              ),
                              SizedBox(height: 16),
                              _HelpSection(
                                icon: Icons.medical_information_outlined,
                                title: 'Medical information',
                                body:
                                    'The Medical Info tab provides evidence-based information about common conditions and their medications, including timing advice to help you get the most out of your treatment.',
                              ),
                              SizedBox(height: 16),
                              _HelpSection(
                                icon: Icons.smart_toy_outlined,
                                title: 'AI assistant',
                                body:
                                    'The Chat tab lets you ask questions about your medications, side effects, and general health advice. The AI knows your current reminders and can suggest nearby pharmacies if you enter your city above. It does not replace your doctor or pharmacist.',
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  subtitle: const Text('App information and version'),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Medicine Reminder',
                      applicationVersion: '1.0.0',
                      children: const [
                        Text(
                          'Medicine Reminder is a final-year university project '
                          'designed to help people manage their daily medication. '
                          'It supports scheduled notifications, caretaker SMS '
                          'alerts, evidence-based medical information, and an '
                          'AI-powered health assistant (Gemini 2.5 Flash).\n\n'
                          'Built with Flutter and Firebase.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
