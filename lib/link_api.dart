// A tiny "device to device" link used for Bluetooth games.
abstract class LinkApi {
  bool get available;

  /// type: status | peer_found | peer_lost | connected | data | disconnected | error
  void Function(String type, Map data)? onEvent;

  Future<void> host(String myName);
  Future<void> search(String myName);
  Future<void> connect(String endpointId, String myName);
  void send(Map msg);
  Future<void> stop();
}
