import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:phone_state/phone_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initPermissions();
  }

  Future<void> _initPermissions() async {
    await [
      Permission.phone,
      Permission.systemAlertWindow,
      Permission.notification,
    ].request();

    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      final granted = await FlutterOverlayWindow.requestPermission();
      debugPrint("Overlay permission granted: $granted");
    }

    _listenPhoneChanges();
  }

  void _listenPhoneChanges() async {
    PhoneState.stream.listen((PhoneState event) {
      debugPrint("📞 PhoneState => ${event.status}");

      switch (event.status) {
        case PhoneStateStatus.CALL_STARTED:
          _showOverlay();
          break;
        case PhoneStateStatus.CALL_ENDED:
          // Add delay before closing to prevent crash
          Future.delayed(const Duration(milliseconds: 500), () {
            _closeOverlay();
          });
          break;
        default:
          break;
      }
    });
  }

  Future<void> _showOverlay() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        debugPrint("⚠️ Overlay already active");
        return;
      }

      debugPrint("🟢 Showing overlay...");
      await FlutterOverlayWindow.showOverlay(
        height: -1,
        width: -1,
        enableDrag: false,
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.center,
        overlayTitle: "Calling",
        overlayContent: "In progress",
      );
      debugPrint("✅ Overlay shown successfully");
    } catch (e) {
      debugPrint("❌ Overlay error: $e");
    }
  }

  Future<void> _closeOverlay() async {
    try {
      // Check if overlay is still active before closing
      final isActive = await FlutterOverlayWindow.isActive();
      if (!isActive) {
        debugPrint("⚠️ Overlay already closed");
        return;
      }

      debugPrint("🔴 Closing overlay...");
      await FlutterOverlayWindow.closeOverlay();
      debugPrint("✅ Overlay closed successfully");
    } catch (e) {
      debugPrint("❌ Close overlay error: $e");
      // Don't rethrow - just log the error
    }
  }

  Future<void> _call() async {
    await FlutterPhoneDirectCaller.callNumber("+917450058394");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Call Test"),
          backgroundColor: Colors.blue,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _call,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text("📞 MAKE CALL"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _showOverlay,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text("🔲 TEST OVERLAY"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _closeOverlay,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: const Text("❌ CLOSE OVERLAY"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Overlay entrypoint
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayUI(),
    ),
  );
}

class OverlayUI extends StatelessWidget {
  const OverlayUI({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {
          debugPrint("Overlay tapped - closing");
          // Add try-catch to prevent crashes
          try {
            FlutterOverlayWindow.closeOverlay();
          } catch (e) {
            debugPrint("Error closing overlay: $e");
          }
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Stack(
            children: [
              // FULLSCREEN IMAGE
              Positioned.fill(
                child: Image.network(
                  "https://picsum.photos/1080/2400",
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(
                        Icons.phone_in_talk,
                        size: 200,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // Semi-transparent overlay with call info
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Calling...",
                        style: TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "+91 745 005 8394",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 25),
                      const SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "Tap anywhere to close",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Close button at top right
              Positioned(
                top: 50,
                right: 20,
                child: GestureDetector(
                  onTap: () {
                    try {
                      FlutterOverlayWindow.closeOverlay();
                    } catch (e) {
                      debugPrint("Error closing overlay: $e");
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
