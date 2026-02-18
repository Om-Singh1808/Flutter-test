import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/mic_button.dart';
import 'services/voice_service.dart';

const String mqttHost =
    '10.0.2.2'; // Android emulator -> host machine

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _loggedInFuture;

  @override
  void initState() {
    super.initState();
    _loggedInFuture = _isLoggedIn();
  }

  Future<bool> _isLoggedIn() async {
    final prefs =
        await SharedPreferences.getInstance();
    return prefs.getBool('loggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loggedInFuture,
      builder: (context, snapshot) {
        final ready =
            snapshot.connectionState ==
            ConnectionState.done;
        final loggedIn = snapshot.data ?? false;

        return MaterialApp(
          title: 'luxOT',
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFF5C542),
              secondary: Color(0xFFF5C542),
              surface: Color(0xFF111A2E),
              surfaceContainerHighest: Color(
                0xFF151F36,
              ),
              onSurface: Color(0xFFE9EDF7),
              onSurfaceVariant: Color(0xFFB9C2D3),
              error: Color(0xFFFF4D4D),
            ),
            scaffoldBackgroundColor: const Color(
              0xFF0B1020,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              scrolledUnderElevation: 0,
            ),
            cardTheme: const CardThemeData(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(
                  Radius.circular(20),
                ),
              ),
            ),
            navigationBarTheme:
                NavigationBarThemeData(
                  backgroundColor: const Color(
                    0xFF0B1020,
                  ),
                  indicatorColor: const Color(
                    0xFFF5C542,
                  ).withOpacity(0.16),
                  labelTextStyle:
                      WidgetStateProperty.all(
                        const TextStyle(
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                ),
            filledButtonTheme:
                FilledButtonThemeData(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFF5C542,
                    ),
                    foregroundColor: const Color(
                      0xFF0B1020,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 18,
                        ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                            16,
                          ),
                    ),
                  ),
                ),
            outlinedButtonTheme:
                OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF2A3553),
                    ),
                    foregroundColor: const Color(
                      0xFFE9EDF7,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 18,
                        ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                            16,
                          ),
                    ),
                  ),
                ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
            ),
            inputDecorationTheme:
                InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF2A3553),
                    ),
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                        borderSide:
                            const BorderSide(
                              color: Color(
                                0xFF2A3553,
                              ),
                            ),
                      ),
                  focusedBorder:
                      OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                              14,
                            ),
                        borderSide:
                            const BorderSide(
                              color: Color(
                                0xFFF5C542,
                              ),
                              width: 2,
                            ),
                      ),
                  filled: true,
                  fillColor: const Color(
                    0xFF111A2E,
                  ),
                  labelStyle: const TextStyle(
                    color: Color(0xFFB9C2D3),
                  ),
                ),
          ),
          home: ready
              ? (loggedIn
                    ? const HomePage()
                    : const LoginPage())
              : const _SplashPage(),
        );
      },
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}

/// Reusable StatusPill widget for compact status indicators
class StatusPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const StatusPill({
    super.key,
    required this.text,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color:
                  textColor ??
                  Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  textColor ??
                  Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable LuxCard wrapper for consistent card styling
class LuxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const LuxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Simple MQTT manager (singleton) for connecting and publishing messages.

class MQTTManager {
  MQTTManager._internal();
  static final MQTTManager _instance =
      MQTTManager._internal();
  factory MQTTManager() => _instance;

  late MqttServerClient client;
  final ValueNotifier<bool> connected =
      ValueNotifier<bool>(false);
  String? _lastServer;
  int? _lastPort;

  String? get lastServer => _lastServer;
  int? get lastPort => _lastPort;

  Future<void> connect({
    required String server,
    int port = 1883,
  }) async {
    _lastServer = server;
    _lastPort = port;

    final clientId =
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
    client = MqttServerClient.withPort(
      server,
      clientId,
      port,
    );
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;

    client.secure = false;

    client.connectionMessage =
        MqttConnectMessage()
            .withClientIdentifier(clientId)
            .startClean();

    try {
      await client.connect();
    } catch (e) {
      print('MQTT Connection Error: $e');
      client.disconnect();
      connected.value = false;
      return;
    }

    if (client.connectionStatus?.state ==
        MqttConnectionState.connected) {
      connected.value = true;
    } else {
      connected.value = false;
      print(
        'Connection failed: ${client.connectionStatus?.state}',
      );
      client.disconnect();
    }
  }

  void _onConnected() => connected.value = true;
  void _onDisconnected() =>
      connected.value = false;

  Future<bool> reconnectNow() async {
    if (_lastServer == null ||
        _lastPort == null) {
      return false;
    }
    try {
      await connect(
        server: _lastServer!,
        port: _lastPort!,
      ).timeout(const Duration(seconds: 5));
      return connected.value;
    } catch (e) {
      return false;
    }
  }

  void publish(
    String topic,
    Map<String, dynamic> payload,
  ) {
    if (!connected.value) return;
    final builder = MqttClientPayloadBuilder();
    final jsonString = jsonEncode(payload);
    builder.addString(jsonString);
    client.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  void disconnect() {
    try {
      client.disconnect();
    } catch (_) {}
    connected.value = false;
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() =>
      _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController =
      TextEditingController(text: 'admin');
  final TextEditingController _passController =
      TextEditingController(text: 'password');
  final TextEditingController _hostController =
      TextEditingController(text: mqttHost);
  final TextEditingController _portController =
      TextEditingController(text: '1883');

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedBroker();
  }

  Future<void> _loadSavedBroker() async {
    final prefs =
        await SharedPreferences.getInstance();
    final host = prefs.getString('mqttHost');
    final port = prefs.getInt('mqttPort');
    if (host != null && host.isNotEmpty) {
      _hostController.text = host;
    }
    if (port != null) {
      _portController.text = port.toString();
    }
  }

  void _tryLogin() async {
    final username = _userController.text.trim();
    final password = _passController.text;
    final host =
        _hostController.text.trim().isEmpty
        ? mqttHost
        : _hostController.text.trim();
    final port =
        int.tryParse(
          _portController.text.trim(),
        ) ??
        1883;

    if (username == 'admin' &&
        password == 'password') {
      setState(() => _loading = true);
      try {
        // Connect MQTT with 5 second timeout
        await MQTTManager()
            .connect(server: host, port: port)
            .timeout(const Duration(seconds: 5));
      } on TimeoutException {
        setState(() => _loading = false);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text(
                'Connection Timeout',
              ),
              content: const Text(
                'MQTT connection timed out. Make sure the broker is running.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      } catch (e) {
        setState(() => _loading = false);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text(
                'Connection Error',
              ),
              content: Text(
                'Connection error: $e',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      if (!mounted) return;
      setState(() => _loading = false);

      if (MQTTManager().connected.value) {
        final prefs =
            await SharedPreferences.getInstance();
        await prefs.setBool('loggedIn', true);
        await prefs.setString('mqttHost', host);
        await prefs.setInt('mqttPort', port);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomePage(),
          ),
        );
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text(
                  "Connection Status",
                ),
                content: const Text(
                  "Connection Failed",
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    child: const Text("ok"),
                  ),
                ],
              );
            },
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid username or password',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 450,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo/Icon Header
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0.0,
                        end: 1.0,
                      ),
                      duration: const Duration(
                        milliseconds: 800,
                      ),
                      curve: Curves.easeOutBack,
                      builder:
                          (
                            context,
                            value,
                            child,
                          ) {
                            return Transform.scale(
                              scale: value,
                              child: Opacity(
                                opacity: value
                                    .clamp(
                                      0.0,
                                      1.0,
                                    ),
                                child: child,
                              ),
                            );
                          },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.15),
                          borderRadius:
                              BorderRadius.circular(
                                24,
                              ),
                        ),
                        child: Icon(
                          Icons.lightbulb_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    Text(
                      'luxOT',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w900,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Smart Lighting Control',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontWeight:
                                FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 40),

                    // Username Field
                    TextField(
                      controller: _userController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(
                          Icons
                              .person_outline_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        hintText:
                            'Enter your username',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextField(
                      controller: _passController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(
                          Icons
                              .lock_outline_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary,
                        ),
                        hintText:
                            'Enter your password',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium,
                      obscureText: true,
                    ),
                    const SizedBox(height: 32),

                    // Expandable Broker Settings
                    Theme(
                      data: Theme.of(context)
                          .copyWith(
                            dividerColor: Colors
                                .transparent,
                          ),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Icon(
                              Icons
                                  .settings_input_antenna_rounded,
                              size: 20,
                              color:
                                  Theme.of(
                                        context,
                                      )
                                      .colorScheme
                                      .primary,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Text(
                              'Broker Settings',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                            ),
                          ],
                        ),
                        tilePadding:
                            EdgeInsets.zero,
                        childrenPadding:
                            const EdgeInsets.only(
                              top: 16,
                            ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller:
                                      _hostController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Host/IP',
                                    hintText:
                                        '192.168.1.10',
                                    prefixIcon: Icon(
                                      Icons
                                          .wifi_tethering_rounded,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(
                                width: 12,
                              ),
                              Expanded(
                                child: TextField(
                                  controller:
                                      _portController,
                                  keyboardType:
                                      TextInputType
                                          .number,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Port',
                                    hintText:
                                        '1883',
                                    prefixIcon: Icon(
                                      Icons
                                          .settings_ethernet_rounded,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _loading
                            ? null
                            : _tryLogin,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<
                                        Color
                                      >(
                                        Color(
                                          0xFF0B1020,
                                        ),
                                      ),
                                ),
                              )
                            : const Text(
                                'Sign In',
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Demo Credentials Info
                    Container(
                      padding:
                          const EdgeInsets.all(
                            12,
                          ),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withOpacity(0.5),
                        borderRadius:
                            BorderRadius.circular(
                              12,
                            ),
                        border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons
                                .info_outline_rounded,
                            size: 16,
                            color:
                                Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(
                                      0.7,
                                    ),
                          ),
                          const SizedBox(
                            width: 8,
                          ),
                          Text(
                            'Demo: admin / password',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      Theme.of(
                                            context,
                                          )
                                          .colorScheme
                                          .primary
                                          .withOpacity(
                                            0.7,
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
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Map<String, dynamic>> _lights = [
    {
      'id': '1',
      'name': 'Living Room',
      'room': 'Living',
      'type': 'light',
      'on': false,
    },
    {
      'id': '2',
      'name': 'Kitchen',
      'room': 'Kitchen',
      'type': 'light',
      'on': false,
    },
    {
      'id': '3',
      'name': 'Bedroom',
      'room': 'Bedroom',
      'type': 'light',
      'on': false,
    },
    {
      'id': '4',
      'name': 'Porch',
      'room': 'Outdoor',
      'type': 'light',
      'on': false,
    },
    {
      'id': '5',
      'name': 'Class',
      'room': 'Classroom',
      'type': 'light',
      'on': false,
    },
  ];
  late List<String> _roomsList = [
    'Living',
    'Kitchen',
    'Bedroom',
    'Outdoor',
    'Classroom',
  ];

  final mqtt = MQTTManager();
  bool _isReconnecting = false;
  int _currentTab = 0;

  // ─── Voice state ─────────────────────────────────────────────────────────
  String _recognizedText = '';
  Map<String, dynamic>? _lastVoiceJson;

  /// Called by MicButton when speech is recognized and formatted as JSON.
  void _onVoiceResult(Map<String, dynamic> json) {
    setState(() {
      _recognizedText = json['text'] as String? ?? '';
      _lastVoiceJson = json;
    });
    debugPrint('[Voice] JSON:\n${encodeVoiceCommandJson(json)}');
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _ensureConnection();
    mqtt.connected.addListener(
      _onConnectionChanged,
    );
  }

  Future<void> _loadData() async {
    final prefs =
        await SharedPreferences.getInstance();

    // Load rooms
    final roomsJson = prefs.getStringList(
      'rooms',
    );
    if (roomsJson != null &&
        roomsJson.isNotEmpty) {
      setState(() => _roomsList = roomsJson);
    } else {
      await prefs.setStringList(
        'rooms',
        _roomsList,
      );
    }

    // Load devices
    final devicesJson = prefs.getStringList(
      'devices',
    );
    if (devicesJson != null &&
        devicesJson.isNotEmpty) {
      final devices = devicesJson.map((json) {
        final parts = json.split('|');
        final type = parts.length >= 5
            ? parts[3]
            : 'light';
        final onIndex = parts.length >= 5 ? 4 : 3;
        return {
          'id': parts[0],
          'name': parts[1],
          'room': parts[2],
          'type': type,
          'on': parts[onIndex] == 'true',
        };
      }).toList();
      setState(() => _lights = devices);
    } else {
      await _saveDevices();
    }
  }

  Future<void> _saveDevices() async {
    final prefs =
        await SharedPreferences.getInstance();
    final devicesJson = _lights
        .map(
          (light) =>
              '${light['id']}|${light['name']}|${light['room']}|${light['type'] ?? 'light'}|${light['on']}',
        )
        .toList();
    await prefs.setStringList(
      'devices',
      devicesJson,
    );
  }

  Future<void> _saveRooms() async {
    final prefs =
        await SharedPreferences.getInstance();
    await prefs.setStringList(
      'rooms',
      _roomsList,
    );
  }

  List<String> get _rooms {
    // Return all rooms from the rooms list, not just rooms with devices
    return ['All', ..._roomsList];
  }

  Future<void> _ensureConnection() async {
    if (mqtt.connected.value) return;
    final prefs =
        await SharedPreferences.getInstance();
    final server =
        prefs.getString('mqttHost') ??
        mqtt.lastServer ??
        mqttHost;
    final port =
        prefs.getInt('mqttPort') ??
        mqtt.lastPort ??
        1883;
    await mqtt.connect(
      server: server,
      port: port,
    );
  }

  void _onConnectionChanged() => setState(() {});

  @override
  void dispose() {
    mqtt.connected.removeListener(
      _onConnectionChanged,
    );
    super.dispose();
  }

  void _toggleLight(int index, bool value) {
    setState(() => _lights[index]['on'] = value);
    final room = _lights[index]['room'];
    final id = _lights[index]['id'];
    final deviceType =
        _lights[index]['type'] ?? 'light';
    final topic = 'home';
    final payload = {
      'room': room,
      'device_type': deviceType,
      'device_id': id,
      'state': value ? 'ON' : 'OFF',
      'timestamp': DateTime.now()
          .toIso8601String(),
    };
    mqtt.publish(topic, payload);
    _saveDevices();
  }

  Future<void> _reconnect() async {
    if (!mounted) return;
    setState(() => _isReconnecting = true);
    final success = await mqtt.reconnectNow();
    if (!mounted) return;
    setState(() => _isReconnecting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reconnected to MQTT'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reconnection failed'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _disconnect() {
    mqtt.disconnect();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disconnected from MQTT'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    mqtt.disconnect();
    final prefs =
        await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() +
                    word
                        .substring(1)
                        .toLowerCase(),
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final connected = mqtt.connected.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'luxOT',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            color: Theme.of(
              context,
            ).colorScheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 16,
            ),
            child: Center(
              child: StatusPill(
                text: connected
                    ? 'Online'
                    : 'Offline',
                icon: connected
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                backgroundColor: connected
                    ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1)
                    : Theme.of(context)
                          .colorScheme
                          .error
                          .withOpacity(0.1),
                textColor: connected
                    ? Theme.of(
                        context,
                      ).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.error,
              ),
            ),
          ),
          if (!connected)
            Padding(
              padding: const EdgeInsets.only(
                right: 8,
              ),
              child: IconButton(
                icon: _isReconnecting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<
                                Color
                              >(
                                Color(0xFFFF6B6B),
                              ),
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        size: 24,
                      ),
                style: IconButton.styleFrom(
                  foregroundColor: const Color(
                    0xFFFF6B6B,
                  ),
                  backgroundColor: const Color(
                    0xFFFF6B6B,
                  ).withOpacity(0.1),
                  padding: const EdgeInsets.all(
                    8,
                  ),
                ),
                onPressed: _isReconnecting
                    ? null
                    : _reconnect,
              ),
            ),
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
            ),
            onPressed: _logout,
            style: IconButton.styleFrom(
              foregroundColor: const Color(
                0xFFFFD700,
              ),
            ),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor,
        child: AnimatedSwitcher(
          duration: const Duration(
            milliseconds: 350,
          ),
          switchInCurve: Curves.easeOutCirc,
          switchOutCurve: Curves.easeInCirc,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(
                        0.02,
                        0.02,
                      ),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCirc,
                      ),
                    ),
                child: child,
              ),
            );
          },
          child: _currentTab == 2
              ? _buildVoiceTab()
              : _currentTab == 0
              ? Column(
                  key: const ValueKey('rooms'),
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(
                        milliseconds: 250,
                      ),
                      child: !connected
                          ? Container(
                              key: const ValueKey(
                                'banner',
                              ),
                              width:
                                  double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal:
                                        16,
                                  ),
                              decoration: BoxDecoration(
                                color: Colors
                                    .orange[50],
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors
                                        .orange[200]!,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .warning_rounded,
                                    color: Colors
                                        .orange[700],
                                    size: 20,
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Disconnected from MQTT',
                                      style: TextStyle(
                                        color: Colors
                                            .orange[700],
                                        fontSize:
                                            14,
                                        fontWeight:
                                            FontWeight
                                                .w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: GridView.builder(
                        physics:
                            const BouncingScrollPhysics(
                              parent:
                                  AlwaysScrollableScrollPhysics(),
                            ),
                        padding:
                            const EdgeInsets.all(
                              16,
                            ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing:
                                  16,
                              childAspectRatio:
                                  0.85,
                            ),
                        itemCount:
                            _rooms.length - 1,
                        itemBuilder: (context, i) {
                          final roomName =
                              _rooms[i + 1];
                          final roomLights = _lights
                              .where(
                                (light) =>
                                    light['room'] ==
                                    roomName,
                              )
                              .toList();
                          final allOn = roomLights
                              .every(
                                (light) =>
                                    light['on'],
                              );

                          return Hero(
                            tag: 'room_$roomName',
                            child: Material(
                              color: Colors
                                  .transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => _RoomDetailPage(
                                            roomName:
                                                roomName,
                                            lights:
                                                roomLights,
                                            onToggleLight:
                                                _toggleLight,
                                            connected:
                                                connected,
                                          ),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            const begin = Offset(
                                              1.0,
                                              0.0,
                                            );
                                            const end =
                                                Offset.zero;
                                            const curve =
                                                Curves.easeOutCubic;
                                            var tween =
                                                Tween(
                                                  begin: begin,
                                                  end: end,
                                                ).chain(
                                                  CurveTween(
                                                    curve: curve,
                                                  ),
                                                );
                                            return SlideTransition(
                                              position: animation.drive(
                                                tween,
                                              ),
                                              child: FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              ),
                                            );
                                          },
                                      transitionDuration:
                                          const Duration(
                                            milliseconds:
                                                400,
                                          ),
                                    ),
                                  );
                                },
                                borderRadius:
                                    BorderRadius.circular(
                                      20,
                                    ),
                                child: Card(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  elevation: 0,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(
                                          16,
                                        ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        // Top row: Room name only
                                        Text(
                                          _toTitleCase(
                                            roomName,
                                          ),
                                          maxLines:
                                              1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(
                                          height:
                                              12,
                                        ),
                                        // Device count
                                        Text(
                                          '${roomLights.length} device${roomLights.length != 1 ? 's' : ''}',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(
                                          height:
                                              12,
                                        ),
                                        // Status pill center
                                        Center(
                                          child: StatusPill(
                                            text:
                                                roomLights.isEmpty
                                                ? 'No devices'
                                                : allOn
                                                ? 'All On'
                                                : 'Some Off',
                                            icon:
                                                roomLights.isEmpty
                                                ? Icons.devices_other
                                                : allOn
                                                ? Icons.lightbulb
                                                : Icons.lightbulb_outline,
                                            backgroundColor: Theme.of(
                                              context,
                                            ).colorScheme.surface.withOpacity(0.6),
                                            textColor:
                                                allOn
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const Spacer(),
                                        // Bottom: Master toggle
                                        if (connected)
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.power_settings_new_rounded,
                                                    size: 18,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onSurfaceVariant,
                                                  ),
                                                  const SizedBox(
                                                    width: 6,
                                                  ),
                                                  Text(
                                                    'Master',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelSmall,
                                                  ),
                                                ],
                                              ),
                                              Switch(
                                                value: allOn,
                                                onChanged: roomLights.isEmpty
                                                    ? null
                                                    : (
                                                        value,
                                                      ) {
                                                        for (final light in roomLights) {
                                                          _toggleLight(
                                                            int.parse(
                                                                  light['id'],
                                                                ) -
                                                                1,
                                                            value,
                                                          );
                                                        }
                                                      },
                                              ),
                                            ],
                                          )
                                        else
                                          Center(
                                            child: StatusPill(
                                              text:
                                                  'Offline',
                                              icon:
                                                  Icons.cloud_off,
                                              backgroundColor:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.error.withOpacity(
                                                    0.12,
                                                  ),
                                              textColor: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
              : ListView(
                  key: const ValueKey('settings'),
                  padding: const EdgeInsets.all(
                    16,
                  ),
                  physics:
                      const BouncingScrollPhysics(
                        parent:
                            AlwaysScrollableScrollPhysics(),
                      ),
                  children: [
                    _buildSettingCard(
                      icon: Icons.wifi_tethering,
                      title: 'Broker Host',
                      subtitle:
                          mqtt.lastServer ??
                          mqttHost,
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon:
                          Icons.settings_ethernet,
                      title: 'Broker Port',
                      subtitle:
                          '${mqtt.lastPort ?? 1883}',
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: connected
                          ? Icons.cloud_done
                          : Icons.cloud_off,
                      iconColor: connected
                          ? Colors.green
                          : Colors.red,
                      title: 'Connection Status',
                      subtitle: connected
                          ? 'Online'
                          : 'Offline',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isReconnecting
                            ? null
                            : _reconnect,
                        icon: _isReconnecting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<
                                        Color
                                      >(
                                        Color(
                                          0xFF0B1020,
                                        ),
                                      ),
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                              ),
                        label: const Text(
                          'Reconnect',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: connected
                            ? _disconnect
                            : null,
                        icon: const Icon(
                          Icons.cloud_off,
                        ),
                        label: const Text(
                          'Disconnect',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _showRoomManagement,
                        icon: const Icon(
                          Icons.home_work,
                        ),
                        label: const Text(
                          'Manage Rooms',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _showDeviceManagement,
                        icon: const Icon(
                          Icons.lightbulb,
                        ),
                        label: const Text(
                          'Manage Devices',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _logout,
                        icon: const Icon(
                          Icons.logout,
                        ),
                        label: const Text(
                          'Logout',
                        ),
                        style:
                            TextButton.styleFrom(
                              foregroundColor:
                                  Theme.of(
                                        context,
                                      )
                                      .colorScheme
                                      .error,
                            ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme:
              NavigationBarThemeData(
                backgroundColor: const Color(
                  0xFF1a1a1a,
                ),
                indicatorColor: const Color(
                  0xFFD4AF37,
                ).withOpacity(0.2),
                labelTextStyle:
                    WidgetStateProperty.all(
                      const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
              ),
        ),
        child: NavigationBar(
          selectedIndex: _currentTab,
          onDestinationSelected: (index) {
            setState(() => _currentTab = index);
          },
          labelBehavior:
              NavigationDestinationLabelBehavior
                  .alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(
                Icons.home_rounded,
                color: Color(0xFF666666),
              ),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: Color(0xFFFFD700),
              ),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.mic_none_rounded,
                color: Color(0xFF666666),
              ),
              selectedIcon: Icon(
                Icons.mic_rounded,
                color: Color(0xFFFFD700),
              ),
              label: 'Voice',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.settings,
                color: Color(0xFF666666),
              ),
              selectedIcon: Icon(
                Icons.settings,
                color: Color(0xFFFFD700),
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  // ─── Voice Tab ────────────────────────────────────────────────────────────

  Widget _buildVoiceTab() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = _recognizedText.isNotEmpty;

    return SingleChildScrollView(
      key: const ValueKey('voice'),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Text(
            'Voice Command',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Speak a command to control your devices',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),

          // ── Mic Button ──────────────────────────────────────────────────
          MicButton(onJsonResult: _onVoiceResult),
          const SizedBox(height: 40),

          // ── Recognized Text Card ────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: hasText
                ? LuxCard(
                    key: const ValueKey('voice_result'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.record_voice_over_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Recognized Text',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _recognizedText,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('voice_empty')),
          ),

          // ── JSON Preview Card ───────────────────────────────────────────
          if (_lastVoiceJson != null) ...[
            const SizedBox(height: 16),
            LuxCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.data_object_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'JSON Payload',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      StatusPill(
                        text: 'MQTT Ready',
                        icon: Icons.send_rounded,
                        backgroundColor:
                            colorScheme.primary.withOpacity(0.1),
                        textColor: colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1020),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF2A3553),
                      ),
                    ),
                    child: Text(
                      encodeVoiceCommandJson(_lastVoiceJson!),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF7EC8A4),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRoomManagement() {
    showDialog(
      context: context,
      builder: (context) => _RoomManagementDialog(
        rooms: _roomsList,
        onSave: (rooms) async {
          setState(() => _roomsList = rooms);
          await _saveRooms();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeviceManagement() {
    showDialog(
      context: context,
      builder: (context) =>
          _DeviceManagementDialog(
            devices: _lights,
            rooms: _roomsList,
            onSave: (devices) async {
              setState(() => _lights = devices);
              await _saveDevices();
              Navigator.pop(context);
            },
          ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 400),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest,
        child: ListTile(
          leading: Icon(
            icon,
            color:
                iconColor ??
                Theme.of(
                  context,
                ).colorScheme.primary,
          ),
          title: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }
}

class _RoomDetailPage extends StatefulWidget {
  final String roomName;
  final List<Map<String, dynamic>> lights;
  final Function(int, bool) onToggleLight;
  final bool connected;

  const _RoomDetailPage({
    required this.roomName,
    required this.lights,
    required this.onToggleLight,
    required this.connected,
  });

  @override
  State<_RoomDetailPage> createState() =>
      _RoomDetailPageState();
}

class _RoomDetailPageState
    extends State<_RoomDetailPage> {
  late List<Map<String, dynamic>> _roomLights;

  @override
  void initState() {
    super.initState();
    _roomLights = List.from(widget.lights);
  }

  void _toggleLight(int index, bool value) {
    setState(
      () => _roomLights[index]['on'] = value,
    );
    widget.onToggleLight(
      _findLightIndexInMain(
        _roomLights[index]['id'],
      ),
      value,
    );
  }

  int _findLightIndexInMain(String lightId) {
    // This is a helper to find the index in the original lights list
    // We'll pass the actual index from HomePage
    return int.parse(lightId) - 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              const LinearGradient(
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFD4AF37),
                ],
              ).createShader(bounds),
          child: Text(
            widget.roomName,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Theme.of(
                context,
              ).colorScheme.primary,
            ),
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(
            context,
          ).colorScheme.primary,
        ),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        itemCount: _roomLights.length,
        itemBuilder: (context, i) {
          final light = _roomLights[i];
          return Padding(
            padding: const EdgeInsets.only(
              bottom: 12,
            ),
            child: Card(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
              child: ListTile(
                title: Text(
                  light['name'],
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                ),
                subtitle: Text(
                  light['room'],
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
                leading: Icon(
                  (light['type'] ?? 'light') ==
                          'fan'
                      ? Icons.mode_fan_off
                      : (light['type'] ??
                                'light') ==
                            'buzzer'
                      ? (light['on']
                            ? Icons
                                  .notifications_active_rounded
                            : Icons
                                  .notifications_off_rounded)
                      : light['on']
                      ? Icons.lightbulb
                      : Icons.lightbulb_outline,
                  color: light['on']
                      ? Theme.of(
                          context,
                        ).colorScheme.primary
                      : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                ),
                trailing: Switch(
                  value: light['on'],
                  onChanged: widget.connected
                      ? (v) => _toggleLight(i, v)
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoomManagementDialog
    extends StatefulWidget {
  final List<String> rooms;
  final Function(List<String>) onSave;

  const _RoomManagementDialog({
    required this.rooms,
    required this.onSave,
  });

  @override
  State<_RoomManagementDialog> createState() =>
      _RoomManagementDialogState();
}

class _RoomManagementDialogState
    extends State<_RoomManagementDialog> {
  late List<String> _rooms;
  final _newRoomController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _rooms = List.from(widget.rooms);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Rooms'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _rooms.length,
                itemBuilder: (context, i) {
                  return ListTile(
                    title: Text(_rooms[i]),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        setState(
                          () =>
                              _rooms.removeAt(i),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newRoomController,
              decoration: InputDecoration(
                labelText: 'New Room Name',
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_newRoomController
                      .text
                      .isNotEmpty) {
                    setState(() {
                      _rooms.add(
                        _newRoomController.text,
                      );
                      _newRoomController.clear();
                    });
                  }
                },
                child: const Text('Add Room'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => widget.onSave(_rooms),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DeviceManagementDialog
    extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final List<String> rooms;
  final Function(List<Map<String, dynamic>>)
  onSave;

  const _DeviceManagementDialog({
    required this.devices,
    required this.rooms,
    required this.onSave,
  });

  @override
  State<_DeviceManagementDialog> createState() =>
      _DeviceManagementDialogState();
}

class _DeviceManagementDialogState
    extends State<_DeviceManagementDialog> {
  late List<Map<String, dynamic>> _devices;
  final _nameController = TextEditingController();
  final _numberController =
      TextEditingController();
  String? _selectedRoom;
  String _selectedType = 'light';

  @override
  void initState() {
    super.initState();
    _devices = List.from(widget.devices);
  }

  String _formatDeviceType(String type) {
    if (type.isEmpty) return 'Light';
    return type[0].toUpperCase() +
        type.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Devices'),
      content: SizedBox(
        width: double.maxFinite,
        height:
            MediaQuery.of(context).size.height *
            0.6,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  itemBuilder: (context, i) {
                    final device = _devices[i];
                    return ListTile(
                      title: Text(device['name']),
                      subtitle: Text(
                        '${device['room']} • ${_formatDeviceType(device['type'] ?? 'light')} (ID: ${device['id']})',
                      ),
                      leading: Icon(
                        (device['type'] ??
                                    'light') ==
                                'fan'
                            ? Icons.mode_fan_off
                            : (device['type'] ??
                                      'light') ==
                                  'buzzer'
                            ? Icons
                                  .notifications_active_rounded
                            : Icons.lightbulb,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(
                            () => _devices
                                .removeAt(i),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _numberController,
                decoration: InputDecoration(
                  labelText: 'Device ID',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
                keyboardType:
                    TextInputType.number,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedRoom,
                decoration: InputDecoration(
                  labelText: 'Room',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
                items: widget.rooms
                    .map(
                      (room) => DropdownMenuItem(
                        value: room,
                        child: Text(room),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(
                  () => _selectedRoom = value,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Device Type',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'light',
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: 'fan',
                    child: Text('Fan'),
                  ),
                  DropdownMenuItem(
                    value: 'buzzer',
                    child: Text('Buzzer'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(
                    () => _selectedType = value,
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selectedRoom != null &&
                          _nameController
                              .text
                              .isNotEmpty &&
                          _numberController
                              .text
                              .isNotEmpty
                      ? () {
                          _devices.add({
                            'id':
                                _numberController
                                    .text,
                            'name':
                                _nameController
                                    .text,
                            'room': _selectedRoom,
                            'type': _selectedType,
                            'on': false,
                          });
                          setState(() {
                            _nameController
                                .clear();
                            _numberController
                                .clear();
                            _selectedRoom = null;
                            _selectedType =
                                'light';
                          });
                        }
                      : null,
                  child: const Text('Add Device'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () =>
              widget.onSave(_devices),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
