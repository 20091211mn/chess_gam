import 'backend_api.dart';

// Used by builds that have no online backend.
class NoBackend implements Backend {
  void Function(Map m)? _emit;
  @override
  bool get connected => false;
  @override
  void start(void Function(Map m) emit) {
    _emit = emit;
  }

  @override
  void send(Map m) {
    _emit?.call({'t': 'unavailable', 'msg': 'اللعب الأونلاين غير مفعّل في هذه النسخة'});
  }

  @override
  void stop() {}
}

Backend createBackend() => NoBackend();
