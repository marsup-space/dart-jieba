import 'package:dart_jieba/dart_jieba.dart';

const _dictPath = 'assets/dict.txt';

void main() async {
  final jieba = await JiebaSegmenter.load(dictPath: _dictPath);

  // Warmup
  for (int i = 0; i < 1000; i++) {
    jieba.cut('我们都是好孩子');
  }

  const iterations = 10000;
  const sentences = <(String, String)>[
    ('short-4', '我们都是'),
    ('medium-7', '我们都是好孩子'),
    ('long-14', '小明硕士毕业于中国科学院计算所'),
    ('mixed-20', 'hello 中文 world 你好世界 test 测试'),
    (
      'paragraph-100',
      '我来到北京清华大学，在这里学习和生活了四年。这段时间里，我不仅学到了很多知识，还结交了许多好朋友。北京是一座美丽的城市，有着悠久的历史和丰富的文化。我非常喜欢这里的一切，包括那些古老的建筑、美味的食物和热情的人们。',
    ),
  ];

  print('=== Precise throughput benchmark ($iterations iterations) ===');
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
  print('=== Dict load benchmark (5 runs, fresh JiebaSegmenter each) ===');
  for (int run = 0; run < 5; run++) {
    final sw = Stopwatch()..start();
    final fresh = JiebaSegmenter();
    await fresh.initialize(dictPath: _dictPath);
    sw.stop();
    print('  Run ${run + 1}: ${sw.elapsedMilliseconds} ms');
  }
}
