import 'dart:math';

/// 🧠 Naive Bayes Classifier for Fast Intent Detection
class NaiveBayesClassifier {
  // Vocabulary: Word -> Count per Class
  final Map<String, Map<String, int>> _wordCounts = {};

  // Class Counts: Class -> Total Documents
  final Map<String, int> _classCounts = {};

  // Total Documents
  int _totalDocuments = 0;

  // Vocabulary Size (Unique words)
  final Set<String> _vocabulary = {};

  /// 🎓 Train the classifier with data
  void train(Map<String, String> data) {
    data.forEach((text, label) {
      _trainSingle(text, label);
    });
  }

  void _trainSingle(String text, String label) {
    final cleanText = text.toLowerCase();

    _classCounts[label] = (_classCounts[label] ?? 0) + 1;
    _totalDocuments++;

    final tokens = _tokenize(cleanText);
    for (var token in tokens) {
      _vocabulary.add(token);
      if (!_wordCounts.containsKey(label)) {
        _wordCounts[label] = {};
      }
      _wordCounts[label]![token] = (_wordCounts[label]![token] ?? 0) + 1;
    }
  }

  /// 🔮 Predict the intent of a given text
  Map<String, double> predict(String text) {
    final tokens = _tokenize(text);
    final scores = <String, double>{};

    for (var label in _classCounts.keys) {
      // Prior Probability: P(Class)
      double logProb = log(_classCounts[label]! / _totalDocuments);

      // Likelihood: P(Word | Class)
      for (var token in tokens) {
        if (_vocabulary.contains(token)) {
          final wordCount = _wordCounts[label]![token] ?? 0;
          // Laplace Smoothing (+1)
          final totalWordsInClass =
              _wordCounts[label]!.values.fold(0, (a, b) => a + b);
          final probWordGivenClass =
              (wordCount + 1) / (totalWordsInClass + _vocabulary.length);
          logProb += log(probWordGivenClass);
        }
      }
      scores[label] = logProb;
    }

    // Normalize logic (Optional, but useful for relative confidence)
    // For now, we return raw log probabilities or convert to simple confidence?
    // Let's Normalize to 0-1 range using Softmax approximation if needed,
    // but for simple max retrieval, raw logs are fine.

    // Convert Log to simple Probability (un-normalized)
    final maxScore = scores.values.reduce(max);
    final expScores = scores.map((k, v) => MapEntry(k, exp(v - maxScore)));
    final sumExp = expScores.values.reduce((a, b) => a + b);

    return expScores.map((k, v) => MapEntry(k, v / sumExp));
  }

  /// ✂️ Simple Tokenizer
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(
            RegExp(r'[^\w\s\u0600-\u06FF]'), '') // Keep Arabic & English chars
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2) // Filter tiny words
        .toList();
  }
}
