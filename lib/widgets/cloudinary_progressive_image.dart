import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../core/services/cloudinary_service.dart';

/// A high-performance progressive image loader for Cloudinary assets.
/// Automatically renders an instant blurred Low-Quality Image Placeholder (LQIP)
/// before cross-fading into the optimized high-resolution delivery URL.
class CloudinaryProgressiveImage extends StatelessWidget {
  final String imageUrl;
  final String? localPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeDuration;

  const CloudinaryProgressiveImage({
    super.key,
    required this.imageUrl,
    this.localPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeDuration = const Duration(milliseconds: 250),
  });

  @override
  Widget build(BuildContext context) {
    Widget imageContent = _buildContent(context);

    if (borderRadius != null) {
      imageContent = ClipRRect(
        borderRadius: borderRadius!,
        child: imageContent,
      );
    }

    if (width != null || height != null) {
      return SizedBox(
        width: width,
        height: height,
        child: imageContent,
      );
    }

    return imageContent;
  }

  Widget _buildContent(BuildContext context) {
    if (imageUrl.isEmpty && (localPath == null || localPath!.isEmpty)) {
      return _buildPlaceholder();
    }

    // 1. Remote URLs: Cloudinary Progressive LQIP or standard network image (prioritized when uploaded)
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      final isCloudinary = imageUrl.contains('res.cloudinary.com') && imageUrl.contains('/upload/');

      if (isCloudinary) {
        final lqipUrl = CloudinaryService.getLqipUrl(imageUrl, width: 30);
        final targetUrl = CloudinaryService.getCardBannerUrl(imageUrl, width: 800, height: 600);

        return Stack(
          fit: StackFit.passthrough,
          children: [
            // Instant blurred placeholder
            Image.network(
              lqipUrl,
              fit: fit,
              width: width,
              height: height,
              errorBuilder: (ctx, err, stack) => _buildPlaceholder(),
            ),
            // High-res image with smooth fade transition
            Image.network(
              targetUrl,
              fit: fit,
              width: width,
              height: height,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return AnimatedOpacity(
                    opacity: frame == null ? 0.0 : 1.0,
                    duration: fadeDuration,
                    curve: Curves.easeOut,
                    child: child,
                  );
                }
                return const SizedBox.shrink();
              },
              errorBuilder: (ctx, err, stack) {
                // Offline fallback to local cached file if available
                if (!kIsWeb && localPath != null && localPath!.isNotEmpty) {
                  try {
                    final f = File(localPath!);
                    if (f.existsSync()) {
                      return Image.file(
                        f,
                        fit: fit,
                        width: width,
                        height: height,
                        errorBuilder: (_, __, ___) => _buildErrorFallback(),
                      );
                    }
                  } catch (_) {}
                }
                return _buildErrorFallback();
              },
            ),
          ],
        );
      }

      // Standard non-Cloudinary remote URL
      return Image.network(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildPlaceholder();
        },
        errorBuilder: (ctx, err, stack) {
          if (!kIsWeb && localPath != null && localPath!.isNotEmpty) {
            try {
              final f = File(localPath!);
              if (f.existsSync()) {
                return Image.file(
                  f,
                  fit: fit,
                  width: width,
                  height: height,
                  errorBuilder: (_, __, ___) => _buildErrorFallback(),
                );
              }
            } catch (_) {}
          }
          return _buildErrorFallback();
        },
      );
    }

    // 2. Base64 data URLs
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        return Image.memory(
          base64Decode(base64Str),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (ctx, err, stack) => _buildErrorFallback(),
        );
      } catch (_) {
        return _buildErrorFallback();
      }
    }

    // 3. Local filesystem path in imageUrl or localPath (when not yet uploaded)
    if (!kIsWeb) {
      final pathToCheck = imageUrl.isNotEmpty && !imageUrl.startsWith('http') ? imageUrl : localPath;
      if (pathToCheck != null && pathToCheck.isNotEmpty) {
        try {
          final f = File(pathToCheck);
          if (f.existsSync()) {
            return Image.file(
              f,
              fit: fit,
              width: width,
              height: height,
              errorBuilder: (ctx, err, stack) => _buildErrorFallback(),
            );
          }
        } catch (_) {}
      }
    }

    return _buildErrorFallback();
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.withAlpha(40),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
  }

  Widget _buildErrorFallback() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey.withAlpha(30),
          child: const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
          ),
        );
  }
}
