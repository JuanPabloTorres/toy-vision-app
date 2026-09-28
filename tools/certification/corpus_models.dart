import 'dart:convert';
import 'dart:io';

import 'package:toyvision_realtime/domain/toy/normalized_box.dart';

const requiredScenarioTags = <String>{
  'known_toy',
  'unknown_toy',
  'stuffed_toy',
  'vehicle_toy',
  'figure_toy',
  'blocks',
  'small_object',
  'partial_occlusion',
  'multiple_toys',
  'low_light',
  'motion_blur',
  'hand_interaction',
  'camera_motion',
  'disappear_reappear',
  'hard_negative_clothing',
  'hard_negative_shoes',
  'hard_negative_remote',
  'hard_negative_bottle',
  'hard_negative_box',
  'hard_negative_furniture',
};

enum CorpusSplit { train, validation, test }

class CorpusDefinition {
  CorpusDefinition({
    required this.rootFile,
    required this.sessions,
    required this.acceptance,
  });

  final File rootFile;
  final List<CorpusSession> sessions;
  final AcceptanceCriteria acceptance;

  static CorpusDefinition load(String path) {
    final file = File(path).absolute;
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported dataset schemaVersion');
    }
    final base = file.parent;
    return CorpusDefinition(
      rootFile: file,
      sessions: (json['sessions'] as List<dynamic>? ?? const [])
          .map(
            (item) => CorpusSession.fromJson(
              item as Map<String, dynamic>,
              base,
            ),
          )
          .toList(growable: false),
      acceptance: AcceptanceCriteria.fromJson(
        json['acceptance'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  List<String> validate() {
    final errors = <String>[];
    if (sessions.isEmpty) errors.add('dataset has no sessions');
    for (final split in CorpusSplit.values) {
      if (!sessions.any((session) => session.split == split)) {
        errors.add('dataset has no ${split.name} split');
      }
    }
    final tags = sessions.expand((session) => session.tags).toSet();
    final missingTags = requiredScenarioTags.difference(tags).toList()..sort();
    if (missingTags.isNotEmpty) {
      errors.add('missing required scenario tags: ${missingTags.join(', ')}');
    }
    final ids = <String>{};
    final captureOwners = <String, CorpusSession>{};
    final annotationOwners = <String, CorpusSession>{};
    for (final session in sessions) {
      if (!ids.add(session.id)) {
        errors.add('duplicate session id: ${session.id}');
      }
      final captureKey = session.captureDirectory.absolute.path.toLowerCase();
      final captureOwner = captureOwners[captureKey];
      if (captureOwner != null) {
        errors.add(
          '${session.id}: capture is already used by ${captureOwner.id}; '
          'corpus sessions and splits must be independent',
        );
      } else {
        captureOwners[captureKey] = session;
      }
      final annotationKey = session.annotationsFile.absolute.path.toLowerCase();
      final annotationOwner = annotationOwners[annotationKey];
      if (annotationOwner != null) {
        errors.add(
          '${session.id}: annotations are already used by '
          '${annotationOwner.id}',
        );
      } else {
        annotationOwners[annotationKey] = session;
      }
      if (!session.captureDirectory.existsSync()) {
        errors.add('${session.id}: capture directory does not exist');
      } else {
        final sessionMetadata =
            File('${session.captureDirectory.path}/session.json');
        final frameEvidence =
            File('${session.captureDirectory.path}/frames.jsonl');
        if (!sessionMetadata.existsSync()) {
          errors.add('${session.id}: capture has no session.json');
        }
        if (!frameEvidence.existsSync()) {
          errors.add('${session.id}: capture has no frames.jsonl');
        }
      }
      if (!session.annotationsFile.existsSync()) {
        errors.add('${session.id}: annotations file does not exist');
      } else {
        try {
          final annotations = SessionAnnotations.load(session.annotationsFile);
          if (!annotations.isComplete) {
            errors.add('${session.id}: annotations are not COMPLETE');
          }
          if (annotations.sessionId != session.id) {
            errors.add(
              '${session.id}: annotation sessionId is '
              '${annotations.sessionId}',
            );
          }
        } on Object catch (error) {
          errors.add('${session.id}: invalid annotations: $error');
        }
      }
    }
    return errors;
  }
}

class CorpusSession {
  const CorpusSession({
    required this.id,
    required this.captureDirectory,
    required this.annotationsFile,
    required this.split,
    required this.tags,
  });

  factory CorpusSession.fromJson(Map<String, dynamic> json, Directory base) {
    final capture = _resolve(base, json['capture']! as String);
    final annotations = _resolve(base, json['annotations']! as String);
    return CorpusSession(
      id: json['id']! as String,
      captureDirectory: Directory(capture),
      annotationsFile: File(annotations),
      split: CorpusSplit.values.byName(json['split']! as String),
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>().toSet(),
    );
  }

  final String id;
  final Directory captureDirectory;
  final File annotationsFile;
  final CorpusSplit split;
  final Set<String> tags;

  static String _resolve(Directory base, String path) {
    final candidate = File(path);
    if (candidate.isAbsolute) return candidate.path;
    return File('${base.path}${Platform.pathSeparator}$path').absolute.path;
  }
}

class AcceptanceCriteria {
  const AcceptanceCriteria({
    required this.minimumPrecision,
    required this.minimumRecall,
    required this.minimumF1,
    required this.maximumIdSwitches,
    required this.maximumDuplicateCollections,
    required this.maximumFalseCollections,
    required this.minimumIdentityAuc,
    required this.minimumToyNonToyAuc,
  });

  factory AcceptanceCriteria.fromJson(Map<String, dynamic> json) =>
      AcceptanceCriteria(
        minimumPrecision:
            (json['minimumPrecision'] as num?)?.toDouble() ?? 0.90,
        minimumRecall: (json['minimumRecall'] as num?)?.toDouble() ?? 0.85,
        minimumF1: (json['minimumF1'] as num?)?.toDouble() ?? 0.87,
        maximumIdSwitches: (json['maximumIdSwitches'] as num?)?.toInt() ?? 0,
        maximumDuplicateCollections:
            (json['maximumDuplicateCollections'] as num?)?.toInt() ?? 0,
        maximumFalseCollections:
            (json['maximumFalseCollections'] as num?)?.toInt() ?? 0,
        minimumIdentityAuc:
            (json['minimumIdentityAuc'] as num?)?.toDouble() ?? 0.90,
        minimumToyNonToyAuc:
            (json['minimumToyNonToyAuc'] as num?)?.toDouble() ?? 0.85,
      );

  final double minimumPrecision;
  final double minimumRecall;
  final double minimumF1;
  final int maximumIdSwitches;
  final int maximumDuplicateCollections;
  final int maximumFalseCollections;
  final double minimumIdentityAuc;
  final double minimumToyNonToyAuc;
}

class SessionAnnotations {
  SessionAnnotations({
    required this.sessionId,
    required this.isComplete,
    required this.frames,
    required this.expectedCollections,
    required this.expectCompletion,
  });

  factory SessionAnnotations.load(File file) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw FormatException('${file.path}: unsupported annotation schema');
    }
    return SessionAnnotations(
      sessionId: json['sessionId']! as String,
      isComplete: json['annotationStatus'] == 'COMPLETE',
      frames: {
        for (final item in json['frames'] as List<dynamic>? ?? const [])
          (item as Map<String, dynamic>)['frameId']! as int:
              FrameAnnotation.fromJson(item),
      },
      expectedCollections:
          (json['expectedCollections'] as List<dynamic>? ?? const [])
              .map(
                (item) => CollectionExpectation.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
      expectCompletion: json['expectCompletion'] as bool? ?? false,
    );
  }

  final String sessionId;
  final bool isComplete;
  final Map<int, FrameAnnotation> frames;
  final List<CollectionExpectation> expectedCollections;
  final bool expectCompletion;
}

class FrameAnnotation {
  const FrameAnnotation({
    required this.frameId,
    required this.cameraMoving,
    required this.objects,
  });

  factory FrameAnnotation.fromJson(Map<String, dynamic> json) =>
      FrameAnnotation(
        frameId: json['frameId']! as int,
        cameraMoving: json['cameraMoving'] as bool? ?? false,
        objects: (json['objects'] as List<dynamic>? ?? const [])
            .map(
              (item) => AnnotatedObject.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
      );

  final int frameId;
  final bool cameraMoving;
  final List<AnnotatedObject> objects;
}

enum AnnotatedObjectKind { toy, nonToy }

class AnnotatedObject {
  const AnnotatedObject({
    required this.objectId,
    required this.kind,
    required this.visible,
    required this.occluded,
    required this.bounds,
  });

  factory AnnotatedObject.fromJson(Map<String, dynamic> json) {
    final bounds = json['bounds'] as Map<String, dynamic>?;
    return AnnotatedObject(
      objectId: json['objectId']! as String,
      kind: AnnotatedObjectKind.values.byName(json['kind']! as String),
      visible: json['visible'] as bool? ?? true,
      occluded: json['occluded'] as bool? ?? false,
      bounds: bounds == null
          ? null
          : NormalizedBox(
              x: (bounds['x']! as num).toDouble(),
              y: (bounds['y']! as num).toDouble(),
              width: (bounds['width']! as num).toDouble(),
              height: (bounds['height']! as num).toDouble(),
            ),
    );
  }

  final String objectId;
  final AnnotatedObjectKind kind;
  final bool visible;
  final bool occluded;
  final NormalizedBox? bounds;
}

class CollectionExpectation {
  const CollectionExpectation({
    required this.objectId,
    required this.minimumFrameId,
    required this.maximumFrameId,
  });

  factory CollectionExpectation.fromJson(Map<String, dynamic> json) =>
      CollectionExpectation(
        objectId: json['objectId']! as String,
        minimumFrameId: json['minimumFrameId']! as int,
        maximumFrameId: json['maximumFrameId']! as int,
      );

  final String objectId;
  final int minimumFrameId;
  final int maximumFrameId;

  bool includes(int frameId) =>
      frameId >= minimumFrameId && frameId <= maximumFrameId;
}
