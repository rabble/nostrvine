// ABOUTME: Stub file for WebSocket when not on web platform
// ABOUTME: Provides empty implementations to avoid compilation errors

class WebSocket {
  WebSocket(String url) {
    throw UnsupportedError('WebSocket is only available on web platform');
  }
  
  static const int open = 1;
  
  void close() {}
  void send(String data) {}
  
  int get readyState => 0;
  
  Stream<dynamic> get onOpen => Stream.empty();
  Stream<dynamic> get onError => Stream.empty();
  Stream<dynamic> get onClose => Stream.empty();
  Stream<dynamic> get onMessage => Stream.empty();
}