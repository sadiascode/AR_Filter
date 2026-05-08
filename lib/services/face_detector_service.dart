import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/face_model.dart';

class FaceDetectorService {
  final FaceDetector? _faceDetector = (Platform.isAndroid || Platform.isIOS) 
    ? FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableClassification: false,
          enableLandmarks: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      )
    : null;

  Future<FaceModel?> detectFace(InputImage inputImage) async {
    if (_faceDetector == null) return null;
    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      
      if (faces.isEmpty) return null;

      final face = faces.first;
      return FaceModel(
        boundingBox: face.boundingBox,
        headEulerAngleX: face.headEulerAngleX,
        headEulerAngleY: face.headEulerAngleY,
        headEulerAngleZ: face.headEulerAngleZ,
      );
    } catch (e) {
      print('Error detecting face: $e');
      return null;
    }
  }

  void dispose() {
    _faceDetector?.close();
  }
}
