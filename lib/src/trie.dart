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
    for (int i = 0; i < word.length; i++) {
      final cp = word.codeUnitAt(i);
      node.children ??= {};
      node = node.children!.putIfAbsent(cp, TrieNode.new);
    }
    node.freq = freq;
  }

  void insertPrefix(String word) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final cp = word.codeUnitAt(i);
      node.children ??= {};
      node = node.children!.putIfAbsent(cp, TrieNode.new);
    }
  }

  int freqOf(String word) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final next = node.children?[word.codeUnitAt(i)];
      if (next == null) return 0;
      node = next;
    }
    return node.freq;
  }

  bool contains(String word) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final next = node.children?[word.codeUnitAt(i)];
      if (next == null) return false;
      node = next;
    }
    return node.freq > 0;
  }

  bool containsPrefix(String word) {
    var node = root;
    for (int i = 0; i < word.length; i++) {
      final next = node.children?[word.codeUnitAt(i)];
      if (next == null) return false;
      node = next;
    }
    return true;
  }

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
