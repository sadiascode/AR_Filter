import 'package:flutter/material.dart';

class FaceModel {
  final Rect boundingBox;
  final double? headEulerAngleX; // Up/Down
  final double? headEulerAngleY; // Left/Right
  final double? headEulerAngleZ; // Tilt

  FaceModel({
    required this.boundingBox,
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.headEulerAngleZ,
  });

  @override
  String toString() {
    return 'FaceModel(boundingBox: $boundingBox, angleY: $headEulerAngleY)';
  }
}
