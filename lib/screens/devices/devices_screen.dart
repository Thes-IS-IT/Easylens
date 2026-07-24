import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/esp32_service.dart';
import '../../widgets/screen_tutorial_card.dart';

// Pairing flow state machine
enum _DeviceState { dashboard, enterIp, scanning, connected, deviceSettings }

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen>
    with TickerProviderStateMixin {
  final Esp32Service _esp32 = Esp32Service();
  _DeviceState _state = _DeviceState.dashboard;

  final TextEditingController _ipCtrl = TextEditingController(
    text: 'http://192.168.4.1:81/stream',
  );

  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _esp32.initialize().then((_) {
      if (mounted) {
        _ipCtrl.text = _esp32.streamUrl;
        setState(() {});
      }
    });
    _esp32.addListener(_rebuild);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    if (_esp32.isConnected) _state = _DeviceState.connected;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScreenTutorialCard.showIfNeeded(
        context,
        tutorialKey: 'devices',
        titleKey: 'tutorial_devices_title',
        descriptionKey: 'tutorial_devices_desc',
        mascotAsset: 'assets/Mascots/05 Welcome.gif',
      );
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _esp32.removeListener(_rebuild);
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  // ── Navigation helpers ──────────────────────────────────────────────────
  void _go(_DeviceState s) {
    _fadeCtrl.forward(from: 0);
    setState(() => _state = s);
  }

  // ── Connect flow ────────────────────────────────────────────────────────
  Future<void> _connect() async {
    final url = _ipCtrl.text.trim();
    if (url.isEmpty) return;
    _go(_DeviceState.scanning);
    final ok = await _esp32.connect(url: url);
    if (mounted) {
      _go(ok ? _DeviceState.connected : _DeviceState.enterIp);
      if (!ok) {
        _showSnack('Could not connect. Make sure you joined the "EasyLens-Camera" WiFi.', isError: true);
      }
    }
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    final url = _ipCtrl.text.trim();
    final ok = await _esp32.ping(url);
    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = ok ? '✓ Device reachable!' : '✗ Device not found';
      });
    }
  }

  Future<void> _disconnect() async {
    await _esp32.disconnect();
    if (mounted) _go(_DeviceState.dashboard);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeCtrl,
          child: _buildCurrentState(),
        ),
      ),
    );
  }

  Widget _buildCurrentState() {
    switch (_state) {
      case _DeviceState.dashboard:
        return _buildDashboard();
      case _DeviceState.enterIp:
        return _buildEnterIp();
      case _DeviceState.scanning:
        return _buildScanning();
      case _DeviceState.connected:
        return _buildConnected();
      case _DeviceState.deviceSettings:
        return _buildDeviceSettings();
    }
  }

  // ── Header ───────────────────────────────────────────────────────────────
  Widget _buildHeader(String title, String subtitle, {VoidCallback? onBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack ?? () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chevron_left, color: Color(0xFF002663), size: 22),
                      const SizedBox(width: 2),
                      Text(
                        'Back',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF002663),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF002663),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATE: Dashboard
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader('Devices', 'Manage your EasyLens smart glasses.'),

          // Live connection status banner
          _buildConnectionBanner(),
          const SizedBox(height: 20),

          // Add / Connect button
          _buildActionCard(
            icon: Icons.add_circle_outline_rounded,
            color: const Color(0xFF002663),
            title: 'Connect ESP32-CAM Glasses',
            subtitle: 'Join "EasyLens-Camera" WiFi, then tap here.',
            onTap: () => _go(_DeviceState.enterIp),
          ),
          const SizedBox(height: 16),

          // Instructions card
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    final connected = _esp32.isConnected;
    final color = connected ? const Color(0xFF10B981) : const Color(0xFF94A3B8);
    final bgColor = connected ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC);
    final borderColor = connected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0);

    return GestureDetector(
      onTap: connected ? () => _go(_DeviceState.connected) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(connected ? 0.08 + _pulseCtrl.value * 0.1 : 0.08),
                ),
                child: Icon(
                  connected
                      ? Icons.wifi_rounded
                      : Icons.wifi_off_rounded,
                  color: color,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connected ? 'EasyLens-Camera' : 'No Device Connected',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    _esp32.statusMessage,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (connected)
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final steps = [
      ('1', 'Turn on your ESP32-CAM smart glasses.'),
      ('2', 'On your phone, go to WiFi Settings.'),
      ('3', 'Connect to "EasyLens-Camera" (open, no password).'),
      ('4', 'Come back here and tap "Connect".'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF002663), size: 18),
              const SizedBox(width: 8),
              Text(
                'How to Connect',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: const Color(0xFF002663),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFF002663),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          s.$1,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.$2,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF374151),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATE: Enter IP / Stream URL
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEnterIp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Add Device',
            'Enter the stream URL of your ESP32-CAM.',
            onBack: () => _go(_DeviceState.dashboard),
          ),

          // URL Input
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stream URL',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF002663),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ipCtrl,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  style: GoogleFonts.robotoMono(fontSize: 13, color: const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF002663), width: 2),
                    ),
                    hintText: 'http://192.168.4.1:81/stream',
                    hintStyle: GoogleFonts.robotoMono(
                      fontSize: 12,
                      color: const Color(0xFFB0BEC5),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _ipCtrl.clear(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Quick presets
                Text(
                  'Quick Presets',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _preset('AP Mode (default)', 'http://192.168.4.1:81/stream'),
                    _preset('Custom IP', 'http://192.168.1.X:81/stream'),
                  ],
                ),

                if (_testResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _testResult!.startsWith('✓')
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _testResult!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _testResult!.startsWith('✓')
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Test button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isTesting ? null : _testConnection,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF002663), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isTesting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF002663)),
                    )
                  : Text(
                      'Test Connection',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF002663),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Connect button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _connect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002663),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                'Connect to Device',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preset(String label, String url) {
    return GestureDetector(
      onTap: () => setState(() => _ipCtrl.text = url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF002663).withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF002663),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATE: Scanning / Connecting
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildScanning() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 100 + _pulseCtrl.value * 20,
                height: 100 + _pulseCtrl.value * 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF002663).withOpacity(0.08 + _pulseCtrl.value * 0.08),
                ),
                child: const Center(
                  child: Icon(Icons.wifi_find_rounded, color: Color(0xFF002663), size: 44),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Connecting...',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF002663),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Establishing link with EasyLens-Camera.\nMake sure you\'re on the device\'s WiFi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            const LinearProgressIndicator(
              backgroundColor: Color(0xFFE2E8F0),
              color: Color(0xFF002663),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATE: Connected — live preview + controls
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildConnected() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Connected!',
            'EasyLens-Camera is streaming live.',
            onBack: () => _go(_DeviceState.dashboard),
          ),

          // Live Camera Preview
          _buildLivePreview(),
          const SizedBox(height: 20),

          // Quick controls
          Row(
            children: [
              Expanded(
                child: _controlBtn(
                  icon: _esp32.flashOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                  label: _esp32.flashOn ? 'Flash On' : 'Flash Off',
                  color: _esp32.flashOn ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
                  onTap: () => _esp32.toggleFlash(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _controlBtn(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  color: const Color(0xFF002663),
                  onTap: () => _go(_DeviceState.deviceSettings),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Disconnect button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _disconnect,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Disconnect Device',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF002663).withOpacity(0.3),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: _esp32,
        builder: (_, __) {
          final frame = _esp32.currentFrame;
          if (frame == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Icon(
                      Icons.videocam_rounded,
                      color: Colors.white.withOpacity(0.3 + _pulseCtrl.value * 0.3),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Waiting for stream...',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            );
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              RotatedBox(
                quarterTurns: 3, // Rotate 270 degrees clockwise for correct vertical alignment of ESP32-CAM
                child: Image.memory(
                  frame,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              // Live indicator
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5 + _pulseCtrl.value * 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'LIVE',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Flash indicator
              if (_esp32.flashOn)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flashlight_on_rounded, color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'FLASH',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STATE: Device Settings
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDeviceSettings() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Device Settings',
            'EasyLens-Camera ESP32-CAM',
            onBack: () => _go(_DeviceState.connected),
          ),

          // Device info card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.videocam_rounded, size: 60, color: Color(0xFF002663)),
                const SizedBox(height: 12),
                Text(
                  'EasyLens-Camera',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: const Color(0xFF002663),
                  ),
                ),
                Text(
                  'ESP32-CAM — WiFi AP Mode',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Connection details
          _settingsCard([
            _settingsRow(Icons.wifi_rounded, 'SSID', 'EasyLens-Camera', const Color(0xFF002663)),
            _settingsDivider(),
            _settingsRow(Icons.link_rounded, 'Stream URL', _esp32.streamUrl, const Color(0xFF6366F1)),
            _settingsDivider(),
            _settingsRow(Icons.circle, 'Status', _esp32.statusMessage, const Color(0xFF10B981)),
          ]),
          const SizedBox(height: 16),

          // Flash toggle card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flash LED',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    Text(
                      'Toggle the ESP32-CAM flash light',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                Switch(
                  value: _esp32.flashOn,
                  onChanged: (v) => _esp32.setFlash(v),
                  activeColor: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Change URL
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(
                'Change Stream URL',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF002663),
                side: const BorderSide(color: Color(0xFF002663), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _go(_DeviceState.enterIp),
            ),
          ),
          const SizedBox(height: 12),

          // Disconnect
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: Text(
                'Disconnect',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _disconnect,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsDivider() =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9));
}
