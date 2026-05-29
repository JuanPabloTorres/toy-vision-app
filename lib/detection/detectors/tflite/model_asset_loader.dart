import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Thrown when a TFLite model cannot be used (asset missing, config invalid, or
/// the inference runtime is not yet wired). Detectors translate this into a
/// graceful fallback rather than a crash.
class ModelUnavailableException implements Exception {
  const ModelUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'ModelUnavailableException: $message';
}

/// Loads model bytes from an asset path. Abstracted so tests can supply a fake
/// (present/absent) without bundling a real model.
abstract class ModelAssetLoader {
  Future<Uint8List> load(String assetPath);
}

/// Default loader backed by Flutter's asset bundle.
class RootBundleModelAssetLoader implements ModelAssetLoader {
  const RootBundleModelAssetLoader();

  @override
  Future<Uint8List> load(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }
}
