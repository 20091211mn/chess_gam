// The online layer talks to the app only through simple messages (maps).
abstract class Backend {
  bool get connected;
  void start(void Function(Map m) emit);
  void send(Map m);
  void stop();
}
