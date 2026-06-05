import 'package:dart_jieba/dart_jieba.dart';
import 'package:dart_jieba/src/route.dart';

const _dictBinPath = 'assets/dict.dgz';

void main() async {
  final trie = FlatTrie.load(_dictBinPath);

  const sentence = '我们都是好孩子';
  const longSentence = '小明硕士毕业于中国科学院计算所，在这里学习和生活了四年。';
  const paraSentence =
      '我来到北京清华大学，在这里学习和生活了四年。这段时间里，我不仅学到了很多知识，还结交了许多好朋友。北京是一座美丽的城市，有着悠久的历史和丰富的文化。我非常喜欢这里的一切，包括那些古老的建筑、美味的食物和热情的人们。';

  print('=== Component breakdown (1000 iterations each) ===');
  print('');

  for (final (name, text) in [
    ('short', sentence),
    ('long', longSentence),
    ('para', paraSentence),
  ]) {
    final sw = Stopwatch();
    for (int i = 0; i < 1000; i++) {
      sw.start();
      buildDag(text, trie);
      sw.stop();
    }
    print('  buildDag $name: ${sw.elapsedMicroseconds / 1000} µs');
  }

  print('');
  for (final (name, text) in [
    ('short', sentence),
    ('long', longSentence),
    ('para', paraSentence),
  ]) {
    final dag = buildDag(text, trie);
    final sw = Stopwatch();
    for (int i = 0; i < 1000; i++) {
      sw.start();
      calcRoute(text, dag, trie.total);
      sw.stop();
    }
    print('  calcRoute $name: ${sw.elapsedMicroseconds / 1000} µs');
  }

  print('');
  for (final text in ['杭研', '网易杭研', '来到']) {
    final sw = Stopwatch();
    for (int i = 0; i < 1000; i++) {
      sw.start();
      hmmCut(text);
      sw.stop();
    }
    print('  hmmCut "$text": ${sw.elapsedMicroseconds / 1000} µs');
  }

  print('');
  for (final word in ['我们', '都', '是', '好孩子', '中国', '清华大学']) {
    final sw = Stopwatch();
    for (int i = 0; i < 10000; i++) {
      sw.start();
      trie.freqOf(word);
      sw.stop();
    }
    print('  trie.freqOf("$word"): ${sw.elapsedMicroseconds / 10000} µs');
  }

  print('');
  {
    final reHan = RegExp(r'[\u4E00-\u9FD5a-zA-Z0-9+#&\._%\-]+');
    final sw = Stopwatch();
    for (int i = 0; i < 1000; i++) {
      sw.start();
      _splitWithCapture(reHan, paraSentence);
      sw.stop();
    }
    print(
      '  _splitWithCapture (paragraph): ${sw.elapsedMicroseconds / 1000} µs',
    );
  }

  print('');
  print('=== Binary dict load time ===');
  for (int run = 0; run < 5; run++) {
    final sw = Stopwatch()..start();
    FlatTrie.load(_dictBinPath);
    sw.stop();
    print('  Run ${run + 1}: ${sw.elapsedMilliseconds} ms');
  }
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
