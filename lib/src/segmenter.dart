import 'dart:math' as math;

import 'trie.dart';
import 'dag.dart';
import 'route.dart';
import 'hmm.dart';

final _reHan = RegExp(
  r'([\u4E00-\u9FD5\u3400-\u4DBF\U00020000-\U0002A6DF\uF900-\uFAFF]+)',
);
final _reSkip = RegExp(r'([a-zA-Z0-9]+(?:\.\d+)?|[a-zA-Z0-9]+)');

bool _isCjkRune(int rune) {
  return (rune >= 0x4E00 && rune <= 0x9FD5) ||
      (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x20000 && rune <= 0x2A6DF) ||
      (rune >= 0x2A700 && rune <= 0x2B73F) ||
      (rune >= 0xF900 && rune <= 0xFAFF);
}

class JiebaSegmenter {
  final Trie _trie;
  double _totalFreq = 0; // updated during _loadDict
  bool _initialized = false;

  JiebaSegmenter._() : _trie = Trie();

  static JiebaSegmenter? _instance;

  static Future<JiebaSegmenter> load({String? dictPath}) async {
    if (_instance != null) return _instance!;
    final s = JiebaSegmenter._();
    await s._loadDict(dictPath ?? 'assets/dict.txt');
    s._loadHmmData();
    s._initialized = true;
    _instance = s;
    return s;
  }

  static JiebaSegmenter get instance {
    if (_instance == null) {
      throw StateError('JiebaSegmenter not loaded. Call load() first.');
    }
    return _instance!;
  }

  List<String> cut(String sentence, {bool hmm = true}) {
    if (!_initialized) {
      throw StateError('JiebaSegmenter not loaded. Call load() first.');
    }
    if (sentence.isEmpty) return [];

    final result = <String>[];
    final blocks = sentence.split(_reHan);
    for (final block in blocks) {
      if (block.isEmpty) continue;
      if (_reHan.hasMatch(block)) {
        result.addAll(_cutDag(block, hmm: hmm));
      } else {
        result.addAll(_splitNonCjk(block));
      }
    }
    return result;
  }

  List<String> _cutDag(String sentence, {required bool hmm}) {
    final dag = _buildDag(sentence);
    final route = _calcRoute(sentence, dag);
    final result = <String>[];
    final runes = sentence.runes.toList();
    int i = 0;

    while (i < runes.length) {
      final j = route.endIndex[i];
      if (j == i + 1 && _isCjkRune(runes[i]) && hmm) {
        final oovRun = _collectOovRun(runes, i, route);
        if (oovRun.isNotEmpty) {
          result.addAll(hmmCut(String.fromCharCodes(oovRun)));
          i += oovRun.length;
          continue;
        }
      }
      result.add(String.fromCharCodes(runes.sublist(i, j)));
      i = j;
    }
    return result;
  }

  Dag _buildDag(String sentence) {
    final runes = sentence.runes.toList();
    final dag = Dag(runes.length);
    for (int i = 0; i < runes.length; i++) {
      var node = _trie.root;
      dag.add(i, i + 1);
      for (int k = i + 1; k < runes.length; k++) {
        final next = node.children?[runes[k]];
        if (next == null) break;
        node = next;
        if (node.isTerminal) {
          dag.add(i, k + 1);
        }
      }
    }
    return dag;
  }

  Route _calcRoute(String sentence, Dag dag) {
    final runes = sentence.runes.toList();
    final n = runes.length;
    final route = Route(n);
    route.logProbs[n] = 0.0;
    route.endIndex[n] = n;
    for (int i = n - 1; i >= 0; i--) {
      double bestLogProb = double.negativeInfinity;
      int bestEnd = i + 1;
      for (final j in dag.edgesAt(i)) {
        final word = String.fromCharCodes(runes.sublist(i, j));
        final freq = _trie.freqOf(word).toDouble();
        double logProb;
        if (freq > 0) {
          logProb = math.log(freq / _totalFreq);
        } else {
          logProb = math.log(1.0 / (_totalFreq * math.pow(runes.length, 1.5)));
        }
        final v = logProb + route.logProbs[j];
        if (v > bestLogProb) {
          bestLogProb = v;
          bestEnd = j;
        }
      }
      route.logProbs[i] = bestLogProb;
      route.endIndex[i] = bestEnd;
    }
    return route;
  }

  List<int> _collectOovRun(List<int> runes, int start, Route route) {
    final oov = <int>[];
    int i = start;
    while (i < runes.length) {
      if (!_isCjkRune(runes[i])) break;
      if (route.endIndex[i] == i + 1) {
        oov.add(runes[i]);
        i++;
      } else {
        break;
      }
    }
    return oov;
  }

  List<String> _splitNonCjk(String block) {
    final result = <String>[];
    final parts = _reSkip.allMatches(block);
    var lastEnd = 0;
    for (final m in parts) {
      if (m.start > lastEnd) {
        result.add(block.substring(lastEnd, m.start));
      }
      result.add(m.group(0)!);
      lastEnd = m.end;
    }
    if (lastEnd < block.length) {
      result.add(block.substring(lastEnd));
    }
    return result;
  }

  Future<void> _loadDict(String path) async {
    // TODO: Load dict.txt from assets
  }

  void _loadHmmData() {
    // TODO: Load HMM probability data from finalseg
  }
}
