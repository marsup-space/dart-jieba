import 'dart:io';
import 'dart:typed_data';

class FlatTrie {
  final Uint32List _freqs;
  final Uint32List _firstChild;
  final Uint16List _childCount;
  final Uint16List _edgeCps;
  final Uint32List _edgeTargets;
  final int _rootIdx;
  final int _total;

  int get total => _total;
  bool get isEmpty => _freqs.isEmpty;

  FlatTrie._(
    this._freqs,
    this._firstChild,
    this._childCount,
    this._edgeCps,
    this._edgeTargets,
    this._rootIdx,
    this._total,
  );

  static FlatTrie load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw StateError('Binary dict file not found: $path');
    }
    final bytes = file.readAsBytesSync();
    return fromBytes(bytes);
  }

  static FlatTrie fromBytes(Uint8List bytes) {
    // Detect gzip-compressed dict (magic 0x1f8b)
    if (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
      bytes = Uint8List.fromList(gzip.decode(bytes));
    }

    final data = bytes.buffer.asByteData(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );

    final magic = data.getUint32(0, Endian.little);
    if (magic != 0x4A494542) {
      throw FormatException(
        'Invalid dict.dgz magic: 0x${magic.toRadixString(16)}',
      );
    }
    final version = data.getUint16(4, Endian.little);
    if (version == 4) {
      return _fromDeltaEncoded(bytes);
    }
    if (version != 3) {
      throw FormatException('Unsupported dict.dgz version: $version');
    }
    return _fromUncompressed(bytes);
  }

  static FlatTrie _fromDeltaEncoded(Uint8List bytes) {
    final data = bytes.buffer.asByteData(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );

    final nodeCount = data.getUint32(6, Endian.little);
    final totalFreq = data.getUint32(10, Endian.little);
    final edgeCount = data.getUint32(14, Endian.little);

    int offset = 24;
    final freqs = Uint32List.sublistView(bytes, offset, offset + nodeCount * 4);
    offset += nodeCount * 4;

    final firstChild = Uint32List.sublistView(
      bytes,
      offset,
      offset + nodeCount * 4,
    );
    offset += nodeCount * 4;

    final childCount = Uint16List.sublistView(
      bytes,
      offset,
      offset + nodeCount * 2,
    );
    offset += nodeCount * 2;
    if (offset % 4 != 0) offset += 2;

    final edgeCps = Uint16List.sublistView(
      bytes,
      offset,
      offset + edgeCount * 2,
    );
    offset += edgeCount * 2;
    if (offset % 4 != 0) offset += 2;

    final edgeTargets = Uint32List.sublistView(
      bytes,
      offset,
      offset + edgeCount * 4,
    );

    _undoDelta32(freqs);
    _undoDelta32(firstChild);
    _undoDelta16(childCount);
    _undoDelta16(edgeCps);
    _undoDelta32(edgeTargets);

    return FlatTrie._(
      freqs,
      firstChild,
      childCount,
      edgeCps,
      edgeTargets,
      0,
      totalFreq,
    );
  }

  static FlatTrie _fromUncompressed(Uint8List bytes) {
    final data = bytes.buffer.asByteData(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );

    final nodeCount = data.getUint32(6, Endian.little);
    final totalFreq = data.getUint32(10, Endian.little);
    final edgeCount = data.getUint32(14, Endian.little);

    int offset = 24;
    final freqs = Uint32List.sublistView(bytes, offset, offset + nodeCount * 4);
    offset += nodeCount * 4;

    final firstChild = Uint32List.sublistView(
      bytes,
      offset,
      offset + nodeCount * 4,
    );
    offset += nodeCount * 4;

    final childCount = Uint16List.sublistView(
      bytes,
      offset,
      offset + nodeCount * 2,
    );
    offset += nodeCount * 2;
    if (offset % 4 != 0) offset += 2;

    final edgeCps = Uint16List.sublistView(
      bytes,
      offset,
      offset + edgeCount * 2,
    );
    offset += edgeCount * 2;
    if (offset % 4 != 0) offset += 2;

    final edgeTargets = Uint32List.sublistView(
      bytes,
      offset,
      offset + edgeCount * 4,
    );

    return FlatTrie._(
      freqs,
      firstChild,
      childCount,
      edgeCps,
      edgeTargets,
      0,
      totalFreq,
    );
  }

  static void _undoDelta32(Uint32List arr) {
    for (int i = 1; i < arr.length; i++) {
      arr[i] = (arr[i] + arr[i - 1]).toUnsigned(32);
    }
  }

  static void _undoDelta16(Uint16List arr) {
    for (int i = 1; i < arr.length; i++) {
      arr[i] = (arr[i] + arr[i - 1]) & 0xFFFF;
    }
  }

  int freqOf(String word) {
    var nodeIdx = _rootIdx;
    for (int i = 0; i < word.length; i++) {
      nodeIdx = _findChild(nodeIdx, word.codeUnitAt(i));
      if (nodeIdx < 0) return 0;
    }
    return _freqs[nodeIdx];
  }

  bool contains(String word) {
    var nodeIdx = _rootIdx;
    for (int i = 0; i < word.length; i++) {
      nodeIdx = _findChild(nodeIdx, word.codeUnitAt(i));
      if (nodeIdx < 0) return false;
    }
    return _freqs[nodeIdx] > 0;
  }

  bool containsPrefix(String word) {
    var nodeIdx = _rootIdx;
    for (int i = 0; i < word.length; i++) {
      nodeIdx = _findChild(nodeIdx, word.codeUnitAt(i));
      if (nodeIdx < 0) return false;
    }
    return true;
  }

  int _findChild(int parentIdx, int cp) {
    final start = _firstChild[parentIdx];
    final count = _childCount[parentIdx];
    if (count == 0) return -1;
    int lo = 0;
    int hi = count - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >>> 1;
      final midCp = _edgeCps[start + mid];
      if (midCp < cp) {
        lo = mid + 1;
      } else if (midCp > cp) {
        hi = mid - 1;
      } else {
        return _edgeTargets[start + mid];
      }
    }
    return -1;
  }

  int get rootIdx => _rootIdx;
  int freqOfIdx(int nodeIdx) => _freqs[nodeIdx];
  int findChild(int parentIdx, int cp) => _findChild(parentIdx, cp);
}
