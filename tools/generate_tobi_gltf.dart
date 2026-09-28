// ignore_for_file: require_trailing_commas

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

void main() {
  final buffer = BytesBuilder(copy: false);
  final views = <Map<String, Object>>[];
  final accessors = <Map<String, Object>>[];

  int addFloatAccessor(
    List<double> values,
    String type, {
    List<double>? min,
    List<double>? max,
  }) {
    while (buffer.length % 4 != 0) {
      buffer.addByte(0);
    }
    final offset = buffer.length;
    final bytes = ByteData(values.length * 4);
    for (var index = 0; index < values.length; index++) {
      bytes.setFloat32(index * 4, values[index], Endian.little);
    }
    buffer.add(bytes.buffer.asUint8List());
    final viewIndex = views.length;
    views.add(
        {'buffer': 0, 'byteOffset': offset, 'byteLength': bytes.lengthInBytes});
    final components =
        switch (type) { 'SCALAR' => 1, 'VEC3' => 3, 'VEC4' => 4, _ => 1 };
    final accessor = <String, Object>{
      'bufferView': viewIndex,
      'componentType': 5126,
      'count': values.length ~/ components,
      'type': type,
    };
    if (min != null) accessor['min'] = min;
    if (max != null) accessor['max'] = max;
    accessors.add(accessor);
    return accessors.length - 1;
  }

  int addIndexAccessor(List<int> values) {
    while (buffer.length % 4 != 0) {
      buffer.addByte(0);
    }
    final offset = buffer.length;
    final bytes = ByteData(values.length * 2);
    for (var index = 0; index < values.length; index++) {
      bytes.setUint16(index * 2, values[index], Endian.little);
    }
    buffer.add(bytes.buffer.asUint8List());
    final viewIndex = views.length;
    views.add({
      'buffer': 0,
      'byteOffset': offset,
      'byteLength': bytes.lengthInBytes,
      'target': 34963,
    });
    accessors.add({
      'bufferView': viewIndex,
      'componentType': 5123,
      'count': values.length,
      'type': 'SCALAR',
      'min': [0],
      'max': [7],
    });
    return accessors.length - 1;
  }

  const positions = <double>[
    -0.5,
    -0.5,
    -0.5,
    0.5,
    -0.5,
    -0.5,
    0.5,
    0.5,
    -0.5,
    -0.5,
    0.5,
    -0.5,
    -0.5,
    -0.5,
    0.5,
    0.5,
    -0.5,
    0.5,
    0.5,
    0.5,
    0.5,
    -0.5,
    0.5,
    0.5,
  ];
  const indices = <int>[
    0,
    1,
    2,
    0,
    2,
    3,
    4,
    6,
    5,
    4,
    7,
    6,
    0,
    4,
    5,
    0,
    5,
    1,
    3,
    2,
    6,
    3,
    6,
    7,
    1,
    5,
    6,
    1,
    6,
    2,
    0,
    3,
    7,
    0,
    7,
    4,
  ];
  final positionAccessor = addFloatAccessor(
    positions,
    'VEC3',
    min: const [-0.5, -0.5, -0.5],
    max: const [0.5, 0.5, 0.5],
  );
  final indexAccessor = addIndexAccessor(indices);

  final materials = [
    [0.08, 0.60, 0.95, 1.0],
    [0.92, 0.96, 1.0, 1.0],
    [1.0, 0.72, 0.10, 1.0],
    [0.08, 0.13, 0.25, 1.0],
  ]
      .map((color) => {
            'pbrMetallicRoughness': {
              'baseColorFactor': color,
              'metallicFactor': 0.05,
              'roughnessFactor': 0.48,
            },
            'extensions': {'KHR_materials_unlit': <String, Object>{}},
          })
      .toList();
  final meshes = List.generate(
      materials.length,
      (material) => {
            'primitives': [
              {
                'attributes': {'POSITION': positionAccessor},
                'indices': indexAccessor,
                'material': material,
              }
            ]
          });

  final nodes = <Map<String, Object>>[
    {
      'name': 'Tobi',
      'children': [1, 2, 3, 4, 5, 6, 7, 8]
    },
    {
      'name': 'Body',
      'mesh': 0,
      'translation': [0, 0.1, 0],
      'scale': [0.85, 1.0, 0.5]
    },
    {
      'name': 'Head',
      'mesh': 1,
      'translation': [0, 1.15, 0],
      'scale': [0.72, 0.58, 0.55]
    },
    {
      'name': 'LeftArm',
      'mesh': 0,
      'translation': [-0.62, 0.2, 0],
      'scale': [0.22, 0.78, 0.22]
    },
    {
      'name': 'RightArm',
      'mesh': 0,
      'translation': [0.62, 0.2, 0],
      'scale': [0.22, 0.78, 0.22]
    },
    {
      'name': 'LeftLeg',
      'mesh': 3,
      'translation': [-0.28, -0.95, 0],
      'scale': [0.28, 0.55, 0.34]
    },
    {
      'name': 'RightLeg',
      'mesh': 3,
      'translation': [0.28, -0.95, 0],
      'scale': [0.28, 0.55, 0.34]
    },
    {
      'name': 'LeftEye',
      'mesh': 3,
      'translation': [-0.22, 1.23, 0.29],
      'scale': [0.11, 0.13, 0.06]
    },
    {
      'name': 'RightEye',
      'mesh': 3,
      'translation': [0.22, 1.23, 0.29],
      'scale': [0.11, 0.13, 0.06]
    },
  ];

  final animations = <Map<String, Object>>[];
  List<double> quaternionY(double degrees) {
    final radians = degrees * math.pi / 180;
    return [0, math.sin(radians / 2), 0, math.cos(radians / 2)];
  }

  List<double> quaternionZ(double degrees) {
    final radians = degrees * math.pi / 180;
    return [0, 0, math.sin(radians / 2), math.cos(radians / 2)];
  }

  void rotationAnimation(String name, int node, List<double> degrees,
      {bool yAxis = false}) {
    final times = addFloatAccessor([0, 0.5, 1], 'SCALAR', min: [0], max: [1]);
    final values = addFloatAccessor(
      degrees
          .expand((value) => yAxis ? quaternionY(value) : quaternionZ(value))
          .toList(),
      'VEC4',
    );
    animations.add({
      'name': name,
      'samplers': [
        {'input': times, 'output': values, 'interpolation': 'LINEAR'}
      ],
      'channels': [
        {
          'sampler': 0,
          'target': {'node': node, 'path': 'rotation'}
        }
      ],
    });
  }

  rotationAnimation('idle', 2, [-3, 3, -3]);
  rotationAnimation('scan', 2, [-25, 25, -25], yAxis: true);
  rotationAnimation('happy', 0, [-5, 5, -5]);
  rotationAnimation('celebrate', 0, [0, 180, 360], yAxis: true);
  rotationAnimation('confused', 2, [-14, 14, -14]);

  final clapTimes = addFloatAccessor([0, 0.5, 1], 'SCALAR', min: [0], max: [1]);
  final leftClap = addFloatAccessor(
    <double>[-12, 0, 12].expand(quaternionZ).toList(),
    'VEC4',
  );
  final rightClap = addFloatAccessor(
    <double>[12, 0, -12].expand(quaternionZ).toList(),
    'VEC4',
  );
  animations.add({
    'name': 'clap',
    'samplers': [
      {'input': clapTimes, 'output': leftClap, 'interpolation': 'LINEAR'},
      {'input': clapTimes, 'output': rightClap, 'interpolation': 'LINEAR'},
    ],
    'channels': [
      {
        'sampler': 0,
        'target': {'node': 3, 'path': 'rotation'}
      },
      {
        'sampler': 1,
        'target': {'node': 4, 'path': 'rotation'}
      },
    ],
  });

  final binary = buffer.takeBytes();
  final gltf = {
    'asset': {'version': '2.0', 'generator': 'Toy Vision Tobi generator'},
    'extensionsUsed': ['KHR_materials_unlit'],
    'scene': 0,
    'scenes': [
      {
        'nodes': [0]
      }
    ],
    'nodes': nodes,
    'meshes': meshes,
    'materials': materials,
    'animations': animations,
    'buffers': [
      {
        'byteLength': binary.length,
        'uri': 'data:application/octet-stream;base64,${base64Encode(binary)}',
      }
    ],
    'bufferViews': views,
    'accessors': accessors,
  };
  final output = File('assets/models/tobi.gltf');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(gltf));
  stdout.writeln('Generated ${output.path} (${output.lengthSync()} bytes)');
}
