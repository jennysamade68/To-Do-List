import 'package:flutter/material.dart';
import 'database.dart';
import 'notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.initialize();

  runApp(const TodoListApp());
}

// ==========================================================
// APP
// ==========================================================

class TodoListApp extends StatelessWidget {
  const TodoListApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'To-do List',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color.fromARGB(
          255,
          227,
          238,
          247,
        ),
      ),
      home: const TodoHomePage(),
    );
  }
}

// ==========================================================
// TODO MODEL
// ==========================================================

class Todo {
  final int id;
  String title;
  bool completed;

  // 📅 Date the task should be completed
  DateTime? taskDate;

  // 🔔 Optional reminder
  bool hasReminder;
  DateTime? reminderDateTime;

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
    this.taskDate,
    this.hasReminder = false,
    this.reminderDateTime,
  });
}

// ==========================================================
// TODO HOME PAGE
// ==========================================================

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

// ==========================================================
// TODO HOME PAGE STATE
// ==========================================================

class _TodoHomePageState extends State<TodoHomePage> {
  final TextEditingController taskController =
      TextEditingController();

  List<Todo> todos = [];

  bool isLoading = true;

  // ========================================================
  // INIT
  // ========================================================

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  // ========================================================
  // FORMAT REMINDER
  // ========================================================

  String _formatReminder(DateTime dateTime) {
    final day =
        dateTime.day.toString().padLeft(2, '0');

    final month =
        dateTime.month.toString().padLeft(2, '0');

    final year =
        dateTime.year.toString();

    final hour =
        dateTime.hour.toString().padLeft(2, '0');

    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year at $hour:$minute';
  }

  // ========================================================
  // LOAD TASKS
  // ========================================================

  Future<void> loadTasks() async {
    try {
      final rows = await TodoDatabase.getTasks();

      final loadedTasks = rows.map((row) {
        return Todo(
          id: row['id'] as int,
          title: row['title'] as String,
          completed: row['completed'] == 1,

          // 📅 Load task date
          taskDate: row['task_date'] != null
              ? DateTime.tryParse(
                  row['task_date'].toString(),
                )
              : null,

          // 🔔 Load reminder
          hasReminder: row['has_reminder'] == 1,

          reminderDateTime: row['reminder_datetime'] != null
              ? DateTime.tryParse(
                  row['reminder_datetime'].toString(),
                )
              : null,
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        todos = loadedTasks;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tasks: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  // ========================================================
  // ADD TASK
  // ========================================================

  Future<void> addTask() async {
    final title = taskController.text.trim();

    if (title.isEmpty) return;

    try {
      final id = await TodoDatabase.addTask(title);

      if (!mounted) return;

      setState(() {
        todos.add(
          Todo(
            id: id,
            title: title,
          ),
        );

        taskController.clear();
      });
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  // ========================================================
  // CHECK / UNCHECK
  // ========================================================

  Future<void> toggleTask(
    int index,
    bool? value,
  ) async {
    final todo = todos[index];

    final completed = value ?? false;

    setState(() {
      todo.completed = completed;
    });

    await TodoDatabase.updateTask(
      todo.id,
      completed: todo.completed,
      hasReminder: todo.hasReminder,
      reminderDateTime:
          todo.reminderDateTime?.toIso8601String(),
    );
  }

  // ========================================================
  // SET REMINDER
  // ========================================================

  Future<void> setReminder(int index) async {
    final todo = todos[index];

    final selectedDate = await showDatePicker(
      context: context,
      initialDate:
          todo.reminderDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate:
          DateTime.now().add(
        const Duration(days: 3650),
      ),
    );

    if (selectedDate == null) return;

    if (!mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime:
          todo.reminderDateTime != null
              ? TimeOfDay.fromDateTime(
                  todo.reminderDateTime!,
                )
              : TimeOfDay.now(),
    );

    if (selectedTime == null) return;

    final reminderDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (reminderDateTime.isBefore(DateTime.now())) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose a future date and time.',
          ),
        ),
      );

      return;
    }

    try {
      await NotificationService.scheduleReminder(
        id: todo.id,
        title: todo.title,
        dateTime: reminderDateTime,
      );

      if (!mounted) return;

      setState(() {
        todo.hasReminder = true;
        todo.reminderDateTime = reminderDateTime;
      });

      await TodoDatabase.updateTask(
        todo.id,
        completed: todo.completed,
        hasReminder: true,
        reminderDateTime:
            reminderDateTime.toIso8601String(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reminder set for '
            '${selectedDate.day}/'
            '${selectedDate.month}/'
            '${selectedDate.year} '
            'at ${selectedTime.format(context)}',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Error scheduling reminder: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not set reminder.',
          ),
        ),
      );
    }
  }

  // ========================================================
  // DELETE ONE TASK
  // ========================================================

  Future<void> deleteTask(int index) async {
    final todo = todos[index];

    if (todo.hasReminder) {
      await NotificationService.cancelReminder(
        todo.id,
      );
    }

    await TodoDatabase.deleteTask(todo.id);

    if (!mounted) return;

    setState(() {
      todos.removeAt(index);
    });
  }

  // ========================================================
  // DELETE CHECKED TASKS
  // ========================================================

  Future<void> deleteCheckedTasks() async {
    final checkedTasks =
        todos.where(
          (todo) => todo.completed,
        ).toList();

    for (final todo in checkedTasks) {
      if (todo.hasReminder) {
        await NotificationService.cancelReminder(
          todo.id,
        );
      }
    }

    await TodoDatabase.deleteCheckedTasks();

    if (!mounted) return;

    setState(() {
      todos.removeWhere(
        (todo) => todo.completed,
      );
    });
  }

  // ========================================================
  // DISPOSE
  // ========================================================

  @override
  void dispose() {
    taskController.dispose();
    super.dispose();
  }

  // ========================================================
  // BUILD
  // ========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F7FB),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 700,
            ),

            child: Padding(
              padding:
                  const EdgeInsets.all(24),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // ==================================================
                  // AI PREDICTIONS
                  // ==================================================

                  Align(
                    alignment:
                        Alignment.centerRight,

                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AIPredictionsPage(
                              todos: todos,
                            ),
                          ),
                        );
                      },

                      style:
                          TextButton.styleFrom(
                        foregroundColor:
                            const Color.fromARGB(255, 119, 12, 12),
                        padding:
                            EdgeInsets.zero,
                      ),

                      icon: const Icon(
                        Icons.psychology_alt,
                        size: 20,
                      ),

                      label: const Text(
                        'AI Predictions',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 0),

                  // ==================================================
                  // TITLE
                  // ==================================================

                  const Row(
                    children: [
                      Icon(
                        Icons.check_box,
                        size: 32,
                        color: Colors.blue,
                      ),

                      SizedBox(width: 10),

                      Text(
                        'To-do List',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // ADD TASK
                  // ==================================================

                  Row(
                    children: [

                      Expanded(
                        child: TextField(
                          controller:
                              taskController,

                          textInputAction:
                              TextInputAction.done,

                          onSubmitted: (_) =>
                              addTask(),

                          decoration:
                              InputDecoration(
                            hintText:
                                'Add to-do item',

                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),

                            contentPadding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      SizedBox(
                        height: 52,

                        child:
                            ElevatedButton.icon(
                          onPressed: addTask,

                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color
                                    .fromARGB(
                              255,
                              30,
                              68,
                              133,
                            ),

                            foregroundColor:
                                Colors.white,

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),

                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 22,
                            ),
                          ),

                          icon: const Icon(
                            Icons.add,
                            size: 22,
                          ),

                          label: const Text(
                            'Add',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // TASK LIST
                  // ==================================================

                  Expanded(
                    child: isLoading
                        ? const Center(
                            child:
                                CircularProgressIndicator(),
                          )
                        : todos.isEmpty
                            ? const Center(
                                child: Text(
                                  'No tasks yet',
                                  style:
                                      TextStyle(
                                    fontSize: 18,
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount:
                                    todos.length,

                                separatorBuilder:
                                    (_, _) =>
                                        const SizedBox(
                                  height: 10,
                                ),

                                itemBuilder:
                                    (context, index) {
                                  final todo =
                                      todos[index];

                                  return Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),

                                    decoration:
                                        BoxDecoration(
                                      border:
                                          Border.all(
                                        color:
                                            const Color
                                                .fromARGB(
                                          255,
                                          165,
                                          162,
                                          162,
                                        ),
                                      ),

                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        10,
                                      ),
                                    ),

                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .center,

                                      children: [

                                        // CHECKBOX
                                        Checkbox(
                                          value:
                                              todo.completed,

                                          visualDensity:
                                              VisualDensity
                                                  .compact,

                                          materialTapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,

                                          onChanged:
                                              (value) {
                                            toggleTask(
                                              index,
                                              value,
                                            );
                                          },
                                        ),

                                        // ==================================================
                                        // TASK + REMINDER DATE/TIME
                                        // ==================================================

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,

                                            mainAxisSize:
                                                MainAxisSize
                                                    .min,

                                            children: [

                                              // TASK TITLE
                                              Text(
                                                todo.title,

                                                style:
                                                    TextStyle(
                                                  fontSize:
                                                      17,

                                                  fontWeight:
                                                      FontWeight
                                                          .w500,

                                                  decoration:
                                                      todo.completed
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : TextDecoration
                                                              .none,

                                                  color:
                                                      todo.completed
                                                          ? Colors.grey
                                                          : Colors.black,
                                                ),
                                              ),

                                              // ==================================================
                                              // REMINDER DATE/TIME
                                              // ==================================================

                                              if (todo.hasReminder &&
                                                  todo.reminderDateTime !=
                                                      null)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top: 4,
                                                  ),

                                                  child:
                                                      Row(
                                                    children: [

                                                      Icon(
                                                        Icons
                                                            .notifications_none,
                                                        size:
                                                            14,
                                                        color:
                                                            Colors.orange.shade700,
                                                      ),

                                                      const SizedBox(
                                                        width:
                                                            5,
                                                      ),

                                                      Text(
                                                        _formatReminder(
                                                          todo.reminderDateTime!,
                                                        ),

                                                        style:
                                                            TextStyle(
                                                          fontSize:
                                                              12,
                                                          color:
                                                              Colors.orange.shade700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // ==================================================
                                        // REMINDER BUTTON
                                        // ==================================================

                                        IconButton(
                                          tooltip:
                                              'Reminder',

                                          onPressed:
                                              () {
                                            setReminder(
                                              index,
                                            );
                                          },

                                          icon: Icon(
                                            todo.hasReminder
                                                ? Icons
                                                    .notifications_active
                                                : Icons
                                                    .notifications_none,

                                            color: todo
                                                    .hasReminder
                                                ? Colors
                                                    .orange
                                                : Colors
                                                    .grey,
                                          ),
                                        ),                                  
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // DELETE ALL CHECKED
                  // ==================================================

                  SizedBox(
                    width:
                        double.infinity,

                    height: 50,

                    child:
                        TextButton.icon(
                      onPressed: todos.any(
                        (todo) =>
                            todo.completed,
                      )
                          ? deleteCheckedTasks
                          : null,

                      style:
                          TextButton.styleFrom(
                        foregroundColor:
                            const Color.fromARGB(
                          255,
                          48,
                          43,
                          43,
                        ),

                        padding:
                            EdgeInsets.zero,
                      ),

                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                      ),

                      label: const Text(
                        'Delete all checked',

                        style: TextStyle(
                          fontWeight:
                              FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================
// AI PREDICTIONS PAGE
// ==========================================================

class AIPredictionsPage extends StatelessWidget {
  final List<Todo> todos;

  const AIPredictionsPage({
    super.key,
    required this.todos,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Tasks with reminders
    final scheduledTasks = todos
        .where(
          (todo) =>
              !todo.completed &&
              todo.hasReminder &&
              todo.reminderDateTime != null,
        )
        .toList();

    // Sort by reminder date/time
    scheduledTasks.sort(
      (a, b) => a.reminderDateTime!
          .compareTo(b.reminderDateTime!),
    );

    // Tasks without reminders
    final unscheduledTasks = todos
        .where(
          (todo) =>
              !todo.completed &&
              (!todo.hasReminder ||
                  todo.reminderDateTime == null),
        )
        .toList();

    // Today's tasks
    final todayTasks = scheduledTasks.where((todo) {
      final date = todo.reminderDateTime!;

      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Predictions'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),

        child: ListView(
          children: [

            const Text(
              '☀️ Good afternoon 👋',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "Today's priorities",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            // ------------------------------------------------
            // TODAY'S TASKS
            // ------------------------------------------------

            if (todayTasks.isEmpty)
              const Text(
                'No scheduled tasks for today.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              )
            else
              ...todayTasks.take(3).toList().asMap().entries.map(
                (entry) {
                  final todo = entry.value;

                  String stars;

                  if (entry.key == 0) {
                    stars = '⭐⭐⭐';
                  } else if (entry.key == 1) {
                    stars = '⭐⭐';
                  } else {
                    stars = '⭐';
                  }

                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: Text(
                      '$stars ${todo.title}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            // ------------------------------------------------
            // ESTIMATED COMPLETION
            // ------------------------------------------------

            if (todayTasks.isNotEmpty)
              Text(
                '📅 ${todayTasks.length} task'
                '${todayTasks.length == 1 ? '' : 's'} scheduled today',
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                ),
              ),

            const SizedBox(height: 30),

            // ------------------------------------------------
            // UPCOMING
            // ------------------------------------------------

            if (scheduledTasks.any(
              (todo) =>
                  todo.reminderDateTime!.isAfter(
                    DateTime(
                      now.year,
                      now.month,
                      now.day,
                      23,
                      59,
                    ),
                  ),
            )) ...[
              const Text(
                '📆 Upcoming',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              ...scheduledTasks
                  .where(
                    (todo) =>
                        todo.reminderDateTime!
                            .isAfter(
                      DateTime(
                        now.year,
                        now.month,
                        now.day,
                        23,
                        59,
                      ),
                    ),
                  )
                  .take(5)
                  .map(
                    (todo) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: Text(
                        '🔔 ${todo.title}\n'
                        '    ${_formatDateTime(todo.reminderDateTime!)}',
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
            ],

            // ------------------------------------------------
            // NO SCHEDULED DATE
            // ------------------------------------------------

            if (unscheduledTasks.isNotEmpty) ...[
              const SizedBox(height: 25),

              const Text(
                '📝 No scheduled date',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              ...unscheduledTasks.map(
                (todo) => Padding(
                  padding: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: Text(
                    '⭐ ${todo.title}',
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ========================================================
  // FORMAT DATE/TIME
  // ========================================================

  static String _formatDateTime(DateTime dateTime) {
    final day =
        dateTime.day.toString().padLeft(2, '0');

    final month =
        dateTime.month.toString().padLeft(2, '0');

    final hour =
        dateTime.hour.toString().padLeft(2, '0');

    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month at $hour:$minute';
  }
}