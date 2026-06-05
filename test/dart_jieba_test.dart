import 'package:dart_jieba/dart_jieba.dart';
import 'package:test/test.dart';

void main() {
  group('JiebaSegmenter', () {
    test('empty string returns empty list', () {
      // Placeholder: will be tested after dict loading is implemented
    });

    test('cut produces correct segmentation', () async {
      // TODO: enable after dict loading
      // final jieba = await JiebaSegmenter.load();
      // expect(jieba.cut('我们都是好孩子'), ['我们', '都是', '好', '孩子']);
    });

    test('cut handles mixed CJK and Latin', () async {
      // TODO: enable after dict loading
      // final jieba = await JiebaSegmenter.load();
      // expect(jieba.cut('hello 中文 world'), ['hello', ' ', '中文', ' ', 'world']);
    });

    test('cut with HMM for OOV', () async {
      // TODO: enable after dict loading
      // final jieba = await JiebaSegmenter.load();
      // expect(jieba.cut('结过婚和尚未结过婚的'), ['结过', '婚', '和', '尚未', '结过', '婚', '的']);
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

    test('walk returns null for missing words', () {
      final trie = Trie();
      trie.insert('我们', 3542);
      expect(trie.walk('你们'), isNull);
    });
  });

  group('Dag', () {
    test('add and query edges', () {
      final dag = Dag(3);
      dag.add(0, 1);
      dag.add(0, 2);
      dag.add(1, 2);
      expect(dag.edgesAt(0), [1, 2]);
      expect(dag.edgesAt(1), [2]);
      expect(dag.edgesAt(2), isEmpty);
    });
  });

  group('HMM', () {
    test('hmmCut on empty string', () {
      expect(hmmCut(''), isEmpty);
    });
  });
}
