import 'dart:math' as math;
import 'dart:typed_data';

import 'dag.dart';

typedef Route = ({Float64List logProbs, Int32List endIndex});

Route calcRoute(String sentence, Dag dag, int total) {
  final n = sentence.length;
  final logProbs = Float64List(n + 1);
  final endIndex = Int32List(n + 1);
  final logTotal = math.log(total.toDouble());

  logProbs[n] = 0.0;
  endIndex[n] = n;

  for (int idx = n - 1; idx >= 0; idx--) {
    final edges = dag.edgesAt(idx);
    final freqs = dag.freqsAt(idx);
    double bestLogProb = double.negativeInfinity;
    int bestX = edges[0];

    for (int i = 0; i < edges.length; i++) {
      final x = edges[i];
      final freq = freqs[i];
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
