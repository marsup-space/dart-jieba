# dart_jieba

[![pub.dev](https://img.shields.io/pub/v/dart_jieba.svg)](https://pub.dev/packages/dart_jieba)

Pure Dart 中文分词 —— [Python jieba](https://github.com/fxsjy/jieba) 的完整移植，使用二进制 Trie + Delta-Gzip 压缩实现快速加载。

Pure Dart Chinese text segmentation — a complete port of [Python jieba](https://github.com/fxsjy/jieba) with binary trie and delta-gzip compression for fast loading.

## 特性 / Features

- **输出完全一致** — 与 Python jieba 输出逐字节匹配（24 项黄金测试）
- **2–29× 更快** — Dart AOT 性能远超 Python jieba
- **1.9 MB 压缩词典** — Delta 编码 + Gzip，约 19ms 加载
- **零拷贝 FlatTrie** — 排序子节点 + 二分查找，无 Map 分配
- **HMM 未登录词识别** — 与 Python jieba HMM 模型一致
- **同步 / 异步初始化** — 支持 `initializeSync()` 和 `load()`
- **纯 Dart 实现** — 无 FFI，跨平台运行

## 快速开始 / Getting started

```dart
import 'package:dart_jieba/dart_jieba.dart';

void main() {
  final jieba = JiebaSegmenter();
  jieba.initializeSync();

  print(jieba.cut('我来到北京清华大学'));
  // [我, 来到, 北京, 清华大学]
}
```

## 分词模式 / Segmentation modes

```dart
// 精确模式（默认）—— 最精确的分词，适合文本分析
// Accurate mode (default) — best for text analysis
jieba.cut('我来到北京清华大学');
// [我, 来到, 北京, 清华大学]

// 全模式—— 扫描所有可能的词组，速度快但存在歧义
// Full mode — all possible word combinations, fast but ambiguous
jieba.cut('我来到北京清华大学', cutAll: true);
// [我, 来到, 北京, 清华, 清华大学, 华大, 大学]

// 搜索引擎模式—— 精确模式基础上对长词再次切分，适合搜索
// Search engine mode — further splits long words for search indexing
jieba.cutForSearch('我来到北京清华大学');
// [我, 来到, 北京, 清华, 华大, 大学, 清华大学]
```

## 词典格式 / Dictionary formats

dart_jieba 支持两种词典格式：

| 格式 / Format | 扩展名 / Extension | 加载时间 / Load time | 说明 |
|---|---|---|---|
| 二进制压缩 / Binary compressed | `.dgz` | **~19 ms** | Delta 编码 + Gzip，生产环境推荐 |
| 文本 / Text | `.txt` | ~110 ms | 运行时构建 FlatTrie，适合开发调试 |

`initializeSync()` 自动检测词典格式——如果指定路径为 `dict.txt`，会先查找同目录下的 `dict.dgz`，找到则优先加载二进制格式：

```dart
// 自动优先加载 assets/dict.dgz（如果存在），否则加载 assets/dict.txt
jieba.initializeSync(dictPath: 'assets/dict.txt');

// 也可以直接指定 .dgz
jieba.initializeSync(dictPath: 'assets/dict.dgz');
```

### 生成 .dgz 文件 / Generating .dgz from .txt

```bash
dart run tool/build_dict_bin.dart
```

此命令读取 `tool/dict.txt` 并生成 `assets/dict.dgz`。词典格式与 Python jieba 一致：

This reads `tool/dict.txt` and produces `assets/dict.dgz`. Dictionary format same as Python jieba:

```
词语 词频 词性
创新 5463 v
中国科学院 150 nt
```

词频和词性可选，但词频影响分词结果。自定义词典也支持此格式。

Freq and tag are optional, but freq affects segmentation results. Custom dictionaries use the same format.

## 自定义词典 / Custom dictionary

```dart
// 使用自定义文本词典（运行时构建 FlatTrie，加载较慢）
jieba.initializeSync(dictPath: '/path/to/custom_dict.txt');

// 推荐先用 build_dict_bin.dart 生成 .dgz，然后加载二进制格式
jieba.initializeSync(dictPath: '/path/to/custom_dict.dgz');
```

## 性能对比 / Performance

Benchmark: 10,000 iterations, same machine. Python 3.14 + jieba, Dart JIT (`dart run`), Dart AOT (`dart compile exe`).

### 分词吞吐 / Segmentation throughput

| 输入 / Input | Python jieba | dart_jieba (JIT) | dart_jieba (AOT) | AOT 加速 / Speedup |
|---|---|---|---|---|
| 4 字 / 4 chars | 48 µs | 2.2 µs | 1.7 µs | **29×** |
| 7 字 / 7 chars | 14 µs | 1.3 µs | 1.8 µs | **7.9×** |
| 14 字 / 14 chars | 17 µs | 1.8 µs | 2.6 µs | **6.6×** |
| 20 字混合 / 20 mixed | 22 µs | 4.7 µs | 6.5 µs | **3.4×** |
| 100 字段落 / 100 chars | 89 µs | 15 µs | 18 µs | **4.7×** |

> JIT 在部分负载上比 AOT 更快，因为运行时 profiling 可以内联热路径。
> JIT can outperform AOT on some workloads due to runtime profiling and inline caching.

### 分词模式 / Cut mode throughput

| 模式 / Mode | dart_jieba (JIT) | dart_jieba (AOT) |
|---|---|---|
| 精确 + HMM / Accurate + HMM | 1.42 µs/call | 1.78 µs/call |
| 精确无 HMM / Accurate no HMM | 0.89 µs/call | 1.35 µs/call |
| 全模式 / Full mode | 0.75 µs/call | 1.05 µs/call |
| 搜索引擎 / Search mode | 1.78 µs/call | 1.96 µs/call |

### 词典加载 / Dictionary load

| | Python jieba | dart_jieba |
|---|---|---|
| 冷启动 / Cold load | ~400 ms | **~19 ms** |
| 词典大小 / Dict size | 4.8 MB (txt) | **1.9 MB** (dgz) |

### 词典压缩细节 / Compression breakdown

| 数组 / Array | 原始 / Raw | Delta 编码后 / After delta | 说明 |
|---|---|---|---|
| freqs | 2.0 MB | 485 KB | BFS 序使频率单调递增 |
| firstChild | 2.0 MB | 530 KB | BFS 序使子节点索引连续 |
| childCount | 1.0 MB | 145 KB | 大部分节点子节点少 |
| edgeCps | 2.0 MB | 838 KB | 编码点值相近 |
| edgeTargets | 2.0 MB | **2 KB** | BFS 序使目标索引增量极小 |
| **合计压缩后 / Total compressed** | | **1.9 MB** | gzip(原始 + delta) |

## 技术实现 / Technical details

- **FlatTrie v3**：将 Trie 展平为 `Uint32List`/`Uint16List` 子视图，零拷贝加载，无 Map 分配
- **BFS 节点排序**：使 `freq`、`firstChild`、`edgeTarget` 单调递增，Delta 编码后压缩率极高
- **二分查找**：子节点按 `codepoint` 排序，查找 O(log n) 而非链表遍历 O(n)
- **Binary format v4**：24 字节对齐头部 + delta 编码数组 + gzip 压缩
- **DAG 动态规划**：与 Python jieba 相同的 DAG + 最短路径算法

## License

MIT
