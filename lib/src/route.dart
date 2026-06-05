import 'dart:typed_data';

class Route {
  final Float64List logProbs;
  final Int32List endIndex;

  Route(int length)
      : logProbs = Float64List(length + 1),
        endIndex = Int32List(length + 1);
}
