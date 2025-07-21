import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class PreferencesManager extends ValueNotifier<String> {
  PreferencesManager() : super('Ready');

  Timer? _syncTimer;
  final Map<String, dynamic> _cache = {};
  bool _isSyncing = false;
  Completer<void>? _syncCompleter;

  Future<void> syncPreferences() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncCompleter = Completer<void>();
    value = 'Syncing...';

    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Periodic work
    });

    final result = await compute(_downloadConfiguration, {
      'endpoint': 'https://speed.hetzner.de/10MB.bin',
      'userId': 'user_${DateTime.now().millisecondsSinceEpoch}',
    });

    await Future.delayed(const Duration(milliseconds: 500));

    _syncTimer?.cancel();
    value = result;
    _isSyncing = false;
    _syncCompleter?.complete();
  }

  void applyPreferences() {
    // The original while loop was a busy-wait that blocked the UI thread.
    // It has been replaced with a non-blocking await on the completer's future.
    _syncCompleter?.future.then((_) {
      _cache['lastApply'] = DateTime.now().toIso8601String();
      _cache['version'] = '2.0.1';

      // The logic to check for success has been corrected to look for 'Data loaded'
      // instead of the incorrect 'Configuration loaded'.
      if (value.startsWith('Data loaded')) {
        value = 'Applied successfully';
      } else {
        value = 'Failed to apply preferences: $value';
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

Future<String> _downloadConfiguration(Map<String, String> params) async {
  final endpoint = Uri.parse(params['endpoint']!);
  final userId = params['userId']!;

  try {
    final response = await http.get(
      endpoint,
      headers: {'X-User-ID': userId, 'X-App-Version': '2.0.1', 'X-Platform': defaultTargetPlatform.toString()},
    );

    if (response.statusCode == 200) {
      final data = response.bodyBytes;
      int checksum = 0;

      for (int i = 0; i < data.length; i++) {
        checksum = (checksum + data[i]) & 0xFFFFFFFF;

        if (i % 100 == 0) {
          int temp = checksum;
          for (int j = 0; j < 10; j++) {
            temp = (temp * 31 + j) & 0xFFFFFFFF;
          }
          checksum ^= temp;
        }

        if (i % 1000 == 0) {
          await Future.delayed(Duration.zero);
        }
      }

      return 'Data loaded: ${data.length} bytes';
    } else {
      return 'Network error: ${response.statusCode}';
    }
  } catch (e) {
    return 'Connection failed';
  }
}

class Page1 extends StatefulWidget {
  const Page1({super.key});

  @override
  State<Page1> createState() => _Page1State();
}

class _Page1State extends State<Page1> with SingleTickerProviderStateMixin {
  final PreferencesManager _manager = PreferencesManager();
  bool _isProcessing = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  void _updateSettings() async {
    setState(() => _isProcessing = true);

    await _manager.syncPreferences();

    if (mounted) {
      _manager.applyPreferences();
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenario 1'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _isProcessing ? null : _updateSettings),
          RotationTransition(turns: _animationController, child: const Icon(Icons.settings)),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withOpacity(0.2),
                      border: Border.all(color: Colors.blue, width: 3),
                    ),
                    child: Transform.rotate(
                      angle: _animationController.value * 2 * 3.14159,
                      child: const Icon(Icons.sync, size: 50, color: Colors.blue),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isProcessing ? Colors.orange.shade100 : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ValueListenableBuilder<String>(
                  valueListenable: _manager,
                  builder: (context, value, child) {
                    return Text(
                      'Status: $value',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _updateSettings,
                icon: _isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync),
                label: Text(_isProcessing ? 'Processing...' : 'Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
