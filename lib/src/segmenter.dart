import 'dart:io';

import 'flat_trie.dart';
import 'dag.dart';
import 'route.dart';
import 'hmm.dart';

final _reHanDefault = RegExp(r'[\u4E00-\u9FD5a-zA-Z0-9+#&\._%\-]+');
final _reSkipDefault = RegExp(r'\r\n|\s');
final _reEng = RegExp(r'[a-zA-Z0-9]');
final _reHanFinalseg = RegExp(r'[\u4E00-\u9FD5]+');
final _reSkipFinalseg = RegExp(r'([a-zA-Z0-9]+(?:\.\d+)?%?)');

class JiebaSegmenter {
  late FlatTrie _trie;
  bool _initialized = false;
  String? _dictPath;
  final Set<String> _forceSplitWords = {};

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
    initializeSync(dictPath: dictPath);
  }

  void initializeSync({String? dictPath}) {
    if (_initialized && _dictPath == dictPath) return;
    _dictPath = dictPath ?? _findDefaultDict();

    final binPath = _dictPath!.replaceAll(RegExp(r'\.txt$'), '.dgz');
    final binFile = File(binPath);
    if (binFile.existsSync()) {
      _trie = FlatTrie.load(binPath);
    } else {
      _trie = _loadTextDict(_dictPath!);
    }
    _initialized = true;
    _instance ??= this;
  }

  static String _findDefaultDict() {
    final candidates = ['assets/dict.txt', 'dart-jieba/assets/dict.txt'];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    throw StateError('No dict.dgz or dict.txt found');
  }

  FlatTrie _loadTextDict(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Dictionary file not found: $path');
    }
    // Fallback: build trie from text (slow path)
    // For now, use the Map-based Trie and convert
    // This should rarely be hit in production
    throw StateError(
      'Text dict loading removed. Run tool/build_dict_bin.dart first to generate dict.dgz',
    );
  }

  List<String> cut(String sentence, {bool cutAll = false, bool hmm = true}) {
    _checkInitialized();
    if (sentence.isEmpty) return [];

    final result = <String>[];
    final blocks = _splitWithCapture(_reHanDefault, sentence);
    for (final blk in blocks) {
      if (blk.isEmpty) continue;
      if (_reHanDefault.hasMatch(blk)) {
        if (cutAll) {
          result.addAll(_cutAll(blk));
        } else if (hmm) {
          result.addAll(_cutDag(blk));
        } else {
          result.addAll(_cutDagNoHmm(blk));
        }
      } else {
        final tmp = _splitWithCapture(_reSkipDefault, blk);
        for (final x in tmp) {
          if (x.isEmpty) continue;
          if (_reSkipDefault.hasMatch(x)) {
            result.add(x);
          } else if (!cutAll) {
            for (int i = 0; i < x.length; i++) {
              result.add(x.substring(i, i + 1));
            }
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
      final wLen = w.length;
      if (wLen > 2) {
        for (int i = 0; i < wLen - 1; i++) {
          final gram2 = w.substring(i, i + 2);
          if (_trie.contains(gram2)) {
            result.add(gram2);
          }
        }
      }
      if (wLen > 3) {
        for (int i = 0; i < wLen - 2; i++) {
          final gram3 = w.substring(i, i + 3);
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
    final route = calcRoute(sentence, dag, _trie.total);
    final n = sentence.length;
    final endIndex = route.endIndex;
    final result = <String>[];
    final buf = StringBuffer();
    int x = 0;

    while (x < n) {
      final y = endIndex[x];
      if (y - x == 1) {
        buf.writeCharCode(sentence.codeUnitAt(x));
      } else {
        _flushBuf(result, buf);
        result.add(sentence.substring(x, y));
      }
      x = y;
    }

    _flushBuf(result, buf);
    return result;
  }

  void _flushBuf(List<String> result, StringBuffer buf) {
    if (buf.isEmpty) return;
    final bufStr = buf.toString();
    buf.clear();
    if (bufStr.length == 1) {
      result.add(bufStr);
    } else if (!_trie.contains(bufStr)) {
      result.addAll(_finalsegCut(bufStr));
    } else {
      for (int i = 0; i < bufStr.length; i++) {
        result.add(bufStr.substring(i, i + 1));
      }
    }
  }

  List<String> _cutDagNoHmm(String sentence) {
    final dag = buildDag(sentence, _trie);
    final route = calcRoute(sentence, dag, _trie.total);
    final n = sentence.length;
    final endIndex = route.endIndex;
    final result = <String>[];
    final buf = StringBuffer();
    int x = 0;

    while (x < n) {
      final y = endIndex[x];
      final lWord = sentence.substring(x, y);
      if (_reEng.hasMatch(lWord) && y - x == 1) {
        buf.write(lWord);
      } else {
        if (buf.isNotEmpty) {
          result.add(buf.toString());
          buf.clear();
        }
        result.add(lWord);
      }
      x = y;
    }

    if (buf.isNotEmpty) {
      result.add(buf.toString());
    }

    return result;
  }

  List<String> _cutAll(String sentence) {
    final dag = buildDag(sentence, _trie);
    final n = sentence.length;
    final result = <String>[];
    int oldJ = -1;

    for (int k = 0; k < n; k++) {
      final L = dag.edgesAt(k);
      if (L.length == 1 && k > oldJ) {
        result.add(sentence.substring(k, L[0]));
        oldJ = L[0] - 1;
      } else {
        for (final j in L) {
          if (j > k + 1) {
            result.add(sentence.substring(k, j));
            oldJ = j - 1;
          }
        }
      }
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
            for (int i = 0; i < word.length; i++) {
              result.add(word.substring(i, i + 1));
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
