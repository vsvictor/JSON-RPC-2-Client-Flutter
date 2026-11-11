import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_rpc_2_flutter/main.dart';
import 'package:jsonrpc_client_flutter/jsonrpc_client_flutter.dart';

void main() {
  testWidgets('explains certificate contents for TLS/TCP transport', (
    tester,
  ) async {
    await tester.pumpWidget(
      const JsonRpcDemoApp(availableTransports: [RpcTransport.tls]),
    );
    await tester.ensureVisible(find.text('Transport-specific options'));
    await tester.tap(find.text('Transport-specific options'));
    await tester.pumpAndSettle();
    expect(find.text('Trusted CA certificate (PEM)'), findsOneWidget);
    expect(
      find.text(
        'Paste the server public cert.pem contents below before connecting. '
        'Do not paste the file path or private key.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows connection and JSON-RPC controls', (tester) async {
    await tester.pumpWidget(
      const JsonRpcDemoApp(
        availableTransports: [RpcTransport.tcp, RpcTransport.wsHttp3],
      ),
    );

    expect(find.text('JSON-RPC 2 · Flutter client'), findsOneWidget);
    expect(find.text('Connection'), findsOneWidget);
    expect(find.text('JSON-RPC operations'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Notify'), findsOneWidget);
    expect(find.text('Transport ping'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('Liveness and request policy'), findsOneWidget);
    expect(find.text('Ping frequency (ms, 0 = off)'), findsOneWidget);
    expect(find.text('Max missed pongs'), findsOneWidget);
    expect(find.text('Request timeout (ms)'), findsOneWidget);
    expect(find.text('Apply settings'), findsOneWidget);
  });
}
