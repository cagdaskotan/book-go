import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidResult =
        await android?.requestNotificationsPermission() ?? true;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosResult =
        await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
        true;
    return androidResult && iosResult;
  }

  /// Günlük hatırlatıcıyı kurar.
  ///
  /// [title] ve [body] verilmezse genel metin kullanılır. Seri durumuna göre
  /// konuşan metinler için [refreshStreakReminder] çağrılır.
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    String? title,
    String? body,
  }) async {
    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      7001,
      title ?? 'Kitabın seni bekliyor',
      body ?? 'Birkaç sayfa okuyup serini korumaya ne dersin?',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reading_reminders',
          'Okuma hatırlatıcıları',
          channelDescription: 'Günlük okuma alışkanlığı hatırlatmaları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reading_reminder_enabled', true);
    await prefs.setInt('reading_reminder_hour', hour);
    await prefs.setInt('reading_reminder_minute', minute);
  }

  /// Hatırlatıcı metnini okuma serisine göre tazeler.
  ///
  /// Arka planda çalışan bir servisimiz yok (ve olmasını da istemiyoruz),
  /// bu yüzden metin uygulama her açıldığında ve her kayıt sonrası yeniden
  /// kuruluyor. Pratikte bu yeterli: kullanıcı gün içinde uygulamaya
  /// girdiyse akşamki hatırlatma güncel seriyi biliyor.
  ///
  /// Hatırlatıcı kapalıysa hiçbir şey yapmaz — kullanıcı kapatmışsa
  /// arkasından açmayız.
  Future<void> refreshStreakReminder({
    required int currentStreak,
    required bool readToday,
  }) async {
    final current = await settings();
    if (!current.enabled) return;

    final (title, body) = _streakMessage(
      streak: currentStreak,
      readToday: readToday,
    );
    await scheduleDaily(
      hour: current.hour,
      minute: current.minute,
      title: title,
      body: body,
    );
  }

  /// Seri durumuna göre bildirim metni.
  ///
  /// Suçlayıcı dil yok: "serini kaybettin" demek kullanıcıyı uygulamadan
  /// soğutuyor. Kayıp yaşandıysa yeniden başlamaya davet ediyoruz.
  static (String, String) _streakMessage({
    required int streak,
    required bool readToday,
  }) {
    if (readToday) {
      return (
        'Bugünü tamamladın',
        streak > 1
            ? '$streak günlük serin sürüyor. Yarın görüşürüz.'
            : 'Yarın da birkaç sayfa, olur mu?',
      );
    }
    if (streak >= 2) {
      return (
        'Serin tehlikede',
        '$streak günlük serini korumak için birkaç sayfa yeter.',
      );
    }
    if (streak == 1) {
      return ('Serini büyütelim', 'Bugün de okursan seri ikiye çıkıyor.');
    }
    return ('Bilge seni bekliyor', 'Birkaç sayfayla yeniden başlayabilirsin.');
  }

  Future<void> cancelDaily() async {
    await initialize();
    await _plugin.cancel(7001);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reading_reminder_enabled', false);
  }

  Future<ReminderSettings> settings() async {
    final prefs = await SharedPreferences.getInstance();
    return ReminderSettings(
      enabled: prefs.getBool('reading_reminder_enabled') ?? false,
      hour: prefs.getInt('reading_reminder_hour') ?? 21,
      minute: prefs.getInt('reading_reminder_minute') ?? 0,
    );
  }
}

class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
  });
  final bool enabled;
  final int hour;
  final int minute;
}
