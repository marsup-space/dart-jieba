import 'dart:math' as math;
import 'dart:typed_data';

import 'trie.dart';
import 'dag.dart';

typedef Route = ({Float64List logProbs, Int32List endIndex});

Route calcRoute(String sentence, Dag dag, Trie trie, int total) {
  final runes = sentence.runes.toList();
  final n = runes.length;
  final logProbs = Float64List(n + 1);
  final endIndex = Int32List(n + 1);
  final logTotal = math.log(total.toDouble());

  logProbs[n] = 0.0;
  endIndex[n] = n;

  for (int idx = n - 1; idx >= 0; idx--) {
    double bestLogProb = double.negativeInfinity;
    int bestX = dag.edgesAt(idx).first;

    for (final x in dag.edgesAt(idx)) {
      final freq = trie.freqOfRunes(runes, idx, x);
      final logFreq = freq > 0 ? math.log(freq) : 0.0;
      final v = logFreq - logTotal + logProbs[x];
      if (v > bestLogProb) {
        bestLogProb = v;
        bestX = x;
      }
    }

    logProbs[idx] = bestLogProb;
    endIndex[idx] = bestX;
  }

  return (logProbs: logProbs, endIndex: endIndex);
}
