# Quizora — Interactive Quiz Application

Quizora is a modern interactive quiz application built with **Flutter and Firebase**. It provides an engaging learning experience through category-based quizzes, custom quizzes, difficulty levels, and classroom-based assessments.

## Features

### Student Features
- Register and log in as a student.
- Explore quizzes across different categories.
- Attempt quizzes with Easy, Medium, and Hard difficulty levels.
- Create and play custom quizzes.
- Join classroom quizzes using a room code.
- Answer timed classroom questions.
- View scores, percentages, and correct answers after submission.
- View quiz history.

### Teacher Features
- Register and log in as a teacher.
- Access the Teacher Dashboard.
- Create classroom quizzes.
- Choose Live or Self-Paced quiz modes.
- Share classroom codes with students.
- View student submissions and scores.

### Technology Stack
- **Frontend:** Flutter, Dart
- **Authentication:** Firebase Authentication
- **Database:** Cloud Firestore
- **Local Storage:** Shared Preferences
- **Testing:** Flutter Test

## Project Structure

```text
Quizora/
├── android/
├── ios/
├── lib/
│   ├── main.dart
│   └── firebase_options.dart
├── test/
├── web/
├── windows/
├── functions/
├── firestore.rules
├── firebase.json
├── pubspec.yaml
└── README.md
```

## Getting Started

### Prerequisites
- Flutter SDK
- Dart SDK
- Visual Studio Code or Android Studio
- A Firebase project
- Chrome or an Android device for running the application

### Installation

1. Clone the repository:

```bash
git clone https://github.com/lekha-sri-nag/Quizora.git
```

2. Navigate to the project directory:

```bash
cd Quizora
```

3. Install dependencies:

```bash
flutter pub get
```

4. Configure Firebase for your own Firebase project. Generate the required Flutter Firebase configuration and configure Firebase Authentication and Cloud Firestore.

5. Run the application:

```bash
flutter run
```

### Firebase Configuration

Quizora uses Firebase Authentication and Cloud Firestore.

The repository includes a Firestore security rules file named `firestore.rules`. Review and deploy the rules to your own Firebase project before using classroom features.

Do not commit private service-account credentials or other secret configuration files.

## Running Tests

Run the Flutter test suite:

```bash
flutter test
```

Check the code for issues:

```bash
flutter analyze
```

## Future Improvements
- Android APK distribution.
- Enhanced classroom management.
- Additional quiz categories and question banks.
- Improved analytics and performance tracking.

## Author

**V. Lekha Sri Nag**

B.Tech — Computer Science and Engineering

GitHub: [lekha-sri-nag](https://github.com/lekha-sri-nag)

---

*Quizora — Learn • Play • Grow*
