import 'package:dart_jieba/dart_jieba.dart';

Future<void> main() async {
  final jieba = await JiebaSegmenter.load();
  print(jieba.cut('我们都是好孩子'));
}
