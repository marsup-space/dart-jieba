import 'dart:typed_data';

import 'finalseg_data.dart';

const int _stateB = 0;
const int _stateM = 1;
const int _stateE = 2;
const int _stateS = 3;

const _prevStatus = <int, List<int>>{
  _stateB: [_stateE, _stateS],
  _stateM: [_stateM, _stateB],
  _stateS: [_stateE, _stateS],
  _stateE: [_stateB, _stateM],
};

const _terminalStates = [_stateE, _stateS];

List<String> hmmCut(String sentence) {
  if (sentence.isEmpty) return [];

  final codepoints = sentence.runes.toList();
  final length = codepoints.length;

  final V = List<Float64List>.generate(length, (_) => Float64List(4));
  final path = List<Int32List>.generate(length, (_) => Int32List(4));

  for (int t = 0; t < length; t++) {
    final cp = codepoints[t];
    if (t == 0) {
      for (int y = 0; y < 4; y++) {
        V[0][y] = probStart[y] + _emit(y, cp);
        path[0][y] = y;
      }
    } else {
      for (int y = 0; y < 4; y++) {
        final emP = _emit(y, cp);
        double bestProb = double.negativeInfinity;
        int bestPrev = 0;
        for (final y0 in _prevStatus[y]!) {
          final v = V[t - 1][y0] + probTrans[y0][y] + emP;
          if (v > bestProb) {
            bestProb = v;
            bestPrev = y0;
          }
        }
        V[t][y] = bestProb;
        path[t][y] = bestPrev;
      }
    }
  }

  double bestFinal = double.negativeInfinity;
  int bestState = _stateS;
  for (final y in _terminalStates) {
    if (V[length - 1][y] > bestFinal) {
      bestFinal = V[length - 1][y];
      bestState = y;
    }
  }

  final states = Int32List(length);
  states[length - 1] = bestState;
  for (int i = length - 2; i >= 0; i--) {
    states[i] = path[i + 1][states[i + 1]];
  }

  final result = <String>[];
  int begin = 0;
  for (int i = 0; i < length; i++) {
    switch (states[i]) {
      case _stateB:
        begin = i;
      case _stateE:
        result.add(String.fromCharCodes(codepoints.sublist(begin, i + 1)));
      case _stateS:
        result.add(String.fromCharCodes(codepoints.sublist(i, i + 1)));
      case _stateM:
        break;
    }
  }

  return result;
}

double _emit(int state, int rune) {
  return switch (state) {
    _stateB => probEmitB[rune] ?? -3.14e100,
    _stateM => probEmitM[rune] ?? -3.14e100,
    _stateE => probEmitE[rune] ?? -3.14e100,
    _stateS => probEmitS[rune] ?? -3.14e100,
    _ => -3.14e100,
  };
}
