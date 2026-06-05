/// Pure Dart Chinese text segmentation — a port of Python jieba.
///
/// Supports accurate mode, full mode, and search engine mode segmentation
/// with binary trie (`.dgz`) and text dictionary (`.txt`) loading.
library dart_jieba;

export 'src/segmenter.dart';
export 'src/trie.dart';
export 'src/flat_trie.dart';
export 'src/dag.dart';
export 'src/hmm.dart';
