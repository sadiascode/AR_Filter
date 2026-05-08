import 'package:flutter/material.dart';
import '../models/face_model.dart';

class StickerOverlay extends StatefulWidget {
  final FaceModel? face;
  final String stickerAsset;
  final Size previewSize;
  final Size screenSize;
  final bool isFrontCamera;

  const StickerOverlay({
    Key? key,
    required this.face,
    required this.stickerAsset,
    required this.previewSize,
    required this.screenSize,
    required this.isFrontCamera,
  }) : super(key: key);

  @override
  State<StickerOverlay> createState() => _StickerOverlayState();
}

class _StickerOverlayState extends State<StickerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.face == null) return const SizedBox.shrink();

    // Scale logic
    final double scaleX = widget.screenSize.width / widget.previewSize.width;
    final double scaleY = widget.screenSize.height / widget.previewSize.height;

    double faceX = widget.face!.boundingBox.left * scaleX;
    double faceY = widget.face!.boundingBox.top * scaleY;
    double faceWidth = widget.face!.boundingBox.width * scaleX;
    double faceHeight = widget.face!.boundingBox.height * scaleY;

    // Handle mirror effect for front camera
    if (widget.isFrontCamera) {
      faceX = widget.screenSize.width - faceX - faceWidth;
    }

    const double stickerSize = 120.0;
    const double offset = 30.0;

    // Logic for left or right placement
    bool placeRight = (faceX + faceWidth + offset + stickerSize) < widget.screenSize.width;
    
    double stickerX;
    if (placeRight) {
      stickerX = faceX + faceWidth + offset;
    } else {
      // Try left
      if (faceX - offset - stickerSize > 0) {
        stickerX = faceX - offset - stickerSize;
      } else {
        // Default to right if both tight, but clamp
        stickerX = (faceX + faceWidth + offset).clamp(0, widget.screenSize.width - stickerSize);
      }
    }

    double stickerY = faceY + (faceHeight / 2) - (stickerSize / 2);
    stickerY = stickerY.clamp(0, widget.screenSize.height - stickerSize);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      left: stickerX,
      top: stickerY,
      child: AnimatedBuilder(
        animation: _floatAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: child,
          );
        },
        child: Image.asset(
          widget.stickerAsset,
          width: stickerSize,
          height: stickerSize,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
