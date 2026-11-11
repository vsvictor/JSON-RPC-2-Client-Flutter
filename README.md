# JSON-RPC 2 Flutter demo

This Flutter app demonstrates [`jsonrpc_client_flutter`](../JsonRPCClient-Flutter),
a separate Dart package that calls the Rust client's UniFFI layer through
`flutter_rust_bridge`.

## Run

The standalone client library lives in the sibling directory
`../JsonRPCClient-Flutter` and is referenced by the app's `pubspec.yaml`.

```sh
flutter pub get
flutter run -d linux
```

The same app can run on Android, iOS, macOS and Windows with the corresponding
Flutter toolchain installed. Web is not supported because the Rust client uses
native networking transports.

Enter a reachable JSON-RPC server's host and transport-specific port, then
connect. The demo exposes all transports built into the native client, calls,
notifications, transport ping, request timeout, and periodic liveness pings
with a missed-pong threshold. TLS/QUIC, SRT, MQTT/AMQP, and UDP-Lite options
are shown when relevant. The Flutter demo repository does not modify or join
the upstream Rust workspace.

For TLS transports, expand **Transport-specific options** and paste the
contents of the server's public `cert.pem` into **Trusted CA certificate
(PEM)** before connecting. A file path is not sufficient. Never copy `key.pem`
to the client. The demo uses
`JsonRpc2ClientBuilder.setCaCertificatePem()` before connecting.

Transport availability depends on the target OS and native build features:
DCCP, SCTP and UDP-Lite are Linux/Android only. SRT and WebSocket SRT are enabled
by default through the upstream Rust client's native dependencies.
SRT and WebSocket SRT remain encrypted by the upstream
`tstrans-srt-sys`/mbedTLS-backed implementation.
The Rust client is pinned to a GitHub revision rather than a local checkout.
See the package README for
build prerequisites and the update procedure. When running on Android, use the
server's LAN address rather than
`127.0.0.1` unless the server is running on the Android device itself.
