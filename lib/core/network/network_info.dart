import 'dart:async';
import 'dart:io';

abstract class INetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoImpl implements INetworkInfo {
  final List<String> _hosts = ['google.com', 'cloudflare.com', '8.8.8.8'];

  @override
  Future<bool> get isConnected async {
    for (final host in _hosts) {
      try {
        final result = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return Stream.periodic(
      const Duration(seconds: 5),
    ).asyncMap((_) => isConnected).asBroadcastStream();
  }
}
