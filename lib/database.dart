import 'dart:convert';
import 'dart:html' as html;

class TodoDatabase {
  static const String _storageKey = 'todo_list_tasks';

  static List<Map<String, dynamic>> _getTasksFromStorage() {
    final data = html.window.localStorage[_storageKey];

    if (data == null || data.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(data);

    return List<Map<String, dynamic>>.from(
      decoded.map(
        (item) => Map<String, dynamic>.from(item),
      ),
    );
  }

  static void _saveTasks(
    List<Map<String, dynamic>> tasks,
  ) {
    html.window.localStorage[_storageKey] =
        jsonEncode(tasks);
  }

  // ADD TASK
  static Future<int> addTask(String title) async {
    final tasks = _getTasksFromStorage();

    int id = 1;

    if (tasks.isNotEmpty) {
      id = tasks
          .map((task) => task['id'] as int)
          .reduce((a, b) => a > b ? a : b) + 1;
    }

    tasks.add({
      'id': id,
      'title': title,
      'completed': 0,
      'has_reminder': 0,
      'reminder_datetime': null,
    });

    _saveTasks(tasks);

    return id;
  }

  // GET TASKS
  static Future<List<Map<String, dynamic>>> getTasks() async {
    return _getTasksFromStorage();
  }

  // UPDATE TASK
  static Future<void> updateTask(
    int id, {
    required bool completed,
    required bool hasReminder,
    String? reminderDateTime,
  }) async {
    final tasks = _getTasksFromStorage();

    final index = tasks.indexWhere(
      (task) => task['id'] == id,
    );

    if (index == -1) return;

    tasks[index]['completed'] =
        completed ? 1 : 0;

    tasks[index]['has_reminder'] =
        hasReminder ? 1 : 0;

    tasks[index]['reminder_datetime'] =
        reminderDateTime;

    _saveTasks(tasks);
  }

  // DELETE TASK
  static Future<void> deleteTask(int id) async {
    final tasks = _getTasksFromStorage();

    tasks.removeWhere(
      (task) => task['id'] == id,
    );

    _saveTasks(tasks);
  }

  // DELETE CHECKED TASKS
  static Future<void> deleteCheckedTasks() async {
    final tasks = _getTasksFromStorage();

    tasks.removeWhere(
      (task) => task['completed'] == 1,
    );

    _saveTasks(tasks);
  }
}