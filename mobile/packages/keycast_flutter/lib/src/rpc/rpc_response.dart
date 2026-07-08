// ABOUTME: Generic RPC response wrapper with error handling
// ABOUTME: Represents either a successful result or an error from Keycast RPC

class RpcResponse<T> {
  const RpcResponse({this.result, this.error});

  factory RpcResponse.success(T result) => RpcResponse(result: result);
  factory RpcResponse.failure(String error) => RpcResponse(error: error);

  factory RpcResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromResult,
  ) {
    if (json.containsKey('error') && json['error'] != null) {
      return RpcResponse.failure(json['error'].toString());
    }
    if (json.containsKey('result')) {
      return RpcResponse.success(fromResult(json['result']));
    }
    return RpcResponse.failure('Invalid RPC response');
  }
  final T? result;
  final String? error;

  bool get isError => error != null;
  bool get isSuccess => result != null && error == null;
}
