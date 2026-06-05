import 'package:dart_jieba/dart_jieba.dart';

void main() {
  final jieba = JiebaSegmenter();

  // initializeSync() auto-detects dict.dgz (fast ~19ms) or dict.txt (slow ~1s)
  jieba.initializeSync();

  // Or specify a custom dictionary path:
  // jieba.initializeSync(dictPath: 'assets/dict.dgz'); // fast: binary trie
  // jieba.initializeSync(dictPath: 'assets/dict.txt'); // slow: text dict

  print(jieba.cut('我们都是好孩子'));
  print(jieba.cut('他来到了网易杭研大厦'));
  print(jieba.cut('我来到北京清华大学'));
  print(jieba.cut('小明硕士毕业于中国科学院计算所'));
  print(jieba.cutForSearch('我爱北京天安门'));
  print(jieba.cut('我来到北京清华大学', cutAll: true));
}
