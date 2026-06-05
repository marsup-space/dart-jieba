import 'dart:io';
import 'package:dart_jieba/dart_jieba.dart';

const _dictPath = 'assets/dict.txt';

void main() async {
  final jieba = await JiebaSegmenter.load(dictPath: _dictPath);

  for (int i = 0; i < 1000; i++) {
    jieba.cut('我们都是好孩子');
  }

  const iterations = 10000;

  print('=== Dart jieba throughput benchmark ($iterations iterations) ===');
  final sentences = <(String, String)>[
    ('short-4', '我们都是'),
    ('medium-7', '我们都是好孩子'),
    ('long-14', '小明硕士毕业于中国科学院计算所'),
    ('mixed-20', 'hello 中文 world 你好世界 test 测试'),
    ('paragraph-100', '我来到北京清华大学，在这里学习和生活了四年。这段时间里，我不仅学到了很多知识，还结交了许多好朋友。北京是一座美丽的城市，有着悠久的历史和丰富的文化。我非常喜欢这里的一切，包括那些古老的建筑、美味的食物和热情的人们。'),
  ];

  for (final (name, text) in sentences) {
    final sw = Stopwatch();
    for (int i = 0; i < iterations; i++) {
      sw.start();
      jieba.cut(text);
      sw.stop();
    }
    final avg = sw.elapsedMicroseconds / iterations;
    print('  $name: ${avg.toStringAsFixed(2)} µs/call');
  }

  print('');
  print('=== Cut modes comparison (medium-7, $iterations iterations) ===');
  const text = '我们都是好孩子';

  final sw1 = Stopwatch();
  for (int i = 0; i < iterations; i++) { sw1.start(); jieba.cut(text, hmm: true); sw1.stop(); }
  print('  default+hmm: ${sw1.elapsedMicroseconds / iterations} µs/call');

  final sw2 = Stopwatch();
  for (int i = 0; i < iterations; i++) { sw2.start(); jieba.cut(text, hmm: false); sw2.stop(); }
  print('  default+no-hmm: ${sw2.elapsedMicroseconds / iterations} µs/call');

  final sw3 = Stopwatch();
  for (int i = 0; i < iterations; i++) { sw3.start(); jieba.cut(text, cutAll: true); sw3.stop(); }
  print('  cut_all: ${sw3.elapsedMicroseconds / iterations} µs/call');

  final sw4 = Stopwatch();
  for (int i = 0; i < iterations; i++) { sw4.start(); jieba.cutForSearch(text); sw4.stop(); }
  print('  search: ${sw4.elapsedMicroseconds / iterations} µs/call');

  print('');
  print('=== Dict load time ===');
  final sw5 = Stopwatch()..start();
  final fresh = JiebaSegmenter();
  await fresh.initialize(dictPath: _dictPath);
  sw5.stop();
  print('  Cold load: ${sw5.elapsedMilliseconds} ms');
}
