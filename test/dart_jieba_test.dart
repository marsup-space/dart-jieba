import 'dart:io';

import 'package:dart_jieba/dart_jieba.dart';
import 'package:test/test.dart';

String _dictPath() {
  final dir = Directory.current.path;
  for (final candidate in [
    '$dir/assets/dict.dgz',
    '$dir/assets/dict.txt',
    '$dir/dart-jieba/assets/dict.dgz',
    '$dir/dart-jieba/assets/dict.txt',
  ]) {
    if (File(candidate).existsSync()) return candidate;
  }
  throw StateError('No dict found in $dir');
}

void main() {
  late JiebaSegmenter jieba;

  setUpAll(() async {
    jieba = await JiebaSegmenter.load(dictPath: _dictPath());
  });

  group('cut (default mode, HMM=true)', () {
    test('basic Chinese segmentation', () {
      expect(jieba.cut('我们都是好孩子'), ['我们', '都', '是', '好孩子']);
    });

    test('ambiguous segmentation', () {
      expect(jieba.cut('结过婚和尚未结过婚的'), ['结过婚', '和', '尚未', '结过婚', '的']);
    });

    test('mixed CJK and Latin', () {
      expect(jieba.cut('hello 中文 world'), ['hello', ' ', '中文', ' ', 'world']);
    });

    test('standard test sentences', () {
      expect(jieba.cut('我来到北京清华大学'), ['我', '来到', '北京', '清华大学']);
    });

    test('HMM OOV words', () {
      expect(jieba.cut('他来到了网易杭研大厦'), ['他', '来到', '了', '网易', '杭研', '大厦']);
    });

    test('longer sentence', () {
      expect(jieba.cut('小明硕士毕业于中国科学院计算所'), [
        '小明',
        '硕士',
        '毕业',
        '于',
        '中国科学院',
        '计算所',
      ]);
    });

    test('short sentence', () {
      expect(jieba.cut('我爱北京天安门'), ['我', '爱', '北京', '天安门']);
    });

    test('empty string', () {
      expect(jieba.cut(''), []);
    });

    test('single ASCII char', () {
      expect(jieba.cut('a'), ['a']);
    });

    test('ASCII word', () {
      expect(jieba.cut('abc'), ['abc']);
    });

    test('digits', () {
      expect(jieba.cut('123'), ['123']);
    });

    test('whitespace', () {
      expect(jieba.cut('  '), [' ', ' ']);
    });
  });

  group('cut (no HMM)', () {
    test('basic segmentation without HMM', () {
      expect(jieba.cut('我们都是好孩子', hmm: false), ['我们', '都', '是', '好孩子']);
    });

    test('OOV without HMM falls back to per-char', () {
      expect(jieba.cut('他来到了网易杭研大厦', hmm: false), [
        '他',
        '来到',
        '了',
        '网易',
        '杭',
        '研',
        '大厦',
      ]);
    });
  });

  group('cut_all', () {
    test('full mode segmentation', () {
      expect(jieba.cut('我来到北京清华大学', cutAll: true), [
        '我',
        '来到',
        '北京',
        '清华',
        '清华大学',
        '华大',
        '大学',
      ]);
    });

    test('full mode longer sentence', () {
      expect(jieba.cut('小明硕士毕业于中国科学院计算所', cutAll: true), [
        '小',
        '明',
        '硕士',
        '毕业',
        '于',
        '中国',
        '中国科学院',
        '科学',
        '科学院',
        '学院',
        '计算',
        '计算所',
      ]);
    });
  });

  group('cutForSearch', () {
    test('search mode segmentation', () {
      expect(jieba.cutForSearch('小明硕士毕业于中国科学院计算所'), [
        '小明',
        '硕士',
        '毕业',
        '于',
        '中国',
        '科学',
        '学院',
        '科学院',
        '中国科学院',
        '计算',
        '计算所',
      ]);
    });

    test('search mode shorter sentence', () {
      expect(jieba.cutForSearch('我爱北京天安门'), ['我', '爱', '北京', '天安', '天安门']);
    });
  });

  group('Trie', () {
    test('insert and lookup', () {
      final trie = Trie();
      trie.insert('我们', 3542);
      trie.insert('我', 100);
      expect(trie.freqOf('我们'), 3542);
      expect(trie.freqOf('我'), 100);
      expect(trie.freqOf('你'), 0);
    });

    test('isEmpty on fresh trie', () {
      final trie = Trie();
      expect(trie.isEmpty, isTrue);
      trie.insert('测试', 1);
      expect(trie.isEmpty, isFalse);
    });

    test('contains and containsPrefix', () {
      final trie = Trie();
      trie.insert('我们', 3542);
      expect(trie.contains('我们'), isTrue);
      expect(trie.contains('我'), isFalse);
      expect(trie.containsPrefix('我'), isTrue);
      expect(trie.containsPrefix('你们'), isFalse);
    });
  });

  group('Dag', () {
    test('add and query edges', () {
      final dag = Dag(3);
      dag.add(0, 1, 0);
      dag.add(0, 2, 0);
      dag.add(1, 2, 0);
      expect(dag.edgesAt(0), [1, 2]);
      expect(dag.edgesAt(1), [2]);
      expect(dag.edgesAt(2), isEmpty);
    });
  });

  group('HMM', () {
    test('hmmCut on empty string', () {
      expect(hmmCut(''), isEmpty);
    });

    test('hmmCut produces reasonable segmentation for OOV', () {
      final result = hmmCut('杭研');
      expect(result, isNotEmpty);
      expect(result.join(''), equals('杭研'));
    });
  });
}
