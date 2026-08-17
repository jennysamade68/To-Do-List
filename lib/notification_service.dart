class NotificationService {
  static Future<void> initialize() async {}

  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required DateTime dateTime,
  }) async {}

  static Future<void> cancelReminder(int id) async {}
}