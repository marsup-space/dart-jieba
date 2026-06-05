import 'dart:io';

import 'package:dart_jieba/dart_jieba.dart';

const _dictPath = 'assets/dict.txt';

const _sentences = <(String name, String text)>[
  ('short-4', '我们都是'),
  ('medium-7', '我们都是好孩子'),
  ('long-14', '小明硕士毕业于中国科学院计算所'),
  ('mixed-20', 'hello 中文 world 你好世界 test 测试'),
  (
    'paragraph-100',
    '我来到北京清华大学，在这里学习和生活了四年。这段时间里，我不仅学到了很多知识，还结交了许多好朋友。北京是一座美丽的城市，有着悠久的历史和丰富的文化。我非常喜欢这里的一切，包括那些古老的建筑、美味的食物和热情的人们。',
  ),
];

void main() async {
  final jieba = await JiebaSegmenter.load(dictPath: _dictPath);

  print('=== Cold start (first call) ===');
  for (final (name, text) in _sentences) {
    final sw = Stopwatch()..start();
    final result = jieba.cut(text);
    sw.stop();
    print(
      '  $name (${text.length} chars): ${sw.elapsedMicroseconds} µs → $result',
    );
  }

  print('');
  print('=== Warm benchmark (10 iterations) ===');
  for (final (name, text) in _sentences) {
    final sw = Stopwatch();
    for (int i = 0; i < 10; i++) {
      sw.start();
      jieba.cut(text);
      sw.stop();
    }
    final avg = sw.elapsedMicroseconds / 10;
    print('  $name: avg ${avg.toStringAsFixed(1)} µs');
  }

  print('');
  print('=== Throughput benchmark (1000 iterations) ===');
  for (final (name, text) in _sentences) {
    final sw = Stopwatch();
    for (int i = 0; i < 1000; i++) {
      sw.start();
      jieba.cut(text);
      sw.stop();
    }
    final avg = sw.elapsedMicroseconds / 1000;
    print(
      '  $name: avg ${avg.toStringAsFixed(1)} µs/call, ${(1000000 / avg).toStringAsFixed(0)} calls/sec',
    );
  }

  print('');
  print('=== Cut modes comparison (medium-7, 1000 iterations) ===');
  const mediumText = '我们都是好孩子';
  for (final mode in [
    ('default+hmm', true, false),
    ('default+no-hmm', false, false),
    ('cut_all', true, true),
    ('search', false, false),
  ]) {
    final (name, hmm, cutAll) = mode;
    final sw = Stopwatch();
    for (int i = 0; i < 1000; i++) {
      sw.start();
      if (name == 'search') {
        jieba.cutForSearch(mediumText);
      } else {
        jieba.cut(mediumText, hmm: hmm, cutAll: cutAll);
      }
      sw.stop();
    }
    final avg = sw.elapsedMicroseconds / 1000;
    print('  $name: avg ${avg.toStringAsFixed(1)} µs/call');
  }

  print('');
  print('=== Dict load time ===');
  final sw = Stopwatch()..start();
  final fresh = JiebaSegmenter();
  await fresh.initialize(dictPath: _dictPath);
  sw.stop();
  print('  Cold load: ${sw.elapsedMilliseconds} ms');

  print('');
  print('=== Memory estimate ===');
  print('  Dict entries: 349046');
  print('  Trie nodes: estimated ~500k+ (each with Map<int, TrieNode>)');
}
