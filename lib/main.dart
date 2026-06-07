import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_settings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';
import 'alarm_service.dart';
import 'notification_service.dart';

const _kPrimary = Color(0xFF4361EE);
const _kPrimaryDark = Color(0xFF738EFF);

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AlarmService.instance.navigatorKey = navigatorKey;
  await NotificationService.instance.init();
  runApp(const ReminderApp());
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.listenable,
      builder: (context, _) {
        final darkMode = AppSettings.isDarkMode.value;
        final largeButtons = AppSettings.largeButtons.value;
        final highContrast = AppSettings.highContrast.value;
        final textScale = AppSettings.textScale.value;

        ThemeData baseLight = ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _kPrimary,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F6FF),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFFF4F6FF),
            elevation: 0,
            centerTitle: false,
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shadowColor: _kPrimary.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimary,
              side: const BorderSide(color: _kPrimary),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: _kPrimary.withValues(alpha: 0.15),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kPrimary,
                );
              }
              return GoogleFonts.poppins(fontSize: 12, color: Colors.grey);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: _kPrimary);
              }
              return const IconThemeData(color: Colors.grey);
            }),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
        );

        ThemeData baseDark = ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _kPrimary,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFF0F0F1A),
            elevation: 0,
            centerTitle: false,
            titleTextStyle: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shadowColor: Colors.black45,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: const Color(0xFF1C1C2E),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF1C1C2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E2E42)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2E2E42)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimaryDark, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kPrimaryDark,
              side: const BorderSide(color: _kPrimaryDark),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF1C1C2E),
            indicatorColor: _kPrimaryDark.withValues(alpha: 0.2),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kPrimaryDark,
                );
              }
              return GoogleFonts.poppins(fontSize: 12, color: Colors.grey);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: _kPrimaryDark);
              }
              return const IconThemeData(color: Colors.grey);
            }),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: _kPrimaryDark,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
        );

        ThemeData applyAccessibility(ThemeData theme) {
          final bool isDark = theme.brightness == Brightness.dark;

          final listTileTheme = ListTileThemeData(
            contentPadding:
                largeButtons
                    ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                    : const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            minVerticalPadding: largeButtons ? 16 : 8,
          );

          final elevatedButtonTheme = ElevatedButtonThemeData(
            style: theme.elevatedButtonTheme.style?.copyWith(
              padding:
                  largeButtons
                      ? WidgetStateProperty.all(
                        const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                      )
                      : null,
              textStyle:
                  largeButtons
                      ? WidgetStateProperty.all(
                        GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                      : null,
            ),
          );

          ThemeData t = theme.copyWith(
            listTileTheme: listTileTheme,
            elevatedButtonTheme: elevatedButtonTheme,
            dividerColor:
                highContrast
                    ? (isDark ? Colors.white70 : Colors.black54)
                    : theme.dividerColor,
          );

          if (highContrast) {
            final base = t.textTheme;
            t = t.copyWith(
              textTheme: base.copyWith(
                bodyLarge: base.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                bodyMedium: base.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          return t;
        }

        final lightTheme = applyAccessibility(baseLight);
        final darkTheme = applyAccessibility(baseDark);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Medicine Reminder',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
          navigatorKey: navigatorKey,
          home: const AuthGate(),
        );
      },
    );
  }
}
