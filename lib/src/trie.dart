/// A Map-based trie node used during dictionary loading.
class TrieNode {
  int freq = 0;
  Map<int, TrieNode>? children;

  /// Whether this node represents a complete word (freq > 0).
  bool get isTerminal => freq > 0;
}

/// Map-based trie for dictionary loading. Converted to [FlatTrie] for runtime use.
class Trie {
  final TrieNode root = TrieNode();

  bool get isEmpty => root.children == null || root.children!.isEmpty;

  /// Inserts [word] with the given [freq] into the trie.
  void insert(String word, int freq) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final cp = word.codeUnitAt(i);
      node.children ??= {};
      node = node.children!.putIfAbsent(cp, TrieNode.new);
    }
    node.freq = freq;
  }

  /// Inserts [word] as a prefix only (freq remains 0).
  void insertPrefix(String word) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final cp = word.codeUnitAt(i);
      node.children ??= {};
      node = node.children!.putIfAbsent(cp, TrieNode.new);
    }
  }

  /// Returns the frequency of [word], or 0 if not found.
  int freqOf(String word) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final next = node.children?[word.codeUnitAt(i)];
      if (next == null) return 0;
      node = next;
    }
    return node.freq;
  }

  /// Returns true if [word] exists in the trie with freq > 0.
  bool contains(String word) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final next = node.children?[word.codeUnitAt(i)];
      if (next == null) return false;
      node = next;
    }
    return node.freq > 0;
  }

  /// Returns true if [word] is a prefix of any entry in the trie.
  bool containsPrefix(String word) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final next = node.children?[word.codeUnitAt(i)];
      if (next == null) return false;
      node = next;
    }
    return true;
  }

  /// Walks the trie along [word] and returns the final node, or null.
  TrieNode? walk(String word) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final next = node.children?[word.codeUnitAt(i)];
      if (next == null) return null;
      node = next;
    }
    return node;
  }
}
