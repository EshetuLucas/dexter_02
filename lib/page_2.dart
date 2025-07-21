import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// Moved out of the class to be a true top-level function
int _heavyDatabaseComputation(int max) {
  int result = 0;
  for (int i = 0; i < max; i++) {
    result += i * i;
  }
  return result;
}

// Moved out of the class and optimized with StringBuffer for efficiency
int _heavyFileComputation(int max) {
  final buffer = StringBuffer();
  for (int i = 0; i < max; i++) {
    buffer.write('Processing block $i\n');
    if (buffer.length > 10000) {
      buffer.clear(); // More efficient than creating substrings
    }
  }
  return buffer.length;
}

// This function will run in a separate isolate for background sync
void _backgroundSyncWork(SendPort sendPort) {
  Timer.periodic(const Duration(milliseconds: 100), (timer) {
    // This heavy work is now off the main thread
    final List<List<int>> memoryConsumer = [];
    for (int i = 0; i < 100; i++) {
      memoryConsumer.add(List.generate(1000, (index) => Random().nextInt(1000)));
    }
    double result = 0;
    for (int i = 0; i < 10000; i++) {
      result += sin(i) * cos(i) * tan(i / 100);
    }
    // Send a message back to the main isolate to update the UI
    sendPort.send(1);
  });
}

class Page2 extends StatefulWidget {
  const Page2({super.key});

  @override
  State<Page2> createState() => _Page2State();
}

class _Page2State extends State<Page2> with TickerProviderStateMixin {
  final Stopwatch _operationTimer = Stopwatch();
  int _transactionCount = 0;
  String _status = 'System ready';

  final Map<String, dynamic> _transactionCache = {};
  final List<Timer> _activeTimers = [];
  final List<Future> _pendingOperations = [];

  bool _isProcessing = false;
  late AnimationController _progressController;
  late AnimationController _rotationController;

  bool _databaseLocked = false;
  bool _fileLocked = false;
  final List<Completer> _lockQueue = [];

  // For managing the background sync isolate
  Isolate? _syncIsolate;
  ReceivePort? _syncReceivePort;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(duration: const Duration(seconds: 10), vsync: this);
    _rotationController = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  Future<void> _performDataSync() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _status = 'Initializing...';
      _operationTimer.reset();
      _operationTimer.start();
    });

    _progressController.forward();

    _startDatabaseOperation();
    _startFileOperation();
    _startBackgroundSync();

    await Future.delayed(const Duration(milliseconds: 100));
    _createDeadlock();
  }

  void _startDatabaseOperation() async {
    _databaseLocked = true;
    setState(() {
      _status = 'Operation A in progress...';
    });
    // Use the top-level function
    int result = await compute(_heavyDatabaseComputation, 5000000);
    if (!mounted) return;
    _transactionCache['db_progress'] = result;
    setState(() {
      _status = 'Operation A complete';
      _databaseLocked = false;
    });
  }

  void _startFileOperation() async {
    _fileLocked = true;
    setState(() {
      _status = 'Operation B in progress...';
    });
    // Use the top-level function
    int fileSize = await compute(_heavyFileComputation, 100000);
    if (!mounted) return;
    _transactionCache['file_size'] = fileSize;
    setState(() {
      _status = 'Operation B complete';
      _fileLocked = false;
    });
  }

  void _startBackgroundSync() async {
    _syncReceivePort = ReceivePort();
    _syncIsolate = await Isolate.spawn(_backgroundSyncWork, _syncReceivePort!.sendPort);

    // Listen for messages from the isolate
    _syncReceivePort!.listen((message) {
      if (mounted) {
        setState(() {
          _transactionCount += message as int;
          _transactionCache['sync_count'] = _transactionCount;
        });
      }
    });
  }

  void _createDeadlock() async {
    // Simulate deadlock asynchronously with a timeout
    setState(() {
      _status = 'Simulating deadlock...';
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _status = 'Deadlock resolved (simulated)';
      _isProcessing = false;
    });
    _cleanup();
  }

  void _cleanup() {
    // Stop the background isolate
    _syncIsolate?.kill(priority: Isolate.immediate);
    _syncReceivePort?.close();
    _syncIsolate = null;
    _syncReceivePort = null;

    _databaseLocked = false;
    _fileLocked = false;
    _progressController.stop();
    _progressController.reset();
    _operationTimer.stop();
  }

  @override
  void dispose() {
    _cleanup();
    _progressController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenario 2'),
        actions: [
          RotationTransition(turns: _rotationController, child: const Icon(Icons.cloud_sync)),
          if (_operationTimer.isRunning)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '${_operationTimer.elapsed.inSeconds}s',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: AnimatedBuilder(
                              animation: _progressController,
                              builder: (context, child) {
                                return CircularProgressIndicator(
                                  value: _isProcessing ? _progressController.value : 0,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.grey[300],
                                );
                              },
                            ),
                          ),
                          Icon(
                            _isProcessing ? Icons.hourglass_empty : Icons.check_circle,
                            size: 48,
                            color: _isProcessing ? Colors.orange : Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(_status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _performDataSync,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
