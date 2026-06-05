import 'dart:typed_data';

const _nStates = 4; // B, M, E, S

final Float64List probStart = Float64List.fromList(const [
  -0.26268660809250016, // B
  -3.14e100, // M
  -3.14e100, // E
  -1.4652633398537678, // S
]);

final List<Float64List> probTrans = [
  Float64List.fromList(const [
    -0.510825623765990, // B->B
    -3.14e100, // B->M (impossible)
    -0.916290731874155, // B->E
    -3.14e100, // B->S (impossible)
  ]),
  Float64List.fromList(const [
    -3.14e100, // M->B (impossible)
    -0.577292158903549, // M->M
    -0.686997760354388, // M->E
    -3.14e100, // M->S (impossible)
  ]),
  Float64List.fromList(const [
    -0.345633880679018, // E->B
    -3.14e100, // E->M (impossible)
    -3.14e100, // E->E (impossible)
    -1.014755070699919, // E->S
  ]),
  Float64List.fromList(const [
    -0.257568472249361, // S->B
    -3.14e100, // S->M (impossible)
    -3.14e100, // S->E (impossible)
    -1.260305560596424, // S->S
  ]),
];

// probEmit[state][runeCodePoint] = log P(char | state)
// Initialized as empty; populated from finalseg data at load time.
List<Map<int, double>> probEmit = List.generate(_nStates, (_) => <int, double>{});

const double _minProb = -3.14e100;

List<String> hmmCut(String sentence) {
  if (sentence.isEmpty) return [];

  final codepoints = sentence.runes.toList();
  final length = codepoints.length;
  final probs = List<Float64List>.generate(
    length,
    (_) => Float64List(_nStates),
  );
  final backtrace = List<Int32List>.generate(
    length,
    (_) => Int32List(_nStates),
  );

  for (int i = 0; i < length; i++) {
    final cp = codepoints[i];
    for (int s = 0; s < _nStates; s++) {
      final emit = probEmit[s][cp] ?? _minProb;
      if (i == 0) {
        probs[i][s] = probStart[s] + emit;
      } else {
        double best = _minProb;
        int bestPrev = 0;
        for (int prev = 0; prev < _nStates; prev++) {
          final v = probs[i - 1][prev] + probTrans[prev][s] + emit;
          if (v > best) {
            best = v;
            bestPrev = prev;
          }
        }
        probs[i][s] = best;
        backtrace[i][s] = bestPrev;
      }
    }
  }

  // Find best final state (must end in E or S, i.e. states 2 or 3)
  double bestFinal = _minProb;
  int bestState = 3; // default to S
  for (final s in [2, 3]) {
    if (probs[length - 1][s] > bestFinal) {
      bestFinal = probs[length - 1][s];
      bestState = s;
    }
  }

  // Backtrace
  final states = Int32List(length);
  states[length - 1] = bestState;
  for (int i = length - 2; i >= 0; i--) {
    states[i] = backtrace[i + 1][states[i + 1]];
  }

  // Decode states into words: B=begin, M=middle, E=end, S=single
  final result = <String>[];
  int start = 0;
  for (int i = 0; i < length; i++) {
    if (states[i] == 0) {
      // B
      start = i;
    } else if (states[i] == 2) {
      // E
      result.add(
        String.fromCharCodes(codepoints.sublist(start, i + 1)),
      );
    } else if (states[i] == 3) {
      // S
      result.add(String.fromCharCode(codepoints[i]));
    }
    // M: just continue, part of current word
  }

  return result;
}
