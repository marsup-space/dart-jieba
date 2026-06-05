import 'flat_trie.dart';

class Dag {
  final List<List<int>> _edges;
  final List<List<int>> _freqs;

  Dag(int length)
    : _edges = List.generate(length, (_) => <int>[]),
      _freqs = List.generate(length, (_) => <int>[]);

  void add(int from, int to, int freq) {
    _edges[from].add(to);
    _freqs[from].add(freq);
  }

  List<int> edgesAt(int i) => _edges[i];
  List<int> freqsAt(int i) => _freqs[i];

  int get length => _edges.length;
}

Dag buildDag(String sentence, FlatTrie trie) {
  final n = sentence.length;
  final dag = Dag(n);

  for (int k = 0; k < n; k++) {
    bool found = false;
    var nodeIdx = trie.rootIdx;

    for (int i = k; i < n; i++) {
      final childIdx = trie.findChild(nodeIdx, sentence.codeUnitAt(i));
      if (childIdx < 0) break;
      nodeIdx = childIdx;
      final freq = trie.freqOfIdx(nodeIdx);
      if (freq > 0) {
        dag.add(k, i + 1, freq);
        found = true;
      }
    }

    if (!found) {
      dag.add(k, k + 1, 0);
    }
  }

  return dag;
}
