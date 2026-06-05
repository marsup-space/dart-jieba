class TrieNode {
  int freq = 0;
  Map<int, TrieNode>? children;

  bool get isTerminal => freq > 0;
}

class Trie {
  final TrieNode root = TrieNode();

  bool get isEmpty => root.children == null || root.children!.isEmpty;

  void insert(String word, int freq) {
    var node = root;
    for (final cp in word.runes) {
      node.children ??= {};
      node = node.children!.putIfAbsent(cp, TrieNode.new);
    }
    node.freq = freq;
  }

  int freqOf(String word) {
    final node = walk(word);
    return node?.freq ?? 0;
  }

  TrieNode? walk(String word) {
    var node = root;
    for (final cp in word.runes) {
      final next = node.children?[cp];
      if (next == null) return null;
      node = next;
    }
    return node;
  }
}
