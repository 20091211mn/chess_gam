import 'link_api.dart';

// Used by builds without the Nearby plugin.
LinkApi createLink() => NoLink();
bool linkSupported() => false;

class NoLink implements LinkApi {
  @override
  bool get available => false;
  @override
  void Function(String type, Map data)? onEvent;

  @override
  Future<void> host(String myName) async {
    onEvent?.call('error', {'msg': 'البلوتوث غير مفعّل في هذه النسخة'});
  }

  @override
  Future<void> search(String myName) async {
    onEvent?.call('error', {'msg': 'البلوتوث غير مفعّل في هذه النسخة'});
  }

  @override
  Future<void> connect(String endpointId, String myName) async {}
  @override
  void send(Map msg) {}
  @override
  Future<void> stop() async {}
}
