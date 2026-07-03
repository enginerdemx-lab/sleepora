import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/localization_service.dart';

/// Koyu temalı, tekerlekli (Cupertino) saat seçici — alttan açılan şık bir sayfa.
/// Hem onboarding hatırlatma adımında hem de Ayarlar'da kullanılır.
Future<TimeOfDay?> showSleepTimePicker(
  BuildContext context,
  TimeOfDay initial,
) async {
  final loc = LocalizationService();
  DateTime temp = DateTime(2020, 1, 1, initial.hour, initial.minute);
  TimeOfDay? result;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1025),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 14, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: Color(0xFFFBBF24), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        loc.t('ReminderMain'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      result = TimeOfDay(hour: temp.hour, minute: temp.minute);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        loc.t('BtnSave'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 196,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: temp,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  return result;
}
