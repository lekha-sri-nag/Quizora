import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quizora/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Quizora home screen displays correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuizoraApp(testHome: const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Quizora'), findsOneWidget);
    expect(find.text('Saved Quizzes'), findsOneWidget);
    expect(find.text('Explore Categories'), findsOneWidget);
    expect(find.text('Programming'), findsOneWidget);
    expect(find.text('Computer Science'), findsOneWidget);
    expect(find.text('General Knowledge'), findsOneWidget);
    expect(find.text('Aptitude'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  test('CustomQuizStorage can save, load, and delete quizzes with category', () async {
    final quiz = CustomQuiz(
      id: 'test_quiz_1',
      title: 'Flutter Trivia',
      category: 'Programming',
      createdAt: DateTime.now(),
      questions: [
        {
          'question': 'What is Flutter?',
          'options': ['Framework', 'Bird', 'Language', 'IDE'],
          'answer': 0,
          'explanation': 'Flutter is a UI framework.',
        }
      ],
    );

    // Save quiz
    final saveResult = await CustomQuizStorage.saveQuiz(quiz);
    expect(saveResult, isTrue);

    // Load quizzes
    final loaded = await CustomQuizStorage.loadQuizzes();
    expect(loaded.length, 1);
    expect(loaded.first.title, 'Flutter Trivia');
    expect(loaded.first.category, 'Programming');
    expect(loaded.first.questions.first['question'], 'What is Flutter?');

    // Delete quiz
    final deleteResult = await CustomQuizStorage.deleteQuiz('test_quiz_1');
    expect(deleteResult, isTrue);

    final emptyList = await CustomQuizStorage.loadQuizzes();
    expect(emptyList.isEmpty, isTrue);
  });

  testWidgets('Saved quizzes display category on home screen and can be played', (
    WidgetTester tester,
  ) async {
    final quiz = CustomQuiz(
      id: 'custom_1',
      title: 'Mobile Architecture',
      category: 'Computer Science',
      createdAt: DateTime.now(),
      questions: [
        {
          'question': 'What is BLoC?',
          'options': ['Pattern', 'Toy', 'Database', 'Server'],
          'answer': 0,
          'explanation': 'BLoC stands for Business Logic Component.',
        }
      ],
    );
    await CustomQuizStorage.saveQuiz(quiz);

    await tester.pumpWidget(const QuizoraApp(testHome: const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Mobile Architecture'), findsOneWidget);
    expect(find.text('Computer Science'), findsWidgets);
    expect(find.text('1 Questions'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);

    // Scroll into view and tap play
    await tester.ensureVisible(find.text('Play'));
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    // Verify QuizScreen opened with custom quiz title and questions
    expect(find.text('Mobile Architecture'), findsOneWidget);
    expect(find.text('What is BLoC?'), findsOneWidget);
    expect(find.text('Pattern'), findsOneWidget);
  });

  testWidgets('CreateQuizScreen validates and requires category selection', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const QuizoraApp(testHome: const HomeScreen()));
    await tester.pumpAndSettle();

    // Tap Create Your Own Quiz
    await tester.tap(find.text('Create Your Own Quiz'));
    await tester.pumpAndSettle();

    expect(find.text('Create Your Quiz'), findsOneWidget);
    expect(find.text('Select Category'), findsOneWidget);
    expect(find.text('Choose a category'), findsOneWidget);

    // Enter title, but do not select a category
    final titleField = find.byType(TextField);
    await tester.enterText(titleField, 'Dart Mastery');
    await tester.pumpAndSettle();

    // Try continuing without category
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Please select a category.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Select category from dropdown
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    // Select 'Programming' option in dropdown
    await tester.tap(find.text('Programming').last);
    await tester.pumpAndSettle();

    // Now continue to question editor
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Dart Mastery'), findsOneWidget);
    expect(find.text('Create 10 Questions'), findsOneWidget);
  });

  testWidgets('QuizReviewScreen displays only question, your answer, and correct answer without explanations', (
    WidgetTester tester,
  ) async {
    final sampleQuestions = [
      {
        'question': 'What is Flutter?',
        'options': ['Framework', 'Bird', 'Language', 'IDE'],
        'answer': 0,
        'explanation': 'This explanation should be hidden completely.',
      },
      {
        'question': 'What is Dart?',
        'options': ['Game', 'Language', 'Fruit', 'Tool'],
        'answer': 1,
        'explanation': 'Dart explanation should also be removed.',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: QuizReviewScreen(
          questions: sampleQuestions,
          userAnswers: const [0, null],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify question text is displayed
    expect(find.text('What is Flutter?'), findsOneWidget);
    expect(find.text('What is Dart?'), findsOneWidget);

    // Verify answered question shows user answer and correct answer
    expect(find.text('Your Answer: Framework'), findsOneWidget);
    expect(find.text('Correct Answer: Framework'), findsOneWidget);

    // Verify unanswered question shows 'Your Answer: Not answered'
    expect(find.text('Your Answer: Not answered'), findsOneWidget);
    expect(find.text('Correct Answer: Language'), findsOneWidget);

    // Verify NO explanation text or label exists
    expect(find.textContaining('Explanation'), findsNothing);
    expect(find.textContaining('This explanation should be hidden'), findsNothing);
    expect(find.textContaining('Dart explanation should also be removed'), findsNothing);
  });
}
