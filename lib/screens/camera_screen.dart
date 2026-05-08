import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/camera_controller.dart';
import '../widgets/sticker_overlay.dart';

class CameraScreen extends StatelessWidget {
  final ARCameraController controller = Get.put(ARCameraController());

   CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Obx(() {
        if (!controller.isCameraInitialized.value) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFFFFC00), // Snapchat yellow
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Screenshot Area (Camera + Stickers)
            RepaintBoundary(
              key: controller.screenShotKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraPreview(),
                  _buildStickerOverlay(context),
                  
                  // Simulator Mode Indicator (include in photo if active)
                  if (controller.isSimulatorMode.value)
                    _buildSimulatorIndicator(),
                ],
              ),
            ),

            // 2. UI Controls (Hides from screenshot)
            _buildTopControls(),
            _buildBottomControls(),
          ],
        );
      }),
    );
  }

  Widget _buildSimulatorIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 80, color: Colors.white24),
          const SizedBox(height: 20),
          Text(
            'Simulator/Desktop Mode',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Camera & AR tracking disabled',
            style: TextStyle(
              color: Colors.white.withAlpha(100),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 50,
      right: 20,
      child: Column(
        children: [
          _buildCircleButton(
            icon: Icons.flip_camera_ios_outlined,
            onTap: controller.flipCamera,
          ),
          const SizedBox(height: 15),
          _buildCircleButton(
            icon: Icons.flash_off_outlined,
            onTap: () {}, // Optional
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sticker Selector
          Container(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildStickerItem('assets/stickers/cat.png'),
                _buildStickerItem('assets/stickers/dog.png'),
                _buildStickerItem('assets/stickers/ghost.png'),
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          // Capture Button
          GestureDetector(
            onTap: controller.capturePhoto,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 5),
              ),
              child: Center(
                child: Container(
                  height: 65,
                  width: 65,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final scale = 1 / (controller.cameraController!.value.aspectRatio * Get.width / Get.height);
    
    return Transform.scale(
      scale: scale < 1 ? 1 / scale : scale,
      child: Center(
        child: CameraPreview(controller.cameraController!),
      ),
    );
  }

  Widget _buildStickerOverlay(BuildContext context) {
    final previewSize = controller.cameraController!.value.previewSize!;
    
    // ML Kit coordinates are relative to the preview size.
    // Note: previewSize is (height, width) because of orientation in some cases,
    // but camera plugin usually gives it correctly for the sensor.
    // However, on Android/iOS there are differences.
    
    return StickerOverlay(
      face: controller.detectedFace.value,
      stickerAsset: controller.selectedSticker.value,
      previewSize: Size(previewSize.height, previewSize.width),
      screenSize: Size(Get.width, Get.height),
      isFrontCamera: controller.isFrontCamera.value,
    );
  }

  Widget _buildStickerItem(String assetPath) {
    return Obx(() {
      bool isSelected = controller.selectedSticker.value == assetPath;
      return GestureDetector(
        onTap: () => controller.selectSticker(assetPath),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.3) : Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? const Color(0xFFFFFC00) : Colors.transparent,
              width: 3,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Image.asset(assetPath),
        ),
      );
    });
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
