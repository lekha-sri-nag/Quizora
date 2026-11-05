import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'dart:math';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const QuizoraApp());
}
class CustomQuiz {
  final String id;
  final String title;
  final String category;
  final DateTime createdAt;
  final List<Map<String, dynamic>> questions;

  CustomQuiz({
    required this.id,
    required this.title,
    required this.category,
    required this.createdAt,
    required this.questions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'questions': questions,
    };
  }

  factory CustomQuiz.fromMap(Map<String, dynamic> map) {
    return CustomQuiz(
      id: map['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? 'Untitled Quiz',
      category: map['category'] as String? ?? 'General Knowledge',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      questions: (map['questions'] as List<dynamic>?)?.map((q) {
            final qMap = Map<String, dynamic>.from(q as Map);
            return {
              'question': qMap['question'] as String? ?? '',
              'options': (qMap['options'] as List<dynamic>?)
                      ?.map((o) => o.toString())
                      .toList() ??
                  <String>[],
              'answer': qMap['answer'] as int? ?? 0,
              'explanation': qMap['explanation'] as String? ?? '',
            };
          }).toList() ??
          [],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CustomQuiz.fromJson(String source) =>
      CustomQuiz.fromMap(jsonDecode(source) as Map<String, dynamic>);
}


class QuizAttempt {
  final String id;
  final String title;
  final String category;
  final int score;
  final int totalQuestions;
  final int percentage;
  final DateTime completedAt;

  QuizAttempt({
    required this.id,
    required this.title,
    required this.category,
    required this.score,
    required this.totalQuestions,
    required this.percentage,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'score': score,
      'totalQuestions': totalQuestions,
      'percentage': percentage,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  factory QuizAttempt.fromMap(Map<String, dynamic> map) {
    return QuizAttempt(
      id: map['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: map['title'] as String? ?? 'Untitled Quiz',
      category: map['category'] as String? ?? 'General Knowledge',
      score: (map['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (map['totalQuestions'] as num?)?.toInt() ?? 0,
      percentage: (map['percentage'] as num?)?.toInt() ?? 0,
      completedAt: DateTime.tryParse(
            map['completedAt'] as String? ?? '',
          ) ??
          DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory QuizAttempt.fromJson(String source) =>
      QuizAttempt.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

class CustomQuizStorage {
  static const String _storageKey = 'quizora_saved_custom_quizzes';

  static Future<List<CustomQuiz>> loadQuizzes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      final List<dynamic> decodedList = jsonDecode(jsonString) as List<dynamic>;
      return decodedList
          .map((item) =>
              CustomQuiz.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('Error loading custom quizzes: $e');
      return [];
    }
  }

  static Future<bool> saveQuiz(CustomQuiz quiz) async {
    try {
      final quizzes = await loadQuizzes();
      final index = quizzes.indexWhere((q) => q.id == quiz.id);
      if (index >= 0) {
        quizzes[index] = quiz;
      } else {
        quizzes.insert(0, quiz);
      }
      return await _saveList(quizzes);
    } catch (e) {
      debugPrint('Error saving custom quiz: $e');
      return false;
    }
  }

  static Future<bool> deleteQuiz(String id) async {
    try {
      final quizzes = await loadQuizzes();
      quizzes.removeWhere((q) => q.id == id);
      return await _saveList(quizzes);
    } catch (e) {
      debugPrint('Error deleting custom quiz: $e');
      return false;
    }
  }

  static Future<bool> _saveList(List<CustomQuiz> quizzes) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> rawList =
        quizzes.map((q) => q.toMap()).toList();
    return await prefs.setString(_storageKey, jsonEncode(rawList));
  }
}


class QuizHistoryStorage {
  static const String _storageKey = 'quizora_quiz_history';

  static Future<List<QuizAttempt>> loadAttempts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decodedList = jsonDecode(jsonString);
      return decodedList
          .map((item) => QuizAttempt.fromMap(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList();
    } catch (e) {
      debugPrint('Error loading quiz history: $e');
      return [];
    }
  }

  static Future<bool> saveAttempt(QuizAttempt attempt) async {
    try {
      final attempts = await loadAttempts();
      attempts.insert(0, attempt);

      final prefs = await SharedPreferences.getInstance();
      final jsonList = attempts.map((item) => item.toMap()).toList();

      return await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving quiz history: $e');
      return false;
    }
  }
}
class QuestionRotationStorage {
  static const String _storageKey = 'quizora_question_rotation';

  static Future<List<Map<String, dynamic>>> selectQuestions({
    required String category,
    required String difficulty,
    required List<Map<String, dynamic>> allQuestions,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedData = prefs.getString(_storageKey);
      final Map<String, dynamic> rotationData = savedData == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(savedData));

      final key = '${category}_$difficulty';

      List<int> usedIndices = [];
      if (rotationData[key] != null) {
        usedIndices = List<int>.from(rotationData[key]);
      }

      List<int> availableIndices = List.generate(
        allQuestions.length,
        (index) => index,
      ).where((index) => !usedIndices.contains(index)).toList();

      // Start a new cycle when fewer than 10 questions remain.
      if (availableIndices.length < 10) {
        usedIndices = [];
        availableIndices = List.generate(
          allQuestions.length,
          (index) => index,
        );
      }

      availableIndices.shuffle();

      final selectedIndices = availableIndices.take(10).toList();
      usedIndices.addAll(selectedIndices);

      rotationData[key] = usedIndices;

      await prefs.setString(_storageKey, jsonEncode(rotationData));

      return selectedIndices
          .map((index) => allQuestions[index])
          .toList();
    } catch (e) {
      debugPrint('Error rotating quiz questions: $e');

      final shuffledQuestions = List<Map<String, dynamic>>.from(allQuestions)
        ..shuffle();

      return shuffledQuestions.take(10).toList();
    }
  }
}

class QuizoraApp extends StatelessWidget {
  final Widget? testHome;

  const QuizoraApp({super.key, this.testHome});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quizora',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6558F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FC),
        fontFamily: 'Arial',
      ),
    home: testHome ?? const AuthGate(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<CustomQuiz> _savedQuizzes = [];
  bool _isLoading = true;
  List<QuizAttempt> _quizHistory = [];

  bool _isHistoryLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedQuizzes();
     _loadQuizHistory();
  }

  Future<void> _loadSavedQuizzes() async {
    final quizzes = await CustomQuizStorage.loadQuizzes();
    if (mounted) {
      setState(() {
        _savedQuizzes = quizzes;
        _isLoading = false;
      });
    }
  }
  Future<void> _loadQuizHistory() async {
  final attempts = await QuizHistoryStorage.loadAttempts();

  if (mounted) {
    setState(() {
      _quizHistory = attempts;
      _isHistoryLoading = false;
    });
  }
}
Future<void> _openQuizHistory() async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const QuizHistoryScreen(),
    ),
  );

  await _loadQuizHistory();
}

int get _totalQuizzes => _quizHistory.length;

int get _averageScore {
  if (_quizHistory.isEmpty) return 0;

  final total = _quizHistory.fold<int>(
    0,
    (sum, attempt) => sum + attempt.percentage,
  );

  return (total / _quizHistory.length).round();
}

int get _bestScore {
  if (_quizHistory.isEmpty) return 0;

  return _quizHistory
      .map((attempt) => attempt.percentage)
      .reduce((a, b) => a > b ? a : b);
}

  Future<void> _openCreateQuiz() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateQuizScreen(),
      ),
    );
    _loadSavedQuizzes();
  }

  Future<void> _openCategoryQuiz(String category) async {
  final selectedDifficulty = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (context) => DifficultySelectionScreen(
        category: category,
      ),
    ),
  );

  if (!mounted || selectedDifficulty == null) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => QuizScreen(
        category: category,
        difficulty: selectedDifficulty,
      ),
    ),
  );
}

  Future<void> _playCustomQuiz(CustomQuiz quiz) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          category: quiz.category,
          customTitle: quiz.title,
          customQuestions: quiz.questions,
        ),
      ),
    );
    _loadSavedQuizzes();
  }

  Future<void> _deleteCustomQuiz(CustomQuiz quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: Text('Are you sure you want to delete "${quiz.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CustomQuizStorage.deleteQuiz(quiz.id);
      await _loadSavedQuizzes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${quiz.title}"'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6558F5),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.psychology_alt_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quizora',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF252344),
                        ),
                      ),
                      Text(
                        'LEARN • PLAY • GROW',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: Color(0xFF77758D),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                                                      IconButton(
                    tooltip: 'My Profile',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                    icon: const CircleAvatar(
                      radius: 23,
                      backgroundColor: Color(0xFFE9E6FF),
                      child: Icon(
                        Icons.person_rounded,
                        color: Color(0xFF6558F5),
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Hello, Learner! 👋',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF252344),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ready to challenge your mind today?',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF77758D),
                ),
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(23),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6558F5),
                      Color(0xFF9185FF),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '⭐  FEATURED QUIZ',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Knowledge is\nYour Superpower!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        height: 1.25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Explore, learn, and discover what you know.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(
                          Icons.help_outline_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '10 Questions',
                          style: TextStyle(color: Colors.white),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => _openCategoryQuiz('General Knowledge'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF6558F5),
                          ),
                          child: const Text('Start Quiz  →'),
                        ),
                      ],
                    ),
                  ],
                ),
                            ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openCreateQuiz,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Create Your Own Quiz'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6558F5),
                    side: const BorderSide(
                      color: Color(0xFF6558F5),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),


              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openQuizHistory,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('View Quiz History'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6558F5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),


              const SizedBox(height: 25),

const Text(
  'Your Performance',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Color(0xFF252344),
  ),
),

const SizedBox(height: 15),

if (_isHistoryLoading)
  const Center(
    child: CircularProgressIndicator(),
  )
else
  Row(
    children: [
      Expanded(
        child: _PerformanceCard(
          title: 'Quizzes',
          value: '$_totalQuizzes',
          icon: Icons.quiz_rounded,
          color: const Color(0xFF6558F5),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _PerformanceCard(
          title: 'Average',
          value: '$_averageScore%',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFF079B85),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _PerformanceCard(
          title: 'Best Score',
          value: '$_bestScore%',
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFED8B37),
        ),
      ),
    ],
  ),

const SizedBox(height: 30),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(

                    'Saved Quizzes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF252344),
                    ),
                  ),
                  Text(
                    _isLoading
                        ? 'Loading...'
                        : '${_savedQuizzes.length} ${_savedQuizzes.length == 1 ? 'quiz' : 'quizzes'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF77758D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (_savedQuizzes.isEmpty && !_isLoading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: const Color(0xFFECEAF5)),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        color: Color(0xFF77758D),
                        size: 26,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No saved quizzes yet. Create one above to play later!',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF77758D),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._savedQuizzes.map(
                  (quiz) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CustomQuizCard(
                      quiz: quiz,
                      onPlay: () => _playCustomQuiz(quiz),
                      onDelete: () => _deleteCustomQuiz(quiz),
                    ),
                  ),
                ),

              const SizedBox(height: 30),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Explore Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF252344),
                    ),
                  ),
                  Text(
                    '5 topics',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF77758D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _CategoryCard(
                title: 'Programming',
                subtitle: 'Code your way to success',
                icon: Icons.code_rounded,
                color: const Color(0xFF6558F5),
                questionCount: '10 Questions',
                onTap: () => _openCategoryQuiz('Programming'),
              ),
              const SizedBox(height: 12),
              _CategoryCard(
                title: 'Computer Science',
                subtitle: 'Discover how technology works',
                icon: Icons.memory_rounded,
                color: const Color(0xFF079B85),
                questionCount: '10 Questions',
                onTap: () => _openCategoryQuiz('Computer Science'),
              ),
              const SizedBox(height: 12),
              _CategoryCard(
                title: 'General Knowledge',
                subtitle: 'Explore the world around you',
                icon: Icons.public_rounded,
                color: const Color(0xFFED8B37),
                questionCount: '10 Questions',
                onTap: () => _openCategoryQuiz('General Knowledge'),
              ),
              const SizedBox(height: 12),
              _CategoryCard(
                title: 'Aptitude',
                subtitle: 'Sharpen your logical thinking',
                icon: Icons.psychology_rounded,
                color: const Color(0xFF4776E6),
                questionCount: '10 Questions',
                onTap: () => _openCategoryQuiz('Aptitude'),
              ),
              const SizedBox(height: 12),
              _CategoryCard(
                title: 'English',
                subtitle: 'Improve your grammar and vocabulary',
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFE05A87),
                questionCount: '10 Questions',
                onTap: () => _openCategoryQuiz('English'),
              ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFECEAF5)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Color(0xFFED8B37),
                      size: 30,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Small steps, big progress!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF252344),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Every question is a chance to learn.',
                            style: TextStyle(
                              color: Color(0xFF77758D),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _PerformanceCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFECEAF5),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 27,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF77758D),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomQuizCard extends StatelessWidget {
  const _CustomQuizCard({
    required this.quiz,
    required this.onPlay,
    required this.onDelete,
  });

  final CustomQuiz quiz;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6558F5);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFECEAF5),
        ),
      ),
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.quiz_rounded,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF252344),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9E6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            quiz.category,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6558F5),
                            ),
                          ),
                        ),
                        Text(
                          'Created ${_formatDate(quiz.createdAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF77758D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${quiz.questions.length} Questions',
                      style: const TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFF77758D),
                  size: 22,
                ),
                tooltip: 'Delete Quiz',
                onPressed: onDelete,
              ),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: onPlay,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Play',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.play_arrow_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.questionCount,
    this.onTap,
  });

  final VoidCallback? onTap;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String questionCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: const Color(0xFFECEAF5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF252344),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF77758D),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    questionCount,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class DifficultySelectionScreen extends StatelessWidget {
  final String category;

  const DifficultySelectionScreen({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Difficulty'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              category,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose your challenge level',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            _buildDifficultyButton(
              context,
              'Easy',
              'Beginner-friendly questions',
            ),
            const SizedBox(height: 16),
            _buildDifficultyButton(
              context,
              'Medium',
              'Moderately challenging questions',
            ),
            const SizedBox(height: 16),
            _buildDifficultyButton(
              context,
              'Hard',
              'Test your advanced knowledge',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    BuildContext context,
    String difficulty,
    String description,
  ) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          difficulty,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.pop(context, difficulty);
        },
      ),
    );
  }
}


class QuizScreen extends StatefulWidget {
  final String category;
  final String? customTitle;
  final List<Map<String, dynamic>>? customQuestions;
  final String difficulty;

  const QuizScreen({
    super.key,
    this.category = 'Programming',
    this.customTitle,
    this.customQuestions,
    this.difficulty = 'Easy',
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}


class _QuizScreenState extends State<QuizScreen> {
  int currentQuestion = 0;
  int? selectedAnswer;
  int score = 0;
  Timer? questionTimer;
  int remainingSeconds = 30;
  List<int?> userAnswers = [];
  List<Map<String, dynamic>> quizQuestions = [];
bool isQuizLoading = true;
    @override
  void initState() {
    super.initState();
    _initializeQuiz();
  }

  Future<void> _initializeQuiz() async {
    final allQuestions = questions;

    if (widget.customQuestions != null) {
      quizQuestions = List<Map<String, dynamic>>.from(allQuestions);
    } else {
      quizQuestions = await QuestionRotationStorage.selectQuestions(
        category: widget.category,
        difficulty: widget.difficulty,
        allQuestions: allQuestions,
      );
    }

    if (!mounted) return;

    setState(() {
      userAnswers = List<int?>.filled(quizQuestions.length, null);
      isQuizLoading = false;
    });

    startTimer();
  }
  @override
  void dispose() {
   questionTimer?.cancel();
   super.dispose();
  }
  void startTimer() {
  questionTimer?.cancel();
  remainingSeconds = 30;

  questionTimer = Timer.periodic(
    const Duration(seconds: 1),
    (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        timer.cancel();
        // We'll add automatic question advancement next.
        if (mounted) {
          nextQuestion();
        }
      }
    },
  );
}

List<Map<String, dynamic>> get questions {
  if (widget.customQuestions != null) {
    return widget.customQuestions!;
  }

  switch (widget.category) {
case 'Programming':
  if (widget.difficulty == 'Medium') {
    return [
      {
        'question': 'What is the time complexity of binary search?',
        'options': ['O(n)', 'O(log n)', 'O(n²)', 'O(1)'],
        'answer': 1,
      },
      {
        'question': 'Which principle allows a class to inherit properties from another class?',
        'options': ['Encapsulation', 'Inheritance', 'Polymorphism', 'Abstraction'],
        'answer': 1,
      },
      {
        'question': 'Which data structure uses LIFO?',
        'options': ['Queue', 'Array', 'Stack', 'Linked List'],
        'answer': 2,
      },
      {
        'question': 'What is the purpose of a constructor?',
        'options': [
          'Destroy an object',
          'Initialize an object',
          'Loop through data',
          'Declare an interface',
        ],
        'answer': 1,
      },
      {
        'question': 'Which sorting algorithm has an average time complexity of O(n log n)?',
        'options': ['Bubble Sort', 'Selection Sort', 'Merge Sort', 'Linear Search'],
        'answer': 2,
      },
      {
        'question': 'What does API stand for?',
        'options': [
          'Application Programming Interface',
          'Advanced Program Integration',
          'Application Process Internet',
          'Automated Programming Instruction',
        ],
        'answer': 0,
      },
      {
        'question': 'Which keyword is used to handle exceptions in Dart?',
        'options': ['catch', 'switch', 'repeat', 'define'],
        'answer': 0,
      },
      {
        'question': 'What is recursion?',
        'options': [
          'A function calling itself',
          'A loop running forever',
          'A variable declaration',
          'A class importing another class',
        ],
        'answer': 0,
      },
      {
        'question': 'Which SQL command retrieves data from a table?',
        'options': ['INSERT', 'UPDATE', 'SELECT', 'DELETE'],
        'answer': 2,
      },
      {
        'question': 'Which concept hides internal implementation details?',
        'options': ['Inheritance', 'Abstraction', 'Iteration', 'Compilation'],
        'answer': 1,
      },
          {
        'question': 'What is the main purpose of a constructor in Dart?',
        'options': [
          'To initialize an object',
          'To delete a class',
          'To stop a program',
          'To import a package',
        ],
        'answer': 0,
      },
      {
        'question': 'Which data structure follows the LIFO principle?',
        'options': ['Queue', 'Stack', 'Tree', 'Graph'],
        'answer': 1,
      },
      {
        'question': 'What does API stand for?',
        'options': [
          'Application Programming Interface',
          'Advanced Program Integration',
          'Automated Program Internet',
          'Application Process Input',
        ],
        'answer': 0,
      },
      {
        'question': 'Which Dart collection stores key-value pairs?',
        'options': ['List', 'Set', 'Map', 'Queue'],
        'answer': 2,
      },
      {
        'question': 'What is the purpose of the break statement?',
        'options': [
          'To exit a loop or switch',
          'To declare a variable',
          'To create a class',
          'To import a library',
        ],
        'answer': 0,
      },
      {
        'question': 'Which principle allows a class to acquire properties of another class?',
        'options': ['Encapsulation', 'Inheritance', 'Abstraction', 'Recursion'],
        'answer': 1,
      },
      {
        'question': 'What does HTTP stand for?',
        'options': [
          'HyperText Transfer Protocol',
          'HighText Transmission Program',
          'Hyper Transfer Text Process',
          'Host Transfer Technology Protocol',
        ],
        'answer': 0,
      },
      {
        'question': 'Which sorting algorithm repeatedly compares adjacent elements?',
        'options': ['Merge Sort', 'Quick Sort', 'Bubble Sort', 'Heap Sort'],
        'answer': 2,
      },
      {
        'question': 'What is the purpose of exception handling?',
        'options': [
          'To manage runtime errors',
          'To increase screen brightness',
          'To create database tables',
          'To remove all variables',
        ],
        'answer': 0,
      },
      {
        'question': 'Which keyword is used to handle an exception in Dart?',
        'options': ['catch', 'switch', 'import', 'extends'],
        'answer': 0,
      },
      {
        'question': 'What is the average time complexity of searching in a hash table?',
        'options': ['O(n)', 'O(log n)', 'O(1)', 'O(n²)'],
        'answer': 2,
      },
      {
        'question': 'Which data structure follows the FIFO principle?',
        'options': ['Stack', 'Queue', 'Tree', 'Graph'],
        'answer': 1,
      },
      {
        'question': 'What is method overriding?',
        'options': [
          'Redefining an inherited method in a subclass',
          'Creating multiple variables',
          'Deleting a method',
          'Calling a method repeatedly',
        ],
        'answer': 0,
      },
      {
        'question': 'Which operator performs null-aware access in Dart?',
        'options': ['?.', '??', '!', '=='],
        'answer': 0,
      },
      {
        'question': 'What is the purpose of an abstract class?',
        'options': [
          'To provide a base for subclasses',
          'To store only numbers',
          'To execute loops',
          'To create user input',
        ],
        'answer': 0,
      },
      {
        'question': 'Which algorithm uses divide and conquer to sort elements?',
        'options': ['Bubble Sort', 'Merge Sort', 'Linear Search', 'Selection Sort'],
        'answer': 1,
      },
      {
        'question': 'What does JSON commonly represent?',
        'options': [
          'A data-interchange format',
          'A programming language',
          'An operating system',
          'A database engine',
        ],
        'answer': 0,
      },
      {
        'question': 'Which Flutter widget manages mutable state?',
        'options': ['StatelessWidget', 'StatefulWidget', 'Text', 'Icon'],
        'answer': 1,
      },
      {
        'question': 'What is the purpose of the async keyword in Dart?',
        'options': [
          'To define an asynchronous function',
          'To create a constant',
          'To declare a class',
          'To stop execution permanently',
        ],
        'answer': 0,
      },
      {
        'question': 'Which search algorithm requires sorted data?',
        'options': ['Linear Search', 'Binary Search', 'Depth First Search', 'Hash Search'],
        'answer': 1,
      },
];
}
  if (widget.difficulty == 'Hard') {
    return [
      {
        'question': 'What is the worst-case time complexity of Quick Sort?',
        'options': ['O(n)', 'O(n log n)', 'O(n²)', 'O(log n)'],
        'answer': 2,
      },
      {
        'question': 'Which data structure is commonly used in Dijkstra’s algorithm?',
        'options': ['Stack', 'Priority Queue', 'Linked List', 'Hash Set'],
        'answer': 1,
      },
      {
        'question': 'What is a deadlock in operating systems?',
        'options': [
          'A process completing successfully',
          'Processes waiting indefinitely for resources',
          'A memory allocation technique',
          'A CPU scheduling algorithm',
        ],
        'answer': 1,
      },
      {
        'question': 'Which design pattern ensures only one instance of a class?',
        'options': ['Factory', 'Observer', 'Singleton', 'Adapter'],
        'answer': 2,
      },
      {
        'question': 'What is the average lookup complexity of a hash table?',
        'options': ['O(n)', 'O(log n)', 'O(1)', 'O(n²)'],
        'answer': 2,
      },
      {
        'question': 'Which algorithm finds the minimum spanning tree using sorted edges?',
        'options': ['Dijkstra', 'Kruskal', 'Binary Search', 'Floyd-Warshall'],
        'answer': 1,
      },
      {
        'question': 'What does ACID stand for in database transactions?',
        'options': [
          'Atomicity, Consistency, Isolation, Durability',
          'Accuracy, Control, Integrity, Data',
          'Access, Consistency, Integration, Durability',
          'Atomicity, Control, Isolation, Dependency',
        ],
        'answer': 0,
      },
      {
        'question': 'Which technique prevents multiple threads from accessing a critical section simultaneously?',
        'options': ['Recursion', 'Synchronization', 'Inheritance', 'Compilation'],
        'answer': 1,
      },
      {
        'question': 'What is the space complexity of an iterative binary search?',
        'options': ['O(n)', 'O(log n)', 'O(1)', 'O(n²)'],
        'answer': 2,
      },
      {
        'question': 'Which principle allows objects of different classes to be treated through a common interface?',
        'options': ['Encapsulation', 'Polymorphism', 'Compilation', 'Recursion'],
        'answer': 1,
      },
       ];
  }

  // EASY DIFFICULTY QUESTIONS
  return [
    {
      'question': 'Which programming language is used with Flutter?',
      'options': ['Java', 'Dart', 'Python', 'C++'],
      'answer': 1,
    },
    {
      'question': 'Which keyword declares a variable in Dart?',
      'options': ['var', 'define', 'let', 'dim'],
      'answer': 0,
    },
    {
      'question': 'Which widget arranges children vertically in Flutter?',
      'options': ['Row', 'Stack', 'Column', 'Container'],
      'answer': 2,
    },
    {
      'question': 'What does HTML stand for?',
      'options': [
        'Hyper Text Markup Language',
        'High Text Machine Language',
        'Hyper Transfer Markup Language',
        'Home Tool Markup Language',
      ],
      'answer': 0,
    },
    {
      'question': 'Which symbol is used for single-line comments in Dart?',
      'options': ['#', '//', '/*', '<!--'],
      'answer': 1,
    },
    {
      'question': 'Which data type stores true or false values?',
      'options': ['String', 'int', 'bool', 'double'],
      'answer': 2,
    },
    {
      'question': 'Which loop repeats while a condition is true?',
      'options': ['if', 'while', 'switch', 'class'],
      'answer': 1,
    },
    {
      'question': 'What is the extension of a Dart source file?',
      'options': ['.java', '.py', '.dart', '.html'],
      'answer': 2,
    },
    {
      'question': 'Which operator is used for addition?',
      'options': ['-', '*', '+', '/'],
      'answer': 2,
    },
    {
      'question': 'Which keyword is used to return a value from a function?',
      'options': ['class', 'return', 'import', 'switch'],
      'answer': 1,
    },
        {
      'question': 'Which company developed the Dart programming language?',
      'options': ['Microsoft', 'Google', 'Apple', 'Meta'],
      'answer': 1,
    },
    {
      'question': 'What is a variable used for?',
      'options': [
        'Storing data',
        'Deleting programs',
        'Displaying images',
        'Connecting networks',
      ],
      'answer': 0,
    },
    {
      'question': 'Which symbol is used to end a statement in Dart?',
      'options': [':', ';', ',', '.'],
      'answer': 1,
    },
    {
      'question': 'Which keyword defines a class in Dart?',
      'options': ['object', 'struct', 'class', 'function'],
      'answer': 2,
    },
    {
      'question': 'Which data type stores whole numbers in Dart?',
      'options': ['String', 'int', 'bool', 'double'],
      'answer': 1,
    },
    {
      'question': 'Which function is the usual entry point of a Dart program?',
      'options': ['start()', 'run()', 'main()', 'init()'],
      'answer': 2,
    },
    {
      'question': 'Which operator checks equality?',
      'options': ['=', '==', '!=', '+='],
      'answer': 1,
    },
    {
      'question': 'Which keyword is used to create an object in Dart?',
      'options': ['new', 'make', 'object', 'create'],
      'answer': 0,
    },
    {
      'question': 'Which collection stores elements in an ordered sequence?',
      'options': ['List', 'Set', 'Map', 'bool'],
      'answer': 0,
    },
    {
      'question': 'What does IDE stand for?',
      'options': [
        'Integrated Development Environment',
        'Internal Data Editor',
        'Internet Design Engine',
        'Integrated Database Extension',
      ],
      'answer': 0,
    },
    {
      'question': 'Which Flutter widget displays text?',
      'options': ['Image', 'Text', 'Row', 'Scaffold'],
      'answer': 1,
    },
    {
      'question': 'Which keyword makes a variable unchangeable in Dart?',
      'options': ['final', 'change', 'update', 'modify'],
      'answer': 0,
    },
    {
      'question': 'Which operator is used for multiplication?',
      'options': ['+', '-', '*', '/'],
      'answer': 2,
    },
    {
      'question': 'Which statement is used for decision-making?',
      'options': ['for', 'if', 'import', 'return'],
      'answer': 1,
    },
    {
      'question': 'What does UI stand for?',
      'options': [
        'User Interface',
        'Universal Internet',
        'Unique Input',
        'User Integration',
      ],
      'answer': 0,
    },
    {
      'question': 'Which keyword imports a library in Dart?',
      'options': ['include', 'using', 'import', 'library'],
      'answer': 2,
    },
    {
      'question': 'Which Flutter widget provides a horizontal layout?',
      'options': ['Column', 'Row', 'Stack', 'Center'],
      'answer': 1,
    },
    {
      'question': 'Which file usually contains the main Flutter application code?',
      'options': ['main.dart', 'index.html', 'style.css', 'package.json'],
      'answer': 0,
    },
    {
      'question': 'Which keyword is used to create a constant in Dart?',
      'options': ['var', 'dynamic', 'const', 'static'],
      'answer': 2,
    },
    {
      'question': 'Which loop is commonly used to repeat code a fixed number of times?',
      'options': ['if', 'for', 'switch', 'try'],
      'answer': 1,
    },

    {
      'question': 'What is the worst-case time complexity of Binary Search?',
      'options': ['O(1)', 'O(log n)', 'O(n)', 'O(n log n)'],
      'answer': 1,
    },
    {
      'question': 'Which data structure is used in Depth First Search?',
      'options': ['Queue', 'Stack', 'Heap', 'Hash Map'],
      'answer': 1,
    },
    {
      'question': 'What is the time complexity of Merge Sort?',
      'options': ['O(n)', 'O(n log n)', 'O(n²)', 'O(log n)'],
      'answer': 1,
    },
    {
      'question': 'Which principle allows a subclass to provide its own implementation of a method?',
      'options': ['Encapsulation', 'Method Overriding', 'Compilation', 'Iteration'],
      'answer': 1,
    },
    {
      'question': 'What is a race condition?',
      'options': [
        'Two or more operations access shared data and the result depends on timing',
        'A program running without errors',
        'A database backup process',
        'A sorting technique',
      ],
      'answer': 0,
    },
    {
      'question': 'Which algorithm finds the shortest path in a graph with non-negative edge weights?',
      'options': ['DFS', 'Dijkstra', 'Bubble Sort', 'Linear Search'],
      'answer': 1,
    },
    {
      'question': 'What is the space complexity of an iterative Binary Search?',
      'options': ['O(1)', 'O(n)', 'O(log n)', 'O(n²)'],
      'answer': 0,
    },
    {
      'question': 'Which memory area stores dynamically allocated objects in many programming languages?',
      'options': ['Stack', 'Heap', 'Register', 'Cache'],
      'answer': 1,
    },
    {
      'question': 'What is the main purpose of a mutex?',
      'options': [
        'To sort data',
        'To protect shared resources from simultaneous access',
        'To allocate memory',
        'To compress files',
      ],
      'answer': 1,
    },
    {
      'question': 'Which database property ensures that a transaction is completed entirely or not at all?',
      'options': ['Consistency', 'Isolation', 'Atomicity', 'Durability'],
      'answer': 2,
    },
    {
      'question': 'What is the average time complexity of Quick Sort?',
      'options': ['O(n)', 'O(n log n)', 'O(n²)', 'O(log n)'],
      'answer': 1,
    },
    {
      'question': 'Which data structure is commonly used to implement a priority queue efficiently?',
      'options': ['Heap', 'Stack', 'Array only', 'Linked List only'],
      'answer': 0,
    },
    {
      'question': 'What does polymorphism allow in object-oriented programming?',
      'options': [
        'One interface to represent different underlying forms',
        'A class to contain only constants',
        'A program to run without memory',
        'A method to execute only once',
      ],
      'answer': 0,
    },
    {
      'question': 'Which technique helps prevent SQL injection?',
      'options': [
        'Using longer table names',
        'Parameterized queries',
        'Disabling all indexes',
        'Using plain-text passwords',
      ],
      'answer': 1,
    },
    {
      'question': 'What is the purpose of a hash function in a hash table?',
      'options': [
        'To convert a key into an index',
        'To sort all keys alphabetically',
        'To encrypt the entire database',
        'To create a linked list',
      ],
      'answer': 0,
    },
    {
      'question': 'Which traversal visits the left subtree, root, then right subtree in a binary tree?',
      'options': ['Preorder', 'Postorder', 'Inorder', 'Level order'],
      'answer': 2,
    },
    {
      'question': 'What is the primary purpose of garbage collection?',
      'options': [
        'To remove unused objects from memory',
        'To compile source code',
        'To increase network speed',
        'To encrypt variables',
      ],
      'answer': 0,
    },
    {
      'question': 'Which design principle recommends that a class should have only one reason to change?',
      'options': [
        'Open-Closed Principle',
        'Single Responsibility Principle',
        'Dependency Inversion Principle',
        'Interface Segregation Principle',
      ],
      'answer': 1,
    },
    {
      'question': 'What is the worst-case time complexity of searching in an unbalanced Binary Search Tree?',
      'options': ['O(1)', 'O(log n)', 'O(n)', 'O(n log n)'],
      'answer': 2,
    },
    {
      'question': 'Which sorting algorithm guarantees O(n log n) worst-case time complexity?',
      'options': ['Bubble Sort', 'Insertion Sort', 'Merge Sort', 'Selection Sort'],
      'answer': 2,
    },

  ];

    case 'Computer Science':
  if (widget.difficulty == 'Medium') {
    return [
      {
        'question': 'Which scheduling algorithm gives each process a fixed time slot?',
        'options': ['FCFS', 'Round Robin', 'SJF', 'Priority'],
        'answer': 1,
      },
      {
        'question': 'Which data structure is used in BFS?',
        'options': ['Stack', 'Queue', 'Tree', 'Heap'],
        'answer': 1,
      },
      {
        'question': 'Which layer of the OSI model handles routing?',
        'options': ['Physical', 'Data Link', 'Network', 'Session'],
        'answer': 2,
      },
      {
        'question': 'What is the binary representation of decimal 10?',
        'options': ['1001', '1010', '1100', '1110'],
        'answer': 1,
      },
      {
        'question': 'Which SQL command removes a table?',
        'options': ['DELETE', 'REMOVE', 'DROP', 'CLEAR'],
        'answer': 2,
      },
      {
        'question': 'Which memory is volatile?',
        'options': ['ROM', 'Hard Disk', 'RAM', 'SSD'],
        'answer': 2,
      },
      {
        'question': 'Which protocol is used to send emails?',
        'options': ['HTTP', 'SMTP', 'FTP', 'DNS'],
        'answer': 1,
      },
      {
        'question': 'Which key uniquely identifies a database record?',
        'options': ['Foreign Key', 'Primary Key', 'Candidate Value', 'Index'],
        'answer': 1,
      },
      {
        'question': 'What is the main purpose of an operating system?',
        'options': ['Manage resources', 'Create websites', 'Design hardware', 'Write programs'],
        'answer': 0,
      },
      {
        'question': 'Which topology connects all devices to a central hub?',
        'options': ['Bus', 'Ring', 'Star', 'Mesh'],
        'answer': 2,
      },
            {
        'question': 'Which data structure is used for implementing recursion?',
        'options': ['Queue', 'Stack', 'Array', 'Graph'],
        'answer': 1,
      },
      {
        'question': 'Which SQL clause is used to filter grouped records?',
        'options': ['WHERE', 'ORDER BY', 'HAVING', 'GROUP BY'],
        'answer': 2,
      },
      {
        'question': 'Which OSI layer is responsible for end-to-end communication?',
        'options': ['Network', 'Transport', 'Physical', 'Data Link'],
        'answer': 1,
      },
      {
        'question': 'What is the average time complexity of searching in a hash table?',
        'options': ['O(n)', 'O(log n)', 'O(1)', 'O(n²)'],
        'answer': 2,
      },
      {
        'question': 'Which traversal visits the root between left and right subtrees?',
        'options': ['Preorder', 'Inorder', 'Postorder', 'Level order'],
        'answer': 1,
      },
      {
        'question': 'Which SQL command modifies existing records?',
        'options': ['INSERT', 'UPDATE', 'CREATE', 'DROP'],
        'answer': 1,
      },
      {
        'question': 'Which protocol translates domain names into IP addresses?',
        'options': ['FTP', 'SMTP', 'DNS', 'HTTP'],
        'answer': 2,
      },
      {
        'question': 'Which memory is typically used for CPU cache?',
        'options': ['SRAM', 'Hard Disk', 'Optical Disk', 'Magnetic Tape'],
        'answer': 0,
      },
      {
        'question': 'Which algorithm follows the divide-and-conquer approach?',
        'options': ['Linear Search', 'Merge Sort', 'Bubble Sort', 'Selection Sort'],
        'answer': 1,
      },
      {
        'question': 'What is the purpose of a foreign key in a database?',
        'options': [
          'Uniquely identify every database',
          'Connect related tables',
          'Delete duplicate records',
          'Sort table records',
        ],
        'answer': 1,
      },
      {
        'question': 'Which scheduling algorithm may cause starvation?',
        'options': ['Round Robin', 'FCFS', 'Priority Scheduling', 'FIFO'],
        'answer': 2,
      },
      {
        'question': 'Which network device forwards packets between networks?',
        'options': ['Hub', 'Router', 'Repeater', 'Switch'],
        'answer': 1,
      },
      {
        'question': 'Which data structure is commonly used in a priority queue?',
        'options': ['Heap', 'Stack', 'Linked List only', 'Array only'],
        'answer': 0,
      },
      {
        'question': 'What does ACID stand for in database transactions?',
        'options': [
          'Atomicity, Consistency, Isolation, Durability',
          'Access, Control, Integrity, Data',
          'Automatic, Consistent, Indexed, Distributed',
          'Atomic, Central, Internal, Direct',
        ],
        'answer': 0,
      },
      {
        'question': 'Which technique allows multiple processes to share CPU time?',
        'options': ['Multiprogramming', 'Formatting', 'Defragmentation', 'Encryption'],
        'answer': 0,
      },
      {
        'question': 'Which HTTP status code indicates a successful request?',
        'options': ['404', '500', '200', '301'],
        'answer': 2,
      },
      {
        'question': 'Which data structure is used in depth-first search?',
        'options': ['Queue', 'Stack', 'Hash Table', 'Heap'],
        'answer': 1,
      },
      {
        'question': 'Which command displays the current working directory in Linux?',
        'options': ['ls', 'cd', 'pwd', 'mkdir'],
        'answer': 2,
      },
      {
        'question': 'What is the primary purpose of an index in a database?',
        'options': [
          'Increase storage capacity',
          'Speed up data retrieval',
          'Remove all duplicate data',
          'Encrypt database records',
        ],
        'answer': 1,
      },
      {
        'question': 'Which type of testing checks individual software components?',
        'options': ['System Testing', 'Acceptance Testing', 'Unit Testing', 'Load Testing'],
        'answer': 2,
      },
    ];
  }

  if (widget.difficulty == 'Hard') {
    return [
      {
        'question': 'Which page replacement algorithm replaces the least recently used page?',
        'options': ['FIFO', 'LRU', 'Optimal', 'FCFS'],
        'answer': 1,
      },
      {
        'question': 'What is the worst-case time complexity of AVL tree search?',
        'options': ['O(1)', 'O(log n)', 'O(n)', 'O(n log n)'],
        'answer': 1,
      },
      {
        'question': 'Which normal form removes transitive dependencies?',
        'options': ['1NF', '2NF', '3NF', '4NF'],
        'answer': 2,
      },
      {
        'question': 'Which algorithm is used to find shortest paths with negative edge weights?',
        'options': ['Dijkstra', 'Bellman-Ford', 'Prim', 'Kruskal'],
        'answer': 1,
      },
      {
        'question': 'What does a semaphore primarily control?',
        'options': ['Memory size', 'Process synchronization', 'File naming', 'CPU speed'],
        'answer': 1,
      },
      {
        'question': 'Which protocol provides reliable, connection-oriented communication?',
        'options': ['UDP', 'IP', 'TCP', 'ICMP'],
        'answer': 2,
      },
      {
        'question': 'What is the maximum number of edges in a simple undirected graph with n vertices?',
        'options': ['n', 'n-1', 'n(n-1)/2', 'n²'],
        'answer': 2,
      },
      {
        'question': 'Which compiler phase performs syntax checking?',
        'options': ['Lexical analysis', 'Syntax analysis', 'Code generation', 'Optimization'],
        'answer': 1,
      },
      {
        'question': 'Which RAID level uses disk mirroring?',
        'options': ['RAID 0', 'RAID 1', 'RAID 5', 'RAID 6'],
        'answer': 1,
      },
      {
        'question': 'Which condition is necessary for deadlock?',
        'options': ['Mutual exclusion', 'Compilation', 'Paging', 'Caching'],
        'answer': 0,
      },
            {
        'question': 'Which algorithm finds the minimum spanning tree using a greedy approach?',
        'options': ['Dijkstra', 'Kruskal', 'Bellman-Ford', 'Floyd-Warshall'],
        'answer': 1,
      },
      {
        'question': 'What is the time complexity of binary search in a balanced search space?',
        'options': ['O(n)', 'O(log n)', 'O(n log n)', 'O(1)'],
        'answer': 1,
      },
      {
        'question': 'Which data structure is used in Dijkstra’s algorithm?',
        'options': ['Stack', 'Queue', 'Priority Queue', 'Linked List'],
        'answer': 2,
      },
      {
        'question': 'Which normal form eliminates partial dependencies?',
        'options': ['1NF', '2NF', '3NF', 'BCNF'],
        'answer': 1,
      },
      {
        'question': 'Which algorithm detects strongly connected components?',
        'options': ['Kruskal', 'Kosaraju', 'Prim', 'Binary Search'],
        'answer': 1,
      },
      {
        'question': 'What is the worst-case time complexity of Quick Sort?',
        'options': ['O(n)', 'O(log n)', 'O(n log n)', 'O(n²)'],
        'answer': 3,
      },
      {
        'question': 'Which memory management technique divides memory into fixed-size blocks?',
        'options': ['Segmentation', 'Paging', 'Compaction', 'Spooling'],
        'answer': 1,
      },
      {
        'question': 'Which parsing technique is used by many top-down parsers?',
        'options': ['LR parsing', 'LL parsing', 'Shift-reduce parsing', 'Operator precedence only'],
        'answer': 1,
      },
      {
        'question': 'Which scheduling algorithm can cause starvation?',
        'options': ['FCFS', 'Round Robin', 'Priority Scheduling', 'FIFO'],
        'answer': 2,
      },
      {
        'question': 'Which database property ensures committed transactions survive system failures?',
        'options': ['Atomicity', 'Consistency', 'Isolation', 'Durability'],
        'answer': 3,
      },
      {
        'question': 'Which algorithm is commonly used for all-pairs shortest paths?',
        'options': ['Floyd-Warshall', 'Prim', 'Kruskal', 'Binary Search'],
        'answer': 0,
      },
      {
        'question': 'Which type of database index is commonly implemented using a B+ tree?',
        'options': ['Primary memory index', 'Database disk index', 'Hash-only index', 'Bitmap-only index'],
        'answer': 1,
      },
      {
        'question': 'What is the purpose of a compiler symbol table?',
        'options': ['Store variable and function information', 'Execute machine code', 'Manage network packets', 'Allocate disk space'],
        'answer': 0,
      },
      {
        'question': 'Which protocol is used to securely transfer files over SSH?',
        'options': ['FTP', 'TFTP', 'SFTP', 'SMTP'],
        'answer': 2,
      },
      {
        'question': 'Which cryptographic technique uses a public and a private key?',
        'options': ['Symmetric encryption', 'Asymmetric encryption', 'Hashing', 'Encoding'],
        'answer': 1,
      },
      {
        'question': 'Which graph traversal algorithm uses a queue?',
        'options': ['DFS', 'BFS', 'Backtracking', 'Topological sorting only'],
        'answer': 1,
      },
      {
        'question': 'Which technique helps prevent SQL injection?',
        'options': ['String concatenation', 'Prepared statements', 'Disabling indexes', 'Using SELECT *'],
        'answer': 1,
      },
      {
        'question': 'Which operating system concept allows multiple processes to share physical memory safely?',
        'options': ['Virtual memory', 'Spooling', 'Batch processing', 'Polling'],
        'answer': 0,
      },
      {
        'question': 'Which testing technique examines software without executing the program?',
        'options': ['Black-box testing', 'Static testing', 'Load testing', 'Integration testing'],
        'answer': 1,
      },
      {
        'question': 'Which distributed systems problem occurs when replicas temporarily contain different values?',
        'options': ['Data inconsistency', 'Compilation error', 'Stack overflow', 'Memory fragmentation'],
        'answer': 0,
      },

    ];
  }

  return [
        {
          'question': 'What does CPU stand for?',
          'options': [
            'Central Processing Unit',
            'Computer Personal Unit',
            'Central Program Utility',
            'Control Processing User',
          ],
          'answer': 0,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'Which data structure follows FIFO?',
          'options': ['Stack', 'Tree', 'Queue', 'Graph'],
          'answer': 2,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'Which part displays visual output?',
          'options': ['Keyboard', 'Mouse', 'Monitor', 'Microphone'],
          'answer': 2,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'Which device is used to enter text?',
          'options': ['Monitor', 'Keyboard', 'Speaker', 'Projector'],
          'answer': 1,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'What does RAM stand for?',
          'options': [
            'Read Access Memory',
            'Random Access Memory',
            'Run Active Memory',
            'Read Active Module',
          ],
          'answer': 1,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'Which data structure follows LIFO?',
          'options': ['Queue', 'Stack', 'Tree', 'Graph'],
          'answer': 1,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'What does HTML stand for?',
          'options': [
            'HyperText Markup Language',
            'HighText Machine Language',
            'Hyper Transfer Main Link',
            'Home Tool Markup Language',
          ],
          'answer': 0,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'Which device connects different networks?',
          'options': ['Keyboard', 'Printer', 'Router', 'Monitor'],
          'answer': 2,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'Which of these is an operating system?',
          'options': ['Python', 'Linux', 'HTML', 'SQL'],
          'answer': 1,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'What is the main function of an operating system?',
          'options': [
            'Manage computer resources',
            'Print documents only',
            'Browse websites only',
            'Create hardware',
          ],
          'answer': 0,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'What is the full form of CPU?',
          'options': [
            'Central Processing Unit',
            'Computer Personal Unit',
            'Central Program Utility',
            'Control Processing User',
          ],
          'answer': 0,
          'explanation': 'CPU stands for Central Processing Unit.',
        },
        {
          'question': 'Which component is known as the brain of a computer?',
          'options': ['Monitor', 'CPU', 'Keyboard', 'Mouse'],
          'answer': 1,
          'explanation': 'The CPU processes instructions and controls computer operations.',
        },
        {
          'question': 'Which memory is volatile?',
          'options': ['ROM', 'Hard Disk', 'RAM', 'DVD'],
          'answer': 2,
          'explanation': 'RAM loses its stored data when power is turned off.',
        },
        {
          'question': 'Which number system uses only 0 and 1?',
          'options': ['Decimal', 'Binary', 'Octal', 'Hexadecimal'],
          'answer': 1,
          'explanation': 'The binary number system uses two digits: 0 and 1.',
        },
        {
          'question': 'Which device is used to enter text into a computer?',
          'options': ['Monitor', 'Printer', 'Keyboard', 'Speaker'],
          'answer': 2,
          'explanation': 'A keyboard is an input device used to enter text.',
        },
        {
          'question': 'Which of these is an output device?',
          'options': ['Mouse', 'Keyboard', 'Scanner', 'Monitor'],
          'answer': 3,
          'explanation': 'A monitor displays information from the computer.',
        },
        {
          'question': 'What is the full form of USB?',
          'options': [
            'Universal Serial Bus',
            'United System Board',
            'Universal Storage Box',
            'Unified Serial Base',
          ],
          'answer': 0,
          'explanation': 'USB stands for Universal Serial Bus.',
        },
        {
          'question': 'Which software manages computer hardware and software resources?',
          'options': ['Web Browser', 'Operating System', 'Text Editor', 'Compiler'],
          'answer': 1,
          'explanation': 'An operating system manages hardware and software resources.',
        },
        {
          'question': 'Which of these is a web browser?',
          'options': ['Linux', 'Google Chrome', 'Python', 'MySQL'],
          'answer': 1,
          'explanation': 'Google Chrome is a web browser used to access websites.',
        },
        {
          'question': 'What is the full form of URL?',
          'options': [
            'Uniform Resource Locator',
            'Universal Record Link',
            'Unified Resource Language',
            'User Reference Location',
          ],
          'answer': 0,
          'explanation': 'URL stands for Uniform Resource Locator.',
        },
        {
          'question': 'Which device connects a computer to a wired network?',
          'options': ['NIC', 'Monitor', 'Speaker', 'Projector'],
          'answer': 0,
          'explanation': 'A Network Interface Card (NIC) provides network connectivity.',
        },
        {
          'question': 'Which file extension is commonly used for a PDF document?',
          'options': ['.jpg', '.pdf', '.mp3', '.exe'],
          'answer': 1,
          'explanation': 'The .pdf extension identifies a Portable Document Format file.',
        },
        {
          'question': 'Which of these is an example of application software?',
          'options': ['Windows', 'Linux', 'Microsoft Word', 'BIOS'],
          'answer': 2,
          'explanation': 'Microsoft Word is application software used to create documents.',
        },
        {
          'question': 'What does LAN stand for?',
          'options': [
            'Local Area Network',
            'Large Access Node',
            'Linked Application Network',
            'Long Area Number',
          ],
          'answer': 0,
          'explanation': 'LAN stands for Local Area Network.',
        },
        {
          'question': 'Which storage device uses flash memory?',
          'options': ['Magnetic Tape', 'USB Flash Drive', 'Floppy Disk', 'CD-ROM'],
          'answer': 1,
          'explanation': 'USB flash drives use flash memory to store data.',
        },
        {
          'question': 'Which key is commonly used to refresh a webpage?',
          'options': ['F1', 'F2', 'F5', 'F12'],
          'answer': 2,
          'explanation': 'F5 commonly refreshes the current webpage.',
        },
        {
          'question': 'What is the full form of WWW?',
          'options': [
            'World Wide Web',
            'World Web Window',
            'Wide World Work',
            'Web World Wire',
          ],
          'answer': 0,
          'explanation': 'WWW stands for World Wide Web.',
        },
        {
          'question': 'Which device produces a hard copy of a document?',
          'options': ['Scanner', 'Printer', 'Mouse', 'Microphone'],
          'answer': 1,
          'explanation': 'A printer produces a physical copy of a document.',
        },
        {
          'question': 'Which of these is an example of an open-source operating system?',
          'options': ['Linux', 'Microsoft Word', 'PowerPoint', 'Adobe Photoshop'],
          'answer': 0,
          'explanation': 'Linux is a widely used open-source operating system.',
        },
        {
          'question': 'What is the smallest unit of digital information?',
          'options': ['Byte', 'Kilobyte', 'Bit', 'Megabyte'],
          'answer': 2,
          'explanation': 'A bit is the smallest unit of digital information.',
        },
      ];

        case 'General Knowledge':
      if (widget.difficulty == 'Medium') {
        return [
          {
            'question': 'Which country is known as the Land of the Rising Sun?',
            'options': ['China', 'Japan', 'Thailand', 'South Korea'],
            'answer': 1,
          },
          {
            'question': 'Who wrote the Indian national anthem?',
            'options': ['Bankim Chandra', 'Rabindranath Tagore', 'Sarojini Naidu', 'Mahatma Gandhi'],
            'answer': 1,
          },
          {
            'question': 'Which is the largest desert in the world?',
            'options': ['Sahara', 'Gobi', 'Antarctic Desert', 'Arabian Desert'],
            'answer': 2,
          },
          {
            'question': 'How many bones are there in an adult human body?',
            'options': ['206', '208', '210', '201'],
            'answer': 0,
          },
          {
            'question': 'Which gas is most abundant in Earth’s atmosphere?',
            'options': ['Oxygen', 'Carbon dioxide', 'Nitrogen', 'Hydrogen'],
            'answer': 2,
          },
          {
            'question': 'Who was the first woman Prime Minister of India?',
            'options': ['Pratibha Patil', 'Indira Gandhi', 'Sonia Gandhi', 'Sarojini Naidu'],
            'answer': 1,
          },
          {
            'question': 'Which is the smallest continent?',
            'options': ['Europe', 'Australia', 'South America', 'Antarctica'],
            'answer': 1,
          },
          {
            'question': 'Which planet has the most prominent ring system?',
            'options': ['Mars', 'Venus', 'Saturn', 'Mercury'],
            'answer': 2,
          },
          {
            'question': 'In which year did India gain independence?',
            'options': ['1945', '1946', '1947', '1950'],
            'answer': 2,
          },
          {
            'question': 'Which instrument measures atmospheric pressure?',
            'options': ['Thermometer', 'Barometer', 'Hygrometer', 'Anemometer'],
            'answer': 1,
          },
            {
            'question': 'Which is the largest island in the world?',
            'options': ['Madagascar', 'Greenland', 'Borneo', 'New Guinea'],
            'answer': 1,
          },
          {
            'question': 'Who invented the telephone?',
            'options': ['Thomas Edison', 'Alexander Graham Bell', 'Nikola Tesla', 'James Watt'],
            'answer': 1,
          },
          {
            'question': 'Which country hosted the first modern Olympic Games in 1896?',
            'options': ['France', 'Italy', 'Greece', 'United Kingdom'],
            'answer': 2,
          },
          {
            'question': 'What is the chemical symbol for gold?',
            'options': ['Ag', 'Au', 'Fe', 'Go'],
            'answer': 1,
          },
          {
            'question': 'Which is the deepest ocean in the world?',
            'options': ['Atlantic Ocean', 'Indian Ocean', 'Arctic Ocean', 'Pacific Ocean'],
            'answer': 3,
          },
          {
            'question': 'Who was the first person to walk on the Moon?',
            'options': ['Yuri Gagarin', 'Neil Armstrong', 'Buzz Aldrin', 'Michael Collins'],
            'answer': 1,
          },
          {
            'question': 'Which organ in the human body produces insulin?',
            'options': ['Liver', 'Kidney', 'Pancreas', 'Heart'],
            'answer': 2,
          },
          {
            'question': 'What is the currency of the United Kingdom?',
            'options': ['Euro', 'Pound sterling', 'Dollar', 'Franc'],
            'answer': 1,
          },
          {
            'question': 'Which Indian state is famous for the backwaters of Alleppey?',
            'options': ['Tamil Nadu', 'Karnataka', 'Kerala', 'Goa'],
            'answer': 2,
          },
          {
            'question': 'Which gas is commonly used in electric bulbs?',
            'options': ['Oxygen', 'Argon', 'Hydrogen', 'Carbon dioxide'],
            'answer': 1,
          },
          {
            'question': 'Who wrote the play Romeo and Juliet?',
            'options': ['Charles Dickens', 'William Shakespeare', 'Jane Austen', 'George Orwell'],
            'answer': 1,
          },
          {
            'question': 'Which is the largest internal organ in the human body?',
            'options': ['Heart', 'Liver', 'Lungs', 'Kidney'],
            'answer': 1,
          },
          {
            'question': 'Where is the headquarters of the United Nations located?',
            'options': ['London', 'Paris', 'New York', 'Geneva'],
            'answer': 2,
          },
          {
            'question': 'Which planet is known for its Great Red Spot?',
            'options': ['Mars', 'Jupiter', 'Saturn', 'Neptune'],
            'answer': 1,
          },
          {
            'question': 'What is the study of earthquakes called?',
            'options': ['Ecology', 'Seismology', 'Meteorology', 'Geology'],
            'answer': 1,
          },
          {
            'question': 'Which Indian city is known as the Silicon Valley of India?',
            'options': ['Hyderabad', 'Pune', 'Bengaluru', 'Chennai'],
            'answer': 2,
          },
          {
            'question': 'Which blood group is known as the universal red-cell donor?',
            'options': ['AB positive', 'O negative', 'A positive', 'B negative'],
            'answer': 1,
          },
          {
            'question': 'Which metal is liquid at ordinary room temperature?',
            'options': ['Iron', 'Mercury', 'Aluminium', 'Copper'],
            'answer': 1,
          },
          {
            'question': 'Which country gifted the Statue of Liberty to the United States?',
            'options': ['Germany', 'France', 'Spain', 'Canada'],
            'answer': 1,
          },
          {
            'question': 'What is the smallest prime number?',
            'options': ['0', '1', '2', '3'],
            'answer': 2,
          },
          {
            'question': 'Which layer of the atmosphere contains the ozone layer?',
            'options': ['Troposphere', 'Stratosphere', 'Mesosphere', 'Thermosphere'],
            'answer': 1,
          },
        ];
      }

      if (widget.difficulty == 'Easy') {
        return [
        {
          'question': 'What is the capital of India?',
          'options': ['Mumbai', 'New Delhi', 'Chennai', 'Kolkata'],
          'answer': 1,
          'explanation':
    'Your explanation goes here.',
        },
        {
          'question': 'Which planet is known as the Red Planet?',
          'options': ['Venus', 'Jupiter', 'Mars', 'Saturn'],
          'answer': 2,
          'explanation':
    'Your explanation goes here.',
        },
        {
          'question': 'How many days are there in a leap year?',
          'options': ['365', '366', '364', '360'],
          'answer': 1,
          'explanation':
    'Your explanation goes here.',
        },
        {
          'question': 'Which is the largest ocean?',
          'options': [
            'Atlantic Ocean',
            'Indian Ocean',
            'Arctic Ocean',
            'Pacific Ocean',
          ],
          'answer': 3,
          'explanation':
    'Your explanation goes here.',
        },
        {
          'question': 'Which animal is known as the largest land animal?',
          'options': ['Giraffe', 'Elephant', 'Rhino', 'Hippo'],
          'answer': 1,
          'explanation':
    'Your explanation goes here.',
        },
        {
          'question': 'Which is the national animal of India?',
          'options': ['Lion', 'Bengal Tiger', 'Elephant', 'Leopard'],
          'answer': 1,
          'explanation':
    'Your explanation goes here.',
        },
        {
          'question': 'How many continents are there?',
          'options': ['Five', 'Six', 'Seven', 'Eight'],
          'answer': 2,
          'explanation':
    'Your explanation goes here.',
        },
        {
          'question': 'Which gas do plants absorb from the atmosphere?',
          'options': ['Oxygen', 'Nitrogen', 'Carbon dioxide', 'Hydrogen'],
          'answer': 2,
          'explanation':
    'Your explanation goes here.',
        },
        {
          'question': 'Which is the closest star to Earth?',
          'options': ['Sirius', 'The Sun', 'Polaris', 'Vega'],
          'answer': 1,
          'explanation':
    'Your explanation goes here.',
        },
        {
          'question': 'Which festival is widely known as the Festival of Lights in India?',
          'options': ['Holi', 'Pongal', 'Diwali', 'Onam'],
          'answer': 2,
          'explanation':
    'Your explanation goes here.',
        },
           {
          'question': 'Which is the largest planet in our solar system?',
          'options': ['Earth', 'Jupiter', 'Saturn', 'Neptune'],
          'answer': 1,
        },
        {
          'question': 'What is the national flower of India?',
          'options': ['Rose', 'Sunflower', 'Lotus', 'Jasmine'],
          'answer': 2,
        },
        {
          'question': 'Which is the longest river in India?',
          'options': ['Yamuna', 'Godavari', 'Ganga', 'Narmada'],
          'answer': 2,
        },
        {
          'question': 'How many players are there in a cricket team on the field?',
          'options': ['9', '10', '11', '12'],
          'answer': 2,
        },
        {
          'question': 'Which city is known as the Pink City of India?',
          'options': ['Udaipur', 'Jaipur', 'Jodhpur', 'Agra'],
          'answer': 1,
        },
        {
          'question': 'Which vitamin is produced in the skin through sunlight exposure?',
          'options': ['Vitamin A', 'Vitamin B12', 'Vitamin C', 'Vitamin D'],
          'answer': 3,
        },
        {
          'question': 'What is the currency of Japan?',
          'options': ['Yuan', 'Won', 'Yen', 'Dollar'],
          'answer': 2,
        },
        {
          'question': 'Which bird is the national bird of India?',
          'options': ['Parrot', 'Peacock', 'Eagle', 'Sparrow'],
          'answer': 1,
        },
        {
          'question': 'How many sides does a hexagon have?',
          'options': ['Five', 'Six', 'Seven', 'Eight'],
          'answer': 1,
        },
        {
          'question': 'Which ocean lies to the south of India?',
          'options': ['Pacific Ocean', 'Atlantic Ocean', 'Indian Ocean', 'Arctic Ocean'],
          'answer': 2,
        },
        {
          'question': 'Who is known as the Father of the Indian Constitution?',
          'options': ['Mahatma Gandhi', 'B. R. Ambedkar', 'Jawaharlal Nehru', 'Sardar Patel'],
          'answer': 1,
        },
        {
          'question': 'Which is the hardest natural substance?',
          'options': ['Gold', 'Iron', 'Diamond', 'Silver'],
          'answer': 2,
        },
        {
          'question': 'Which planet is famous for its Great Red Spot?',
          'options': ['Mars', 'Jupiter', 'Venus', 'Mercury'],
          'answer': 1,
        },
        {
          'question': 'What is the national aquatic animal of India?',
          'options': ['Blue Whale', 'Ganges River Dolphin', 'Sea Turtle', 'Shark'],
          'answer': 1,
        },
        {
          'question': 'Which Indian state is famous for its backwaters?',
          'options': ['Punjab', 'Kerala', 'Gujarat', 'Haryana'],
          'answer': 1,
        },
        {
          'question': 'How many colours are traditionally seen in a rainbow?',
          'options': ['Five', 'Six', 'Seven', 'Eight'],
          'answer': 2,
        },
        {
          'question': 'Which gas is essential for human respiration?',
          'options': ['Nitrogen', 'Oxygen', 'Carbon dioxide', 'Helium'],
          'answer': 1,
        },
        {
          'question': 'Which is the smallest state in India by area?',
          'options': ['Sikkim', 'Tripura', 'Goa', 'Manipur'],
          'answer': 2,
        },
        {
          'question': 'Where is the headquarters of the United Nations located?',
          'options': ['London', 'Paris', 'New York', 'Geneva'],
          'answer': 2,
        },
        {
          'question': 'Which day is celebrated as World Environment Day?',
          'options': ['April 22', 'June 5', 'July 11', 'December 10'],
          'answer': 1,
        },


        ];
      }

      if (widget.difficulty == 'Hard') {
        return [
          {
            'question': 'Which treaty formally ended World War I?',
            'options': ['Treaty of Paris', 'Treaty of Versailles', 'Treaty of Rome', 'Treaty of Vienna'],
            'answer': 1,
          },
          {
            'question': 'Who discovered the circulation of blood?',
            'options': ['Louis Pasteur', 'William Harvey', 'Edward Jenner', 'Alexander Fleming'],
            'answer': 1,
          },
          {
            'question': 'Which element has the atomic number 74?',
            'options': ['Tungsten', 'Platinum', 'Gold', 'Osmium'],
            'answer': 0,
          },
          {
            'question': 'Which Indian mathematician is known for the Hardy–Ramanujan number?',
            'options': ['Aryabhata', 'Srinivasa Ramanujan', 'Brahmagupta', 'Bhaskara II'],
            'answer': 1,
          },
          {
            'question': 'What is the SI unit of electric capacitance?',
            'options': ['Henry', 'Farad', 'Tesla', 'Weber'],
            'answer': 1,
          },
          {
            'question': 'Which strait separates Asia and North America?',
            'options': ['Malacca Strait', 'Bering Strait', 'Gibraltar Strait', 'Hormuz Strait'],
            'answer': 1,
          },
          {
            'question': 'Who proposed the uncertainty principle?',
            'options': ['Niels Bohr', 'Werner Heisenberg', 'Max Planck', 'Erwin Schrödinger'],
            'answer': 1,
          },
          {
            'question': 'Which is the deepest known ocean trench?',
            'options': ['Java Trench', 'Tonga Trench', 'Mariana Trench', 'Puerto Rico Trench'],
            'answer': 2,
          },
          {
            'question': 'Which Indian mission made a soft landing near the Moon’s south polar region in 2023?',
            'options': ['Chandrayaan-1', 'Chandrayaan-2', 'Chandrayaan-3', 'Mangalyaan'],
            'answer': 2,
          },
          {
            'question': 'Which economist wrote The Wealth of Nations?',
            'options': ['John Maynard Keynes', 'Adam Smith', 'Karl Marx', 'David Ricardo'],
            'answer': 1,
          },

          {
            'question': 'Which ancient civilization developed the cuneiform writing system?',
            'options': ['Egyptian', 'Sumerian', 'Roman', 'Indus Valley'],
            'answer': 1,
          },
          {
            'question': 'What is the chemical symbol for antimony?',
            'options': ['Am', 'At', 'Sb', 'An'],
            'answer': 2,
          },
          {
            'question': 'Who formulated the laws of planetary motion?',
            'options': ['Galileo Galilei', 'Johannes Kepler', 'Isaac Newton', 'Nicolaus Copernicus'],
            'answer': 1,
          },
          {
            'question': 'Which mountain range separates Europe from Asia?',
            'options': ['Alps', 'Andes', 'Ural Mountains', 'Himalayas'],
            'answer': 2,
          },
          {
            'question': 'What is the hardest naturally occurring mineral?',
            'options': ['Quartz', 'Diamond', 'Topaz', 'Corundum'],
            'answer': 1,
          },
          {
            'question': 'Who was the first woman to win a Nobel Prize?',
            'options': ['Mother Teresa', 'Marie Curie', 'Rosalind Franklin', 'Dorothy Hodgkin'],
            'answer': 1,
          },
          {
            'question': 'Which Indian emperor embraced Buddhism after the Kalinga War?',
            'options': ['Chandragupta Maurya', 'Ashoka', 'Bindusara', 'Harsha'],
            'answer': 1,
          },
          {
            'question': 'Which particle carries a negative electric charge?',
            'options': ['Proton', 'Neutron', 'Electron', 'Photon'],
            'answer': 2,
          },
          {
            'question': 'What is the capital of Kazakhstan?',
            'options': ['Almaty', 'Astana', 'Tashkent', 'Bishkek'],
            'answer': 1,
          },
          {
            'question': 'Which scientist introduced the concept of natural selection?',
            'options': ['Gregor Mendel', 'Charles Darwin', 'Louis Pasteur', 'Alfred Wegener'],
            'answer': 1,
          },
          {
            'question': 'Which is the largest moon of Saturn?',
            'options': ['Europa', 'Titan', 'Ganymede', 'Triton'],
            'answer': 1,
          },
          {
            'question': 'What is the main ore of aluminium?',
            'options': ['Hematite', 'Bauxite', 'Galena', 'Magnetite'],
            'answer': 1,
          },
          {
            'question': 'Who wrote the book The Republic?',
            'options': ['Aristotle', 'Socrates', 'Plato', 'Herodotus'],
            'answer': 2,
          },
          {
            'question': 'Which Indian classical dance form originated in Kerala?',
            'options': ['Bharatanatyam', 'Kathak', 'Kathakali', 'Odissi'],
            'answer': 2,
          },
          {
            'question': 'Which layer of Earth lies directly beneath the crust?',
            'options': ['Inner core', 'Outer core', 'Mantle', 'Lithosphere'],
            'answer': 2,
          },
                    {
            'question': 'What is the approximate speed of light in vacuum?',
            'options': [
              '3 × 10^6 m/s',
              '3 × 10^8 m/s',
              '3 × 10^10 m/s',
              '3 × 10^4 m/s',
            ],
            'answer': 1,
          },
          {
            'question': 'Which treaty established the European Union?',
            'options': ['Treaty of Rome', 'Treaty of Maastricht', 'Treaty of Lisbon', 'Treaty of Paris'],
            'answer': 1,
          },
          {
            'question': 'Which blood vessel carries oxygenated blood from the lungs to the heart?',
            'options': ['Pulmonary artery', 'Aorta', 'Pulmonary vein', 'Vena cava'],
            'answer': 2,
          },
          {
            'question': 'Who was the first Indian to receive a Nobel Prize?',
            'options': ['C. V. Raman', 'Rabindranath Tagore', 'Amartya Sen', 'Mother Teresa'],
            'answer': 1,
          },
          {
            'question': 'Which branch of mathematics studies properties of integers?',
            'options': ['Calculus', 'Number theory', 'Geometry', 'Statistics'],
            'answer': 1,
          },

      ];
      }

    case 'Aptitude':
  if (widget.difficulty == 'Medium') {
    return [
      {
        'question': 'What is 35% of 240?',
        'options': ['72', '84', '96', '80'],
        'answer': 1,
        'explanation': '35% of 240 = 84.',
      },
      {
        'question': 'If 5 workers complete a task in 12 days, how many days will 10 workers take?',
        'options': ['4', '5', '6', '8'],
        'answer': 2,
        'explanation': 'Doubling the workers halves the time: 6 days.',
      },
      {
        'question': 'Find the next number: 5, 10, 20, 40, __',
        'options': ['60', '70', '80', '100'],
        'answer': 2,
        'explanation': 'Each number is multiplied by 2.',
      },
      {
        'question': 'A train travels 150 km in 3 hours. What is its speed?',
        'options': ['40 km/h', '45 km/h', '50 km/h', '60 km/h'],
        'answer': 2,
        'explanation': 'Speed = Distance / Time = 150 / 3 = 50 km/h.',
      },
      {
        'question': 'What is the average of 12, 18, 24 and 30?',
        'options': ['18', '20', '21', '22'],
        'answer': 2,
        'explanation': 'Average = 84 / 4 = 21.',
      },
      {
        'question': 'A number increased by 20% becomes 120. What is the original number?',
        'options': ['90', '100', '110', '115'],
        'answer': 1,
        'explanation': '120 / 1.2 = 100.',
      },
      {
        'question': 'Find the LCM of 6 and 8.',
        'options': ['12', '18', '24', '48'],
        'answer': 2,
        'explanation': 'The smallest common multiple is 24.',
      },
      {
        'question': 'If 3x = 45, what is x?',
        'options': ['10', '12', '15', '18'],
        'answer': 2,
        'explanation': 'x = 45 / 3 = 15.',
      },
      {
        'question': 'A product costs ₹800 after a 20% discount. What was its original price?',
        'options': ['₹900', '₹960', '₹1000', '₹1200'],
        'answer': 2,
        'explanation': '800 is 80% of the original price, so 800 / 0.8 = 1000.',
      },
      {
        'question': 'Find the simple interest on ₹2000 at 5% per year for 2 years.',
        'options': ['₹100', '₹150', '₹200', '₹250'],
        'answer': 2,
        'explanation': 'SI = (2000 × 5 × 2) / 100 = ₹200.',
      },
            {
        'question': 'A shopkeeper buys an item for 500 and sells it for 600. What is the profit percentage?',
        'options': ['10%', '15%', '20%', '25%'],
        'answer': 2,
        'explanation': 'Profit = 100; profit percentage = (100 / 500) × 100 = 20%.',
      },
      {
        'question': 'If 8 pens cost 96, what is the cost of 5 pens?',
        'options': ['50', '55', '60', '65'],
        'answer': 2,
        'explanation': 'One pen costs 96 / 8 = 12; five cost 60.',
      },
      {
        'question': 'A sum of 1200 is divided in the ratio 2:3. What is the larger share?',
        'options': ['480', '600', '720', '800'],
        'answer': 2,
        'explanation': 'Larger share = (3 / 5) × 1200 = 720.',
      },
      {
        'question': 'What is the compound interest on 1000 at 10% per year for 2 years?',
        'options': ['200', '210', '220', '250'],
        'answer': 1,
        'explanation': 'Amount = 1000 × 1.1 × 1.1 = 1210; interest = 210.',
      },
      {
        'question': 'A car covers 240 km in 4 hours. How far will it travel in 7 hours at the same speed?',
        'options': ['360 km', '400 km', '420 km', '480 km'],
        'answer': 2,
        'explanation': 'Speed = 60 km/h; distance = 60 × 7 = 420 km.',
      },
      {
        'question': 'The average of five numbers is 18. What is their total?',
        'options': ['80', '85', '90', '95'],
        'answer': 2,
        'explanation': 'Total = average × count = 18 × 5 = 90.',
      },
      {
        'question': 'A person spends 75% of an income of 40000. How much is saved?',
        'options': ['8000', '9000', '10000', '12000'],
        'answer': 0,
        'explanation': 'Savings = 25% of 40000 = 10000.',
      },
      {
        'question': 'If 12 men finish a job in 15 days, how many days will 20 men take?',
        'options': ['8', '9', '10', '12'],
        'answer': 1,
        'explanation': 'Total work = 12 × 15 = 180 man-days; 180 / 20 = 9 days.',
      },
      {
        'question': 'A number is reduced by 15% and becomes 170. What was the original number?',
        'options': ['180', '190', '200', '220'],
        'answer': 2,
        'explanation': '85% of the original = 170; original = 170 / 0.85 = 200.',
      },
      {
        'question': 'Find the HCF of 36 and 60.',
        'options': ['6', '10', '12', '18'],
        'answer': 2,
        'explanation': 'The greatest common factor of 36 and 60 is 12.',
      },
      {
        'question': 'A shop offers a 10% discount on an item marked 1500. What is the selling price?',
        'options': ['1250', '1300', '1350', '1400'],
        'answer': 2,
        'explanation': 'Discount = 150; selling price = 1500 − 150 = 1350.',
      },
      {
        'question': 'If 4 machines produce 200 units in 5 hours, how many units will 6 machines produce in 5 hours?',
        'options': ['250', '275', '300', '350'],
        'answer': 2,
        'explanation': 'Each machine produces 50 units in 5 hours; 6 produce 300.',
      },
      {
        'question': 'A boat travels 30 km downstream in 2 hours. What is its downstream speed?',
        'options': ['10 km/h', '12 km/h', '15 km/h', '18 km/h'],
        'answer': 2,
        'explanation': 'Speed = distance / time = 30 / 2 = 15 km/h.',
      },
      {
        'question': 'What is the probability of getting an even number when a fair die is rolled?',
        'options': ['1/6', '1/3', '1/2', '2/3'],
        'answer': 2,
        'explanation': 'There are 3 even outcomes among 6 possible outcomes.',
      },
      {
        'question': 'Find the next number: 3, 8, 15, 24, 35, __',
        'options': ['42', '46', '48', '50'],
        'answer': 2,
        'explanation': 'The differences are 5, 7, 9, 11; the next difference is 13.',
      },
      {
        'question': 'A sum becomes 1320 after 2 years at 10% simple interest per year. What was the principal?',
        'options': ['1000', '1100', '1200', '1250'],
        'answer': 2,
        'explanation': 'Amount = 1.2 × principal; principal = 1320 / 1.2 = 1100.',
      },
      {
        'question': 'The ratio of boys to girls in a class is 5:4. If there are 45 students, how many are girls?',
        'options': ['15', '20', '25', '30'],
        'answer': 1,
        'explanation': 'Girls = (4 / 9) × 45 = 20.',
      },
      {
        'question': 'A train 180 m long crosses a platform 120 m long in 15 seconds. What is its speed?',
        'options': ['60 km/h', '72 km/h', '80 km/h', '90 km/h'],
        'answer': 1,
        'explanation': 'Total distance = 300 m; speed = 20 m/s = 72 km/h.',
      },
      {
        'question': 'If x/5 = 7, what is the value of x?',
        'options': ['25', '30', '35', '40'],
        'answer': 2,
        'explanation': 'x = 7 × 5 = 35.',
      },
      {
        'question': 'The perimeter of a rectangle is 50 cm and its length is 15 cm. What is its width?',
        'options': ['8 cm', '10 cm', '12 cm', '15 cm'],
        'answer': 1,
        'explanation': '2 × (15 + width) = 50; width = 10 cm.',
      },
    ];
  }

  if (widget.difficulty == 'Hard') {
    return [
      {
        'question': 'A train 120 m long crosses a pole in 6 seconds. What is its speed?',
        'options': ['60 km/h', '72 km/h', '80 km/h', '90 km/h'],
        'answer': 1,
        'explanation': 'Speed = 120 / 6 = 20 m/s = 72 km/h.',
      },
      {
        'question': 'If A can complete a job in 12 days and B in 18 days, how long will they take together?',
        'options': ['6.2 days', '7.2 days', '8 days', '9 days'],
        'answer': 1,
        'explanation': 'Combined rate = 1/12 + 1/18 = 5/36, so time = 36/5 = 7.2 days.',
      },
      {
        'question': 'A sum doubles itself in 8 years at simple interest. What is the annual rate?',
        'options': ['10%', '12%', '12.5%', '15%'],
        'answer': 2,
        'explanation': 'Interest equals principal in 8 years, so rate = 100/8 = 12.5%.',
      },
      {
        'question': 'Find the next number: 2, 6, 12, 20, 30, __',
        'options': ['36', '40', '42', '44'],
        'answer': 2,
        'explanation': 'The pattern is n × (n + 1): 6 × 7 = 42.',
      },
      {
        'question': 'A 30-litre mixture contains milk and water in the ratio 2:1. How much water must be added to make the ratio 1:1?',
        'options': ['5 litres', '10 litres', '15 litres', '20 litres'],
        'answer': 1,
        'explanation': 'Milk = 20 L and water = 10 L. Add 10 L water to make them equal.',
      },
      {
        'question': 'If the marked price is ₹1500 and the discount is 20%, followed by another 10% discount, what is the final price?',
        'options': ['₹1050', '₹1080', '₹1100', '₹1200'],
        'answer': 1,
        'explanation': '1500 × 0.8 × 0.9 = ₹1080.',
      },
      {
        'question': 'The average of 8 numbers is 24. If one number, 32, is removed, what is the new average?',
        'options': ['22.5', '22.86', '23', '23.5'],        'answer': 1,
        'explanation': 'Total = 192. New average = (192 - 32) / 7 = 160/7 ≈ 22.86.',
      },
      {
        'question': 'A boat travels 30 km downstream in 2 hours and the same distance upstream in 3 hours. What is the speed of the stream?',
        'options': ['2.5 km/h', '3 km/h', '5 km/h', '7.5 km/h'],
        'answer': 0,
        'explanation': 'Downstream speed = 15, upstream speed = 10. Stream speed = (15 - 10) / 2 = 2.5 km/h.',
      },
      {
        'question': 'Two numbers are in the ratio 3:5 and their sum is 96. What is the larger number?',
        'options': ['36', '48', '60', '64'],
        'answer': 2,
        'explanation': 'One part = 96 / 8 = 12. Larger number = 5 × 12 = 60.',
      },
      {
        'question': 'A person spends 75% of their income and saves ₹6000. What is their total income?',
        'options': ['₹18000', '₹20000', '₹24000', '₹30000'],
        'answer': 2,
        'explanation': 'Savings are 25% of income. Income = 6000 / 0.25 = ₹24000.',
      },
            {
        'question': 'A train 120 metres long crosses a pole in 6 seconds. What is its speed?',
        'options': ['60 km/h', '72 km/h', '80 km/h', '90 km/h'],
        'answer': 1,
        'explanation': 'Speed = 120 / 6 = 20 m/s = 72 km/h.',
      },
      {
        'question': 'If 5 workers complete a task in 12 days, how many days will 10 workers take at the same rate?',
        'options': ['4 days', '5 days', '6 days', '8 days'],
        'answer': 2,
        'explanation': 'Total work = 5 × 12 = 60 worker-days. 60 / 10 = 6 days.',
      },
      {
        'question': 'Find the simple interest on ₹2000 at 5% per annum for 3 years.',
        'options': ['₹200', '₹250', '₹300', '₹350'],
        'answer': 2,
        'explanation': 'Simple interest = (2000 × 5 × 3) / 100 = ₹300.',
      },
      {
        'question': 'A shopkeeper buys an item for ₹800 and sells it for ₹920. What is the profit percentage?',
        'options': ['10%', '12%', '15%', '20%'],
        'answer': 2,
        'explanation': 'Profit = 120. Profit percentage = (120 / 800) × 100 = 15%.',
      },
      {
        'question': 'The ratio of two numbers is 4:7. If their difference is 21, what is their sum?',
        'options': ['55', '66', '77', '88'],
        'answer': 1,
        'explanation': 'Three parts = 21, so one part = 7. Sum = 11 × 7 = 77.',
      },
      {
        'question': 'A car covers 180 km in 3 hours. What is its average speed?',
        'options': ['50 km/h', '55 km/h', '60 km/h', '65 km/h'],
        'answer': 2,
        'explanation': 'Average speed = 180 / 3 = 60 km/h.',
      },
      {
        'question': 'If 3x + 7 = 25, what is the value of x?',
        'options': ['5', '6', '7', '8'],
        'answer': 1,
        'explanation': '3x = 18, so x = 6.',
      },
      {
        'question': 'What is the compound interest on ₹1000 at 10% per annum for 2 years?',
        'options': ['₹200', '₹210', '₹220', '₹250'],
        'answer': 1,
        'explanation': 'Amount = 1000 × 1.1 × 1.1 = ₹1210. Interest = ₹210.',
      },
      {
        'question': 'A number is increased by 20% and becomes 240. What was the original number?',
        'options': ['180', '190', '200', '220'],
        'answer': 2,
        'explanation': 'Original number = 240 / 1.2 = 200.',
      },
      {
        'question': 'The average of five numbers is 18. What is their total?',
        'options': ['80', '85', '90', '95'],
        'answer': 2,
        'explanation': 'Total = average × count = 18 × 5 = 90.',
      },
      {
        'question': 'If 12 men can complete a job in 15 days, how many men are needed to complete it in 9 days?',
        'options': ['15', '18', '20', '24'],
        'answer': 2,
        'explanation': 'Required men = (12 × 15) / 9 = 20.',
      },
      {
        'question': 'A bag contains 5 red and 3 blue balls. What is the probability of selecting a blue ball?',
        'options': ['3/5', '3/8', '5/8', '1/2'],
        'answer': 1,
        'explanation': 'Probability = favourable outcomes / total outcomes = 3/8.',
      },
      {
        'question': 'Find the least common multiple (LCM) of 12 and 18.',
        'options': ['24', '30', '36', '48'],
        'answer': 2,
        'explanation': 'The smallest number divisible by both 12 and 18 is 36.',
      },
      {
        'question': 'A sum of ₹5000 is divided in the ratio 2:3. What is the larger share?',
        'options': ['₹2000', '₹2500', '₹3000', '₹3500'],
        'answer': 2,
        'explanation': 'Larger share = (3/5) × 5000 = ₹3000.',
      },
      {
        'question': 'If the cost price is ₹600 and the selling price is ₹540, what is the loss percentage?',
        'options': ['5%', '8%', '10%', '12%'],
        'answer': 2,
        'explanation': 'Loss = 60. Loss percentage = (60 / 600) × 100 = 10%.',
      },
      {
        'question': 'A pipe fills a tank in 6 hours. What fraction of the tank does it fill in 2 hours?',
        'options': ['1/6', '1/3', '1/2', '2/3'],
        'answer': 1,
        'explanation': 'Fraction filled = 2/6 = 1/3.',
      },
      {
        'question': 'Find the next number: 3, 9, 27, 81, __',
        'options': ['162', '189', '216', '243'],
        'answer': 3,
        'explanation': 'Each number is multiplied by 3. 81 × 3 = 243.',
      },
      {
        'question': 'A person travels 60 km at 30 km/h and another 60 km at 60 km/h. What is the average speed for the whole journey?',
        'options': ['35 km/h', '40 km/h', '45 km/h', '50 km/h'],
        'answer': 1,
        'explanation': 'Total distance = 120 km. Total time = 2 + 1 = 3 hours. Average speed = 40 km/h.',
      },
      {
        'question': 'If 40% of a number is 64, what is the number?',
        'options': ['120', '140', '160', '180'],
        'answer': 2,
        'explanation': 'Number = 64 / 0.4 = 160.',
      },
      {
        'question': 'A rectangle has a length of 15 cm and a width of 8 cm. What is its area?',
        'options': ['100 cm²', '110 cm²', '120 cm²', '130 cm²'],
        'answer': 2,
        'explanation': 'Area = length × width = 15 × 8 = 120 cm².',
      },
    ];
  }

  return [
        {
          'question': 'What is 15 + 27?',
          'options': ['32', '42', '40', '52'],
          'answer': 1,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'What is 12 × 8?',
          'options': ['84', '96', '88', '108'],
          'answer': 1,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'Find the next number: 2, 4, 6, 8, __',
          'options': ['9', '10', '12', '14'],
          'answer': 1,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'If a pen costs ₹10, what do 5 pens cost?',
          'options': ['₹15', '₹40', '₹50', '₹60'],
          'answer': 2,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'What is half of 150?',
          'options': ['50', '65', '75', '85'],
          'answer': 2,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'What is 25% of 200?',
          'options': ['25', '40', '50', '75'],
          'answer': 2,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'Find the next number: 3, 6, 9, 12, __',
          'options': ['13', '14', '15', '18'],
          'answer': 2,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'If x = 5, what is 2x + 3?',
          'options': ['10', '13', '15', '8'],
          'answer': 1,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'A shirt costs ₹500. What is its price after a 10% discount?',
          'options': ['₹450', '₹400', '₹490', '₹550'],
          'answer': 0,
          'explanation':
    'Write the explanation for this question here.',
        },
        {
          'question': 'How many minutes are there in 3 hours?',
          'options': ['120', '150', '180', '240'],
          'answer': 2,
          'explanation':
    'Write the explanation for this question here.',
        },
                {
          'question': 'What is 18 + 24?',
          'options': ['40', '42', '44', '46'],
          'answer': 1,
          'explanation': '18 + 24 = 42.',
        },
        {
          'question': 'What is 9 × 7?',
          'options': ['56', '63', '72', '49'],
          'answer': 1,
          'explanation': '9 multiplied by 7 equals 63.',
        },
        {
          'question': 'What is 100 divided by 4?',
          'options': ['20', '25', '30', '40'],
          'answer': 1,
          'explanation': '100 ÷ 4 = 25.',
        },
        {
          'question': 'Find the next number: 5, 10, 15, 20, __',
          'options': ['22', '24', '25', '30'],
          'answer': 2,
          'explanation': 'Each number increases by 5.',
        },
        {
          'question': 'What is 10% of 500?',
          'options': ['25', '40', '50', '100'],
          'answer': 2,
          'explanation': '10% of 500 = 50.',
        },
        {
          'question': 'A dozen eggs contains how many eggs?',
          'options': ['10', '12', '15', '20'],
          'answer': 1,
          'explanation': 'One dozen equals 12 items.',
        },
        {
          'question': 'What is the square of 8?',
          'options': ['16', '32', '64', '81'],
          'answer': 2,
          'explanation': '8 × 8 = 64.',
        },
        {
          'question': 'What is 3/4 of 100?',
          'options': ['25', '50', '75', '80'],
          'answer': 2,
          'explanation': '100 × 3/4 = 75.',
        },
        {
          'question': 'How many sides does a hexagon have?',
          'options': ['5', '6', '7', '8'],
          'answer': 1,
          'explanation': 'A hexagon has six sides.',
        },
        {
          'question': 'What is the value of 45 - 19?',
          'options': ['24', '25', '26', '27'],
          'answer': 2,
          'explanation': '45 - 19 = 26.',
        },
        {
          'question': 'If 5 books cost ₹100, what is the cost of one book?',
          'options': ['₹10', '₹15', '₹20', '₹25'],
          'answer': 2,
          'explanation': '100 ÷ 5 = ₹20.',
        },
        {
          'question': 'What is the smallest prime number?',
          'options': ['0', '1', '2', '3'],
          'answer': 2,
          'explanation': '2 is the smallest prime number.',
        },
        {
          'question': 'How many days are there in 2 weeks?',
          'options': ['7', '10', '12', '14'],
          'answer': 3,
          'explanation': '2 × 7 = 14 days.',
        },
        {
          'question': 'What is 20% of 150?',
          'options': ['20', '25', '30', '35'],
          'answer': 2,
          'explanation': '20% of 150 = 30.',
        },
        {
          'question': 'Find the next number: 1, 4, 9, 16, __',
          'options': ['20', '24', '25', '36'],
          'answer': 2,
          'explanation': 'These are consecutive square numbers: 1², 2², 3², 4², 5².',
        },
        {
          'question': 'What is the perimeter of a square with side 5 cm?',
          'options': ['10 cm', '15 cm', '20 cm', '25 cm'],
          'answer': 2,
          'explanation': 'Perimeter = 4 × side = 4 × 5 = 20 cm.',
        },
        {
          'question': 'What is 2.5 + 1.5?',
          'options': ['3', '3.5', '4', '4.5'],
          'answer': 2,
          'explanation': '2.5 + 1.5 = 4.',
        },
        {
          'question': 'If a train travels 60 km in one hour, how far does it travel in 2 hours at the same speed?',
          'options': ['60 km', '90 km', '120 km', '150 km'],
          'answer': 2,
          'explanation': 'Distance = speed × time = 60 × 2 = 120 km.',
        },
        {
          'question': 'What is the average of 10, 20 and 30?',
          'options': ['15', '20', '25', '30'],
          'answer': 1,
          'explanation': 'Average = (10 + 20 + 30) ÷ 3 = 20.',
        },
        {
          'question': 'Simplify the ratio 4:8.',
          'options': ['1:2', '2:3', '2:1', '4:2'],
          'answer': 0,
          'explanation': 'Divide both terms by 4 to get 1:2.',
        },
      ];

    case 'English':
  if (widget.difficulty == 'Medium') {
    return [
      {
        'question': 'Choose the synonym of "abundant".',
        'options': ['Rare', 'Plentiful', 'Empty', 'Limited'],
        'answer': 1,
        'explanation': 'Abundant means plentiful or available in large quantities.',
      },
      {
        'question': 'Choose the antonym of "expand".',
        'options': ['Increase', 'Extend', 'Contract', 'Enlarge'],
        'answer': 2,
        'explanation': 'Contract means to become smaller, the opposite of expand.',
      },
      {
        'question': 'Identify the adverb: "She sings beautifully."',
        'options': ['She', 'Sings', 'Beautifully', 'None'],
        'answer': 2,
        'explanation': 'Beautifully describes how she sings, so it is an adverb.',
      },
      {
        'question': 'Choose the correct sentence.',
        'options': [
          'He do his work.',
          'He does his work.',
          'He doing his work.',
          'He done his work.',
        ],
        'answer': 1,
        'explanation': 'He is third-person singular, so the correct verb is does.',
      },
      {
        'question': 'Fill in the blank: Neither of the answers ___ correct.',
        'options': ['are', 'were', 'is', 'have'],
        'answer': 2,
        'explanation': 'Neither is treated as singular, so we use is.',
      },
      {
        'question': 'Choose the correct passive voice: "She writes a letter."',
        'options': [
          'A letter is written by her.',
          'A letter was written by her.',
          'A letter has written by her.',
          'A letter writes by her.',
        ],
        'answer': 0,
        'explanation': 'The simple present passive form is is + past participle.',
      },
      {
        'question': 'What is the plural of "analysis"?',
        'options': ['Analysises', 'Analysis', 'Analyses', 'Analys'],
        'answer': 2,
        'explanation': 'The plural form of analysis is analyses.',
      },
      {
        'question': 'Choose the correctly punctuated sentence.',
        'options': [
          'Where are you going.',
          'Where are you going?',
          'Where are you going!',
          'Where, are you going?',
        ],
        'answer': 1,
        'explanation': 'A direct question ends with a question mark.',
      },
      {
        'question': 'Identify the conjunction: "I stayed home because it rained."',
        'options': ['Stayed', 'Home', 'Because', 'Rained'],
        'answer': 2,
        'explanation': 'Because connects the clauses and gives a reason.',
      },
      {
        'question': 'Choose the correct comparative form of "good".',
        'options': ['Gooder', 'More good', 'Best', 'Better'],
        'answer': 3,
        'explanation': 'The comparative form of good is better.',
      },
             {
        'question': 'Choose the correct form: By the time we arrived, the movie ___.',
        'options': ['Starts', 'Started', 'Had started', 'Has starting'],
        'answer': 2,
        'explanation': 'Past perfect describes an action completed before another past action.',
      },
      {
        'question': 'Identify the type of sentence: "Please close the door."',
        'options': ['Interrogative', 'Imperative', 'Exclamatory', 'Declarative'],
        'answer': 1,
        'explanation': 'An imperative sentence gives a command or request.',
      },
      {
        'question': 'Choose the correct preposition: She is good ___ mathematics.',
        'options': ['In', 'On', 'At', 'For'],
        'answer': 2,
        'explanation': 'The correct expression is good at mathematics.',
      },
      {
        'question': 'What is the plural of "criterion"?',
        'options': ['Criterions', 'Criteria', 'Criterias', 'Criterion'],
        'answer': 1,
        'explanation': 'Criteria is the plural form of criterion.',
      },
      {
        'question': 'Choose the correct reported speech: She said, "I will call you."',
        'options': [
          'She said that she will call me.',
          'She said that she would call me.',
          'She says she would call me.',
          'She said that I would call her.',
        ],
        'answer': 1,
        'explanation': 'In reported speech, will usually changes to would.',
      },
      {
        'question': 'Identify the adjective in: "The old building was renovated."',
        'options': ['Building', 'Was', 'Renovated', 'Old'],
        'answer': 3,
        'explanation': 'Old describes the noun building.',
      },
      {
        'question': 'Choose the correct word: The medicine had a positive ___ on her.',
        'options': ['Affect', 'Effect', 'Effective', 'Affection'],
        'answer': 1,
        'explanation': 'Effect is a noun meaning a result or influence.',
      },
      {
        'question': 'Fill in the blank: If I ___ rich, I would travel the world.',
        'options': ['Am', 'Was', 'Were', 'Be'],
        'answer': 2,
        'explanation': 'Were is traditionally used in hypothetical conditional sentences.',
      },
      {
        'question': 'Choose the correct passive voice: "They are building a bridge."',
        'options': [
          'A bridge was built by them.',
          'A bridge is being built by them.',
          'A bridge has built by them.',
          'A bridge is building by them.',
        ],
        'answer': 1,
        'explanation': 'Present continuous passive uses is being followed by a past participle.',
      },
      {
        'question': 'Which word is closest in meaning to "reluctant"?',
        'options': ['Eager', 'Unwilling', 'Excited', 'Confident'],
        'answer': 1,
        'explanation': 'Reluctant means unwilling or hesitant.',
      },
      {
        'question': 'Identify the conjunction: "Although he was tired, he continued working."',
        'options': ['Tired', 'Continued', 'Although', 'Working'],
        'answer': 2,
        'explanation': 'Although introduces a concessive subordinate clause.',
      },
      {
        'question': 'Choose the correct superlative form of "little".',
        'options': ['Littlest', 'Less', 'Least', 'More little'],
        'answer': 2,
        'explanation': 'Least is the superlative form of little when referring to quantity.',
      },
      {
        'question': 'What does the phrasal verb "look after" mean?',
        'options': ['Search for', 'Take care of', 'Look behind', 'Ignore'],
        'answer': 1,
        'explanation': 'Look after means to take care of someone or something.',
      },
      {
        'question': 'Choose the correctly punctuated sentence.',
        'options': [
          'Its raining, lets go inside.',
          "It's raining; let's go inside.",
          "Its raining; let's go inside.",
          "It's raining let's go inside",
        ],
        'answer': 1,
        'explanation': 'Apostrophes indicate the contractions it’s and let’s; a semicolon separates the clauses.',
      },
      {
        'question': 'Identify the tense: "She has been studying for three hours."',
        'options': [
          'Present perfect',
          'Past perfect continuous',
          'Present perfect continuous',
          'Present continuous',
        ],
        'answer': 2,
        'explanation': 'Has been studying is present perfect continuous.',
      },
      {
        'question': 'Choose the correct word: Everyone must bring ___ own notebook.',
        'options': ['Their', 'Them', 'They', 'Theirs'],
        'answer': 0,
        'explanation': 'Their is a possessive determiner used before the noun notebook.',
      },
      {
        'question': 'Which of these is an example of a compound sentence?',
        'options': [
          'Because it rained, we stayed home.',
          'She smiled.',
          'I called him, but he did not answer.',
          'Running quickly, he reached the bus.',
        ],
        'answer': 2,
        'explanation': 'A compound sentence joins independent clauses with a coordinating conjunction.',
      },
      {
        'question': 'Choose the antonym of "generous".',
        'options': ['Kind', 'Selfish', 'Helpful', 'Giving'],
        'answer': 1,
        'explanation': 'Selfish describes someone unwilling to give or share.',
      },
      {
        'question': 'Fill in the blank: Neither Ravi nor his friends ___ present.',
        'options': ['Was', 'Is', 'Were', 'Has'],
        'answer': 2,
        'explanation': 'With neither...nor, the verb agrees with the nearer subject, friends.',
      },
      {
        'question': 'Choose the correct phrase: She prefers tea ___ coffee.',
        'options': ['Than', 'Over than', 'To', 'From'],
        'answer': 2,
        'explanation': 'The standard construction is prefer one thing to another.',
      },
    ];
  }

  if (widget.difficulty == 'Hard') {
    return [
      {
        'question': 'Choose the correct meaning of "ephemeral".',
        'options': ['Permanent', 'Short-lived', 'Powerful', 'Ancient'],
        'answer': 1,
        'explanation': 'Ephemeral means lasting for a very short time.',
      },
      {
        'question': 'Identify the figure of speech: "The wind whispered through the trees."',
        'options': ['Simile', 'Metaphor', 'Personification', 'Hyperbole'],
        'answer': 2,
        'explanation': 'Personification gives the human action of whispering to the wind.',
      },
      {
        'question': 'Choose the correct indirect speech: He said, "I am tired."',
        'options': [
          'He said that I am tired.',
          'He said that he was tired.',
          'He says he was tired.',
          'He said that he is tiring.',
        ],
        'answer': 1,
        'explanation': 'In reported speech, am changes to was and I changes to he.',
      },
      {
        'question': 'Choose the correct word: The new rule will ___ everyone.',
        'options': ['Affect', 'Effect', 'Affection', 'Effective'],
        'answer': 0,
        'explanation': 'Affect is a verb meaning to influence.',
      },
      {
        'question': 'Identify the clause: "Although it was raining, we went outside."',
        'options': [
          'Noun clause',
          'Adjective clause',
          'Adverbial clause',
          'Main clause only',
        ],
        'answer': 2,
        'explanation': 'Although it was raining is a concessive adverbial clause.',
      },
      {
        'question': 'Choose the grammatically correct sentence.',
        'options': [
          'Each of the students have a book.',
          'Each of the students has a book.',
          'Each students has a book.',
          'Each of students have books.',
        ],
        'answer': 1,
        'explanation': 'Each is singular and takes the singular verb has.',
      },
      {
        'question': 'What does the idiom "to bite the bullet" mean?',
        'options': [
          'To avoid responsibility',
          'To face a difficult situation bravely',
          'To become angry',
          'To make a quick decision without thought',
        ],
        'answer': 1,
        'explanation': 'The idiom means facing a difficult or unpleasant situation with courage.',
      },
      {
        'question': 'Choose the correct spelling.',
        'options': ['Accomodation', 'Acommodation', 'Accommodation', 'Accommadation'],
        'answer': 2,
        'explanation': 'Accommodation is spelled with double c and double m.',
      },
      {
        'question': 'Identify the word that is closest in meaning to "meticulous".',
        'options': ['Careless', 'Careful', 'Impatient', 'Ordinary'],
        'answer': 1,
        'explanation': 'Meticulous means showing great attention to detail.',
      },
      {
        'question': 'Choose the correct conditional sentence.',
        'options': [
          'If I had known, I would have helped.',
          'If I know, I would have helped.',
          'If I had knew, I will help.',
          'If I knew, I will have helped.',
        ],
        'answer': 0,
        'explanation': 'The third conditional uses if + past perfect and would have + past participle.',
      },
            {
        'question': 'Choose the correct meaning of "obfuscate".',
        'options': ['Clarify', 'Confuse', 'Simplify', 'Reveal'],
        'answer': 1,
        'explanation': 'Obfuscate means to make something unclear or difficult to understand.',
      },
      {
        'question': 'Identify the figure of speech: "Time is a thief."',
        'options': ['Simile', 'Personification', 'Metaphor', 'Alliteration'],
        'answer': 2,
        'explanation': 'The sentence directly compares time to a thief without using like or as.',
      },
      {
        'question': 'Choose the correct word: The evidence was ___ to the investigation.',
        'options': ['Irrelevant', 'Immaterial', 'Pertinent', 'Redundant'],
        'answer': 2,
        'explanation': 'Pertinent means relevant or directly related to a subject.',
      },
      {
        'question': 'Which sentence uses the subjunctive mood correctly?',
        'options': [
          'I suggest that he is present.',
          'I suggest that he be present.',
          'I suggest that he was present.',
          'I suggest that he being present.',
        ],
        'answer': 1,
        'explanation': 'The subjunctive form be is used after expressions such as suggest that.',
      },
      {
        'question': 'Choose the correct meaning of "laconic".',
        'options': ['Using very few words', 'Extremely talkative', 'Emotionally sensitive', 'Difficult to understand'],
        'answer': 0,
        'explanation': 'Laconic describes speech or writing that uses very few words.',
      },
      {
        'question': 'Identify the type of clause: "Whoever finishes first will receive a prize."',
        'options': ['Adjective clause', 'Adverbial clause', 'Noun clause', 'Independent clause only'],
        'answer': 2,
        'explanation': 'Whoever finishes first functions as the subject of the sentence.',
      },
      {
        'question': 'Choose the correct sentence.',
        'options': [
          'Hardly had I arrived when it started raining.',
          'Hardly I had arrived when it started raining.',
          'Hardly had I arrived than it started raining.',
          'Hardly I arrived when it started raining.',
        ],
        'answer': 0,
        'explanation': 'Hardly is followed by subject-auxiliary inversion and the conjunction when.',
      },
      {
        'question': 'What does the idiom "a Pyrrhic victory" mean?',
        'options': [
          'A victory achieved easily',
          'A victory with devastating costs',
          'A completely unexpected defeat',
          'A victory without competition',
        ],
        'answer': 1,
        'explanation': 'A Pyrrhic victory is won at such a great cost that it may not be worthwhile.',
      },
      {
        'question': 'Choose the correct word: The manager tried to ___ the disagreement.',
        'options': ['Provoke', 'Escalate', 'Reconcile', 'Aggravate'],
        'answer': 2,
        'explanation': 'Reconcile means to restore friendly relations or settle a disagreement.',
      },
      {
        'question': 'Identify the literary device: "The silence was deafening."',
        'options': ['Oxymoron', 'Simile', 'Alliteration', 'Onomatopoeia'],
        'answer': 0,
        'explanation': 'Deafening silence combines contradictory terms, creating an oxymoron.',
      },
      {
        'question': 'Choose the correct meaning of "ubiquitous".',
        'options': ['Rarely found', 'Present everywhere', 'Completely invisible', 'Highly valuable'],
        'answer': 1,
        'explanation': 'Ubiquitous means appearing or existing everywhere.',
      },
      {
        'question': 'Choose the grammatically correct sentence.',
        'options': [
          'Neither the manager nor the employees was available.',
          'Neither the manager nor the employees were available.',
          'Neither the manager or the employees were available.',
          'Neither manager nor employees is available.',
        ],
        'answer': 1,
        'explanation': 'The verb agrees with the nearer plural subject employees.',
      },
      {
        'question': 'What is the meaning of "mitigate"?',
        'options': ['To intensify', 'To reduce severity', 'To ignore completely', 'To establish firmly'],
        'answer': 1,
        'explanation': 'Mitigate means to make something less severe or harmful.',
      },
      {
        'question': 'Choose the correct passive construction: "Someone must have stolen the documents."',
        'options': [
          'The documents must have stolen.',
          'The documents must have been stolen.',
          'The documents must be stealing.',
          'The documents must have been stealing.',
        ],
        'answer': 1,
        'explanation': 'The modal perfect passive structure is must have been followed by a past participle.',
      },
      {
        'question': 'Identify the word that is an example of a malapropism.',
        'options': [
          'He gave a brief explanation.',
          'She is the pineapple of politeness.',
          'They arrived before sunset.',
          'The room was extremely quiet.',
        ],
        'answer': 1,
        'explanation': 'Pineapple is mistakenly used in place of pinnacle, creating a malapropism.',
      },
      {
        'question': 'Choose the correct meaning of "fastidious".',
        'options': ['Careless', 'Very attentive to detail', 'Easily satisfied', 'Indifferent'],
        'answer': 1,
        'explanation': 'Fastidious describes someone who pays great attention to detail.',
      },
      {
        'question': 'Which sentence contains a dangling modifier?',
        'options': [
          'Walking down the street, I saw a beautiful garden.',
          'After finishing the assignment, she went to sleep.',
          'Walking down the street, the trees looked beautiful.',
          'Having completed the work, he submitted it.',
        ],
        'answer': 2,
        'explanation': 'The sentence incorrectly suggests that the trees were walking down the street.',
      },
      {
        'question': 'Choose the correct meaning of "equivocal".',
        'options': ['Unambiguous', 'Open to multiple interpretations', 'Completely false', 'Highly persuasive'],
        'answer': 1,
        'explanation': 'Equivocal means ambiguous or open to more than one interpretation.',
      },
      {
        'question': 'Identify the rhetorical device: "Who does not want to succeed?"',
        'options': ['Rhetorical question', 'Hyperbole', 'Irony', 'Euphemism'],
        'answer': 0,
        'explanation': 'A rhetorical question is asked for effect rather than to obtain an answer.',
      },
      {
        'question': 'Choose the correct meaning of "intransigent".',
        'options': ['Flexible', 'Unwilling to compromise', 'Generous', 'Uncertain'],
        'answer': 1,
        'explanation': 'Intransigent describes someone who refuses to change their position or compromise.',
      },
    ];
  }

  return [
        {
          'question': 'Choose the correct spelling.',
          'options': ['Beautifull', 'Beautiful', 'Beutiful', 'Butiful'],
          'answer': 1,
          'explanation':
    'The correct spelling is "Beautiful".',
        },
        {
          'question': 'What is the plural of "child"?',
          'options': ['Childs', 'Childes', 'Children', 'Childrens'],
          'answer': 2,
          'explanation':
    'The plural of child is children, an irregular plural form.',
        },
        {
          'question': 'Choose the opposite of "happy".',
          'options': ['Joyful', 'Cheerful', 'Sad', 'Excited'],
          'answer': 2,
          'explanation':
    'The opposite of happy is sad.',
        },
        {
          'question': 'Which word is a noun?',
          'options': ['Quickly', 'Beautiful', 'Happiness', 'Run'],
          'answer': 2,
          'explanation':
    'Happiness is a noun, while the others are adjectives or verbs.',
        },
        {
          'question': 'Fill in the blank: She ___ to school every day.',
          'options': ['go', 'goes', 'going', 'gone'],
          'answer': 1,
          'explanation':
    'The correct answer is "goes" because it is the third-person singular form of the verb "to go".',
        },
        {
          'question': 'Choose the correct past tense of "go".',
          'options': ['Goed', 'Gone', 'Went', 'Going'],
          'answer': 2,
          'explanation':
    'The correct past tense of "go" is "went".',
        },
        {
          'question': 'Which word is an adjective?',
          'options': ['Quickly', 'Beautiful', 'Running', 'Speak'],
          'answer': 1,
          'explanation':
    'Beautiful is an adjective, while the others are adverbs or verbs.',
        },
        {
          'question': 'Choose the synonym of "big".',
          'options': ['Tiny', 'Small', 'Large', 'Short'],
          'answer': 2,
          'explanation':
    'Large is a synonym of "big".',
        },
        {
          'question': 'Fill in the blank: I ___ a student.',
          'options': ['am', 'is', 'are', 'be'],
          'answer': 0,
          'explanation':
    'The correct answer is "am" because it is the first-person singular form of the verb "to be".',
        },
        {
          'question': 'Which punctuation mark ends a question?',
          'options': ['Full stop (.)', 'Comma (,)', 'Question mark (?)', 'Colon (:)'],
          'answer': 2,
          'explanation':
    'The question mark (?) is used to end a question.',
        },
                {
          'question': 'What is the opposite of "early"?',
          'options': ['Late', 'Soon', 'Quick', 'Fast'],
          'answer': 0,
          'explanation': 'Late is the opposite of early.',
        },
        {
          'question': 'Choose the correct plural of "mouse".',
          'options': ['Mouses', 'Mice', 'Mousees', 'Mices'],
          'answer': 1,
          'explanation': 'The plural form of mouse is mice.',
        },
        {
          'question': 'Which word is a verb?',
          'options': ['Table', 'Happy', 'Dance', 'Blue'],
          'answer': 2,
          'explanation': 'Dance is an action word, so it is a verb.',
        },
        {
          'question': 'Fill in the blank: They ___ playing cricket.',
          'options': ['is', 'am', 'are', 'was'],
          'answer': 2,
          'explanation': 'They is a plural subject and takes are.',
        },
        {
          'question': 'Choose the synonym of "smart".',
          'options': ['Clever', 'Lazy', 'Weak', 'Slow'],
          'answer': 0,
          'explanation': 'Clever means intelligent or smart.',
        },
        {
          'question': 'What is the past tense of "eat"?',
          'options': ['Eated', 'Eating', 'Eaten', 'Ate'],
          'answer': 3,
          'explanation': 'The simple past tense of eat is ate.',
        },
        {
          'question': 'Which word is an adverb?',
          'options': ['Slow', 'Slowly', 'Slowness', 'Slower'],
          'answer': 1,
          'explanation': 'Slowly describes how an action is performed.',
        },
        {
          'question': 'Choose the correct article: ___ apple a day keeps the doctor away.',
          'options': ['A', 'An', 'The', 'No article'],
          'answer': 1,
          'explanation': 'An is used before a vowel sound.',
        },
        {
          'question': 'What is the opposite of "strong"?',
          'options': ['Powerful', 'Brave', 'Weak', 'Healthy'],
          'answer': 2,
          'explanation': 'Weak is the opposite of strong.',
        },
        {
          'question': 'Which sentence is grammatically correct?',
          'options': [
            'He go to school.',
            'He goes to school.',
            'He going to school.',
            'He gone to school.',
          ],
          'answer': 1,
          'explanation': 'He is singular, so the verb takes the form goes.',
        },
        {
          'question': 'Choose the correct spelling.',
          'options': ['Recieve', 'Receive', 'Receeve', 'Receve'],
          'answer': 1,
          'explanation': 'The correct spelling is Receive.',
        },
        {
          'question': 'What is the plural of "tooth"?',
          'options': ['Tooths', 'Toothes', 'Teeth', 'Teeths'],
          'answer': 2,
          'explanation': 'The plural form of tooth is teeth.',
        },
        {
          'question': 'Fill in the blank: I have lived here ___ 2020.',
          'options': ['For', 'Since', 'At', 'By'],
          'answer': 1,
          'explanation': 'Since is used with a specific starting point in time.',
        },
        {
          'question': 'Which of these is a proper noun?',
          'options': ['City', 'Country', 'India', 'River'],
          'answer': 2,
          'explanation': 'India is the specific name of a country.',
        },
        {
          'question': 'Choose the synonym of "begin".',
          'options': ['Finish', 'Start', 'Stop', 'Close'],
          'answer': 1,
          'explanation': 'Start means the same as begin.',
        },
        {
          'question': 'Which punctuation mark is used to show possession?',
          'options': ['Comma', 'Apostrophe', 'Question mark', 'Colon'],
          'answer': 1,
          'explanation': 'An apostrophe can show ownership or possession.',
        },
        {
          'question': 'Choose the correct form: She ___ a beautiful song.',
          'options': ['sing', 'sings', 'singing', 'sung'],
          'answer': 1,
          'explanation': 'She is singular, so the simple present verb is sings.',
        },
        {
          'question': 'What is the comparative form of "good"?',
          'options': ['Gooder', 'Best', 'Better', 'More good'],
          'answer': 2,
          'explanation': 'The comparative form of good is better.',
        },
        {
          'question': 'Identify the pronoun: "They are my friends."',
          'options': ['Are', 'My', 'Friends', 'They'],
          'answer': 3,
          'explanation': 'They is the pronoun referring to people.',
        },
        {
          'question': 'Choose the correct preposition: The book is ___ the table.',
          'options': ['On', 'At', 'By', 'From'],
          'answer': 0,
          'explanation': 'On describes the book resting on the table surface.',
        },
      ];

    default:
      return [
        {
          'question': 'Which language is used to develop Flutter apps?',
          'options': ['Java', 'Dart', 'Python', 'C'],
          'answer': 1,
        },
        {
          'question': 'What does CPU stand for?',
          'options': [
            'Central Processing Unit',
            'Computer Personal Unit',
            'Central Program Utility',
            'Control Processing User',
          ],
          'answer': 0,
        },
        {
          'question': 'Which data structure follows FIFO?',
          'options': ['Stack', 'Tree', 'Queue', 'Graph'],
          'answer': 2,
        },
        {
          'question': 'Which symbol is commonly used for comments in Dart?',
          'options': ['##', '//', '<!-- -->', '**'],
          'answer': 1,
        },
        {
          'question': 'Which part of a computer displays visual output?',
          'options': ['Keyboard', 'Mouse', 'Monitor', 'Microphone'],
          'answer': 2,
        },
            ];
  }

  throw StateError('Unsupported quiz category: ${widget.category}');
}


void nextQuestion() {
  if (selectedAnswer == null && remainingSeconds > 0) return;

  if (selectedAnswer == quizQuestions[currentQuestion]['answer']) {
    score++;
  }

  if (currentQuestion < quizQuestions.length - 1) {
    setState(() {
      currentQuestion++;
      selectedAnswer = null;
    });
    startTimer();
  } else {
    questionTimer?.cancel();

    final int finalScore = score;
    final int total = quizQuestions.length;
    final int percentage =
        total > 0 ? (finalScore / total * 100).round() : 0;

    QuizHistoryStorage.saveAttempt(
      QuizAttempt(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: widget.customTitle ?? '${widget.category} Quiz',
        category: widget.category,
        score: finalScore,
        totalQuestions: total,
        percentage: percentage,
        completedAt: DateTime.now(),
      ),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultsScreen(
          score: finalScore,
          totalQuestions: total,
          category: widget.category,
          userAnswers: userAnswers,
          questions: quizQuestions,
          onPlayAgain: () {
            setState(() {
              currentQuestion = 0;
              selectedAnswer = null;
              score = 0;
            });
            _initializeQuiz();
          },
        ),
      ),
    );
  }
}

  Future<void> _changeDifficulty() async {
    questionTimer?.cancel();

    final selectedDifficulty = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => DifficultySelectionScreen(
          category: widget.category,
        ),
      ),
    );

    if (!mounted) return;

    if (selectedDifficulty == null) {
      startTimer();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          category: widget.category,
          difficulty: selectedDifficulty,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    if (isQuizLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6558F5),
          ),
        ),
      );
    }

    final question = quizQuestions[currentQuestion];
    final options = question['options'] as List<String>;

    return Scaffold(
      appBar: AppBar(
  title: Text(widget.customTitle ?? 'Quizora Quiz'),
  backgroundColor: const Color(0xFF6558F5),
  foregroundColor: Colors.white,
  actions: [
    if (widget.customQuestions == null)
      IconButton(
        onPressed: _changeDifficulty,
        icon: const Icon(Icons.tune),
        tooltip: 'Change Difficulty',
      ),
  ],
),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUESTION ${currentQuestion + 1} OF ${quizQuestions.length}',
                style: const TextStyle(
                  color: Color(0xFF6558F5),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: remainingSeconds <= 10
                      ? const Color(0xFFFFE5E5)
                      : const Color(0xFFE9E6FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        color: remainingSeconds <= 10
                          ? Colors.red
                          : const Color(0xFF6558F5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Time left: $remainingSeconds seconds',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: remainingSeconds <= 10
                            ? Colors.red
                            : const Color(0xFF6558F5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (currentQuestion + 1) / quizQuestions.length,
                minHeight: 8,
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF6558F5),
                backgroundColor: const Color(0xFFE9E6FF),
              ),
              const SizedBox(height: 30),
              Text(
                question['question'] as String,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF252344),
                ),
              ),
              const SizedBox(height: 24),
              ...List.generate(options.length, (index) {
                final isSelected = selectedAnswer == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        selectedAnswer = index;
                        userAnswers[currentQuestion] = index;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE9E6FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6558F5)
                              : const Color(0xFFECEAF5),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isSelected
                                ? const Color(0xFF6558F5)
                                : const Color(0xFFF0EFF8),
                            child: Text(
                              String.fromCharCode(65 + index),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF77758D),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              options[index],
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF6558F5),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed:
                      selectedAnswer == null ? null : nextQuestion,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6558F5),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    currentQuestion == quizQuestions.length - 1
                        ? 'Finish Quiz'
                        : 'Next Question  →',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizResultsScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final String category;
  final List<int?> userAnswers;
  final List<Map<String, dynamic>> questions;
  final VoidCallback onPlayAgain;

  const QuizResultsScreen({
    super.key,
    required this.score,
    required this.totalQuestions,
    required this.category,
    required this.userAnswers,
    required this.questions,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score / totalQuestions * 100).round();

    String feedback;
    String message;
    IconData resultIcon;

    if (percentage >= 80) {
      feedback = 'Excellent Work!';
      message = 'Amazing job! You really know your stuff.';
      resultIcon = Icons.emoji_events_rounded;
    } else if (percentage >= 60) {
      feedback = 'Good Job!';
      message = 'Well done! Keep practising to improve.';
      resultIcon = Icons.thumb_up_rounded;
    } else if (percentage >= 40) {
      feedback = 'Keep Going!';
      message = 'You are learning. Practice makes progress!';
      resultIcon = Icons.trending_up_rounded;
    } else {
      feedback = 'Keep Learning!';
      message = 'Review the topics and give it another try.';
      resultIcon = Icons.school_rounded;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        backgroundColor: const Color(0xFF6558F5),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E6FF),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Icon(
                    resultIcon,
                    size: 54,
                    color: const Color(0xFF6558F5),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  feedback,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$category Quiz Completed',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9E6FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR SCORE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Color(0xFF6558F5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$score / $totalQuestions',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6558F5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$percentage%',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                          MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            category: category,
                          ),
                        ),
                      );
                    },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Play Again'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                    builder: (context) => QuizReviewScreen(
                      questions: questions,
                      userAnswers: userAnswers,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.fact_check_rounded),
              label: const Text('Review Answers'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuizReviewScreen extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final List<int?> userAnswers;

  const QuizReviewScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Answers'),
        backgroundColor: const Color(0xFF6558F5),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          final question = questions[index];
          final options = question['options'] as List;
          final correctAnswer = question['answer'] as int;
          final selectedAnswer = userAnswers[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question['question'] as String,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedAnswer == null
                        ? 'Your Answer: Not answered'
                        : 'Your Answer: ${options[selectedAnswer]}',
                    style: TextStyle(
                      color: selectedAnswer == null
                          ? Colors.orange
                          : selectedAnswer == correctAnswer
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Correct Answer: ${options[correctAnswer]}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final TextEditingController _titleController = TextEditingController();
  String? _selectedCategory;

  static const List<String> _categories = [
    'Programming',
    'Computer Science',
    'General Knowledge',
    'Aptitude',
    'English',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Quiz'),
        foregroundColor: const Color(0xFF252344),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.quiz_rounded,
              size: 55,
              color: Color(0xFF6558F5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Build your own quiz!',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: Color(0xFF252344),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a title, then add 10 questions with four options each.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF77758D),
              ),
            ),
            const SizedBox(height: 25),
            const Text(
              'Quiz Title',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g. Flutter Fundamentals',
                prefixIcon: const Icon(Icons.edit_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                hintText: 'Choose a category',
                prefixIcon: const Icon(Icons.category_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1EFFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.format_list_numbered_rounded,
                    color: Color(0xFF6558F5),
                    size: 30,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '10 questions • 4 options per question • 1 correct answer',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF252344),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final title = _titleController.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a quiz title.'),
                      ),
                    );
                    return;
                  }

                  if (_selectedCategory == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a category.'),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomQuizEditorScreen(
                        quizTitle: title,
                        category: _selectedCategory!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6558F5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ClassroomQuizSetupScreen extends StatefulWidget {
  const ClassroomQuizSetupScreen({super.key});

  @override
  State<ClassroomQuizSetupScreen> createState() =>
      _ClassroomQuizSetupScreenState();
}

class _ClassroomQuizSetupScreenState
    extends State<ClassroomQuizSetupScreen> {
  final TextEditingController _titleController =
      TextEditingController();

  String? _selectedCategory;
  String _quizMode = 'selfPaced';

  static const List<String> _categories = [
    'Programming',
    'Computer Science',
    'General Knowledge',
    'Aptitude',
    'English',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _continueToEditor() {
    final title = _titleController.text.trim();

    if (title.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a quiz title and select a category.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomQuizEditorScreen(
          quizTitle: title,
          category: _selectedCategory!,
          isClassroomQuiz: true,
          quizMode: _quizMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Classroom Quiz'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.cast_for_education_rounded,
              size: 55,
              color: Color(0xFF6558F5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Set up your classroom quiz',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quiz Title',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Enter classroom quiz title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                hintText: 'Choose category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Quiz Mode',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            RadioListTile<String>(
              title: const Text('Live Quiz'),
              subtitle: const Text(
                'All students start together when the teacher starts.',
              ),
              value: 'live',
              groupValue: _quizMode,
              onChanged: (value) {
                setState(() {
                  _quizMode = value!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Self-Paced Quiz'),
              subtitle: const Text(
                'Students can start independently.',
              ),
              value: 'selfPaced',
              groupValue: _quizMode,
              onChanged: (value) {
                setState(() {
                  _quizMode = value!;
                });
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _continueToEditor,
                child: const Text('Continue to Add Questions'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class CustomQuizEditorScreen extends StatefulWidget {
  final String quizTitle;
  final String category;
  final bool isClassroomQuiz;
  final String quizMode;

  const CustomQuizEditorScreen({
    super.key,
    required this.quizTitle,
    required this.category,
    this.isClassroomQuiz = false,
    this.quizMode = 'selfPaced',
  });

  @override
  State<CustomQuizEditorScreen> createState() =>
      _CustomQuizEditorScreenState();
}

class _CustomQuizEditorScreenState
    extends State<CustomQuizEditorScreen> {
  final List<TextEditingController> _questionControllers =
      List.generate(10, (_) => TextEditingController());

  final List<List<TextEditingController>> _optionControllers =
      List.generate(
    10,
    (_) => List.generate(4, (_) => TextEditingController()),
  );

  final List<int> _correctAnswers = List.filled(10, 0);
  bool _isSaving = false;

  @override
  void dispose() {
    for (final controller in _questionControllers) {
      controller.dispose();
    }

    for (final options in _optionControllers) {
      for (final controller in options) {
        controller.dispose();
      }
    }

    super.dispose();
  }

 String _generateRoomCode() {
  const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();

  return List.generate(
    6,
    (_) => characters[random.nextInt(characters.length)],
  ).join();
}

  Future<void> _saveQuiz() async {
    final List<Map<String, dynamic>> customQuestions = [];

    for (int i = 0; i < 10; i++) {
      final question = _questionControllers[i].text.trim();
      final options = _optionControllers[i]
          .map((controller) => controller.text.trim())
          .toList();

      if (question.isEmpty || options.any((option) => option.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please complete question ${i + 1} and all four options.',
            ),
          ),
        );
        return;
      }

      customQuestions.add({
        'question': question,
        'options': options,
        'answer': _correctAnswers[i],
        'explanation': 'The correct answer is ${options[_correctAnswers[i]]}.',
      });
    }

    final newQuiz = CustomQuiz(
      id: 'quiz_${DateTime.now().millisecondsSinceEpoch}',
      title: widget.quizTitle,
      category: widget.category,
      createdAt: DateTime.now(),
      questions: customQuestions,
    );
    if (widget.isClassroomQuiz) {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please log in first.')),
    );
    return;
  }

  setState(() {
    _isSaving = true;
  });

  try {
    final roomCode = _generateRoomCode();
    final profile = await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .get();

debugPrint('TEACHER EMAIL: ${user.email}');
debugPrint('TEACHER UID: ${user.uid}');
debugPrint('FIRESTORE ROLE: ${profile.data()?['role']}');
debugPrint('QUIZ MODE: ${widget.quizMode}');
debugPrint('QUESTION COUNT: ${customQuestions.length}');
debugPrint('ROOM CODE: $roomCode');
    final publicQuestions = customQuestions.map((question) {
  return {
    'question': question['question'],
    'options': question['options'],
  };
}).toList();

final answerKey = customQuestions.map((question) {
  return {
    'answer': question['answer'],
    'explanation': question['explanation'],
  };
}).toList();

final batch = FirebaseFirestore.instance.batch();

final quizRef = FirebaseFirestore.instance
    .collection('classroomQuizzes')
    .doc(roomCode);

final answerRef = FirebaseFirestore.instance
    .collection('classroomQuizAnswers')
    .doc(roomCode);

batch.set(quizRef, {
  'title': widget.quizTitle,
  'category': widget.category,
  'questions': publicQuestions,
  'roomCode': roomCode,
  'teacherId': user.uid,
  'quizMode': widget.quizMode,
  'status': 'waiting',
  'createdAt': FieldValue.serverTimestamp(),
});

batch.set(answerRef, {
  'teacherId': user.uid,
  'answers': answerKey,
  'createdAt': FieldValue.serverTimestamp(),
});

await batch.commit();
final answerVerification = await answerRef.get(
  const GetOptions(source: Source.server),
);

debugPrint('ANSWER KEY EXISTS: ${answerVerification.exists}');
debugPrint('ANSWER KEY DATA: ${answerVerification.data()}');
        final verification = await FirebaseFirestore.instance
        .collection('classroomQuizzes')
        .doc(roomCode)
        .get(const GetOptions(source: Source.server));

    if (!verification.exists) {
      throw Exception('Quiz was not found on the Firestore server.');
    }

    debugPrint('CLASSROOM QUIZ VERIFIED: $roomCode');

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Classroom Quiz Created!'),
        content: Text(
          'Your room code is: $roomCode\n\n'
          'Share this code with your students.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    return;
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save classroom quiz: $e')),
    );
    return;
  }
}
    await CustomQuizStorage.saveQuiz(newQuiz);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quiz "${widget.quizTitle}" saved successfully!'),
        backgroundColor: const Color(0xFF079B85),
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          category: widget.category,
          customTitle: widget.quizTitle,
          customQuestions: customQuestions,
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizTitle),
        foregroundColor: const Color(0xFF252344),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Create 10 Questions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF252344),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter four options for every question and select its correct answer.',
            style: TextStyle(color: Color(0xFF77758D)),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < 10; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question ${i + 1} of 10',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6558F5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _questionControllers[i],
                      decoration: const InputDecoration(
                        labelText: 'Enter question',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    for (int j = 0; j < 4; j++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: _optionControllers[i][j],
                          decoration: InputDecoration(
                            labelText: 'Option ${j + 1}',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(
                              Icons.radio_button_unchecked,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select the correct option:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    for (int j = 0; j < 4; j++)
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Option ${j + 1}'),
                        value: j,
                        groupValue: _correctAnswers[i],
                        activeColor: const Color(0xFF6558F5),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _correctAnswers[i] = value;
                            });
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
      FilledButton.icon(
  onPressed: _isSaving ? null : _saveQuiz,
  icon: _isSaving
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
      : const Icon(Icons.check_circle_outline_rounded),
  label: Text(
    _isSaving ? 'Saving Quiz...' : 'Validate 10 Questions',
  ),
  style: FilledButton.styleFrom(
    backgroundColor: const Color(0xFF6558F5),
    padding: const EdgeInsets.symmetric(vertical: 16),
  ),
),
        ],
      ),
    );
  }
}

class QuizHistoryScreen extends StatefulWidget {
  const QuizHistoryScreen({super.key});

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  List<QuizAttempt> _attempts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final attempts = await QuizHistoryStorage.loadAttempts();

    if (mounted) {
      setState(() {
        _attempts = attempts;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');

    return '$day/$month/${localDate.year} '
        '${localDate.hour.toString().padLeft(2, '0')}:'
        '${localDate.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz History'),
        backgroundColor: const Color(0xFF6558F5),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attempts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 65,
                        color: Color(0xFFAAA6C8),
                      ),
                      SizedBox(height: 15),
                      Text(
                        'No Quiz History Yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Complete a quiz to see your performance here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF77758D)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: _attempts.length,
                  itemBuilder: (context, index) {
                    final attempt = _attempts[index];
                    final percentage = attempt.percentage;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(17),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    attempt.title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF252344),
                                    ),
                                  ),
                                ),
                                Text(
                                  '$percentage%',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6558F5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              attempt.category,
                              style: const TextStyle(
                                color: Color(0xFF77758D),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 17,
                                  color: Color(0xFF079B85),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${attempt.score}/${attempt.totalQuestions} correct',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 15,
                                  color: Color(0xFF77758D),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  _formatDate(attempt.completedAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF77758D),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
  final user = snapshot.data!;

  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    future: FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(),
    builder: (context, profileSnapshot) {
      if (profileSnapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (profileSnapshot.hasError ||
          !profileSnapshot.hasData ||
          !profileSnapshot.data!.exists) {
        return const Scaffold(
          body: Center(
            child: Text('Unable to load your account details.'),
          ),
        );
      }

      final role = profileSnapshot.data!.data()?['role']
          ?.toString()
          .toLowerCase();

      if (role == 'teacher') {
        return const TeacherDashboard();
      }

      return const StudentDashboard();
    },
  );
}

        return const LoginScreen();
      },
    );
  }
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';

      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential') {
        message = 'Invalid email or password.';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
void dispose() {
  _emailController.dispose();
  _passwordController.dispose();
  _passwordFocusNode.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.quiz_rounded,
                    size: 75,
                    color: Color(0xFF6558F5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to Quizora!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF252344),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Login to continue learning and playing',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 35),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _passwordController,
obscureText: _obscurePassword,
textInputAction: TextInputAction.done,
onFieldSubmitted: (_) {
  if (!_isLoading) {
    _login();
  }
},
decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6558F5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                                       ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Don't have an account? Sign up",
                      style: TextStyle(
                        color: Color(0xFF6558F5),
                        fontWeight: FontWeight.bold,
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
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'Student';
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

    } on FirebaseAuthException catch (e) {
      String message = e.message ?? 'Registration failed.';

      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Please choose a stronger password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: const Color(0xFF6558F5),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.person_add_alt_1,
                  size: 65,
                  color: Color(0xFF6558F5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Join Quizora!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your account to get started.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Select Your Role',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Student',
                      child: Text('Student'),
                    ),
                    DropdownMenuItem(
                      value: 'Teacher',
                      child: Text('Teacher'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedRole = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must contain at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6558F5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login again.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFFF8F7FF),
        foregroundColor: const Color(0xFF252344),
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text('Unable to load profile details.'),
            );
          }

          final data =
              snapshot.data!.data() as Map<String, dynamic>;

          final name = data['name'] ?? 'User';
          final email = data['email'] ?? user.email ?? '';
          final role = data['role'] ?? 'Student';

          return Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
  child: Column(
    children: [
                const SizedBox(height: 30),
                const CircleAvatar(
                  radius: 55,
                  backgroundColor: Color(0xFFE9E6FF),
                  child: Icon(
                    Icons.person_rounded,
                    size: 65,
                    color: Color(0xFF6558F5),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  name.toString(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF252344),
                  ),
                ),
                const SizedBox(height: 30),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Full Name'),
                        subtitle: Text(name.toString()),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email Address'),
                        subtitle: Text(email.toString()),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.school_outlined),
                        title: const Text('Account Role'),
                        subtitle: Text(role.toString()),
                      ),
                    ],
                  ),
                                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
  await FirebaseAuth.instance.signOut();

  if (context.mounted) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
},
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6558F5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }
}
class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        backgroundColor: const Color(0xFFF8F7FF),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.school_rounded,
                size: 75,
                color: Color(0xFF6558F5),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome, Student!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Ready to test your knowledge?'),
              const SizedBox(height: 30),
              OutlinedButton.icon(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const JoinClassroomQuizScreen(),
      ),
    );
  },
  icon: const Icon(Icons.meeting_room_rounded),
  label: const Text('Join Classroom Quiz'),
  style: OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF6558F5),
    minimumSize: const Size(220, 48),
  ),
),
const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                  );
                },
                child: const Text('Play Quiz'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JoinClassroomQuizScreen extends StatefulWidget {
  const JoinClassroomQuizScreen({super.key});

  @override
  State<JoinClassroomQuizScreen> createState() =>
      _JoinClassroomQuizScreenState();
}

class _JoinClassroomQuizScreenState
    extends State<JoinClassroomQuizScreen> {
  final TextEditingController _roomCodeController =
      TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

Future<void> _joinClassroom() async {
  final roomCode = _roomCodeController.text.trim().toUpperCase();

  if (roomCode.length != 6) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter a valid 6-character room code.'),
      ),
    );
    return;
  }

  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please log in before joining a classroom quiz.'),
      ),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final quizSnapshot = await FirebaseFirestore.instance
        .collection('classroomQuizzes')
        .doc(roomCode)
        .get();

    if (!quizSnapshot.exists) {
      throw Exception('Invalid classroom code.');
    }

    final data = quizSnapshot.data()!;

    final questions = List<Map<String, dynamic>>.from(
      (data['questions'] as List).map(
        (question) => Map<String, dynamic>.from(question as Map),
      ),
    );

    if (questions.length != 10) {
      throw Exception('This classroom quiz does not have 10 questions.');
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassroomQuizScreen(
  roomCode: roomCode,
  teacherId: data['teacherId'] as String,
  studentId: user.uid,
  quizTitle: data['title'] as String,
  category: data['category'] as String,
  questions: questions,
),
      ),
    );
  } on FirebaseException catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.message ?? 'Unable to join classroom quiz.'),
      ),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Classroom Quiz'),
        backgroundColor: const Color(0xFFF8F7FF),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.meeting_room_rounded,
                  size: 80,
                  color: Color(0xFF6558F5),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Enter Classroom Code',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter the 6-character code shared by your teacher.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _roomCodeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: 'ABC123',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _joinClassroom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6558F5),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text('Join Quiz'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class ClassroomQuizScreen extends StatefulWidget {
  final String roomCode;
  final String teacherId;
  final String studentId;
  final String quizTitle;
  final String category;
  final List<Map<String, dynamic>> questions;

  const ClassroomQuizScreen({
    super.key,
    required this.roomCode,
    required this.teacherId,
    required this.studentId,
    required this.quizTitle,
    required this.category,
    required this.questions,
  });

  @override
  State<ClassroomQuizScreen> createState() =>
      _ClassroomQuizScreenState();
}

class _ClassroomQuizScreenState extends State<ClassroomQuizScreen> {
   int _currentQuestion = 0;
  late List<int?> _answers;
  final Set<int> _lockedQuestions = {};
  bool _isSubmitting = false;

  Timer? _questionTimer;
  int _remainingSeconds = 30;

    @override
  void initState() {
    super.initState();
    _answers = List<int?>.filled(widget.questions.length, null);
    _startQuestionTimer();
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _remainingSeconds = 30;

    _questionTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted || _isSubmitting) {
          timer.cancel();
          return;
        }

        if (_remainingSeconds > 1) {
          setState(() {
            _remainingSeconds--;
          });
        } else {
          timer.cancel();
          _moveToNextQuestion();
        }
      },
    );
  }

  void _moveToNextQuestion() {
  if (_isSubmitting) return;

  _lockedQuestions.add(_currentQuestion);

  if (_currentQuestion < widget.questions.length - 1) {
    setState(() {
      _currentQuestion++;
      _remainingSeconds = 30;
    });
    _startQuestionTimer();
  } else {
    _submitQuiz();
  }
}

  @override
  void dispose() {
    _questionTimer?.cancel();
    super.dispose();
  }


Future<void> _submitQuiz() async {
  if (_isSubmitting) return;

  setState(() {
    _isSubmitting = true;
  });

  try {
    final submissionId = '${widget.roomCode}_${widget.studentId}';

    // Save the student's answers first.
    await FirebaseFirestore.instance
        .collection('classroomSubmissions')
        .doc(submissionId)
        .set({
      'roomCode': widget.roomCode,
      'teacherId': widget.teacherId,
      'studentId': widget.studentId,
      'answers': _answers,
      'submittedAt': FieldValue.serverTimestamp(),
    });

    // Fetch the answer key after submission.
    final answerSnapshot = await FirebaseFirestore.instance
        .collection('classroomQuizAnswers')
        .doc(widget.roomCode)
        .get(const GetOptions(source: Source.server));

    if (!answerSnapshot.exists) {
      throw Exception('Quiz answer key was not found.');
    }

    final answerData = answerSnapshot.data()!;
    final correctAnswers =
        List<dynamic>.from(answerData['answers'] ?? []);

    if (correctAnswers.length != widget.questions.length) {
      throw Exception('Question and answer counts do not match.');
    }

    // Calculate the student's score.
    int score = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      final correctIndex =
          (correctAnswers[i]['answer'] as num).toInt();

      if (_answers[i] == correctIndex) {
        score++;
      }
    }

    final totalQuestions = widget.questions.length;
    final percentage = (score * 100 / totalQuestions).round();

    if (!mounted) return;

    // Display the student's complete results.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Quiz Results',
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 55,
                          color: Color(0xFF6558F5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your Score: $score/$totalQuestions',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Percentage: $percentage%',
                          style: const TextStyle(
                            fontSize: 17,
                            color: Color(0xFF6558F5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const Text(
                    'Answer Review',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...List.generate(totalQuestions, (index) {
                    final question = widget.questions[index];
                    final options =
                        List<String>.from(question['options']);

                    final correctIndex =
                        (correctAnswers[index]['answer'] as num)
                            .toInt();

                    final selectedIndex = _answers[index];

                    final isCorrect =
                        selectedIndex == correctIndex;

                    final selectedText =
                        selectedIndex != null &&
                                selectedIndex >= 0 &&
                                selectedIndex < options.length
                            ? options[selectedIndex]
                            : 'Not answered';

                    final correctText =
                        correctIndex >= 0 &&
                                correctIndex < options.length
                            ? options[correctIndex]
                            : 'Unavailable';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${index + 1}. ${question['question']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Your answer: $selectedText'),
                          const SizedBox(height: 5),
                          Text(
                            'Correct answer: $correctText',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                isCorrect
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: isCorrect
                                    ? Colors.green
                                    : Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isCorrect
                                    ? 'Correct'
                                    : 'Incorrect',
                                style: TextStyle(
                                  color: isCorrect
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pop(context);
              },
              child: const Text('Back'),
            ),
          ],
        );
      },
    );
  } on FirebaseException catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.message ?? 'Unable to submit your quiz.',
        ),
      ),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to load quiz results: $error'),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}


  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Classroom Quiz')),
        body: const Center(
          child: Text('No questions are available.'),
        ),
      );
    }

    final question = widget.questions[_currentQuestion];
    final options = List<String>.from(question['options'] as List);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizTitle),
        backgroundColor: const Color(0xFFF8F7FF),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.category,
              style: const TextStyle(
                color: Color(0xFF6558F5),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestion + 1} of ${widget.questions.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Color(0xFF6558F5),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '00:${_remainingSeconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds <= 10
                            ? Colors.red
                            : const Color(0xFF6558F5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (_currentQuestion + 1) / widget.questions.length,
              color: const Color(0xFF6558F5),
              backgroundColor: Colors.grey.shade200,
            ),
            const SizedBox(height: 28),
            Text(
              question['question'] as String,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ...List.generate(options.length, (index) {
              final isSelected = _answers[_currentQuestion] == index;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF6558F5)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: RadioListTile<int>(
                  value: index,
                  groupValue: _answers[_currentQuestion],
                  activeColor: const Color(0xFF6558F5),
                  title: Text(options[index]),
                  onChanged: _lockedQuestions.contains(_currentQuestion)
                    ? null
                    : (value) {
                    setState(() {
                      _answers[_currentQuestion] = value;
                    });
                  },
                ),
              );
            }),
            const SizedBox(height: 24),
            Row(
              children: [
                if (_currentQuestion > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
    ? null
    : () {
        setState(() {
          _currentQuestion--;
          _remainingSeconds = 30;
        });
        _startQuestionTimer();
      },
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentQuestion > 0)
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                           _moveToNextQuestion();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6558F5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _currentQuestion ==
                                    widget.questions.length - 1
                                ? 'Submit Quiz'
                                : 'Next Question',
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: const Color(0xFFF8F7FF),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Center(
              child: Icon(
                Icons.cast_for_education_rounded,
                size: 75,
                color: Color(0xFF6558F5),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Welcome, Teacher!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF252344),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'Manage your classroom quizzes here.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 35),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ClassroomQuizSetupScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Create Classroom Quiz'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6558F5),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                ),
              ),
            ),
                        const SizedBox(height: 35),
            const Text(
              'My Classroom Quizzes',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: Color(0xFF252344),
              ),
            ),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('classroomQuizzes')
                  .where(
                    'teacherId',
                    isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return const Text('Unable to load classroom quizzes.');
                }

                final quizzes = snapshot.data?.docs ?? [];

                if (quizzes.isEmpty) {
                  return const Text(
                    'No classroom quizzes created yet.',
                    style: TextStyle(color: Colors.grey),
                  );
                }

                return Column(
                  children: quizzes.map((quiz) {
                    final data = quiz.data();

                    return Card(
  margin: const EdgeInsets.only(bottom: 12),
  child: Column(
    children: [
      ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFEDEBFF),
          child: Icon(
            Icons.quiz_rounded,
            color: Color(0xFF6558F5),
          ),
        ),
        title: Text(
          data['title'] ?? 'Untitled Quiz',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Category: ${data['category'] ?? 'N/A'}\n'
          'Room Code: ${data['roomCode'] ?? 'N/A'}\n'
          'Mode: ${data['quizMode'] ?? 'N/A'}\n'
          'Status: ${data['status'] ?? 'N/A'}',
        ),
        isThreeLine: true,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClassroomSubmissionsScreen(
                    roomCode: data['roomCode'] as String,
                    teacherId: data['teacherId'] as String,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.people_alt_rounded),
            label: const Text('View Student Submissions'),
          ),
        ),
      ),
    ],
  ),
);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ClassroomSubmissionsScreen extends StatelessWidget {
  final String roomCode;
  final String teacherId;

  const ClassroomSubmissionsScreen({
    super.key,
    required this.roomCode,
    required this.teacherId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('classroomQuizAnswers')
          .doc(roomCode)
          .get(),
      builder: (context, answerSnapshot) {
        if (answerSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (answerSnapshot.hasError || !answerSnapshot.hasData) {
  return Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Unable to load quiz answer key.\n\n'
          '${answerSnapshot.error}',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

        final answerData = answerSnapshot.data!.data();

        if (answerData == null) {
          return const Scaffold(
            body: Center(
              child: Text('Quiz answer key was not found.'),
            ),
          );
        }

        final correctAnswers = List<dynamic>.from(
          answerData['answers'] ?? [],
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Student Submissions'),
            backgroundColor: const Color(0xFFF8F7FF),
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('classroomSubmissions')
                .where('roomCode', isEqualTo: roomCode)
                .where('teacherId', isEqualTo: teacherId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text('Unable to load student submissions.'),
                );
              }

              final submissions = snapshot.data?.docs ?? [];

              if (submissions.isEmpty) {
                return const Center(
                  child: Text(
                    'No students have submitted this quiz yet.',
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: submissions.length,
                itemBuilder: (context, index) {
                  final submission = submissions[index].data();

                  final answers = List<dynamic>.from(
                    submission['answers'] ?? [],
                  );

                  final totalQuestions = correctAnswers.length;
                  int score = 0;

                  for (int i = 0;
                      i < totalQuestions && i < answers.length;
                      i++) {
                    final correctAnswer = correctAnswers[i]['answer'];

                    if (answers[i] != null &&
                        answers[i] == correctAnswer) {
                      score++;
                    }
                  }

                  final percentage = totalQuestions == 0
                      ? 0
                      : ((score / totalQuestions) * 100).round();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEDEBFF),
                        child: Icon(
                          Icons.person_rounded,
                          color: Color(0xFF6558F5),
                        ),
                      ),
                      title: Text(
                        'Student ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Score: $score/$totalQuestions  •  $percentage%',
                        style: const TextStyle(
                          color: Color(0xFF6558F5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      children: [
                        ListTile(
                          title: const Text('Student ID'),
                          subtitle: Text(
                            submission['studentId'] ?? 'N/A',
                          ),
                        ),
                        ...List<Widget>.generate(
                          totalQuestions,
                          (questionIndex) {
                            final selectedAnswer =
                                questionIndex < answers.length
                                    ? answers[questionIndex]
                                    : null;

                            final correctAnswer =
                                correctAnswers[questionIndex]['answer'];

                            final isCorrect =
                                selectedAnswer != null &&
                                selectedAnswer == correctAnswer;

                            return ListTile(
                              leading: Icon(
                                selectedAnswer == null
                                    ? Icons.remove_circle_outline
                                    : isCorrect
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                color: selectedAnswer == null
                                    ? Colors.orange
                                    : isCorrect
                                        ? Colors.green
                                        : Colors.red,
                              ),
                              title: Text(
                                'Question ${questionIndex + 1}',
                              ),
                              subtitle: Text(
                                selectedAnswer == null
                                    ? 'Not answered • Correct option: ${correctAnswer + 1}'
                                    : 'Selected option: ${selectedAnswer + 1} • '
                                        '${isCorrect ? 'Correct' : 'Incorrect'}',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
