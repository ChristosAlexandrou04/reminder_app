import 'package:flutter/material.dart';
import 'settings.dart';
import 'alarms.dart';
import 'medical.dart';
import 'ai_chat.dart';
import 'notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _kPrimary = Color(0xFF4361EE);
const _kPrimaryLight = Color(0xFF7B8FF5);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  CollectionReference<Map<String, dynamic>> _remindersRef() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reminders');
  }

  // ── Date/time helpers ──────────────────────────────────────────────────────
  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _parseTime(String s) {
    try {
      final parts = s.split(':');
      if (parts.length != 2) return null;
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _occursToday(Map<String, dynamic> r) {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final repeatType = (r['repeatType'] ?? 'daily').toString();
    final startDate = _parseDate(r['startDate'] as String?);

    if (repeatType == 'daily') {
      if (startDate == null) return true;
      return !startDate.isAfter(today);
    }
    if (repeatType == 'once') {
      if (startDate == null) return false;
      return _isSameDay(startDate, today);
    }
    if (repeatType == 'weekly') {
      final weekday = r['weekday'];
      if (weekday is int) {
        final okStart = startDate == null ? true : !startDate.isAfter(today);
        return okStart && now.weekday == weekday;
      }
      return false;
    }
    return false;
  }

  DateTime? _nextOccurrenceFromReminder(Map<String, dynamic> r) {
    final timeHHmm = (r['time'] ?? '').toString();
    final t = _parseTime(timeHHmm);
    if (t == null) return null;

    final now = DateTime.now();
    final today = _startOfDay(now);
    final repeatType = (r['repeatType'] ?? 'daily').toString();
    final startDate = _parseDate(r['startDate'] as String?);

    DateTime baseDay = today;
    if (startDate != null && startDate.isAfter(today)) baseDay = startDate;

    DateTime at(DateTime d) =>
        DateTime(d.year, d.month, d.day, t.hour, t.minute);

    if (repeatType == 'daily') {
      var candidate = at(baseDay);
      if (candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }
    if (repeatType == 'once') {
      if (startDate == null) return null;
      final candidate = at(startDate);
      return candidate.isBefore(now) ? null : candidate;
    }
    if (repeatType == 'weekly') {
      final weekday = r['weekday'];
      if (weekday is! int) return null;
      DateTime d = baseDay;
      while (d.weekday != weekday) {
        d = d.add(const Duration(days: 1));
      }
      var candidate = at(d);
      if (candidate.isBefore(now)) {
        candidate = candidate.add(const Duration(days: 7));
      }
      return candidate;
    }
    return null;
  }

  // ── Add reminder dialog ────────────────────────────────────────────────────
  Future<void> _showAddReminderDialog() async {
    final titleController = TextEditingController();
    final dosageController = TextEditingController();

    TimeOfDay? selectedTime;
    DateTime? selectedDate;
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: this.context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null) setStateDialog(() => selectedTime = picked);
            }

            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: this.context,
                initialDate: now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) setStateDialog(() => selectedDate = picked);
            }

            Future<void> save() async {
              final title = titleController.text.trim();
              final dosage = dosageController.text.trim();
              final messenger = ScaffoldMessenger.of(this.context);
              final nav = Navigator.of(context);

              if (title.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a medicine name.'),
                  ),
                );
                return;
              }
              if (selectedTime == null) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Please choose a time.')),
                );
                return;
              }

              setStateDialog(() => saving = true);

              try {
                await _remindersRef().add({
                  'title': title,
                  'dosage': dosage,
                  'time': _formatTime(selectedTime!),
                  'startDate':
                      selectedDate == null ? null : _formatDate(selectedDate!),
                  'repeatType': 'daily',
                  'createdAt': FieldValue.serverTimestamp(),
                });

                NotificationService.instance.scheduleAll();
                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Reminder added')),
                );
              } catch (e) {
                if (!mounted) return;
                setStateDialog(() => saving = false);
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to save: $e')),
                );
              }
            }

            final timeLabel =
                selectedTime == null
                    ? 'Choose a time'
                    : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: const Text('Add reminder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Medicine name',
                        prefixIcon: Icon(Icons.medication_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage (optional)',
                        prefixIcon: Icon(Icons.numbers_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: const Text('Time'),
                      subtitle: Text(timeLabel),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: saving ? null : pickTime,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Start date (optional)'),
                      subtitle: Text(
                        selectedDate == null
                            ? 'Today (default)'
                            : _formatDate(selectedDate!),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: saving ? null : pickDate,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      titleController.dispose();
      dosageController.dispose();
    });
  }

  // ── Scaffold ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton:
          _currentIndex == 0
              ? FloatingActionButton(
                onPressed: _showAddReminderDialog,
                child: const Icon(Icons.add, size: 28),
              )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeContent(),
              const AlarmsPage(),
              const MedicalPage(),
            ],
          ),
          // AI chat button — bottom-left corner
          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: 'ai_chat',
              elevation: 4,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiChatPage()),
                );
              },
              child: const Icon(Icons.smart_toy, size: 26),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          } else {
            setState(() => _currentIndex = index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Alarms',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_information_outlined),
            selectedIcon: Icon(Icons.medical_information),
            label: 'Medical',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ── Home content ───────────────────────────────────────────────────────────
  Widget _buildHomeContent() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _remindersRef().orderBy('time').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            children: [
              _buildWelcomeBanner(noReminders: true),
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.medication_outlined,
                      size: 64,
                      color: _kPrimary.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No reminders yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first\nmedicine reminder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final reminders =
            docs.map((doc) {
              final data = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'title': (data['title'] ?? '').toString(),
                'time': (data['time'] ?? '').toString(),
                'dosage': (data['dosage'] ?? '').toString(),
                'startDate': data['startDate'] as String?,
                'repeatType': (data['repeatType'] ?? 'daily').toString(),
                'weekday': data['weekday'],
              };
            }).toList();

        final candidates =
            reminders
                .map(
                  (r) => {
                    'reminder': r,
                    'next': _nextOccurrenceFromReminder(r),
                  },
                )
                .where((x) => x['next'] != null)
                .toList()
              ..sort(
                (a, b) =>
                    (a['next'] as DateTime).compareTo(b['next'] as DateTime),
              );

        final nextMap =
            candidates.isEmpty
                ? null
                : candidates.first['reminder'] as Map<String, dynamic>;
        final nextWhen =
            candidates.isEmpty ? null : candidates.first['next'] as DateTime;

        final todaysReminders =
            reminders.where(_occursToday).toList()..sort(
              (a, b) => (a['time'] ?? '').toString().compareTo(
                (b['time'] ?? '').toString(),
              ),
            );

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 20),

            if (nextMap != null && nextWhen != null) ...[
              _NextReminderCard(
                title: nextMap['title'] ?? '',
                time:
                    '${nextWhen.hour.toString().padLeft(2, '0')}:${nextWhen.minute.toString().padLeft(2, '0')}',
                dosage: nextMap['dosage'] ?? '',
              ),
              const SizedBox(height: 24),
            ],

            const Text(
              "Today's Schedule",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            if (todaysReminders.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No reminders for today.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),

            ...todaysReminders.asMap().entries.map((entry) {
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + entry.key * 80),
                curve: Curves.easeOut,
                builder:
                    (context, value, child) => Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - value)),
                        child: child,
                      ),
                    ),
                child: _ScheduleItem(
                  time: entry.value['time'] ?? '',
                  title: entry.value['title'] ?? '',
                  dosage: entry.value['dosage'] ?? '',
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildWelcomeBanner({bool noReminders = false}) {
    final now = DateTime.now();
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final dateStr =
        '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    final user = FirebaseAuth.instance.currentUser;
    final name =
        (user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.split(' ').first
            : null;
    final greeting = name != null ? 'Hello, $name!' : 'Hello!';

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPrimaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                if (!noReminders) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Stay on track today',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.medication_rounded, color: Colors.white38, size: 56),
        ],
      ),
    );
  }
}

// ── Next Reminder Card ─────────────────────────────────────────────────────
class _NextReminderCard extends StatelessWidget {
  final String title;
  final String time;
  final String dosage;

  const _NextReminderCard({
    required this.title,
    required this.time,
    required this.dosage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: const BorderSide(color: _kPrimary, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.alarm, color: _kPrimary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next reminder',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dosage.isNotEmpty)
                  Text(
                    dosage,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              time,
              style: const TextStyle(
                color: _kPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Schedule Item ──────────────────────────────────────────────────────────
class _ScheduleItem extends StatelessWidget {
  final String time;
  final String title;
  final String dosage;

  const _ScheduleItem({
    required this.time,
    required this.title,
    required this.dosage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dosage.isNotEmpty)
                  Text(
                    dosage,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.medication_outlined,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
            size: 20,
          ),
        ],
      ),
    );
  }
}
