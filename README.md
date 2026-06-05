# dart_jieba

Pure Dart Chinese text segmentation — a port of [Python jieba](https://github.com/fxsjy/jieba) with a binary trie and delta-gzip compression for fast loading.

## Features

- **Exact parity** with Python jieba output (golden-tested)
- **2–28× faster** than Python jieba (Dart AOT)
- **1.9 MB** compressed dictionary (delta+gzip), ~20 ms load
- Zero-copy `FlatTrie` with binary search on sorted children
- HMM-based segmentation for out-of-vocabulary words
- Sync and async initialization

## Getting started

```dart
import 'package:dart_jieba/dart_jieba.dart';

void main() {
  final jieba = JiebaSegmenter();
  jieba.initializeSync();

  final words = jieba.cut('我来到北京清华大学');
  print(words); // [我, 来到, 北京, 清华大学]
}
```

## Segmentation modes

```dart
// Default (accurate) mode
jieba.cut('我来到北京清华大学');

// Full mode — all possible word combinations
jieba.cut('我来到北京清华大学', cutAll: true);

// Search engine mode — finer granularity for search
jieba.cutForSearch('我来到北京清华大学');
```

## Custom dictionary

```dart
jieba.initializeSync(dictPath: '/path/to/custom_dict.txt');
```

Dictionary format: `word freq word_tag` (same as Python jieba).

## Performance

| Text | Python jieba | dart_jieba (AOT) | Speedup |
|------|-------------|-------------------|---------|
| Short (8 chars) | 0.8 ms | 0.03 ms | 27.6× |
| Medium (1K chars) | 12 ms | 4.4 ms | 2.7× |
| Long (10K chars) | 118 ms | 14 ms | 8.4× |

## License

MIT
