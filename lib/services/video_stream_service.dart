import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

typedef OnFrameCallback = void Function(Uint8List frameBytes);
typedef OnStreamLogCallback = void Function(String msg);

class VideoStreamService extends ChangeNotifier {
  HttpServer? _server;
  final List<HttpResponse> _connectedClients = [];
  StreamSubscription? _mjpegSubscription;
  HttpClient? _mjpegClient;

  Uint8List? _latestFrameBytes;
  bool _isStreamingServer = false;
  bool _isReceivingStream = false;
  String? _currentStreamSourceIp;
  Timer? _virtualFrameTimer;

  Uint8List? get latestFrameBytes => _latestFrameBytes;
  bool get isStreamingServer => _isStreamingServer;
  bool get isReceivingStream => _isReceivingStream;
  String? get currentStreamSourceIp => _currentStreamSourceIp;

  OnStreamLogCallback? onLogMessage;

  void _log(String msg) {
    debugPrint("[VideoStreamService] $msg");
    if (onLogMessage != null) {
      onLogMessage!(msg);
    }
  }

  /// Start Low-Latency MJPEG Stream Server on Slave Target (Port 8890)
  Future<bool> startStreamServer({int port = 8890}) async {
    if (_isStreamingServer) return true;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
      _isStreamingServer = true;
      _log("Low-latency video server listening on port $port");

      _server!.listen((HttpRequest request) {
        if (request.uri.path == '/live' || request.uri.path == '/') {
          _log("Master connected for video stream from ${request.connectionInfo?.remoteAddress.address}");
          request.response.headers.contentType = ContentType(
            'multipart',
            'x-mixed-replace',
            parameters: {'boundary': 'frame'},
          );
          request.response.headers.set('Cache-Control', 'no-cache, private');
          request.response.headers.set('Pragma', 'no-cache');

          _connectedClients.add(request.response);

          if (_latestFrameBytes != null) {
            try {
              request.response.write('--frame\r\n');
              request.response.write('Content-Type: image/jpeg\r\n');
              request.response.write('Content-Length: ${_latestFrameBytes!.length}\r\n\r\n');
              request.response.add(_latestFrameBytes!);
              request.response.write('\r\n');
            } catch (_) {}
          }

          request.response.done.then((_) {
            _connectedClients.remove(request.response);
            _log("Master video stream client disconnected.");
          }).catchError((e) {
            _connectedClients.remove(request.response);
          });
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        }
      });

      return true;
    } catch (e) {
      _log("Error starting video stream server: $e");
      _isStreamingServer = false;
      return false;
    }
  }

  /// Broadcast a JPEG image frame to connected Master clients
  void broadcastJpegFrame(Uint8List jpegBytes) {
    if (!_isStreamingServer || _connectedClients.isEmpty) return;

    _latestFrameBytes = jpegBytes;
    notifyListeners();

    List<HttpResponse> toRemove = [];
    for (var client in _connectedClients) {
      try {
        client.write('--frame\r\n');
        client.write('Content-Type: image/jpeg\r\n');
        client.write('Content-Length: ${jpegBytes.length}\r\n\r\n');
        client.add(jpegBytes);
        client.write('\r\n');
      } catch (e) {
        toRemove.add(client);
      }
    }

    for (var client in toRemove) {
      _connectedClients.remove(client);
    }
  }

  /// Standard valid 16x16 JPEG image frame bytes for testing stream
  static final Uint8List _validTestJpeg = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48,
    0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08,
    0x07, 0x07, 0x07, 0x09, 0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20,
    0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27,
    0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xDB, 0x00, 0x43, 0x01, 0x09, 0x09,
    0x09, 0x0C, 0x0B, 0x0C, 0x18, 0x0D, 0x0D, 0x18, 0x32, 0x21, 0x1C, 0x21, 0x32, 0x32, 0x32, 0x32,
    0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32,
    0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32,
    0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0x32, 0xFF, 0xC0,
    0x00, 0x11, 0x08, 0x00, 0x10, 0x00, 0x10, 0x03, 0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11,
    0x01, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
    0x0A, 0x0B, 0xFF, 0xC4, 0x00, 0xB5, 0x10, 0x00, 0x02, 0x01, 0x03, 0x03, 0x02, 0x04, 0x03, 0x05,
    0x05, 0x04, 0x04, 0x00, 0x00, 0x01, 0x7D, 0x01, 0x02, 0x03, 0x00, 0x04, 0x11, 0x05, 0x12, 0x21,
    0x31, 0x41, 0x06, 0x13, 0x51, 0x61, 0x07, 0x22, 0x71, 0x14, 0x32, 0x81, 0x91, 0xA1, 0x08, 0x23,
    0x42, 0xB1, 0xC1, 0x15, 0x52, 0xD1, 0xF0, 0x24, 0x33, 0x62, 0x72, 0x82, 0x09, 0x0A, 0x16, 0x17,
    0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A,
    0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A,
    0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A,
    0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99,
    0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7,
    0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5,
    0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF1,
    0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFF, 0xDA, 0x0C, 0x03, 0x01, 0x00, 0x02,
    0x11, 0x03, 0x11, 0x00, 0x3F, 0x00, 0xFA, 0x3A, 0x00, 0x3F, 0xFF, 0xD9
  ]);

  static Uint8List get validTestJpeg => _validTestJpeg;

  /// Start Virtual Low-Latency Stream Generator (for testing / fallback)
  void startVirtualFrameStream() {
    _virtualFrameTimer?.cancel();
    _virtualFrameTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      broadcastJpegFrame(_validTestJpeg);
    });
  }

  bool _isConnecting = false;

  /// Connect Master Receiver to 1st Slave's low-latency MJPEG stream (`http://<slaveIp>:8890/live`)
  Future<bool> connectToSlaveStream(String slaveIp, {int port = 8890}) async {
    if (_isReceivingStream && _currentStreamSourceIp == slaveIp) return true;
    if (_isConnecting && _currentStreamSourceIp == slaveIp) return false;

    _isConnecting = true;
    _currentStreamSourceIp = slaveIp;

    _log("Connecting to 1st Slave video stream at $slaveIp:$port...");

    try {
      _mjpegClient?.close(force: true);
      _mjpegClient = HttpClient();
      _mjpegClient!.connectionTimeout = const Duration(seconds: 3);

      Uri uri = Uri.parse("http://$slaveIp:$port/live");
      HttpClientRequest request = await _mjpegClient!.getUrl(uri);
      HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        _isReceivingStream = true;
        _log("Connected to 1st Slave stream successfully! Receiving frames...");

        List<int> buffer = [];
        _mjpegSubscription = response.listen(
          (List<int> chunk) {
            buffer.addAll(chunk);

            // Parse JPEG frames (0xFFD8 to 0xFFD9)
            int start = -1;
            int end = -1;

            for (int i = 0; i < buffer.length - 1; i++) {
              if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
                start = i;
              }
              if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9 && start != -1) {
                end = i + 2;
                break;
              }
            }

            if (start != -1 && end != -1 && end > start) {
              Uint8List frameData = Uint8List.fromList(buffer.sublist(start, end));
              _latestFrameBytes = frameData;
              buffer = buffer.sublist(end);
              notifyListeners();
            } else if (buffer.length > 500000) {
              // Clear buffer overflow if corrupted
              buffer.clear();
            }
          },
          onError: (error) {
            _log("Stream receiver error: $error");
            _isReceivingStream = false;
            notifyListeners();
          },
          onDone: () {
            _log("Stream connection closed by Slave server.");
            _isReceivingStream = false;
            notifyListeners();
          },
        );
        notifyListeners();
        return true;
      } else {
        _log("Slave returned HTTP status ${response.statusCode}");
        _isReceivingStream = false;
        return false;
      }
    } catch (e) {
      _log("Failed connecting to Slave video stream: $e");
      _isReceivingStream = false;
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// Stop receiving video stream on Master
  void stopStreamReceiver() {
    _mjpegSubscription?.cancel();
    _mjpegSubscription = null;
    _mjpegClient?.close(force: true);
    _mjpegClient = null;
    _isReceivingStream = false;
    _currentStreamSourceIp = null;
    _latestFrameBytes = null;
    notifyListeners();
  }

  /// Stop streaming server on Slave
  void stopStreamServer() {
    _virtualFrameTimer?.cancel();
    _virtualFrameTimer = null;
    for (var client in _connectedClients) {
      try {
        client.close();
      } catch (_) {}
    }
    _connectedClients.clear();
    _server?.close(force: true);
    _server = null;
    _isStreamingServer = false;
    _latestFrameBytes = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopStreamReceiver();
    stopStreamServer();
    super.dispose();
  }
}
