// Device-to-device link using Google Nearby Connections (Bluetooth / Wi-Fi Direct).
// Most calls are made dynamically so small API differences between plugin versions
// cannot break the build; errors are reported to the screen instead.
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'link_api.dart';

LinkApi createLink() => NearbyLink();
bool linkSupported() => true;

class NearbyLink implements LinkApi {
  static const String _service = 'com.shatranj.chess_game.link';

  @override
  bool get available => true;
  @override
  void Function(String type, Map data)? onEvent;

  String? _peerId;
  String _peerName = '';
  bool _connected = false;

  void _ev(String t, Map d) => onEvent?.call(t, d);

  Future<void> _permissions() async {
    final dynamic n = Nearby();
    try {
      await n.askLocationPermission();
    } catch (_) {}
    try {
      await n.askBluetoothPermission();
    } catch (_) {}
    try {
      await n.askNearbyWifiDevicesPermission();
    } catch (_) {}
    try {
      await n.enableLocationServices();
    } catch (_) {}
  }

  void _accept(String id, dynamic info) {
    try {
      _peerName = (info.endpointName ?? '').toString();
    } catch (_) {}
    final dynamic n = Nearby();
    try {
      n.acceptConnection(
        id,
        onPayLoadRecieved: (dynamic eid, dynamic payload) => _onPayload(payload),
        onPayloadTransferUpdate: (dynamic eid, dynamic update) {},
      );
    } catch (e) {
      _ev('error', {'msg': 'تعذر قبول الاتصال: $e'});
    }
  }

  void _result(String id, dynamic status) {
    final s = status.toString().toUpperCase();
    if (s.contains('CONNECTED')) {
      _peerId = id;
      _connected = true;
      _ev('connected', {'id': id, 'name': _peerName});
    } else {
      _ev('error', {'msg': 'تم رفض الاتصال أو فشل ($s)'});
    }
  }

  void _lost() {
    final was = _connected;
    _connected = false;
    _peerId = null;
    if (was) _ev('disconnected', {});
  }

  void _onPayload(dynamic payload) {
    try {
      final dynamic bytes = payload.bytes;
      if (bytes == null) return;
      final text = utf8.decode(List<int>.from(bytes as List));
      final m = jsonDecode(text);
      if (m is Map) _ev('data', {'msg': m});
    } catch (_) {}
  }

  @override
  Future<void> host(String myName) async {
    await stop();
    await _permissions();
    final dynamic n = Nearby();
    try {
      final dynamic ok = await n.startAdvertising(
        myName,
        Strategy.P2P_POINT_TO_POINT,
        onConnectionInitiated: (dynamic id, dynamic info) =>
            _accept(id.toString(), info),
        onConnectionResult: (dynamic id, dynamic status) =>
            _result(id.toString(), status),
        onDisconnected: (dynamic id) => _lost(),
        serviceId: _service,
      );
      _ev('status', {
        'text': ok == true
            ? 'بانتظار صديقك... اجعل شاشتك مفتوحة والبلوتوث والموقع مفعّلين'
            : 'تعذر بدء الاستضافة. تأكد من البلوتوث والموقع والأذونات'
      });
    } catch (e) {
      _ev('error', {'msg': '$e'});
    }
  }

  @override
  Future<void> search(String myName) async {
    await stop();
    await _permissions();
    final dynamic n = Nearby();
    try {
      final dynamic ok = await n.startDiscovery(
        myName,
        Strategy.P2P_POINT_TO_POINT,
        onEndpointFound: (dynamic id, dynamic name, dynamic sid) {
          _ev('peer_found', {'id': id.toString(), 'name': name.toString()});
        },
        onEndpointLost: (dynamic id) {
          _ev('peer_lost', {'id': (id ?? '').toString()});
        },
        serviceId: _service,
      );
      _ev('status', {
        'text': ok == true
            ? 'جاري البحث عن أصدقاء قريبين...'
            : 'تعذر بدء البحث. تأكد من البلوتوث والموقع والأذونات'
      });
    } catch (e) {
      _ev('error', {'msg': '$e'});
    }
  }

  @override
  Future<void> connect(String endpointId, String myName) async {
    final dynamic n = Nearby();
    try {
      await n.requestConnection(
        myName,
        endpointId,
        onConnectionInitiated: (dynamic id, dynamic info) =>
            _accept(id.toString(), info),
        onConnectionResult: (dynamic id, dynamic status) =>
            _result(id.toString(), status),
        onDisconnected: (dynamic id) => _lost(),
      );
    } catch (e) {
      _ev('error', {'msg': '$e'});
    }
  }

  @override
  void send(Map msg) {
    final id = _peerId;
    if (!_connected || id == null) return;
    try {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(msg)));
      final dynamic n = Nearby();
      n.sendBytesPayload(id, bytes);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    final dynamic n = Nearby();
    try {
      await n.stopAdvertising();
    } catch (_) {}
    try {
      await n.stopDiscovery();
    } catch (_) {}
    try {
      await n.stopAllEndpoints();
    } catch (_) {}
    _connected = false;
    _peerId = null;
  }
}
