class Dag {
  final List<List<int>> _edges;

  Dag(int length) : _edges = List.generate(length, (_) => <int>[]);

  void add(int from, int to) => _edges[from].add(to);

  List<int> edgesAt(int i) => _edges[i];

  int get length => _edges.length;
}
