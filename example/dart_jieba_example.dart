import 'package:dart_jieba/dart_jieba.dart';

void main() async {
  final jieba = await JiebaSegmenter.load(dictPath: 'assets/dict.txt');

  print(jieba.cut('我们都是好孩子'));
  print(jieba.cut('他来到了网易杭研大厦'));
  print(jieba.cut('我来到北京清华大学'));
  print(jieba.cut('小明硕士毕业于中国科学院计算所'));
  print(jieba.cutForSearch('我爱北京天安门'));
  print(jieba.cut('我来到北京清华大学', cutAll: true));
}
