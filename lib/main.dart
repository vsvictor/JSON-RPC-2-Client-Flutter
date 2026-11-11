import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jsonrpc_client_flutter/jsonrpc_client_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<RpcTransport> availableTransports = const [];
  String? startupError;
  try {
    availableTransports = await JsonRpc2Client.availableTransports();
  } catch (error) {
    startupError = error.toString();
  }
  runApp(
    JsonRpcDemoApp(
      availableTransports: availableTransports,
      startupError: startupError,
    ),
  );
}

class JsonRpcDemoApp extends StatelessWidget {
  const JsonRpcDemoApp({
    super.key,
    this.availableTransports,
    this.startupError,
  });

  final List<RpcTransport>? availableTransports;
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF6D9EFF);
    return MaterialApp(
      title: 'JSON-RPC 2 Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF111827),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          isDense: true,
        ),
      ),
      home: JsonRpcDemoScreen(
        availableTransports: availableTransports ?? supportedRpcTransports(),
        startupError: startupError,
      ),
    );
  }
}

class JsonRpcDemoScreen extends StatefulWidget {
  const JsonRpcDemoScreen({
    super.key,
    required this.availableTransports,
    this.startupError,
  });

  final List<RpcTransport> availableTransports;
  final String? startupError;

  @override
  State<JsonRpcDemoScreen> createState() => _JsonRpcDemoScreenState();
}

class _JsonRpcDemoScreenState extends State<JsonRpcDemoScreen> {
  final _hostController = TextEditingController(text: '127.0.0.1');
  final _portController = TextEditingController(text: '4000');
  final _caPemController = TextEditingController();
  final _serverNameController = TextEditingController();
  final _srtPassphraseController = TextEditingController();
  final _brokerUrlController = TextEditingController();
  final _brokerRouteController = TextEditingController();
  final _brokerCaPemController = TextEditingController();
  final _brokerOperationTimeoutController = TextEditingController();
  final _brokerResponseTimeoutController = TextEditingController();
  final _sendCoverageController = TextEditingController(text: '8');
  final _receiveCoverageController = TextEditingController(text: '8');
  final _methodController = TextEditingController(text: 'echo');
  final _paramsController = TextEditingController(
    text: '{"message":"Hello from Flutter"}',
  );
  final _pingFrequencyController = TextEditingController(text: '0');
  final _missedPongsController = TextEditingController(text: '3');
  final _requestTimeoutController = TextEditingController(text: '30000');
  final _events = <String>[];

  JsonRpc2Client? _client;
  RpcTransport _transport = RpcTransport.tcp;
  bool _busy = false;
  String? _error;
  String? _lastResult;

  bool get _connected => _client != null;

  @override
  void initState() {
    super.initState();
    if (widget.availableTransports.isNotEmpty) {
      _transport = widget.availableTransports.first;
    }
    if (widget.startupError != null) {
      _error = 'Rust client initialization failed: ${widget.startupError}';
      _record('Native client unavailable');
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _caPemController.dispose();
    _serverNameController.dispose();
    _srtPassphraseController.dispose();
    _brokerUrlController.dispose();
    _brokerRouteController.dispose();
    _brokerCaPemController.dispose();
    _brokerOperationTimeoutController.dispose();
    _brokerResponseTimeoutController.dispose();
    _sendCoverageController.dispose();
    _receiveCoverageController.dispose();
    _methodController.dispose();
    _paramsController.dispose();
    _pingFrequencyController.dispose();
    _missedPongsController.dispose();
    _requestTimeoutController.dispose();
    super.dispose();
  }

  Future<void> _perform(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      _record('$label succeeded');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
      _record('$label failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect() => _perform('Connect', () async {
    final port = int.tryParse(_portController.text.trim());
    if (port == null) throw const FormatException('Port must be an integer.');

    final builder = JsonRpc2ClientBuilder(
      RpcConnectOptions(
        transport: _transport,
        host: _hostController.text,
        port: port,
        serverName: _optionalText(_serverNameController),
        srtPassphrase: _optionalText(_srtPassphraseController),
        udpLiteSendCoverage: _optionalInt(_sendCoverageController),
        udpLiteReceiveCoverage: _optionalInt(_receiveCoverageController),
        brokerUrl: _optionalText(_brokerUrlController),
        brokerRoute: _optionalText(_brokerRouteController),
        brokerCaPem: _optionalText(_brokerCaPemController),
        brokerOperationTimeoutMs: _optionalInt(
          _brokerOperationTimeoutController,
        ),
        brokerResponseTimeoutMs: _optionalInt(_brokerResponseTimeoutController),
      ),
    );

    if (_transport.requiresTls) {
      final caPem = _optionalText(_caPemController);
      if (caPem != null) {
        await builder.setCaCertificatePem(caPem);
      }
    }

    final client = await builder.connect();
    if (!mounted) {
      await client.disconnect();
      return;
    }
    setState(() => _client = client);
    _record('Connected using ${_transport.label}');
  });

  Future<void> _disconnect() => _perform('Disconnect', () async {
    await _client!.disconnect();
    if (mounted) setState(() => _client = null);
  });

  Future<void> _call() => _perform('Call ${_methodController.text}', () async {
    final params = _decodeParams();
    final result = await _client!.call(_methodController.text, params: params);
    final encoded = const JsonEncoder.withIndent('  ').convert(result);
    if (mounted) setState(() => _lastResult = encoded);
    _record('Response: $encoded');
  });

  Future<void> _notify() =>
      _perform('Notify ${_methodController.text}', () async {
        await _client!.notify(_methodController.text, params: _decodeParams());
      });

  Future<void> _applyClientSettings() => _perform(
    'Update liveness settings',
    () async {
      final pingFrequency = _requiredInt(_pingFrequencyController);
      final missedPongs = _requiredInt(_missedPongsController);
      final requestTimeout = _requiredInt(_requestTimeoutController);
      if (pingFrequency < 0 || requestTimeout < 0) {
        throw const FormatException('Durations cannot be negative.');
      }
      await _client!.setPingFrequency(Duration(milliseconds: pingFrequency));
      await _client!.setMaxMissedPongs(missedPongs);
      await _client!.setRequestTimeout(Duration(milliseconds: requestTimeout));
    },
  );

  Object? _decodeParams() {
    final raw = _paramsController.text.trim();
    if (raw.isEmpty) return null;
    final value = jsonDecode(raw);
    if (value is! Map && value is! List) {
      throw const FormatException(
        'JSON-RPC params must be a JSON object or array.',
      );
    }
    return value;
  }

  void _record(String message) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, '${TimeOfDay.now().format(context)}  $message');
      if (_events.length > 30) _events.removeLast();
    });
  }

  int _requiredInt(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null) throw const FormatException('Enter a valid integer.');
    return value;
  }

  int? _optionalInt(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return null;
    final parsed = int.tryParse(value);
    if (parsed == null) {
      throw const FormatException(
        'Optional transport values must be integers.',
      );
    }
    return parsed;
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('JSON-RPC 2 · Flutter client'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Chip(
              avatar: Icon(
                _connected ? Icons.circle : Icons.circle_outlined,
                size: 13,
                color: _connected ? Colors.greenAccent : Colors.white54,
              ),
              label: Text(_connected ? 'CONNECTED' : 'DISCONNECTED'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                Text(
                  'A native Flutter bridge to the Rust JSON-RPC 2.0 client.',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.availableTransports.length} transports available on this build',
                  style: theme.textTheme.bodySmall,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Connection',
                  icon: Icons.hub_outlined,
                  child: _buildConnectionForm(),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'JSON-RPC operations',
                  icon: Icons.swap_horiz,
                  child: _buildOperations(),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Liveness and request policy',
                  icon: Icons.monitor_heart_outlined,
                  child: _buildClientSettings(),
                ),
                const SizedBox(height: 16),
                if (_lastResult != null) ...[
                  _SectionCard(
                    title: 'Last result',
                    icon: Icons.data_object,
                    child: SelectableText(
                      _lastResult!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _SectionCard(
                  title: 'Activity',
                  icon: Icons.receipt_long_outlined,
                  trailing: TextButton(
                    onPressed: () => setState(_events.clear),
                    child: const Text('Clear'),
                  ),
                  child: _events.isEmpty
                      ? const Text(
                          'Connect and run an operation to see activity.',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final event in _events)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: SelectableText(
                                  event,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionForm() {
    final canConnect =
        !_connected && !_busy && widget.availableTransports.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<RpcTransport>(
          initialValue: _transport,
          decoration: const InputDecoration(labelText: 'Transport'),
          items: [
            for (final transport in RpcTransport.values)
              DropdownMenuItem(
                value: transport,
                enabled: widget.availableTransports.contains(transport),
                child: Text(
                  '${transport.label}${widget.availableTransports.contains(transport) ? '' : '  · unavailable'}',
                ),
              ),
          ],
          onChanged: _connected || _busy
              ? null
              : (value) {
                  if (value != null &&
                      widget.availableTransports.contains(value)) {
                    setState(() => _transport = value);
                  }
                },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _textField(
                _hostController,
                label: 'Host',
                hint: '127.0.0.1',
                disabledWhenConnected: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _textField(
                _portController,
                label: 'Port',
                keyboardType: TextInputType.number,
                disabledWhenConnected: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Transport-specific options'),
          subtitle: const Text('TLS, SRT, brokers, UDP-Lite'),
          children: [
            if (_transport.requiresTls) ...[
              const Text(
                'Paste the server public cert.pem contents below before connecting. '
                'Do not paste the file path or private key.',
              ),
              const SizedBox(height: 10),
              _textField(
                _caPemController,
                label: 'Trusted CA certificate (PEM)',
                maxLines: 5,
                disabledWhenConnected: true,
              ),
              const SizedBox(height: 10),
              _textField(
                _serverNameController,
                label: 'TLS server name (optional)',
                disabledWhenConnected: true,
              ),
              const SizedBox(height: 10),
            ],
            if (_transport.requiresSrtPassphrase) ...[
              _textField(
                _srtPassphraseController,
                label: 'SRT passphrase (10–79 bytes)',
                obscureText: true,
                disabledWhenConnected: true,
              ),
              const SizedBox(height: 10),
            ],
            if (_transport.usesBroker) ...[
              _textField(
                _brokerUrlController,
                label: 'Broker URL (optional)',
                disabledWhenConnected: true,
                hint: 'mqtt://user:password@broker:1883',
              ),
              const SizedBox(height: 10),
              _textField(
                _brokerRouteController,
                label:
                    _transport == RpcTransport.amqp ||
                        _transport == RpcTransport.wsAmqp
                    ? 'Request queue (optional)'
                    : 'Request topic (optional)',
                disabledWhenConnected: true,
              ),
              const SizedBox(height: 10),
              if (_transport == RpcTransport.mqtt ||
                  _transport == RpcTransport.wsMqtt) ...[
                _textField(
                  _brokerCaPemController,
                  label: 'Broker CA certificate (PEM, optional)',
                  maxLines: 4,
                  disabledWhenConnected: true,
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      _brokerOperationTimeoutController,
                      label: 'Broker operation timeout (ms)',
                      keyboardType: TextInputType.number,
                      disabledWhenConnected: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      _brokerResponseTimeoutController,
                      label: 'Broker response timeout (ms)',
                      keyboardType: TextInputType.number,
                      disabledWhenConnected: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (_transport.supportsUdpLiteCoverage) ...[
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      _sendCoverageController,
                      label: 'UDP-Lite send coverage',
                      keyboardType: TextInputType.number,
                      disabledWhenConnected: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      _receiveCoverageController,
                      label: 'UDP-Lite receive coverage',
                      keyboardType: TextInputType.number,
                      disabledWhenConnected: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: canConnect ? _connect : null,
              icon: _busy && !_connected
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: const Text('Connect'),
            ),
            OutlinedButton.icon(
              onPressed: _connected && !_busy ? _disconnect : null,
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect'),
            ),
          ],
        ),
        if (widget.availableTransports.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'No native transports are available for this build.',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
      ],
    );
  }

  Widget _buildOperations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textField(_methodController, label: 'Method name'),
        const SizedBox(height: 12),
        _textField(
          _paramsController,
          label: 'Params (JSON object or array)',
          maxLines: 5,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _connected && !_busy ? _call : null,
              icon: const Icon(Icons.call_made),
              label: const Text('Call'),
            ),
            OutlinedButton.icon(
              onPressed: _connected && !_busy ? _notify : null,
              icon: const Icon(Icons.notifications_none),
              label: const Text('Notify'),
            ),
            OutlinedButton.icon(
              onPressed: _connected && !_busy
                  ? () => _perform('Transport ping', _client!.transportPing)
                  : null,
              icon: const Icon(Icons.network_ping),
              label: const Text('Transport ping'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClientSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _textField(
                _pingFrequencyController,
                label: 'Ping frequency (ms, 0 = off)',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _textField(
                _missedPongsController,
                label: 'Max missed pongs',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _textField(
          _requestTimeoutController,
          label: 'Request timeout (ms)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _connected && !_busy ? _applyClientSettings : null,
            icon: const Icon(Icons.tune),
            label: const Text('Apply settings'),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Missed-pong recovery and request timeouts are handled by the Rust client.',
          style: TextStyle(color: Colors.white60),
        ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller, {
    required String label,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    bool disabledWhenConnected = false,
  }) {
    return TextField(
      controller: controller,
      enabled: !_busy && (!disabledWhenConnected || !_connected),
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
