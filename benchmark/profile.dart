import 'dart:convert';
import 'dart:io';

import 'package:dart_jieba/dart_jieba.dart';
import 'package:dart_jieba/src/trie.dart';
import 'package:dart_jieba/src/dag.dart';
import 'package:dart_jieba/src/route.dart';

const _dictPath = 'assets/dict.txt';

void main() async {
  final trie = Trie();
  final file = File(_dictPath);
  final bytes = file.readAsBytesSync();
  final lines = utf8.decoder.convert(bytes);
  int total = 0;
  int lineStart = 0;
  final n = lines.length;
  while (lineStart < n) {
    int lineEnd = lineStart;
    while (lineEnd < n && lines.codeUnitAt(lineEnd) != 0x0A && lines.codeUnitAt(lineEnd) != 0x0D) {
      lineEnd++;
    }
    int spaceIdx = -1;
    for (int i = lineStart; i < lineEnd; i++) {
      if (lines.codeUnitAt(i) == 0x20) {
        spaceIdx = i;
        break;
      }
    }
    if (spaceIdx > lineStart) {
      final word = lines.substring(lineStart, spaceIdx);
      int freqStart = spaceIdx + 1;
      int freqEnd = freqStart;
      while (freqEnd < lineEnd && lines.codeUnitAt(freqEnd) != 0x20) {
        freqEnd++;
      }
      int freq = 0;
      for (int i = freqStart; i < freqEnd; i++) {
        final d = lines.codeUnitAt(i) - 0x30;
        if (d < 0 || d > 9) break;
        freq = freq * 10 + d as int;
      }
      trie.insert(word, freq);
      total += freq;
    }
    lineStart = lineEnd + 1;
    if (lineStart < n && lines.codeUnitAt(lineStart - 1) == 0x0D && lines.codeUnitAt(lineStart) == 0x0A) {
      lineStart++;
    }
  }

  const sentence = '我们都是好孩子';
  const longSentence = '小明硕士毕业于中国科学院计算所，在这里学习和生活了四年。';
  const paraSentence = '我来到北京清华大学，在这里学习和生活了四年。这段时间里，我不仅学到了很多知识，还结交了许多好朋友。北京是一座美丽的城市，有着悠久的历史和丰富的文化。我非常喜欢这里的一切，包括那些古老的建筑、美味的食物和热情的人们。';

  print('=== Component breakdown (1000 iterations each) ===');
  print('');

  for (final (name, text) in [('short', sentence), ('long', longSentence), ('para', paraSentence)]) {
    final sw = Stopwatch();
    for (int i = 0; i < 1000; i++) {
      sw.start();
      buildDag(text, trie);
      sw.stop();
    }
    print('  buildDag $name: ${sw.elapsedMicroseconds / 1000} µs');
  }

  print('');
  for (final (name, text) in [('short', sentence), ('long', longSentence), ('para', paraSentence)]) {
    final dag = buildDag(text, trie);
    final sw = Stopwatch();
    for (int i = 0; i < 1000; i++) {
      sw.start();
      calcRoute(text, dag, total);
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
    print('  _splitWithCapture (paragraph): ${sw.elapsedMicroseconds / 1000} µs');
  }

  print('');
  print('=== Dict load breakdown ===');
  {
    final sw1 = Stopwatch()..start();
    final rawLines = file.readAsLinesSync();
    sw1.stop();
    print('  readAsLinesSync: ${sw1.elapsedMilliseconds} ms');

    final sw2 = Stopwatch()..start();
    final trie2 = Trie();
    int total2 = 0;
    for (final line in rawLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(' ');
      if (parts.length < 2) continue;
      trie2.insert(parts[0], int.tryParse(parts[1]) ?? 0);
      total2 += int.tryParse(parts[1]) ?? 0;
    }
    sw2.stop();
    print('  parse+insert (split): ${sw2.elapsedMilliseconds} ms');
  }

  print('');
  int nodeCount = 0;
  void countNodes(TrieNode node) {
    nodeCount++;
    if (node.children != null) {
      for (final child in node.children!.values) {
        countNodes(child);
      }
    }
  }
  countNodes(trie.root);
  print('  Trie node count: $nodeCount');
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
