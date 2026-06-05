import 'trie.dart';

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

Dag buildDag(String sentence, Trie trie) {
  final n = sentence.length;
  final dag = Dag(n);

  for (int k = 0; k < n; k++) {
    var node = trie.root;
    bool found = false;

    for (int i = k; i < n; i++) {
      final child = node.children?[sentence.codeUnitAt(i)];
      if (child == null) break;
      node = child;
      if (node.isTerminal) {
        dag.add(k, i + 1, node.freq);
        found = true;
      }
    }

    if (!found) {
      dag.add(k, k + 1, 0);
    }
  }

  return dag;
}
