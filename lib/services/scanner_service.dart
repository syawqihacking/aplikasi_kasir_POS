import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import '../database/database_helper.dart';

/// Defines how a screen wants to handle a barcode scan.
enum ScanContextMode {
  /// Default mode — barcode goes to POS cart
  sale,
  /// Barcode fills a form field (e.g. product registration)
  formField,
  /// Barcode looks up a product for stock-in/stock-out/opname
  inventoryLookup,
}

/// Represents a registered scan context from a screen/dialog.
class ScanContext {
  final String id;
  final ScanContextMode mode;
  final void Function(String barcode) handler;

  ScanContext({
    required this.id,
    required this.mode,
    required this.handler,
  });
}

class ScannerService {
  static final ScannerService instance = ScannerService._init();

  String _currentBuffer = '';
  DateTime? _lastKeyPressTime;

  // --- Anti double-scan protection ---
  // Cooldown after a successful scan: ignore any new scan arriving within
  // this window. Prevents scanners that re-read the same code (continuous
  // beam / short re-read delay) from adding the item multiple times.
  static const Duration _dispatchCooldown = Duration(milliseconds: 800);
  // Same-barcode dedup window: ignore the identical barcode within this
  // window, while still allowing different items to be scanned quickly.
  static const Duration _duplicateWindow = Duration(seconds: 1);
  DateTime? _lastDispatchTime;
  String _lastDispatchedBarcode = '';

  // Inter-key gap threshold (ms) used to distinguish scanner input from
  // human typing. Configurable via the "Scanner Input Delay (ms)" setting.
  int _maxKeystrokeGapMs = 50;
  int get maxKeystrokeGapMs => _maxKeystrokeGapMs;

  /// Update the keystroke gap threshold (ms). Values <= 0 are ignored.
  void setKeystrokeThreshold(int ms) {
    if (ms > 0) _maxKeystrokeGapMs = ms;
  }

  // Broadcast stream for backward compatibility (POS default)
  final _barcodeStreamController = StreamController<String>.broadcast();
  Stream<String> get onBarcodeScanned => _barcodeStreamController.stream;

  // --- Context Registry ---
  final List<ScanContext> _contextStack = [];

  /// The currently active scan mode label for UI display.
  final _modeNotifier = ValueNotifier<ScanContextMode>(ScanContextMode.sale);
  ValueNotifier<ScanContextMode> get modeNotifier => _modeNotifier;

  ScanContextMode get currentMode =>
      _contextStack.isNotEmpty ? _contextStack.last.mode : ScanContextMode.sale;

  /// Safely update the mode notifier after the current frame completes.
  /// This avoids "setState during build" when pushContext/popContext is called
  /// inside initState or dispose of a widget that's being built/torn down.
  void _updateModeNotifier(ScanContextMode newMode) {
    // Use Future.microtask to ensure we're completely outside any build/layout phase
    Future.microtask(() {
      if (_modeNotifier.value != newMode) {
        _modeNotifier.value = newMode;
      }
    });
  }

  /// Push a new scan context onto the stack.
  /// The most recently pushed context takes priority.
  void pushContext(ScanContext context) {
    _contextStack.add(context);
    _updateModeNotifier(context.mode);
  }

  /// Remove a scan context by id.
  void popContext(String id) {
    _contextStack.removeWhere((c) => c.id == id);
    _updateModeNotifier(currentMode);
  }

  ScannerService._init() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _loadKeystrokeThreshold();
  }

  /// Load the "Scanner Input Delay (ms)" setting from the database so the
  /// keystroke gap threshold is configurable instead of hardcoded.
  Future<void> _loadKeystrokeThreshold() async {
    try {
      final settings = await DatabaseHelper.instance.getSettings();
      final raw = settings['scanner_delay'];
      final parsed = int.tryParse(raw ?? '');
      if (parsed != null && parsed > 0) _maxKeystrokeGapMs = parsed;
    } catch (_) {
      // Keep the default threshold if the DB is not ready yet.
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();

      // If delay between keys > threshold, it's likely human typing, not a scanner.
      if (_lastKeyPressTime != null && now.difference(_lastKeyPressTime!).inMilliseconds > _maxKeystrokeGapMs) {
        _currentBuffer = '';
      }
      _lastKeyPressTime = now;

      // Scanners typically terminate with an Enter key
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_currentBuffer.isNotEmpty && _currentBuffer.length >= 3) {
          final barcode = _currentBuffer;
          _currentBuffer = '';

          // Anti double-scan: ignore scans arriving during the cooldown
          // window, and ignore the identical barcode within the dedup window.
          final inCooldown = _lastDispatchTime != null &&
              now.difference(_lastDispatchTime!).inMilliseconds < _dispatchCooldown.inMilliseconds;
          final isDuplicate = barcode == _lastDispatchedBarcode &&
              _lastDispatchTime != null &&
              now.difference(_lastDispatchTime!).inMilliseconds < _duplicateWindow.inMilliseconds;

          if (!inCooldown && !isDuplicate) {
            _lastDispatchTime = now;
            _lastDispatchedBarcode = barcode;
            _dispatchBarcode(barcode);
          }
          return true; // Consume the enter event
        }
        _currentBuffer = '';
        return false;
      }

      // Collect typed characters
      if (event.character != null) {
        // Only accept alphanumeric characters for barcodes
        if (RegExp(r'^[a-zA-Z0-9]+$').hasMatch(event.character!)) {
          _currentBuffer += event.character!;
        }
      }
    }
    return false; // Don't block normal typing
  }

  void _dispatchBarcode(String barcode) {
    if (_contextStack.isNotEmpty) {
      // Dispatch to the topmost (most recent) context handler
      _contextStack.last.handler(barcode);
    } else {
      // Fallback: emit on the broadcast stream (POS default behavior)
      _barcodeStreamController.add(barcode);
    }
  }

  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _barcodeStreamController.close();
    _modeNotifier.dispose();
  }
}
