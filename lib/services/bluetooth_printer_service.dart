import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

/// Manages Bluetooth thermal printer lifecycle:
/// discovery, connection, and ESC/POS byte sending.
class BluetoothPrinterService {
  BluetoothPrinterService._();
  static final BluetoothPrinterService instance = BluetoothPrinterService._();

  final FlutterClassicBluetooth _bt = FlutterClassicBluetooth();

  BtcConnection? _connection;
  StreamSubscription? _stateSub;

  /// Notifies when the connection state changes.
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier(false);

  /// The address of the currently connected (or last connected) printer.
  String? connectedAddress;

  /// The name of the currently connected printer.
  String? connectedName;

  /// Whether the platform supports Bluetooth discovery.
  bool _canDiscover = false;

  /// Initialize: check support and permissions.
  Future<bool> initialize() async {
    try {
      final supported = await _bt.isSupported();
      if (!supported) return false;

      final caps = await _bt.getPlatformCapabilities();
      _canDiscover = caps.canDiscoverDevices;

      // Request permissions (scan + connect)
      final status = await _bt.requestPermissions();
      if (status == BtcPermissionStatus.permanentlyDenied) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Bluetooth init error: $e');
      return false;
    }
  }

  /// Scan for nearby Bluetooth devices.
  Future<List<BtcDevice>> scanDevices({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      if (!_canDiscover) {
        // Fallback: return paired devices only
        return await _bt.getPairedDevices();
      }
      return await _bt.scan(timeout: timeout);
    } catch (e) {
      debugPrint('Bluetooth scan error: $e');
      // Return paired devices as fallback
      try {
        return await _bt.getPairedDevices();
      } catch (_) {
        return [];
      }
    }
  }

  /// Get the list of already-paired devices.
  Future<List<BtcDevice>> getPairedDevices() async {
    try {
      return await _bt.getPairedDevices();
    } catch (e) {
      debugPrint('Get paired devices error: $e');
      return [];
    }
  }

  /// Connect to a Bluetooth printer by address.
  Future<bool> connect(String address, {String? name}) async {
    try {
      // Disconnect any existing connection first
      await disconnect();

      final connection = await _bt.connect(
        address: address,
        timeout: const Duration(seconds: 15),
      );

      _connection = connection;
      connectedAddress = address;
      connectedName = name;
      isConnectedNotifier.value = true;

      // Listen for disconnection
      _stateSub = connection.stateStream.listen((state) {
        if (state == BtcConnectionState.disconnected) {
          isConnectedNotifier.value = false;
          _connection = null;
          connectedAddress = null;
          connectedName = null;
        }
      });

      return true;
    } catch (e) {
      debugPrint('Bluetooth connect error: $e');
      return false;
    }
  }

  /// Disconnect from the current Bluetooth printer.
  Future<void> disconnect() async {
    await _stateSub?.cancel();
    _stateSub = null;

    if (_connection != null) {
      try {
        await _connection!.close();
        _connection!.dispose();
      } catch (_) {}
      _connection = null;
    }

    connectedAddress = null;
    connectedName = null;
    isConnectedNotifier.value = false;
  }

  /// Send raw ESC/POS bytes to the connected printer.
  Future<bool> sendBytes(Uint8List data) async {
    if (_connection == null || !_connection!.isConnected) {
      debugPrint('Bluetooth: not connected');
      return false;
    }

    try {
      await _connection!.output.writeBytes(data);
      await _connection!.output.allSent;
      return true;
    } catch (e) {
      debugPrint('Bluetooth send error: $e');
      return false;
    }
  }

  /// Clean up resources.
  void dispose() {
    disconnect();
  }
}

/// A convenience widget that shows a Bluetooth printer picker bottom sheet.
class BluetoothPrinterPicker {
  static Future<String?> show(BuildContext context) async {
    final service = BluetoothPrinterService.instance;

    // Initialize if needed
    final ok = await service.initialize();
    if (!ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth tidak tersedia atau izin ditolak'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    if (!context.mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BluetoothPrinterSheet(service: service),
    );
  }
}

class _BluetoothPrinterSheet extends StatefulWidget {
  final BluetoothPrinterService service;
  const _BluetoothPrinterSheet({required this.service});

  @override
  State<_BluetoothPrinterSheet> createState() => _BluetoothPrinterSheetState();
}

class _BluetoothPrinterSheetState extends State<_BluetoothPrinterSheet> {
  List<BtcDevice> _devices = [];
  bool _isScanning = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isScanning = true);
    try {
      final devices = await widget.service.scanDevices();
      if (mounted) {
        setState(() => _devices = devices);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _connect(BtcDevice device) async {
    setState(() => _isConnecting = true);
    final ok = await widget.service.connect(device.address, name: device.displayName);
    if (mounted) {
      setState(() => _isConnecting = false);
      if (ok) {
        Navigator.pop(context, device.address);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terhubung ke ${device.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal terhubung ke printer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedAddr = widget.service.connectedAddress;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth, size: 24, color: Color(0xFF6C2FE2)),
                  const SizedBox(width: 8),
                  const Text(
                    'Printer Bluetooth',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (widget.service.isConnectedNotifier.value)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Text(
                        'Terhubung',
                        style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isScanning
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    onPressed: _isScanning ? null : _loadDevices,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Connected printer info
            if (widget.service.isConnectedNotifier.value && widget.service.connectedName != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.service.connectedName} (${widget.service.connectedAddress})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await widget.service.disconnect();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Putuskan', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Divider
            const Divider(),
            // Device list
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            _isScanning ? 'Memindai...' : 'Tidak ada perangkat ditemukan',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                          if (!_isScanning) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _loadDevices,
                              child: const Text('Cari Perangkat'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isConnected = device.address == connectedAddr;
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isConnected ? Colors.green.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.print,
                              color: isConnected ? Colors.green : Colors.grey.shade600,
                            ),
                          ),
                          title: Text(
                            device.displayName.isNotEmpty ? device.displayName : '(Tanpa Nama)',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            device.address,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                          trailing: isConnected
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Terhubung', style: TextStyle(fontSize: 12, color: Colors.green)),
                                )
                              : (_isConnecting
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : ElevatedButton(
                                      onPressed: () => _connect(device),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6C2FE2),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Hubungkan', style: TextStyle(fontSize: 12)),
                                    )),
                          onTap: isConnected ? null : () => _connect(device),
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