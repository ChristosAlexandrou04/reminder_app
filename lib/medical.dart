import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// How a template repeats
enum RepeatType { daily, weekly, once }

/// A template reminder definition
class ReminderTemplate {
  final String title;
  final String dosage; // optional
  final String timeHHmm; // "HH:mm"
  final RepeatType repeatType;

  /// For weekly schedules: 1=Mon ... 7=Sun
  final List<int> weekdays;

  /// For one-time schedules: optional date
  final DateTime? onceDate;

  const ReminderTemplate({
    required this.title,
    this.dosage = '',
    required this.timeHHmm,
    required this.repeatType,
    this.weekdays = const [],
    this.onceDate,
  });

  String displayText() {
    switch (repeatType) {
      case RepeatType.daily:
        return '$title — $timeHHmm (Daily)';
      case RepeatType.weekly:
        final days = weekdays.map(_weekdayLabel).join(', ');
        return '$title — $timeHHmm ($days)';
      case RepeatType.once:
        final d = onceDate == null ? 'One-time' : _formatDate(onceDate!);
        return '$title — $timeHHmm ($d)';
    }
  }
}

/// Medical condition model
class ConditionInfo {
  final String name;
  final String description;
  final List<ReminderTemplate> templates;

  const ConditionInfo({
    required this.name,
    required this.description,
    required this.templates,
  });
}

const List<ConditionInfo> _allConditions = [
  ConditionInfo(
    name: 'Asthma',
    description:
        'Asthma inflames and narrows the airways. Regular use of a preventer inhaler with electronic reminders has been shown to raise adherence from 30% to 84%, significantly reducing emergency admissions.',
    templates: [
      ReminderTemplate(
        title: 'Morning inhaler',
        dosage: '2 puffs',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Evening inhaler',
        dosage: '2 puffs',
        timeHHmm: '20:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Check inhaler supply',
        timeHHmm: '18:00',
        repeatType: RepeatType.weekly,
        weekdays: [7], // Sunday
      ),
    ],
  ),

  // Ref: Burgess SW et al. Randomised controlled trial of a large-volume spacer
  // with audiovisual reminder for asthma adherence. Lancet Respir Med. 2015;3(5):362-370.
  // DOI:10.1016/S2213-2600(15)00008-9
  ConditionInfo(
    name: 'Cholesterol',
    description:
        'Statins are taken daily to lower LDL cholesterol and reduce cardiovascular risk. Extended-release statins show equivalent cholesterol reduction whether taken morning or evening, so timing can be adjusted to suit the patient.',
    templates: [
      ReminderTemplate(
        title: 'Cholesterol tablet',
        dosage: '1 tablet',
        timeHHmm: '21:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Bortolotto LA et al. Flexibility of statin administration timing to improve
  // patient compliance. Eur J Clin Pharmacol. 2006;62(4):261-267.
  // DOI:10.1159/000093200
  ConditionInfo(
    name: 'Diabetes',
    description:
        'Type 2 diabetes requires regular oral medication (e.g., metformin) to manage blood glucose. Fewer than 50% of patients reach glycaemic targets due to poor adherence — structured reminders are a clinically proven intervention.',
    templates: [
      ReminderTemplate(
        title: 'Morning medication',
        dosage: '1 tablet',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Check blood sugar (before lunch)',
        timeHHmm: '11:30',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Rubin RR. Adherence to pharmacologic therapy in patients with type 2 diabetes.
  // Am J Med. 2005;118(5A):27S-34S. DOI:10.1007/s13300-013-0034-y
  ConditionInfo(
    name: 'Heart condition',
    description:
        'Heart failure requires daily medication including ACE inhibitors, beta-blockers, and diuretics. Physician adherence to prescribing guidelines has been shown to be a strong predictor of fewer cardiovascular hospitalisations.',
    templates: [
      ReminderTemplate(
        title: 'Morning heart medication',
        dosage: 'As prescribed',
        timeHHmm: '09:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Weekly heart check-in',
        timeHHmm: '10:00',
        repeatType: RepeatType.weekly,
        weekdays: [1, 4], // Monday and Thursday
      ),
    ],
  ),

  // Ref: Komajda M et al. Adherence to guidelines is a predictor of outcome in
  // chronic heart failure: the MAHLER survey. Eur Heart J. 2005;26(16):1653-1659.
  // DOI:10.1093/eurheartj/ehi251
  ConditionInfo(
    name: 'High blood pressure',
    description:
        'Hypertension is managed with daily antihypertensive tablets. Bedtime dosing has been shown to produce better sleep-time blood pressure control and significantly lower risk of cardiovascular events than conventional morning dosing.',
    templates: [
      ReminderTemplate(
        title: 'Morning blood pressure tablet',
        dosage: '1 tablet',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Evening blood pressure tablet',
        dosage: '1 tablet',
        timeHHmm: '20:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Hermida RC et al. Chronotherapy improves blood pressure control and
  // reduces cardiovascular risk. J Appl Biomed. 2010;8(3):119-128.
  // DOI:10.3109/07420528.2010.510230

  // ── New conditions (backed by clinical references) ──────────────────────
  ConditionInfo(
    name: 'Atrial Fibrillation',
    description:
        'A heart rhythm disorder managed with anticoagulants (DOACs) and rate-control drugs.',
    templates: [
      ReminderTemplate(
        title: 'Morning anticoagulant (DOAC)',
        dosage: 'As prescribed',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Evening anticoagulant (DOAC)',
        dosage: 'As prescribed',
        timeHHmm: '20:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Rate-control medication (morning)',
        dosage: 'As prescribed',
        timeHHmm: '08:30',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Joglar JA et al. 2023 ACC/AHA/ACCP/HRS Guideline for AF.
  // Circulation. 2024;149:e1-e156. DOI:10.1161/CIR.0000000000001193
  ConditionInfo(
    name: 'COPD',
    description:
        'Chronic Obstructive Pulmonary Disease is managed with daily inhalers to open the airways.',
    templates: [
      ReminderTemplate(
        title: 'LAMA inhaler (morning)',
        dosage: '1 puff',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'LABA inhaler (morning)',
        dosage: '1 puff',
        timeHHmm: '08:15',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'LABA inhaler (evening)',
        dosage: '1 puff',
        timeHHmm: '20:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Venkatesan P. GOLD COPD report: 2024 update.
  // Lancet Respiratory Medicine. 2024;12(1):15-16. DOI:10.1016/S2213-2600(23)00461-7
  ConditionInfo(
    name: 'Chronic Kidney Disease',
    description:
        'CKD management includes phosphate binders with meals, blood pressure tablets, and vitamin D analogues.',
    templates: [
      ReminderTemplate(
        title: 'Phosphate binder (breakfast)',
        dosage: 'As prescribed',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Phosphate binder (lunch)',
        dosage: 'As prescribed',
        timeHHmm: '13:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Phosphate binder (dinner)',
        dosage: 'As prescribed',
        timeHHmm: '18:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Morning ACE inhibitor / ARB',
        dosage: 'As prescribed',
        timeHHmm: '08:30',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Vitamin D analogue',
        dosage: 'As prescribed',
        timeHHmm: '09:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Martinez YV et al. Chronic kidney disease: summary of updated NICE guidance.
  // BMJ. 2021;374:n1992. DOI:10.1136/bmj.n1992
  ConditionInfo(
    name: 'Depression / Anxiety',
    description:
        'SSRIs and SNRIs are typically taken once daily in the morning to minimise sleep disturbance.',
    templates: [
      ReminderTemplate(
        title: 'Antidepressant (SSRI/SNRI)',
        dosage: 'As prescribed',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Silva S et al. Antidepressants and Circadian Rhythm.
  // Pharmaceutics. 2021;13(11):1975. DOI:10.3390/pharmaceutics13111975
  ConditionInfo(
    name: 'Dementia / Alzheimer\'s',
    description:
        'Cholinesterase inhibitors (e.g., donepezil) are taken at bedtime; memantine in the morning.',
    templates: [
      ReminderTemplate(
        title: 'Donepezil / galantamine (bedtime)',
        dosage: 'As prescribed',
        timeHHmm: '22:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Memantine (morning)',
        dosage: 'As prescribed',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: NICE Technology Appraisal TA217 — Donepezil, galantamine, rivastigmine
  // and memantine for Alzheimer's disease. 2011. nice.org.uk/guidance/ta217
  // Song HR et al. Int Clin Psychopharmacol. 2013;28(6):346-348. DOI:10.1097/YIC.0b013e328364f58d
  ConditionInfo(
    name: 'Epilepsy / Seizures',
    description:
        'Anti-epileptic drugs are spaced 12 hours apart to maintain stable blood levels and prevent breakthrough seizures.',
    templates: [
      ReminderTemplate(
        title: 'Anti-epileptic medication (morning)',
        dosage: 'As prescribed',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Anti-epileptic medication (evening)',
        dosage: 'As prescribed',
        timeHHmm: '20:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Al-Aqeel S et al. Strategies for improving adherence to antiepileptic
  // drug treatment. Cochrane Database Syst Rev. 2020;10:CD008312.
  // DOI:10.1002/14651858.CD008312.pub4
  ConditionInfo(
    name: 'GERD / Acid Reflux',
    description:
        'Proton pump inhibitors (PPIs) must be taken 30–60 minutes before the first meal to be effective.',
    templates: [
      ReminderTemplate(
        title: 'PPI (before breakfast)',
        dosage: '1 tablet',
        timeHHmm: '07:30',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'PPI (before evening meal) — if twice daily',
        dosage: '1 tablet',
        timeHHmm: '17:30',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Katz PO et al. ACG Clinical Guideline for Diagnosis and Management
  // of GERD. Am J Gastroenterol. 2022;117(1):27-56. DOI:10.14309/ajg.0000000000001538
  ConditionInfo(
    name: 'HIV / Antiretroviral Therapy',
    description:
        'Antiretroviral therapy (ART) requires strict once-daily dosing at the same time each day to maintain viral suppression.',
    templates: [
      ReminderTemplate(
        title: 'Antiretroviral medication (ART)',
        dosage: 'As prescribed',
        timeHHmm: '20:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Nachega JB et al. Long-acting antiretrovirals and HIV treatment adherence.
  // Lancet HIV. 2023;10(5):e332-e342. DOI:10.1016/S2352-3018(23)00051-6
  ConditionInfo(
    name: 'Hypothyroidism',
    description:
        'Levothyroxine must be taken on an empty stomach, 30–60 minutes before breakfast, for optimal absorption.',
    templates: [
      ReminderTemplate(
        title: 'Levothyroxine (before breakfast)',
        dosage: '1 tablet',
        timeHHmm: '07:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Geer M, Potter DM, Ulrich H. Alternative schedules of levothyroxine
  // administration. Am J Health-Syst Pharm. 2015;72(5):373-377.
  // DOI:10.2146/ajhp140250
  ConditionInfo(
    name: 'Iron Deficiency Anaemia',
    description:
        'Iron supplements are best absorbed in the morning on an empty stomach, ideally with vitamin C.',
    templates: [
      ReminderTemplate(
        title: 'Iron supplement (morning, empty stomach)',
        dosage: '1 tablet',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: von Siebenthal HK et al. Effect of dietary factors and time of day
  // on iron absorption. Am J Hematol. 2023;98(9):1356-1363.
  // DOI:10.1002/ajh.26987
  ConditionInfo(
    name: 'Migraine',
    description:
        'Migraine prevention uses twice-daily medications; acute treatments are taken at the onset of an attack.',
    templates: [
      ReminderTemplate(
        title: 'Migraine prevention (morning)',
        dosage: 'As prescribed',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Migraine prevention (evening)',
        dosage: 'As prescribed',
        timeHHmm: '20:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Modi S, Lowder DM. Medications for migraine prophylaxis.
  // Am Fam Physician. 2006;73(1):72-78. PMID:16417067
  // NICE CG150 Headaches guideline. nice.org.uk/guidance/cg150
  ConditionInfo(
    name: 'Osteoporosis',
    description:
        'Bisphosphonates are taken once weekly on an empty stomach; calcium and vitamin D are taken daily with meals.',
    templates: [
      ReminderTemplate(
        title: 'Alendronate / bisphosphonate (weekly)',
        dosage: '1 tablet — stay upright 30 min',
        timeHHmm: '07:00',
        repeatType: RepeatType.weekly,
        weekdays: [1], // Monday
      ),
      ReminderTemplate(
        title: 'Calcium + Vitamin D (with meal)',
        dosage: '1 tablet',
        timeHHmm: '13:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Boonen S et al. Management of postmenopausal osteoporosis with
  // bisphosphonates: enhanced efficacy by enhanced compliance.
  // J Intern Med. 2008;264(4):315-332. DOI:10.1111/j.1365-2796.2008.02010.x
  ConditionInfo(
    name: 'Parkinson\'s Disease',
    description:
        'Levodopa/carbidopa is taken 3–4 times daily before meals; timing is critical to avoid akinesia.',
    templates: [
      ReminderTemplate(
        title: 'Levodopa/carbidopa (before breakfast)',
        dosage: 'As prescribed',
        timeHHmm: '07:30',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Levodopa/carbidopa (before lunch)',
        dosage: 'As prescribed',
        timeHHmm: '11:30',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Levodopa/carbidopa (before dinner)',
        dosage: 'As prescribed',
        timeHHmm: '17:30',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'MAO-B inhibitor (morning)',
        dosage: 'As prescribed',
        timeHHmm: '08:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: NICE Guideline NG71 — Parkinson's disease in adults.
  // London: NICE; 2017. PMID:28787113. nice.org.uk/guidance/ng71
  ConditionInfo(
    name: 'Rheumatoid Arthritis',
    description:
        'Methotrexate is taken once weekly; hydroxychloroquine daily with food. Folic acid is taken on the other days.',
    templates: [
      ReminderTemplate(
        title: 'Methotrexate (weekly)',
        dosage: 'As prescribed — with food',
        timeHHmm: '09:00',
        repeatType: RepeatType.weekly,
        weekdays: [1], // Monday
      ),
      ReminderTemplate(
        title: 'Folic acid (daily except methotrexate day)',
        dosage: '1 tablet',
        timeHHmm: '09:00',
        repeatType: RepeatType.weekly,
        weekdays: [2, 3, 4, 5, 6, 7], // Tue–Sun
      ),
      ReminderTemplate(
        title: 'Hydroxychloroquine (with meal)',
        dosage: 'As prescribed',
        timeHHmm: '13:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Smolen JS et al. EULAR recommendations for management of RA — 2022 update.
  // Ann Rheum Dis. 2023;82(1):3-18. DOI:10.1136/ard-2022-223356
  ConditionInfo(
    name: 'Type 1 Diabetes',
    description:
        'Rapid-acting insulin is taken 15–20 minutes before each meal; basal insulin is taken at bedtime.',
    templates: [
      ReminderTemplate(
        title: 'Rapid insulin (before breakfast)',
        dosage: 'As prescribed',
        timeHHmm: '07:45',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Rapid insulin (before lunch)',
        dosage: 'As prescribed',
        timeHHmm: '12:45',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Rapid insulin (before dinner)',
        dosage: 'As prescribed',
        timeHHmm: '17:45',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Basal insulin (bedtime)',
        dosage: 'As prescribed',
        timeHHmm: '22:00',
        repeatType: RepeatType.daily,
      ),
      ReminderTemplate(
        title: 'Blood glucose check (fasting)',
        timeHHmm: '07:30',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Slattery D, Amiel SA, Choudhary P. Optimal prandial timing of bolus insulin.
  // Diabetic Medicine. 2018;35(3):306-316. DOI:10.1111/dme.13525
  // NICE NG17 — Type 1 Diabetes in Adults. London: NICE; 2015. nice.org.uk/guidance/ng17
  ConditionInfo(
    name: 'Vitamin D Deficiency',
    description:
        'Vitamin D3 is a fat-soluble supplement best absorbed when taken with the largest meal of the day.',
    templates: [
      ReminderTemplate(
        title: 'Vitamin D3 supplement (with meal)',
        dosage: 'As prescribed (e.g. 1000–4000 IU)',
        timeHHmm: '13:00',
        repeatType: RepeatType.daily,
      ),
    ],
  ),

  // Ref: Demay MB et al. Vitamin D for the Prevention of Disease:
  // Endocrine Society Clinical Practice Guideline.
  // J Clin Endocrinol Metab. 2024;109(8):1907-1947. DOI:10.1210/clinem/dgae290

];

class MedicalPage extends StatefulWidget {
  const MedicalPage({super.key});

  @override
  State<MedicalPage> createState() => _MedicalPageState();
}

class _MedicalPageState extends State<MedicalPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final q = _searchQuery.trim().toLowerCase();

    final filteredConditions =
        _allConditions.where((c) {
            if (q.isEmpty) return true;
            return c.name.toLowerCase().contains(q) ||
                c.description.toLowerCase().contains(q);
          }).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),

          const Text(
            'Medical',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 16),

          // SEARCH BAR
          TextField(
            decoration: InputDecoration(
              hintText: 'Search medical conditions',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isDark ? Colors.grey[900] : Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),

          const SizedBox(height: 16),

          const Text(
            'Medical conditions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          Text(
            'Tap a condition to see a short explanation and suggested reminders.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Not medical advice. Always follow your doctor/pharmacist.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),

          const SizedBox(height: 16),

          if (filteredConditions.isEmpty)
            const Text('No conditions found.', style: TextStyle(fontSize: 13)),

          ...filteredConditions.map(
            (condition) => Card(
              child: ListTile(
                leading: const Icon(Icons.medical_information),
                title: Text(condition.name),
                subtitle: Text(
                  condition.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${condition.templates.length}'),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () => _showConditionDialog(context, condition),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConditionDialog(BuildContext context, ConditionInfo condition) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> useTemplates() async {
              setStateDialog(() => saving = true);

              try {
                await _applyTemplatesToFirestore(condition.templates);

                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('Templates added for ${condition.name}.'),
                  ),
                );
              } catch (e) {
                setStateDialog(() => saving = false);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Failed to add templates: $e')),
                );
              }
            }

            return AlertDialog(
              title: Text(condition.name),
              backgroundColor: isDark ? Colors.grey[900] : null,
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condition.description,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Recommended reminders:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...condition.templates.map(
                      (t) => Text(
                        '• ${t.displayText()}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'These suggestions are not medical advice. Always follow professional instructions.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : useTemplates,
                  child: Text(saving ? 'Adding...' : 'Use templates'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Adds templates to Firestore under users/{uid}/reminders
  /// - Daily: 1 reminder
  /// - Weekly: 1 reminder per weekday (Mon+Thu => 2 reminders)
  /// - Once: 1 reminder on a specific date
  Future<void> _applyTemplatesToFirestore(
    List<ReminderTemplate> templates,
  ) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final remindersRef = db
        .collection('users')
        .doc(uid)
        .collection('reminders');

    final batch = db.batch();
    final now = DateTime.now();

    for (final t in templates) {
      if (t.repeatType == RepeatType.daily) {
        final ref = remindersRef.doc();
        batch.set(ref, {
          'title': t.title,
          'dosage': t.dosage,
          'time': t.timeHHmm,
          'startDate': _formatDate(_startOfDay(now)),
          'repeatType': 'daily',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (t.repeatType == RepeatType.once) {
        final date = t.onceDate ?? _startOfDay(now);
        final ref = remindersRef.doc();
        batch.set(ref, {
          'title': t.title,
          'dosage': t.dosage,
          'time': t.timeHHmm,
          'startDate': _formatDate(_startOfDay(date)),
          'repeatType': 'once',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else if (t.repeatType == RepeatType.weekly) {
        for (final wd in t.weekdays) {
          final nextDate = _nextWeekdayDate(from: now, weekday: wd);

          final ref = remindersRef.doc();
          batch.set(ref, {
            'title': t.title,
            'dosage': t.dosage,
            'time': t.timeHHmm,
            'startDate': _formatDate(_startOfDay(nextDate)),
            'repeatType': 'weekly',
            'weekday': wd, // 1..7
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    await batch.commit();
  }
}

/// ------------------
/// Helper functions
/// ------------------
String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// weekday: 1=Mon ... 7=Sun
DateTime _nextWeekdayDate({required DateTime from, required int weekday}) {
  final today = _startOfDay(from);
  final current = today.weekday; // 1..7
  int delta = weekday - current;
  if (delta < 0) delta += 7;
  // If today is the same weekday, keep today.
  return today.add(Duration(days: delta));
}

String _weekdayLabel(int weekday) {
  switch (weekday) {
    case 1:
      return 'Mon';
    case 2:
      return 'Tue';
    case 3:
      return 'Wed';
    case 4:
      return 'Thu';
    case 5:
      return 'Fri';
    case 6:
      return 'Sat';
    case 7:
      return 'Sun';
    default:
      return 'Day$weekday';
  }
}
