import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AlarmsPage extends StatelessWidget {
  const AlarmsPage({super.key});

  CollectionReference<Map<String, dynamic>> _remindersRef() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reminders');
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTimeOfDay(String s) {
    try {
      final parts = s.split(':');
      if (parts.length != 2) return null;
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return TimeOfDay(hour: h, minute: m);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _remindersRef().orderBy('time').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 16),
              const Text(
                'Alarms',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your reminders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap a reminder to edit or delete it.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),

              if (docs.isEmpty)
                const Text(
                  'No reminders yet.\nAdd one from the Home page using the + button.',
                  style: TextStyle(fontSize: 13),
                ),

              ...docs.map((doc) {
                final data = doc.data();
                final title = (data['title'] ?? '').toString();
                final dosage = (data['dosage'] ?? '').toString();
                final time = (data['time'] ?? '').toString();
                final startDateStr = data['startDate'] as String?;
                final startDate = _parseDate(startDateStr);

                final subtitleParts = <String>[];
                if (dosage.trim().isNotEmpty) subtitleParts.add(dosage);
                if (startDate != null)
                  subtitleParts.add('From ${_formatDate(startDate)}');

                final subtitle =
                    subtitleParts.isEmpty
                        ? 'Tap to edit'
                        : subtitleParts.join(' · ');

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.alarm),
                    title: Text(
                      time.isEmpty ? title : '$time — $title',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showEditReminderDialog(
                        context: context,
                        docId: doc.id,
                        initialTitle: title,
                        initialDosage: dosage,
                        initialTime: time,
                        initialStartDate: startDate,
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditReminderDialog({
    required BuildContext context,
    required String docId,
    required String initialTitle,
    required String initialDosage,
    required String initialTime,
    required DateTime? initialStartDate,
  }) async {
    final titleController = TextEditingController(text: initialTitle);
    final dosageController = TextEditingController(text: initialDosage);

    TimeOfDay? selectedTime = _parseTimeOfDay(initialTime);
    DateTime? selectedDate = initialStartDate;

    bool saving = false;

    String formatTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final outerContext = context;

    await showDialog(
      context: outerContext,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: outerContext,
                initialTime: selectedTime ?? TimeOfDay.now(),
              );
              if (picked != null) setStateDialog(() => selectedTime = picked);
            }

            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: outerContext,
                initialDate: selectedDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) setStateDialog(() => selectedDate = picked);
            }

            Future<void> save() async {
              final title = titleController.text.trim();
              final dosage = dosageController.text.trim();
              final messenger = ScaffoldMessenger.of(context);
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
                await _remindersRef().doc(docId).update({
                  'title': title,
                  'dosage': dosage,
                  'time': formatTime(selectedTime!),
                  'startDate':
                      selectedDate == null ? null : _formatDate(selectedDate!),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (nav.canPop()) nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Reminder updated')),
                );
              } catch (e) {
                setStateDialog(() => saving = false);
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to update: $e')),
                );
              }
            }

            Future<void> delete() async {
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);

              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (c) => AlertDialog(
                      title: const Text('Delete reminder?'),
                      content: const Text(
                        'This will remove the reminder permanently.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
              );

              if (confirm != true) return;

              setStateDialog(() => saving = true);

              try {
                await _remindersRef().doc(docId).delete();

                if (nav.canPop()) nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Reminder deleted')),
                );
              } catch (e) {
                setStateDialog(() => saving = false);
                messenger.showSnackBar(
                  SnackBar(content: Text('Failed to delete: $e')),
                );
              }
            }

            final timeLabel =
                selectedTime == null
                    ? 'Choose a time'
                    : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              title: const Text('Edit reminder'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Medicine name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage (optional)',
                        border: OutlineInputBorder(),
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectedDate != null)
                            IconButton(
                              tooltip: 'Clear date',
                              onPressed:
                                  saving
                                      ? null
                                      : () => setStateDialog(
                                        () => selectedDate = null,
                                      ),
                              icon: const Icon(Icons.clear),
                            ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: saving ? null : pickDate,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: saving ? null : delete,
                  child: const Text('Delete'),
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

    titleController.dispose();
    dosageController.dispose();
  }
}
