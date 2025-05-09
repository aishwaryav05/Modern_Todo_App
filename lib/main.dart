import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(
    ChangeNotifierProvider(
      create: (context) => TodoProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TodoProvider>(
      builder: (context, todoProvider, child) {
        return MaterialApp(
          title: 'Modern Todo App',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness:
                  todoProvider.isDarkMode ? Brightness.dark : Brightness.light,
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}

// Todo Model
class Todo {
  String id;
  String title;
  String description;
  bool isCompleted;
  DateTime? dueDate;
  String category;
  int priority; // 1: Low, 2: Medium, 3: High

  Todo({
    required this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.dueDate,
    this.category = 'Personal',
    this.priority = 2,
  });

  Todo copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    String? category,
    int? priority,
  }) {
    return Todo(
      id: this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      category: category ?? this.category,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'dueDate': dueDate?.toIso8601String(),
      'category': category,
      'priority': priority,
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      isCompleted: json['isCompleted'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      category: json['category'],
      priority: json['priority'],
    );
  }
}

// Provider for state management
class TodoProvider with ChangeNotifier {
  List<Todo> _todos = [];
  String _filter = 'all'; // all, active, completed
  String _searchQuery = '';
  String _categoryFilter = 'all';
  bool _isDarkMode = false;
  final List<String> _categories = [
    'Personal',
    'Work',
    'Shopping',
    'Health',
    'Other'
  ];

  TodoProvider() {
    _loadTodos();
    _loadThemePreference();
  }

  List<Todo> get todos {
    List<Todo> filteredTodos = _todos;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredTodos = filteredTodos
          .where((todo) =>
              todo.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              todo.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()))
          .toList();
    }

    // Apply category filter
    if (_categoryFilter != 'all') {
      filteredTodos = filteredTodos
          .where((todo) => todo.category == _categoryFilter)
          .toList();
    }

    // Apply completion filter
    if (_filter == 'active') {
      return filteredTodos.where((todo) => !todo.isCompleted).toList();
    } else if (_filter == 'completed') {
      return filteredTodos.where((todo) => todo.isCompleted).toList();
    }

    return filteredTodos;
  }

  String get filter => _filter;
  String get searchQuery => _searchQuery;
  String get categoryFilter => _categoryFilter;
  bool get isDarkMode => _isDarkMode;
  List<String> get categories => _categories;

  void addTodo(Todo todo) {
    _todos.add(todo);
    _saveTodos();
    notifyListeners();
  }

  void updateTodo(Todo todo) {
    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      _todos[index] = todo;
      _saveTodos();
      notifyListeners();
    }
  }

  void deleteTodo(String id) {
    _todos.removeWhere((todo) => todo.id == id);
    _saveTodos();
    notifyListeners();
  }

  void toggleTodoStatus(String id) {
    final index = _todos.indexWhere((todo) => todo.id == id);
    if (index != -1) {
      _todos[index] =
          _todos[index].copyWith(isCompleted: !_todos[index].isCompleted);
      _saveTodos();
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemePreference();
    notifyListeners();
  }

  void addCategory(String category) {
    if (!_categories.contains(category)) {
      _categories.add(category);
      notifyListeners();
    }
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = prefs.getStringList('todos') ?? [];
    _todos = todosJson.map((json) => Todo.fromJson(jsonDecode(json))).toList();
    notifyListeners();
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = _todos.map((todo) => jsonEncode(todo.toJson())).toList();
    await prefs.setStringList('todos', todosJson);
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  Future<void> scheduleNotification(Todo todo) async {
    if (todo.dueDate != null) {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'todo_reminders',
        'Todo Reminders',
        channelDescription: 'Notifications for todo reminders',
        importance: Importance.max,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.schedule(
        todo.id.hashCode,
        'Todo Reminder',
        todo.title,
        todo.dueDate!,
        platformChannelSpecifics,
      );
    }
  }
}

// Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);
    final todos = todoProvider.todos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modern Todo'),
        actions: [
          IconButton(
            icon: Icon(
                todoProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              todoProvider.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: TodoSearchDelegate(todoProvider),
              );
            },
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'categories',
                child: Text('Manage Categories'),
              ),
            ],
            onSelected: (value) {
              if (value == 'categories') {
                _showCategoriesDialog(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: todoProvider.filter == 'all',
                    onSelected: (selected) {
                      if (selected) todoProvider.setFilter('all');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Active'),
                    selected: todoProvider.filter == 'active',
                    onSelected: (selected) {
                      if (selected) todoProvider.setFilter('active');
                    },
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Completed'),
                    selected: todoProvider.filter == 'completed',
                    onSelected: (selected) {
                      if (selected) todoProvider.setFilter('completed');
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text('Category:'),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: todoProvider.categoryFilter,
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('All Categories'),
                      ),
                      ...todoProvider.categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        todoProvider.setCategoryFilter(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Todo list
          Expanded(
            child: todos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No todos yet!',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a new todo to get started',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  )
                : AnimatedList(
                    initialItemCount: todos.length,
                    itemBuilder: (context, index, animation) {
                      final todo = todos[index];
                      return SlideTransition(
                        position: animation.drive(
                          Tween(
                            begin: const Offset(1, 0),
                            end: const Offset(0, 0),
                          ),
                        ),
                        child: TodoItem(todo: todo),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditTodoScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCategoriesDialog(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context, listen: false);
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manage Categories'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'New Category',
                    hintText: 'Enter category name',
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: todoProvider.categories.length,
                    itemBuilder: (context, index) {
                      final category = todoProvider.categories[index];
                      return ListTile(
                        title: Text(category),
                        trailing:
                            index < 5 // Don't allow deleting default categories
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      // Implement category deletion logic
                                    },
                                  ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  todoProvider.addCategory(controller.text);
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

// Todo Item Widget
class TodoItem extends StatelessWidget {
  final Todo todo;

  const TodoItem({Key? key, required this.todo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);

    // Priority color
    Color priorityColor;
    switch (todo.priority) {
      case 1:
        priorityColor = Colors.green;
        break;
      case 2:
        priorityColor = Colors.orange;
        break;
      case 3:
        priorityColor = Colors.red;
        break;
      default:
        priorityColor = Colors.grey;
    }

    return Dismissible(
      key: Key(todo.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        todoProvider.deleteTodo(todo.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Todo deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                todoProvider.addTodo(todo);
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditTodoScreen(todo: todo),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: priorityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        todo.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: todo.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: todo.isCompleted ? Colors.grey : null,
                        ),
                      ),
                    ),
                    Checkbox(
                      value: todo.isCompleted,
                      onChanged: (value) {
                        todoProvider.toggleTodoStatus(todo.id);
                      },
                    ),
                  ],
                ),
                if (todo.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    todo.description,
                    style: TextStyle(
                      color: todo.isCompleted ? Colors.grey : null,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(todo.category),
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceVariant,
                    ),
                    if (todo.dueDate != null)
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, y').format(todo.dueDate!),
                            style: TextStyle(
                              color: todo.dueDate!.isBefore(DateTime.now()) &&
                                      !todo.isCompleted
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Add/Edit Todo Screen
class AddEditTodoScreen extends StatefulWidget {
  final Todo? todo;

  const AddEditTodoScreen({Key? key, this.todo}) : super(key: key);

  @override
  State<AddEditTodoScreen> createState() => _AddEditTodoScreenState();
}

class _AddEditTodoScreenState extends State<AddEditTodoScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late bool _isCompleted;
  DateTime? _dueDate;
  late String _category;
  late int _priority;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.todo?.description ?? '');
    _isCompleted = widget.todo?.isCompleted ?? false;
    _dueDate = widget.todo?.dueDate;
    _category = widget.todo?.category ?? 'Personal';
    _priority = widget.todo?.priority ?? 2;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.todo == null ? 'Add Todo' : 'Edit Todo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              autofocus: widget.todo == null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Status:'),
                const SizedBox(width: 8),
                Switch(
                  value: _isCompleted,
                  onChanged: (value) {
                    setState(() {
                      _isCompleted = value;
                    });
                  },
                ),
                Text(_isCompleted ? 'Completed' : 'Active'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Due Date:'),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime:
                            TimeOfDay.fromDateTime(_dueDate ?? DateTime.now()),
                      );
                      if (time != null) {
                        setState(() {
                          _dueDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Text(
                    _dueDate == null
                        ? 'Set Due Date'
                        : DateFormat('MMM d, y - h:mm a').format(_dueDate!),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _dueDate = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Category:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _category,
                  items: todoProvider.categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _category = value;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Priority:'),
            Slider(
              value: _priority.toDouble(),
              min: 1,
              max: 3,
              divisions: 2,
              label: _getPriorityLabel(_priority),
              onChanged: (value) {
                setState(() {
                  _priority = value.toInt();
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Low'),
                Text('Medium'),
                Text('High'),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_titleController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Title cannot be empty'),
                      ),
                    );
                    return;
                  }

                  if (widget.todo == null) {
                    // Add new todo
                    final newTodo = Todo(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: _titleController.text,
                      description: _descriptionController.text,
                      isCompleted: _isCompleted,
                      dueDate: _dueDate,
                      category: _category,
                      priority: _priority,
                    );
                    todoProvider.addTodo(newTodo);

                    // Schedule notification if due date is set
                    if (_dueDate != null) {
                      todoProvider.scheduleNotification(newTodo);
                    }
                  } else {
                    // Update existing todo
                    final updatedTodo = Todo(
                      id: widget.todo!.id,
                      title: _titleController.text,
                      description: _descriptionController.text,
                      isCompleted: _isCompleted,
                      dueDate: _dueDate,
                      category: _category,
                      priority: _priority,
                    );
                    todoProvider.updateTodo(updatedTodo);

                    // Schedule notification if due date is set
                    if (_dueDate != null) {
                      todoProvider.scheduleNotification(updatedTodo);
                    }
                  }

                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    widget.todo == null ? 'Add Todo' : 'Update Todo',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      default:
        return 'Medium';
    }
  }
}

// Search Delegate
class TodoSearchDelegate extends SearchDelegate<String> {
  final TodoProvider todoProvider;

  TodoSearchDelegate(this.todoProvider);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    todoProvider.setSearchQuery(query);
    final todos = todoProvider.todos;

    return ListView.builder(
      itemCount: todos.length,
      itemBuilder: (context, index) {
        return TodoItem(todo: todos[index]);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Search for todos by title or description'),
      );
    }

    todoProvider.setSearchQuery(query);
    final todos = todoProvider.todos;

    return ListView.builder(
      itemCount: todos.length,
      itemBuilder: (context, index) {
        return TodoItem(todo: todos[index]);
      },
    );
  }
}
