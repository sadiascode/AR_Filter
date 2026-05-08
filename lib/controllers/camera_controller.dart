import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:gal/gal.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../models/face_model.dart';
import '../services/face_detector_service.dart';

class ARCameraController extends GetxController {
  final FaceDetectorService _faceDetectorService = FaceDetectorService();
  
  CameraController? cameraController;
  final Rx<FaceModel?> detectedFace = Rx<FaceModel?>(null);
  final RxString selectedSticker = 'assets/stickers/cat.png'.obs;
  final RxBool isFrontCamera = true.obs;
  final RxBool isCameraInitialized = false.obs;
  final RxBool isProcessing = false.obs;
  final RxBool isSimulatorMode = false.obs;
  
  final GlobalKey screenShotKey = GlobalKey();

  List<CameraDescription> cameras = [];
  
  // Throttling
  DateTime? _lastProcessTime;
  static const int _throttleMs = 150;

  @override
  void onInit() {
    super.onInit();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        print('No cameras found. Entering simulator/desktop mode.');
        isSimulatorMode.value = true;
        isCameraInitialized.value = true;
        return;
      }

      final description = cameras.firstWhere(
        (cam) => cam.lensDirection == (isFrontCamera.value ? CameraLensDirection.front : CameraLensDirection.back),
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      await cameraController!.initialize();
      isCameraInitialized.value = true;
      
      // Start stream if on mobile
      if (Platform.isAndroid || Platform.isIOS) {
        _startImageStream();
      }
    } catch (e) {
      print('Camera initialization error: $e');
      // Fallback for desktop/simulator
      isSimulatorMode.value = true;
      isCameraInitialized.value = true;
    }
  }

  void _startImageStream() {
    cameraController?.startImageStream((CameraImage image) {
      if (isProcessing.value) return;

      final now = DateTime.now();
      if (_lastProcessTime != null && 
          now.difference(_lastProcessTime!).inMilliseconds < _throttleMs) {
        return;
      }

      _lastProcessTime = now;
      _processCameraImage(image);
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    isProcessing.value = true;
    
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final face = await _faceDetectorService.detectFace(inputImage);
      detectedFace.value = face;
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (cameraController == null) return null;

    final sensorOrientation = cameraController!.description.sensorOrientation;
    
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotation.rotation0deg;
    } else if (Platform.isAndroid) {
      switch (sensorOrientation) {
        case 90:
          rotation = InputImageRotation.rotation90deg;
          break;
        case 180:
          rotation = InputImageRotation.rotation180deg;
          break;
        case 270:
          rotation = InputImageRotation.rotation270deg;
          break;
        default:
          rotation = InputImageRotation.rotation0deg;
      }
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  Future<void> flipCamera() async {
    if (isSimulatorMode.value) return;
    
    isFrontCamera.value = !isFrontCamera.value;
    isCameraInitialized.value = false;
    
    await cameraController?.dispose();
    await _initializeCamera();
  }

  void selectSticker(String assetPath) {
    selectedSticker.value = assetPath;
  }

  Future<void> capturePhoto() async {
    if (!isSimulatorMode.value && (cameraController == null || !cameraController!.value.isInitialized)) {
      return;
    }

    try {
      // 1. Capture the RepaintBoundary as an image
      final RenderRepaintBoundary? boundary = screenShotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        Get.snackbar('Error', 'Could not capture screen');
        return;
      }

      // Capture at a higher pixel ratio for better quality
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        Get.snackbar('Error', 'Failed to process image');
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 2. Save to a temporary file
      final directory = (await getTemporaryDirectory()).path;
      final String filePath = '$directory/ar_filter_${DateTime.now().millisecondsSinceEpoch}.png';
      final File imgFile = File(filePath);
      await imgFile.writeAsBytes(pngBytes);
      
      // 3. Save to gallery using Gal
      final bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      
      await Gal.putImage(imgFile.path);
      
      Get.snackbar(
        'Success',
        'Photo with filter saved to gallery!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF1DB954),
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error capturing photo: $e');
      Get.snackbar('Error', 'Failed to save photo');
    }
  }

  @override
  void onClose() {
    cameraController?.dispose();
    _faceDetectorService.dispose();
    super.onClose();
  }
}
