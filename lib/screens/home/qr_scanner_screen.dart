import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  bool _hasDetected = false;
  bool _isTorchOn = false;
  bool _isWebCameraActive = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasDetected) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        setState(() => _hasDetected = true);
        Navigator.of(context).pop(value);
        break;
      }
    }
  }

  void _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          final value = capture.barcodes.first.rawValue;
          if (value != null && value.isNotEmpty && mounted) {
            setState(() => _hasDetected = true);
            Navigator.of(context).pop(value);
            return;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No QR code found in selected image.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showManualInputDialog(
          customTitle: 'Enter Live Trip Code',
          customHint: 'Enter 6-char Room Code (e.g. TRIP-7482) or paste invite text',
        );
      }
    }
  }

  void _showManualInputDialog({String? customTitle, String? customHint}) {
    final textController = TextEditingController(text: 'TRIP-');
    textController.selection = TextSelection.fromPosition(
      TextPosition(offset: textController.text.length),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customTitle ?? 'Enter Trip Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 6-character room code (e.g. TRIP-7482) or paste the invite:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
              decoration: InputDecoration(
                hintText: customHint ?? 'e.g. TRIP-7482',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.vpn_key_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              var text = textController.text.trim().toUpperCase();
              if (text.isNotEmpty && text != 'TRIP-') {
                if (text.length == 4 && !text.contains('TRIP-')) {
                  text = 'TRIP-$text';
                }
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(text);
              }
            },
            child: const Text('Join Trip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanAreaSize = screenSize.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text(
          'Scan Trip QR Code',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            tooltip: 'Toggle Flashlight',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_rounded),
            tooltip: 'Switch Camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: (kIsWeb && !_isWebCameraActive)
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1E293B),
                        Color(0xFF0F172A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.teal.withAlpha(80), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withAlpha(30),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF14B8A6).withAlpha(80),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Join Live Trip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enter the 6-character room code or pick a QR screenshot to sync all expenses and live route.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton.icon(
                        onPressed: () => _showManualInputDialog(),
                        icon: const Icon(Icons.vpn_key_rounded, size: 20),
                        label: const Text('Enter Trip Code (e.g. TRIP-XXXX)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(Icons.photo_library_rounded, size: 18, color: Colors.white),
                        label: const Text('Pick QR Code from Gallery', style: TextStyle(color: Colors.white, fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withAlpha(50)),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: () => setState(() => _isWebCameraActive = true),
                        icon: const Icon(Icons.videocam_rounded, size: 18, color: AppTheme.secondary),
                        label: const Text('Try Live Web Camera', style: TextStyle(color: AppTheme.secondary, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Stack(
              alignment: Alignment.center,
              children: [
                // Live Camera Feed
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.white54),
                            const SizedBox(height: 12),
                            const Text(
                              'Camera unavailable or permission denied.',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _pickImageFromGallery,
                              icon: const Icon(Icons.photo_library_rounded),
                              label: const Text('Choose QR Image from Photos'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => _showManualInputDialog(),
                              child: const Text('Enter Code Manually', style: TextStyle(color: AppTheme.secondary)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Darkened background cutout
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withAlpha(140),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                          backgroundBlendMode: BlendMode.dstOut,
                        ),
                      ),
                      Center(
                        child: Container(
                          width: scanAreaSize,
                          height: scanAreaSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

          // Targeted Scanner Frame Box
          Center(
            child: Container(
              width: scanAreaSize,
              height: scanAreaSize,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.secondary, width: 2.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  // Corner accents
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.primary, width: 5),
                          left: BorderSide(color: AppTheme.primary, width: 5),
                        ),
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(22)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.primary, width: 5),
                          right: BorderSide(color: AppTheme.primary, width: 5),
                        ),
                        borderRadius: BorderRadius.only(topRight: Radius.circular(22)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppTheme.primary, width: 5),
                          left: BorderSide(color: AppTheme.primary, width: 5),
                        ),
                        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(22)),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppTheme.primary, width: 5),
                          right: BorderSide(color: AppTheme.primary, width: 5),
                        ),
                        borderRadius: BorderRadius.only(bottomRight: Radius.circular(22)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar (Gallery & Manual Entry)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImageFromGallery,
                        icon: const Icon(
                          kIsWeb ? Icons.vpn_key_rounded : Icons.photo_library_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text(
                          kIsWeb ? 'Enter Room Code' : 'Pick Image',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black54,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showManualInputDialog(),
                        icon: const Icon(Icons.paste_rounded, size: 18, color: Colors.white),
                        label: const Text('Paste Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.black54,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Point camera at the QR code on your friend\'s screen',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
