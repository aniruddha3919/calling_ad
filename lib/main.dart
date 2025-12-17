import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

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
  static const platform = MethodChannel('com.example.callad/overlay');
  
  final List<Map<String, String>> contacts = [
    {"name": "Soumyadeep", "number": "+917450058394"},
    {"name": "Aniruddha", "number": "+919831209756"},
  ];

  bool _isReady = false;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    debugPrint("🔧 Starting initialization...");
    
    await _requestPermissions();
    await _setupMethodChannel();
    
    // Wait a bit for overlay system to be ready
    await Future.delayed(const Duration(milliseconds: 800));
    
    setState(() => _isReady = true);
    debugPrint("✅ App fully initialized");
  }

  Future<void> _requestPermissions() async {
    final phoneStatus = await Permission.phone.request();
    debugPrint("📞 Phone permission: $phoneStatus");
    
    final overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    debugPrint("🪟 Overlay permission: $overlayGranted");
    
    if (!overlayGranted) {
      final granted = await FlutterOverlayWindow.requestPermission();
      debugPrint("🪟 Overlay permission requested: $granted");
    }
  }

  Future<void> _setupMethodChannel() async {
    platform.setMethodCallHandler((call) async {
      debugPrint("📞 Method call: ${call.method}");
      
      if (call.method == 'handleOverlay') {
        final Map<dynamic, dynamic> data = call.arguments;
        debugPrint("📦 Data: $data");
        
        if (data['action'] == 'show') {
          await _showOverlayWithRetry(
            data['phoneNumber'] as String,
            isIncoming: data['isIncoming'] as bool,
          );
        } else if (data['action'] == 'close') {
          await _closeOverlay();
        }
      }
    });
    debugPrint("✅ Method channel setup complete");
  }

  // Retry showing overlay if it fails initially
  Future<void> _showOverlayWithRetry(String phoneNumber, {bool isIncoming = false, int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        debugPrint("🔄 Attempt ${i + 1} to show overlay");
        
        // Check if already showing
        final isActive = await FlutterOverlayWindow.isActive();
        if (isActive) {
          debugPrint("⚠️ Overlay already active");
          return;
        }

        // Check permission again
        final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
        if (!hasPermission) {
          debugPrint("❌ No overlay permission");
          return;
        }

        debugPrint("🟢 Showing overlay for: $phoneNumber (Incoming: $isIncoming)");

        // Share data
        final overlayData = jsonEncode({
          "phoneNumber": phoneNumber,
          "isIncoming": isIncoming,
        });
        
        await FlutterOverlayWindow.shareData(overlayData);
        debugPrint("✅ Data shared: $overlayData");

        // Show overlay
        await FlutterOverlayWindow.showOverlay(
          height: WindowSize.matchParent,
          width: WindowSize.matchParent,
          enableDrag: false,
          overlayTitle: "Incoming Call",
          overlayContent: phoneNumber,
        );
        
        debugPrint("✅ Overlay shown!");
        return; // Success!
        
      } catch (e) {
        debugPrint("❌ Attempt ${i + 1} failed: $e");
        if (i < retries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
        }
      }
    }
    
    debugPrint("❌ All retry attempts failed");
  }

  Future<void> _closeOverlay() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (!isActive) {
        debugPrint("⚠️ Overlay not active");
        return;
      }
      
      await FlutterOverlayWindow.closeOverlay();
      debugPrint("✅ Overlay closed");
    } catch (e) {
      debugPrint("❌ Error closing: $e");
    }
  }

  Future<void> _testOverlay() async {
    debugPrint("🧪 Testing overlay manually");
    await _showOverlayWithRetry("+919876543210", isIncoming: true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Call Overlay"),
          backgroundColor: Colors.blue,
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _testOverlay,
              tooltip: "Test Overlay",
            ),
          ],
        ),
        body: Column(
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              color: _isReady ? Colors.green.shade50 : Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(
                    _isReady ? Icons.check_circle : Icons.hourglass_empty,
                    color: _isReady ? Colors.green.shade700 : Colors.orange.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isReady ? "✓ System Ready" : "⏳ Initializing...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isReady ? Colors.green.shade900 : Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isReady 
                            ? "Overlay will show on incoming calls" 
                            : "Please wait...",
                          style: TextStyle(
                            fontSize: 12,
                            color: _isReady ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Test Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _isReady ? _testOverlay : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text("Test Overlay Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
            
            const Divider(),
            
            // Contact List
            Expanded(
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          contact['name']![0],
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        contact['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(contact['number']!),
                      trailing: IconButton(
                        icon: const Icon(Icons.call, color: Colors.green, size: 28),
                        onPressed: () => FlutterPhoneDirectCaller.callNumber(contact['number']!),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// OVERLAY UI
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayUI(),
  ));
}

class OverlayUI extends StatefulWidget {
  const OverlayUI({super.key});

  @override
  State<OverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<OverlayUI> {
  String phoneNumber = "Unknown";
  String callerName = "Unknown";
  bool isIncoming = false;

  @override
  void initState() {
    super.initState();
    debugPrint("🎨 Overlay UI initialized");
    _listenToData();
  }

  void _listenToData() {
    FlutterOverlayWindow.overlayListener.listen((data) {
      try {
        debugPrint("📥 Overlay received data: $data");
        final parsed = jsonDecode(data);
        
        if (mounted) {
          setState(() {
            phoneNumber = parsed['phoneNumber'] ?? "Unknown";
            isIncoming = parsed['isIncoming'] ?? false;
            callerName = _lookupContact(phoneNumber);
          });
          debugPrint("✅ Overlay UI updated: $callerName");
        }
      } catch (e) {
        debugPrint("❌ Error parsing overlay data: $e");
      }
    });
  }

  String _lookupContact(String number) {
    final contacts = {
      "+917450058394": "Soumyadeep",
      "+919064847969": "Rakesh",
    };
    return contacts[number] ?? "Unknown Caller";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {
          debugPrint("👆 Overlay tapped - closing");
          FlutterOverlayWindow.closeOverlay();
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isIncoming ? Colors.blue.shade900 : Colors.green.shade900,
                Colors.black,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Main Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Phone Icon
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Icon(
                        isIncoming ? Icons.phone_in_talk : Icons.phone_callback,
                        size: 70,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Call Status
                    Text(
                      isIncoming ? "INCOMING CALL" : "CALLING",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 3,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Caller Name
                    Text(
                      callerName,
                      style: const TextStyle(
                        fontSize: 36,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    // Phone Number
                    Text(
                      phoneNumber,
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.white.withOpacity(0.8),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 50),
                    
                    // Loading Indicator
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isIncoming ? Colors.blueAccent : Colors.greenAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Close Button
              Positioned(
                top: 60,
                right: 24,
                child: GestureDetector(
                  onTap: () {
                    debugPrint("❌ Close button pressed");
                    FlutterOverlayWindow.closeOverlay();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              
              // Tap to close hint
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Tap anywhere to close",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontStyle: FontStyle.italic,
                      ),
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
