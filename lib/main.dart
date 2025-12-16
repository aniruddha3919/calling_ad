import 'dart:convert';
import 'dart:async';
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final List<Map<String, String>> contacts = [
    {"name": "Soumyadeep", "number": "+917450058394"},
    {"name": "Rakesh", "number": "+919064847969"},
  ];

  // ✅ Add debouncing timer
  Timer? _overlayTimer;
  bool _isOverlayShowing = false;
  String? _lastPhoneNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPermissions();
    _startPhoneStateListener();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("App lifecycle state: $state");
  }

  Future<void> _initPermissions() async {
    await [
      Permission.phone,
      Permission.systemAlertWindow,
      Permission.notification,
    ].request();

    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  // ✅ Fixed phone state listener with debouncing
  void _startPhoneStateListener() {
    PhoneState.stream.listen((PhoneState event) {
      debugPrint("📞 PhoneState => ${event.status}");
      debugPrint("📞 Phone Number => ${event.number}");

      switch (event.status) {
        case PhoneStateStatus.CALL_INCOMING:
          // Skip if number is null (first event) - wait for the second event with actual number
          if (event.number == null || event.number!.isEmpty) {
            debugPrint("⏭️ Skipping null/empty number - waiting for actual number");
            return;
          }
          
          debugPrint("🔔 Incoming call detected with valid number!");
          _scheduleOverlay(event.number, isIncoming: true);
          break;

        case PhoneStateStatus.CALL_STARTED:
          // Only show if we haven't already shown it for incoming
          if (!_isOverlayShowing) {
            debugPrint("📲 Call started!");
            _scheduleOverlay(event.number, isIncoming: false);
          }
          break;

        case PhoneStateStatus.CALL_ENDED:
          debugPrint("📵 Call ended");
          _overlayTimer?.cancel();
          _isOverlayShowing = false;
          _lastPhoneNumber = null;
          Future.delayed(const Duration(milliseconds: 300), () {
            _closeOverlay();
          });
          break;

        default:
          break;
      }
    });
  }

  // ✅ Debounced overlay display
  void _scheduleOverlay(String? phoneNumber, {bool isIncoming = false}) {
    // Cancel any existing timer
    _overlayTimer?.cancel();

    // Skip if already showing same number
    if (_isOverlayShowing && _lastPhoneNumber == phoneNumber) {
      debugPrint("⏭️ Overlay already showing for this number");
      return;
    }

    // Wait 300ms to collect all events before showing overlay
    _overlayTimer = Timer(const Duration(milliseconds: 300), () {
      _showOverlay(phoneNumber, isIncoming: isIncoming);
    });
  }

  Future<void> _showOverlay(String? phoneNumber, {bool isIncoming = false}) async {
    try {
      // Double-check if already active
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        debugPrint("⚠️ Overlay already active");
        return;
      }

      _isOverlayShowing = true;
      _lastPhoneNumber = phoneNumber;

      debugPrint("🟢 Showing overlay for: $phoneNumber (Incoming: $isIncoming)");

      final data = jsonEncode({
        "phoneNumber": phoneNumber ?? "Unknown",
        "isIncoming": isIncoming,
      });

      await FlutterOverlayWindow.shareData(data);

      await FlutterOverlayWindow.showOverlay(
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        enableDrag: false,
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.center,
        overlayTitle: isIncoming ? "Incoming Call" : "Calling",
        overlayContent: phoneNumber ?? "Unknown Number",
      );
      
      debugPrint("✅ Overlay shown successfully");
    } catch (e) {
      _isOverlayShowing = false;
      debugPrint("❌ Overlay error: $e");
    }
  }

  Future<void> _closeOverlay() async {
    try {
      final isActive = await FlutterOverlayWindow.isActive();
      if (!isActive) {
        debugPrint("⚠️ Overlay not active");
        return;
      }

      debugPrint("🔴 Closing overlay...");
      await FlutterOverlayWindow.closeOverlay();
      _isOverlayShowing = false;
      debugPrint("✅ Overlay closed successfully");
    } catch (e) {
      debugPrint("❌ Close overlay error: $e");
    }
  }

  Future<void> _call(String number) async {
    debugPrint("📞 Calling: $number");
    await FlutterPhoneDirectCaller.callNumber(number);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Contacts"),
          backgroundColor: Colors.blue,
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "✓ Overlay enabled - Works when app is open or minimized",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.person, size: 32, color: Colors.blue),
                      title: Text(
                        contact['name']!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        contact['number']!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.call, color: Colors.green, size: 32),
                        onPressed: () => _call(contact['number']!),
                      ),
                      onTap: () => _call(contact['number']!),
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

/// =================================================================
/// OVERLAY UI (Same as before)
/// =================================================================

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

class OverlayUI extends StatefulWidget {
  const OverlayUI({super.key});

  @override
  State<OverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<OverlayUI> {
  String phoneNumber = "Unknown";
  String callerName = "Unknown Caller";
  bool isIncoming = false;

  @override
  void initState() {
    super.initState();
    _getCallerInfo();
  }

  Future<void> _getCallerInfo() async {
    FlutterOverlayWindow.overlayListener.listen((data) {
      try {
        debugPrint("📥 Received data: $data");
        final parsedData = jsonDecode(data);

        if (mounted) {
          setState(() {
            phoneNumber = parsedData['phoneNumber'] ?? "Unknown";
            isIncoming = parsedData['isIncoming'] ?? false;
            callerName = _lookupContact(phoneNumber);
          });
        }

        debugPrint("✅ Updated: $callerName ($phoneNumber) - Incoming: $isIncoming");
      } catch (e) {
        debugPrint("❌ Error parsing data: $e");
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
              Positioned.fill(
                child: Image.network(
                  "https://picsum.photos/1080/2400",
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(Icons.phone_in_talk, size: 200, color: Colors.white),
                    ),
                  ),
                ),
              ),
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
                      Text(
                        isIncoming ? "Incoming Call..." : "Calling...",
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        callerName,
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        phoneNumber,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white.withOpacity(0.8),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: isIncoming ? Colors.blueAccent : Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "Tap anywhere to close",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 50,
                right: 20,
                child: GestureDetector(
                  onTap: () => FlutterOverlayWindow.closeOverlay(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 35),
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
