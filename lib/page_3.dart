import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<bool> _validateFileIntegrityIsolate(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return false;

    final stat = await file.stat();
    if (stat.size > 100 * 1024 * 1024) {
      return false;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return true;

    int checksum = 0;
    for (int i = 0; i < bytes.length; i += 1024) {
      checksum ^= bytes[i];
    }

    return checksum != 0;
  } catch (e) {
    debugPrint('_validateFileIntegrityIsolate error: $e');
    return false;
  }
}

String _generateFileSignatureIsolate(Map<String, dynamic> params) {
  final String filePath = params['filePath'];
  final Uint8List? fileBytes = params['fileBytes'];
  final List<int> hashComponents = [];

  int pathSignature = 0;
  final pathSegments = filePath.split(Platform.pathSeparator);

  for (int i = 0; i < 20000; i++) {
    final segment = pathSegments[i % pathSegments.length];

    for (int j = 0; j < segment.length; j++) {
      pathSignature += segment.codeUnitAt(j) * (i + 1) * (j + 1);
      pathSignature ^= (pathSignature << 5) | (pathSignature >> 27);
    }

    if (i % 1000 == 0) {
      hashComponents.add(pathSignature);
      if (hashComponents.length > 10) {
        int accumulated = 0;
        for (var component in hashComponents) {
          accumulated = (accumulated ^ component * 31) & 0xFFFFFFFF;
        }
        hashComponents.clear();
        hashComponents.add(accumulated);
      }
    }
  }

  if (fileBytes != null && fileBytes.isNotEmpty) {
    int contentSignature = 0;
    final sampleSize = min(fileBytes.length, 10000);

    for (int i = 0; i < sampleSize; i++) {
      contentSignature ^= fileBytes[i] << (i % 8);
      contentSignature = (contentSignature * 37) & 0xFFFFFFFF;
    }

    pathSignature ^= contentSignature;
  }

  return '0x${pathSignature.toRadixString(16).toUpperCase().padLeft(8, '0')}';
}

class Page3 extends StatefulWidget {
  const Page3({super.key});

  @override
  State<Page3> createState() => _Page3State();
}

class _Page3State extends State<Page3> with SingleTickerProviderStateMixin {
  String _status = 'Ready';
  double _progress = 0.0;

  String? _fileName;
  int? _fileSize;
  String? _fileHash;

  final Stopwatch _importTimer = Stopwatch();

  late AnimationController _animationController;
  final List<int> _hashComponents = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(seconds: 1), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _importFile() async {
    setState(() {
      _status = 'Starting...';
      _progress = 0.0;
      _fileHash = null;
      _fileName = null;
      _fileSize = null;
      _importTimer.reset();
      _importTimer.start();
    });

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false, withData: true);

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        if (pickedFile.path == null) {
          setState(() {
            _status = 'Error: No path';
          });
          return;
        }

        setState(() {
          _status = 'Validating...';
          _fileName = pickedFile.name;
          _fileSize = pickedFile.size;
          _progress = 0.1;
        });

        final isValid = await compute(_validateFileIntegrityIsolate, pickedFile.path!);
        if (!isValid) {
          setState(() {
            _status = 'Validation failed';
            _importTimer.stop();
          });
          return;
        }

        setState(() {
          _status = 'Generating signature...';
          _progress = 0.2;
        });

        final signature = await compute(_generateFileSignatureIsolate, {
          'filePath': pickedFile.path!,
          'fileBytes': pickedFile.bytes,
        });
        _fileHash = signature;

        setState(() {
          _status = 'Analyzing...';
          _progress = 0.5;
        });

        await _performSecurityAnalysis(pickedFile.bytes ?? Uint8List(0));

        setState(() {
          _status = 'Storing...';
          _progress = 0.8;
        });

        final appDir = await getApplicationDocumentsDirectory();
        final secureDir = Directory(p.join(appDir.path, 'imports', _fileHash!));

        if (!await secureDir.exists()) {
          await secureDir.create(recursive: true);
        }

        final metadataContent = _generateMetadata();
        final metadataFile = File(p.join(secureDir.path, 'metadata.json'));
        await metadataFile.writeAsString(metadataContent);

        setState(() {
          _status = 'Completed';
          _progress = 1.0;
        });

        _importTimer.stop();
      } else {
        setState(() {
          _status = 'Cancelled';
          _progress = 0.0;
        });
      }
    } catch (e, s) {
      debugPrint('File import failed: $e\n$s');
      setState(() {
        _status = 'Failed: $e';
        _progress = 0.0;
        _importTimer.stop();
      });
    }
  }

  Future<void> _performSecurityAnalysis(Uint8List bytes) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  String _generateMetadata() {
    Map<String, dynamic> metadata = {
      "originalName": _fileName,
      "size": _fileSize,
      "signature": _fileHash,
      "imported": DateTime.now().toIso8601String(),
    };

    List<String> properties = [];
    final buffer = StringBuffer();
    for (int i = 0; i < 1000; i++) {
      buffer.clear();
      for (int j = 0; j < 10; j++) {
        buffer.write((i * j).toRadixString(16));
      }
      properties.add(buffer.toString());
    }

    metadata['properties'] = properties.take(100).toList();
    metadata['checksum'] = properties.map((p) => p.hashCode).reduce((a, b) => a ^ b);

    return jsonEncode(metadata);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scenario 3'),
        actions: [
          RotationTransition(
            turns: _animationController,
            child: Icon(
              _importTimer.isRunning ? Icons.security : Icons.shield,
              color: _importTimer.isRunning ? Colors.orange : null,
            ),
          ),
          if (_importTimer.isRunning)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text('${_importTimer.elapsed.inSeconds}s', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 24),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[300],
                    ),
                  ),
                  Icon(
                    _progress == 1.0 ? Icons.check_circle : Icons.folder_open,
                    size: 48,
                    color: _progress == 1.0 ? Colors.green : Colors.blue,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(_status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _importTimer.isRunning ? null : _importFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Select File'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
