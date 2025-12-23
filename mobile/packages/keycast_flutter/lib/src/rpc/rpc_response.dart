// ABOUTME: Generic RPC response wrapper with error handling
// ABOUTME: Represents either a successful result or an error from Keycast RPC

class RpcResponse<T> {
  final T? result;
  final String? error;

  const RpcResponse({this.result, this.error});

  bool get isError => error != null;
  bool get isSuccess => result != null && error == null;

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
}
