/// Configuration for the local Python vision server detector.
///
/// Phase 5.0 wire-up: this is a compile-time const. The user edits the URL
/// here to point at their PC on the LAN (typically
/// `http://192.168.x.x:8000` or `http://10.x.x.x:8000`). A runtime
/// settings screen lands in a later phase once the wire is proven useful.
///
/// The server itself never persists frames; see
/// [`tools/vision_server/README.md`](../../../../tools/vision_server/README.md).
class RemoteVisionConfig {
  const RemoteVisionConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 2),
    this.requestTimeout = const Duration(seconds: 3),
  });

  /// Base URL of the local vision server. **Edit this** to match your PC's
  /// LAN IP. Default is the loopback address, which only works when the
  /// app is running on the same machine as the server (e.g. desktop
  /// development). The Galaxy S25 must reach the PC over Wi-Fi using its
  /// LAN IP.
  final String baseUrl;

  /// Maximum time to wait for the TCP connect to complete.
  final Duration connectTimeout;

  /// Maximum time to wait for the full `/detect` round-trip.
  final Duration requestTimeout;

  /// The default URL the app loads with. **Replace** with your PC's LAN
  /// IP before testing on the S25 — `localhost` will only work in a
  /// host-machine emulator, not on a real phone.
  /// LAN IP for the development machine where the Python vision server
  /// runs. Captured 2026-06-01 for this dev PC; update if the LAN IP
  /// changes (`Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp`).
  /// A runtime settings screen will replace this hardcode in a later
  /// phase.
  static const RemoteVisionConfig defaults = RemoteVisionConfig(
    baseUrl: 'http://192.168.40.7:8000',
    // Bigger budget for the first real detection — CPU YOLO-World takes
    // ~1 s on a small image. Once the GPU path / quantized model lands
    // we can lower this again.
    requestTimeout: Duration(seconds: 6),
  );
}
