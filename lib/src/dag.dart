import 'flat_trie.dart';

/// Directed acyclic graph representing all possible word segmentations
/// of a sentence, built from the trie dictionary.
class Dag {
  final List<List<int>> _edges;
  final List<List<int>> _freqs;

  /// Creates a DAG with [length] positions (one per character).
  Dag(int length)
    : _edges = List.generate(length, (_) => <int>[]),
      _freqs = List.generate(length, (_) => <int>[]);

  /// Adds an edge from position [from] to [to] with frequency [freq].
  void add(int from, int to, int freq) {
    _edges[from].add(to);
    _freqs[from].add(freq);
  }

  /// Returns exclusive-end indices of edges starting at position [i].
  List<int> edgesAt(int i) => _edges[i];

  /// Returns frequencies of edges starting at position [i].
  List<int> freqsAt(int i) => _freqs[i];

  /// Number of positions in the DAG (equals sentence length).
  int get length => _edges.length;
}

/// Builds a DAG from [sentence] using the given [trie] dictionary.
///
/// For each position, finds all word matches starting there.
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
