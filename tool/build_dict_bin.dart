import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class TrieNode {
  int freq = 0;
  Map<int, TrieNode>? children;
}

class Trie {
  final TrieNode root = TrieNode();
  void insert(String word, int freq) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final cp = word.codeUnitAt(i);
      node.children ??= {};
      node = node.children!.putIfAbsent(cp, TrieNode.new);
    }
    node.freq = freq;
  }
}

void _deltaEncode32(Uint32List arr) {
  for (int i = arr.length - 1; i > 0; i--) {
    arr[i] = (arr[i] - arr[i - 1]).toUnsigned(32);
  }
}

void _deltaEncode16(Uint16List arr) {
  for (int i = arr.length - 1; i > 0; i--) {
    arr[i] = (arr[i] - arr[i - 1]) & 0xFFFF;
  }
}

void main() {
  final trie = Trie();
  final file = File('/home/wu/marsup/crux/dart-jieba/assets/dict.txt');
  final text = utf8.decoder.convert(file.readAsBytesSync());
  int total = 0;
  int lineStart = 0;
  final n = text.length;
  while (lineStart < n) {
    int lineEnd = lineStart;
    while (lineEnd < n && text.codeUnitAt(lineEnd) != 0x0A) {
      lineEnd++;
    }
    int spaceIdx = -1;
    for (int i = lineStart; i < lineEnd; i++) {
      if (text.codeUnitAt(i) == 0x20) {
        spaceIdx = i;
        break;
      }
    }
    if (spaceIdx > lineStart) {
      final word = text.substring(lineStart, spaceIdx);
      int freqStart = spaceIdx + 1;
      int freqEnd = freqStart;
      while (freqEnd < lineEnd && text.codeUnitAt(freqEnd) != 0x20) {
        freqEnd++;
      }
      int freq = 0;
      for (int i = freqStart; i < freqEnd; i++) {
        final d = text.codeUnitAt(i) - 0x30;
        if (d < 0 || d > 9) break;
        freq = freq * 10 + d;
      }
      trie.insert(word, freq);
      total += freq;
    }
    lineStart = lineEnd + 1;
  }

  final nodeIndex = <TrieNode, int>{};
  final nodeList = <TrieNode>[];
  nodeIndex[trie.root] = 0;
  nodeList.add(trie.root);
  int queueHead = 0;
  while (queueHead < nodeList.length) {
    final node = nodeList[queueHead++];
    if (node.children != null) {
      final sorted = node.children!.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sorted) {
        nodeIndex[entry.value] = nodeList.length;
        nodeList.add(entry.value);
      }
    }
  }

  final nodeCount = nodeList.length;
  int edgeCount = 0;
  for (final node in nodeList) {
    edgeCount += node.children?.length ?? 0;
  }

  final freqs = Uint32List(nodeCount);
  final firstChild = Uint32List(nodeCount);
  final childCount = Uint16List(nodeCount);
  final edgeCps = Uint16List(edgeCount);
  final edgeTargets = Uint32List(edgeCount);

  int edgeOffset = 0;
  for (int i = 0; i < nodeCount; i++) {
    final node = nodeList[i];
    freqs[i] = node.freq;
    final kids = node.children;
    if (kids != null && kids.isNotEmpty) {
      final sorted = kids.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      firstChild[i] = edgeOffset;
      childCount[i] = sorted.length;
      for (final entry in sorted) {
        edgeCps[edgeOffset] = entry.key;
        edgeTargets[edgeOffset] = nodeIndex[entry.value]!;
        edgeOffset++;
      }
    }
  }

  // Delta-encode arrays (BFS ordering makes deltas small)
  _deltaEncode32(freqs);
  _deltaEncode32(firstChild);
  _deltaEncode16(childCount);
  _deltaEncode16(edgeCps);
  _deltaEncode32(edgeTargets);

  // Assemble raw binary
  final builder = BytesBuilder();

  final headerData = ByteData(24);
  headerData.setUint32(0, 0x4A494542, Endian.little);
  headerData.setUint16(4, 4, Endian.little);
  headerData.setUint32(6, nodeCount, Endian.little);
  headerData.setUint32(10, total, Endian.little);
  headerData.setUint32(14, edgeCount, Endian.little);
  builder.add(headerData.buffer.asUint8List());

  builder.add(freqs.buffer.asUint8List());
  builder.add(firstChild.buffer.asUint8List());
  builder.add(childCount.buffer.asUint8List());
  if ((nodeCount * 2) % 4 != 0) {
    builder.add([0, 0]);
  }
  builder.add(edgeCps.buffer.asUint8List());
  if ((edgeCount * 2) % 4 != 0) {
    builder.add([0, 0]);
  }
  builder.add(edgeTargets.buffer.asUint8List());

  final rawBytes = builder.takeBytes();

  // Write compressed dict.dgz (delta-encoded + gzip)
  final compressed = gzip.encode(rawBytes);
  final outPath = '/home/wu/marsup/crux/dart-jieba/assets/dict.dgz';
  File(outPath).writeAsBytesSync(compressed);

  final txtSize = File(
    '/home/wu/marsup/crux/dart-jieba/assets/dict.txt',
  ).lengthSync();
  print('Format v4 (delta-encoded + gzip):');
  print('  Nodes: $nodeCount');
  print('  Edges: $edgeCount');
  print(
    '  Uncompressed: ${rawBytes.length} bytes = ${(rawBytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
  );
  print(
    '  Compressed:   ${compressed.length} bytes = ${(compressed.length / 1024 / 1024).toStringAsFixed(2)} MB',
  );
  print('  dict.txt:     ${(txtSize / 1024 / 1024).toStringAsFixed(2)} MB');
  print(
    '  Ratio vs dict.txt: ${(compressed.length / txtSize * 100).toStringAsFixed(1)}%',
  );
}
