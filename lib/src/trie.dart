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

  void insertPrefix(String word) {
    var node = root;
    for (final cp in word.runes) {
      node.children ??= {};
      node = node.children!.putIfAbsent(cp, TrieNode.new);
    }
  }

  int freqOf(String word) {
    var node = root;
    for (final cp in word.runes) {
      final next = node.children?[cp];
      if (next == null) return 0;
      node = next;
    }
    return node.freq;
  }

  int freqOfRunes(List<int> runes, int start, int end) {
    var node = root;
    for (int i = start; i < end; i++) {
      final next = node.children?[runes[i]];
      if (next == null) return 0;
      node = next;
    }
    return node.freq;
  }

  bool contains(String word) {
    final node = walk(word);
    return node != null && node.freq > 0;
  }

  bool containsPrefix(String word) {
    return walk(word) != null;
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

  TrieNode? walkRune(int cp, TrieNode from) {
    return from.children?[cp];
  }
}
