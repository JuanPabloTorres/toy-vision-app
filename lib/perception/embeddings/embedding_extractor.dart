import 'package:image/image.dart' as img;

import '../../domain/toy/normalized_box.dart';

/// Replaceable visual representation boundary.
///
/// Implementations may be handcrafted or backed by a TFLite model. Consumers
/// must not assume that an extractor is semantic unless corpus evaluation has
/// demonstrated it.
abstract interface class EmbeddingExtractor {
  String get identifier;
  int get dimensions;

  List<double> embed(img.Image image, NormalizedBox bounds);
}
