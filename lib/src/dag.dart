import 'trie.dart';

class Dag {
  final List<List<int>> _edges;

  Dag(int length) : _edges = List.generate(length, (_) => <int>[]);

  void add(int from, int to) => _edges[from].add(to);

  List<int> edgesAt(int i) => _edges[i];

  int get length => _edges.length;
}

Dag buildDag(String sentence, Trie trie) {
  final runes = sentence.runes.toList();
  final n = runes.length;
  final dag = Dag(n);

  for (int k = 0; k < n; k++) {
    var node = trie.root;
    final tmplist = <int>[];

    for (int i = k; i < n; i++) {
      final child = node.children?[runes[i]];
      if (child == null) break;
      node = child;
      if (node.isTerminal) {
        tmplist.add(i);
      }
    }

    if (tmplist.isEmpty) {
      tmplist.add(k);
    }
    for (final end in tmplist) {
      dag.add(k, end + 1);
    }
  }

  return dag;
}
