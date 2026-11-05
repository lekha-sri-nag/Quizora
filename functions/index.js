
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");

initializeApp();

const db = getFirestore();

function shuffle(items) {
  const result = [...items];

  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }

  return result;
}

// Starts a classroom quiz with independently shuffled questions and options.
exports.startClassroomQuiz = onCall(
    {region: "asia-south1", maxInstances: 10},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Please log in first.");
      }

      const roomCode = String(request.data?.roomCode || "")
          .trim()
          .toUpperCase();

      if (!roomCode) {
        throw new HttpsError("invalid-argument", "Enter a room code.");
      }

      const quizSnapshot = await db
          .collection("classroomQuizzes")
          .doc(roomCode)
          .get();

      if (!quizSnapshot.exists) {
        throw new HttpsError("not-found", "Invalid room code.");
      }

      const quiz = quizSnapshot.data();
      const sourceQuestions = quiz.questions;

      if (!Array.isArray(sourceQuestions) ||
          sourceQuestions.length !== 10) {
        throw new HttpsError(
            "failed-precondition",
            "This quiz does not contain 10 valid questions.",
        );
      }

      const questionOrder = shuffle(
          sourceQuestions.map((_, index) => index),
      );

      const shuffledQuestions = [];
      const optionOrders = [];
      const correctIndices = [];

      for (const originalIndex of questionOrder) {
        const source = sourceQuestions[originalIndex];

        if (!source ||
            typeof source.question !== "string" ||
            !Array.isArray(source.options) ||
            source.options.length !== 4 ||
            !Number.isInteger(source.answer) ||
            source.answer < 0 ||
            source.answer >= source.options.length) {
          throw new HttpsError(
              "failed-precondition",
              "A quiz question has invalid data.",
          );
        }

        const optionOrder = shuffle([0, 1, 2, 3]);

        optionOrders.push(optionOrder);
        correctIndices.push(optionOrder.indexOf(source.answer));

        shuffledQuestions.push({
          questionId: `q${shuffledQuestions.length}`,
          question: source.question,
          options: optionOrder.map((index) => source.options[index]),
        });
      }

      const attemptRef = db.collection("classroomAttempts").doc();

      await attemptRef.set({
        userId: request.auth.uid,
        roomCode,
        questionOrder,
        optionOrders,
        correctIndices,
        status: "in_progress",
        startedAt: FieldValue.serverTimestamp(),
      });

      return {
        attemptId: attemptRef.id,
        title: quiz.title,
        category: quiz.category,
        quizMode: quiz.quizMode,
        questions: shuffledQuestions,
      };
    },
);

// Checks submitted answers without revealing the answer key.
exports.submitClassroomQuiz = onCall(
    {region: "asia-south1", maxInstances: 10},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Please log in first.");
      }

      const attemptId = String(request.data?.attemptId || "").trim();
      const answers = request.data?.answers;

      if (!attemptId || !Array.isArray(answers)) {
        throw new HttpsError(
            "invalid-argument",
            "Invalid quiz submission.",
        );
      }

      const attemptRef = db
          .collection("classroomAttempts")
          .doc(attemptId);

      const result = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(attemptRef);

        if (!snapshot.exists) {
          throw new HttpsError("not-found", "Quiz attempt not found.");
        }

        const attempt = snapshot.data();

        if (attempt.userId !== request.auth.uid) {
          throw new HttpsError(
              "permission-denied",
              "This quiz attempt belongs to another student.",
          );
        }

        if (attempt.status !== "in_progress") {
          throw new HttpsError(
              "failed-precondition",
              "This quiz has already been submitted.",
          );
        }

        const correctIndices = attempt.correctIndices;

        if (!Array.isArray(correctIndices) ||
            answers.length !== correctIndices.length) {
          throw new HttpsError(
              "invalid-argument",
              "Please submit all quiz answers.",
          );
        }

        let score = 0;

        for (let i = 0; i < answers.length; i++) {
          const selected = answers[i];

          if (selected !== null &&
              (!Number.isInteger(selected) ||
               selected < 0 ||
               selected > 3)) {
            throw new HttpsError(
                "invalid-argument",
                "An answer selection is invalid.",
            );
          }

          if (selected === correctIndices[i]) {
            score++;
          }
        }

        const totalQuestions = correctIndices.length;
        const percentage = Math.round(
            (score / totalQuestions) * 100,
        );

        transaction.update(attemptRef, {
          status: "completed",
          score,
          totalQuestions,
          percentage,
          submittedAt: FieldValue.serverTimestamp(),
        });

        return {
          score,
          totalQuestions,
          percentage,
        };
      });

      return result;
    },
);
