import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'trie.dart';
import 'dag.dart';
import 'route.dart';
import 'hmm.dart';

final _reHanDefault = RegExp(r'[\u4E00-\u9FD5a-zA-Z0-9+#&\._%\-]+');
final _reSkipDefault = RegExp(r'\r\n|\s');
final _reEng = RegExp(r'[a-zA-Z0-9]');
final _reHanFinalseg = RegExp(r'[\u4E00-\u9FD5]+');
final _reSkipFinalseg = RegExp(r'[a-zA-Z0-9]+(?:\.\d+)?%?');
final _reUserdict = RegExp(r'^(.+?)( [0-9]+)?( [a-z]+)?$');

class JiebaSegmenter {
  final Trie _trie = Trie();
  int _total = 0;
  final Set<String> _forceSplitWords = {};
  bool _initialized = false;
  String? _dictPath;

  static JiebaSegmenter? _instance;

  JiebaSegmenter();

  static Future<JiebaSegmenter> load({String? dictPath}) async {
    if (_instance != null) return _instance!;
    final s = JiebaSegmenter();
    await s.initialize(dictPath: dictPath);
    _instance = s;
    return s;
  }

  static JiebaSegmenter get instance {
    if (_instance == null) {
      throw StateError('JiebaSegmenter not loaded. Call load() first.');
    }
    return _instance!;
  }

  Future<void> initialize({String? dictPath}) async {
    if (_initialized && _dictPath == dictPath) return;
    _dictPath = dictPath;
    await _loadDict(dictPath ?? _defaultDictPath());
    _initialized = true;
  }

  String _defaultDictPath() {
    final scriptPath = Platform.script.toFilePath();
    final libDir = scriptPath.substring(0, scriptPath.lastIndexOf('/'));
    return '$libDir/assets/dict.txt';
  }

  Future<void> _loadDict(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Dictionary file not found: $path');
    }
    final lines = await file.readAsLines(encoding: utf8);

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(' ');
      if (parts.length < 2) continue;
      final word = parts[0];
      final freq = int.tryParse(parts[1]) ?? 0;
      _trie.insert(word, freq);
      _total += freq;
    }
  }

  Future<void> loadUserDict(String path) async {
    _checkInitialized();
    final file = File(path);
    final lines = await file.readAsLines(encoding: utf8);
    for (final ln in lines) {
      final line = ln.trim();
      if (line.isEmpty) continue;
      final match = _reUserdict.firstMatch(line);
      if (match == null) continue;
      final word = match.group(1)!;
      final freqStr = match.group(2)?.trim();
      final freq = freqStr != null ? int.tryParse(freqStr) : null;
      addWord(word, freq: freq);
    }
  }

  void addWord(String word, {int? freq}) {
    _checkInitialized();
    freq ??= _suggestFreq(word);
    _trie.insert(word, freq);
    _total += freq;
    if (freq == 0) {
      _forceSplitWords.add(word);
    }
  }

  void delWord(String word) {
    addWord(word, freq: 0);
  }

  int _suggestFreq(String segment) {
    _checkInitialized();
    final ftotal = _total.toDouble();
    double freq = 1.0;
    for (final seg in cut(segment, hmm: false)) {
      freq *= _trie.freqOf(seg).toDouble() / ftotal;
    }
    return math.max((freq * _total).toInt() + 1, _trie.freqOf(segment));
  }

  List<String> cut(String sentence, {bool cutAll = false, bool hmm = true}) {
    _checkInitialized();
    if (sentence.isEmpty) return [];

    final reHan = _reHanDefault;
    final reSkip = _reSkipDefault;

    List<String> Function(String) cutBlock;
    if (cutAll) {
      cutBlock = _cutAll;
    } else if (hmm) {
      cutBlock = _cutDag;
    } else {
      cutBlock = _cutDagNoHmm;
    }

    final result = <String>[];
    final blocks = _splitWithCapture(reHan, sentence);
    for (final blk in blocks) {
      if (blk.isEmpty) continue;
      if (reHan.hasMatch(blk)) {
        result.addAll(cutBlock(blk));
      } else {
        final tmp = _splitWithCapture(reSkip, blk);
        for (final x in tmp) {
          if (x.isEmpty) continue;
          if (reSkip.hasMatch(x)) {
            result.add(x);
          } else if (!cutAll) {
            result.addAll(x.split(''));
          } else {
            result.add(x);
          }
        }
      }
    }
    return result;
  }

  List<String> cutForSearch(String sentence, {bool hmm = true}) {
    final words = cut(sentence, hmm: hmm);
    final result = <String>[];
    for (final w in words) {
      final runes = w.runes.toList();
      if (runes.length > 2) {
        for (int i = 0; i < runes.length - 1; i++) {
          final gram2 = String.fromCharCodes(runes.sublist(i, i + 2));
          if (_trie.contains(gram2)) {
            result.add(gram2);
          }
        }
      }
      if (runes.length > 3) {
        for (int i = 0; i < runes.length - 2; i++) {
          final gram3 = String.fromCharCodes(runes.sublist(i, i + 3));
          if (_trie.contains(gram3)) {
            result.add(gram3);
          }
        }
      }
      result.add(w);
    }
    return result;
  }

  List<String> _cutDag(String sentence) {
    final dag = buildDag(sentence, _trie);
    final route = calcRoute(sentence, dag, _trie, _total);
    final runes = sentence.runes.toList();
    final n = runes.length;
    final result = <String>[];
    final buf = StringBuffer();
    int x = 0;

    while (x < n) {
      final y = route.endIndex[x];
      final lWord = String.fromCharCodes(runes.sublist(x, y));
      if (y - x == 1) {
        buf.write(lWord);
      } else {
        if (buf.isNotEmpty) {
          final bufStr = buf.toString();
          buf.clear();
          if (bufStr.runes.length == 1) {
            result.add(bufStr);
          } else {
            if (!_trie.contains(bufStr)) {
              result.addAll(_finalsegCut(bufStr));
            } else {
              for (final elem in bufStr.split('')) {
                result.add(elem);
              }
            }
          }
        }
        result.add(lWord);
      }
      x = y;
    }

    if (buf.isNotEmpty) {
      final bufStr = buf.toString();
      if (bufStr.runes.length == 1) {
        result.add(bufStr);
      } else if (!_trie.contains(bufStr)) {
        result.addAll(_finalsegCut(bufStr));
      } else {
        for (final elem in bufStr.split('')) {
          result.add(elem);
        }
      }
    }

    return result;
  }

  List<String> _cutDagNoHmm(String sentence) {
    final dag = buildDag(sentence, _trie);
    final route = calcRoute(sentence, dag, _trie, _total);
    final runes = sentence.runes.toList();
    final n = runes.length;
    final result = <String>[];
    final buf = StringBuffer();
    int x = 0;

    while (x < n) {
      final y = route.endIndex[x];
      final lWord = String.fromCharCodes(runes.sublist(x, y));
      if (_reEng.hasMatch(lWord) && lWord.runes.length == 1) {
        buf.write(lWord);
        x = y;
      } else {
        if (buf.isNotEmpty) {
          result.add(buf.toString());
          buf.clear();
        }
        result.add(lWord);
        x = y;
      }
    }

    if (buf.isNotEmpty) {
      result.add(buf.toString());
    }

    return result;
  }

  List<String> _cutAll(String sentence) {
    final dag = buildDag(sentence, _trie);
    final runes = sentence.runes.toList();
    final n = runes.length;
    final result = <String>[];
    int oldJ = -1;
    int engScan = 0;
    String engBuf = '';

    for (int k = 0; k < n; k++) {
      final L = dag.edgesAt(k);
      if (engScan == 1 && !_reEng.hasMatch(String.fromCharCode(runes[k]))) {
        engScan = 0;
        result.add(engBuf);
        engBuf = '';
      }
      if (L.length == 1 && k > oldJ) {
        final word = String.fromCharCodes(runes.sublist(k, L[0]));
        if (_reEng.hasMatch(word)) {
          if (engScan == 0) {
            engScan = 1;
            engBuf = word;
          } else {
            engBuf += word;
          }
        }
        if (engScan == 0) {
          result.add(word);
        }
        oldJ = L[0] - 1;
      } else {
        for (final j in L) {
          if (j > k + 1) {
            result.add(String.fromCharCodes(runes.sublist(k, j)));
            oldJ = j - 1;
          }
        }
      }
    }

    if (engScan == 1) {
      result.add(engBuf);
    }

    return result;
  }

  List<String> _finalsegCut(String sentence) {
    final result = <String>[];
    final blocks = _splitWithCapture(_reHanFinalseg, sentence);
    for (final blk in blocks) {
      if (blk.isEmpty) continue;
      if (_reHanFinalseg.hasMatch(blk)) {
        for (final word in hmmCut(blk)) {
          if (!_forceSplitWords.contains(word)) {
            result.add(word);
          } else {
            for (final c in word.split('')) {
              result.add(c);
            }
          }
        }
      } else {
        final tmp = _splitWithCapture(_reSkipFinalseg, blk);
        for (final x in tmp) {
          if (x.isNotEmpty) {
            result.add(x);
          }
        }
      }
    }
    return result;
  }

  List<String> _splitWithCapture(RegExp pattern, String input) {
    final result = <String>[];
    int lastEnd = 0;
    for (final match in pattern.allMatches(input)) {
      if (match.start > lastEnd) {
        result.add(input.substring(lastEnd, match.start));
      }
      result.add(match.group(0)!);
      lastEnd = match.end;
    }
    if (lastEnd < input.length) {
      result.add(input.substring(lastEnd));
    }
    return result;
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'JiebaSegmenter not initialized. Call initialize() first.',
      );
    }
  }
}
