import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

const String mqttHost = '10.0.2.2'; // Android emulator -> host machine

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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('loggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loggedInFuture,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;
        final loggedIn = snapshot.data ?? false;

        return MaterialApp(
          title: 'luxOT',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF6F7FB),
            appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
            cardTheme: const CardThemeData(
              elevation: 3,
              shadowColor: Color(0x1A000000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: Colors.white,
              selectedColor: Colors.indigo.shade100,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              secondaryLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF4338CA),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 32,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          home: ready
              ? (loggedIn ? const HomePage() : const LoginPage())
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
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}

/// Simple MQTT manager (singleton) for connecting and publishing messages.

class MQTTManager {
  MQTTManager._internal();
  static final MQTTManager _instance = MQTTManager._internal();
  factory MQTTManager() => _instance;

  late MqttServerClient client;
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  String? _lastServer;
  int? _lastPort;

  String? get lastServer => _lastServer;
  int? get lastPort => _lastPort;

  Future<void> connect({required String server, int port = 1883}) async {
    _lastServer = server;
    _lastPort = port;

    final clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
    client = MqttServerClient.withPort(server, clientId, port);
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;

    client.secure = false;

    client.connectionMessage = MqttConnectMessage()
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

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      connected.value = true;
    } else {
      connected.value = false;
      print('Connection failed: ${client.connectionStatus?.state}');
      client.disconnect();
    }
  }

  void _onConnected() => connected.value = true;
  void _onDisconnected() => connected.value = false;

  Future<bool> reconnectNow() async {
    if (_lastServer == null || _lastPort == null) return false;
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

  void publish(String topic, String payload) {
    if (!connected.value) return;
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
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
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController(
    text: 'admin',
  );
  final TextEditingController _passController = TextEditingController(
    text: 'password',
  );
  final TextEditingController _hostController = TextEditingController(
    text: mqttHost,
  );
  final TextEditingController _portController = TextEditingController(
    text: '1883',
  );

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedBroker();
  }

  Future<void> _loadSavedBroker() async {
    final prefs = await SharedPreferences.getInstance();
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
    final host = _hostController.text.trim().isEmpty
        ? mqttHost
        : _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 1883;

    if (username == 'admin' && password == 'password') {
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
              title: const Text('Connection Timeout'),
              content: const Text(
                'MQTT connection timed out. Make sure the broker is running.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
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
              title: const Text('Connection Error'),
              content: Text('Connection error: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('loggedIn', true);
        await prefs.setString('mqttHost', host);
        await prefs.setInt('mqttPort', port);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text("Connection Status"),
                content: const Text("Connection Failed"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
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
        const SnackBar(content: Text('Invalid username or password')),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1a1a1a),
              const Color(0xFF0a0a0a),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Card(
                    elevation: 32,
                    color: const Color(0xFF1a1a1a),
                    shadowColor: const Color(0xFFD4AF37).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                      side: const BorderSide(
                        color: Color(0xFFD4AF37),
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutBack,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Opacity(
                                  opacity: value.clamp(0.0, 1.0),
                                  child: child,
                                ),
                              );
                            },
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFD4AF37),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withOpacity(0.6),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                    spreadRadius: 0,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 15),
                                    spreadRadius: -5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.tungsten_rounded,
                                color: Colors.white,
                                size: 50,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
                            ).createShader(bounds),
                            child: Text(
                              'luxOT',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 48,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Smart Lighting Control',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                          ),
                          const SizedBox(height: 40),

                          // Username Field
                          TextField(
                            controller: _userController,
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(
                                Icons.person_outline_rounded,
                                color: const Color(0xFFFFD700),
                              ),
                              hintText: 'Enter your username',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0a0a0a),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFFD700),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF333333),
                                  width: 1.5,
                                ),
                              ),
                              hintStyle: const TextStyle(
                                color: Color(0xFF555555),
                              ),
                              labelStyle: const TextStyle(
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          TextField(
                            controller: _passController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(
                                Icons.lock_outline_rounded,
                                color: const Color(0xFFD4AF37),
                              ),
                              hintText: 'Enter your password',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF0a0a0a),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD4AF37),
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                            obscureText: true,
                          ),
                          const SizedBox(height: 32),

                          // Expandable Broker Settings
                          Theme(
                            data: Theme.of(
                              context,
                            ).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              title: Row(
                                children: [
                                  Icon(
                                    Icons.settings_input_antenna_rounded,
                                    size: 20,
                                    color: const Color(0xFFD4AF37),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Broker Settings',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFD4AF37),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(top: 16),
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _hostController,
                                        decoration: InputDecoration(
                                          labelText: 'Host/IP',
                                          labelStyle: const TextStyle(
                                            color: Color(0xFFFFD700),
                                            fontSize: 12,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.wifi_tethering_rounded,
                                            size: 20,
                                            color: Color(0xFFFFD700),
                                          ),
                                          hintText: '192.168.1.10',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF666666),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF333333),
                                              width: 1.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF333333),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFFFD700),
                                              width: 2,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFF1a1a1a),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 14,
                                              ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _portController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Port',
                                          labelStyle: const TextStyle(
                                            color: Color(0xFFFFD700),
                                            fontSize: 12,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.settings_ethernet_rounded,
                                            size: 20,
                                            color: Color(0xFFFFD700),
                                          ),
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF666666),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF333333),
                                              width: 1.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF333333),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFFFD700),
                                              width: 2,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFF1a1a1a),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 14,
                                              ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _tryLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFD4AF37),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFFFFD700,
                                      ).withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: _loading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.black,
                                                ),
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0a0a0a),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFD4AF37)!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: const Color(0xFFD4AF37),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Demo: admin / password',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: const Color(0xFFD4AF37),
                                    fontWeight: FontWeight.w600,
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
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Map<String, dynamic>> _lights = [
    {'id': '1', 'name': 'Living Room', 'room': 'Living', 'on': false},
    {'id': '2', 'name': 'Kitchen', 'room': 'Kitchen', 'on': false},
    {'id': '3', 'name': 'Bedroom', 'room': 'Bedroom', 'on': false},
    {'id': '4', 'name': 'Porch', 'room': 'Outdoor', 'on': false},
    {'id': '5', 'name': 'Class', 'room': 'Classroom', 'on': false},
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
  String _selectedRoom = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
    _ensureConnection();
    mqtt.connected.addListener(_onConnectionChanged);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load rooms
    final roomsJson = prefs.getStringList('rooms');
    if (roomsJson != null && roomsJson.isNotEmpty) {
      setState(() => _roomsList = roomsJson);
    } else {
      await prefs.setStringList('rooms', _roomsList);
    }

    // Load devices
    final devicesJson = prefs.getStringList('devices');
    if (devicesJson != null && devicesJson.isNotEmpty) {
      final devices = devicesJson.map((json) {
        final parts = json.split('|');
        return {
          'id': parts[0],
          'name': parts[1],
          'room': parts[2],
          'on': parts[3] == 'true',
        };
      }).toList();
      setState(() => _lights = devices);
    } else {
      await _saveDevices();
    }
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = _lights
        .map(
          (light) =>
              '${light['id']}|${light['name']}|${light['room']}|${light['on']}',
        )
        .toList();
    await prefs.setStringList('devices', devicesJson);
  }

  Future<void> _saveRooms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('rooms', _roomsList);
  }

  List<String> get _rooms {
    // Return all rooms from the rooms list, not just rooms with devices
    return ['All', ..._roomsList];
  }

  List<Map<String, dynamic>> get _filteredLights {
    if (_selectedRoom == 'All') return _lights;
    return _lights.where((light) => light['room'] == _selectedRoom).toList();
  }

  Future<void> _ensureConnection() async {
    if (mqtt.connected.value) return;
    final prefs = await SharedPreferences.getInstance();
    final server = prefs.getString('mqttHost') ?? mqtt.lastServer ?? mqttHost;
    final port = prefs.getInt('mqttPort') ?? mqtt.lastPort ?? 1883;
    await mqtt.connect(server: server, port: port);
  }

  void _onConnectionChanged() => setState(() {});

  @override
  void dispose() {
    mqtt.connected.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _toggleLight(int index, bool value) {
    setState(() => _lights[index]['on'] = value);
    final room = _lights[index]['room'];
    final id = _lights[index]['id'];
    final topic = 'home/$room.light/$id';
    final payload = value ? 'ON' : 'OFF';
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

  Future<void> _logout() async {
    mqtt.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = mqtt.connected.value;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
          ).createShader(bounds),
          child: const Text(
            'luxOT',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1a1a1a),
        scrolledUnderElevation: 0,
        shadowColor: const Color(0xFFD4AF37).withOpacity(0.3),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFD4AF37).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        actions: [
          if (!connected)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: _isReconnecting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF6B6B),
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 24),
                style: IconButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B6B),
                  backgroundColor: const Color(0xFFFF6B6B).withOpacity(0.1),
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: _isReconnecting ? null : _reconnect,
              ),
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: connected
                    ? [const Color(0xFF51CF66), const Color(0xFF37B24D)]
                    : [const Color(0xFFFF6B6B), const Color(0xFFFA5252)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:
                      (connected
                              ? const Color(0xFF51CF66)
                              : const Color(0xFFFF6B6B))
                          .withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  connected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  connected ? 'Online' : 'Offline',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFFFFD700),
            ),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a1a), Color(0xFF121212), Color(0xFF0a0a0a)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCirc,
          switchOutCurve: Curves.easeInCirc,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.02, 0.02),
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
          child: _currentTab == 0
              ? Column(
                  key: const ValueKey('rooms'),
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: !connected
                          ? Container(
                              key: const ValueKey('banner'),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.orange[200]!,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning_rounded,
                                    color: Colors.orange[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Disconnected from MQTT',
                                      style: TextStyle(
                                        color: Colors.orange[700],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
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
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.85,
                            ),
                        itemCount: _rooms.length - 1,
                        itemBuilder: (context, i) {
                          final roomName = _rooms[i + 1];
                          final roomLights = _lights
                              .where((light) => light['room'] == roomName)
                              .toList();
                          final allOn = roomLights.every(
                            (light) => light['on'],
                          );

                          return Hero(
                            tag: 'room_$roomName',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _selectedRoom = roomName);
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                          ) => _RoomDetailPage(
                                            roomName: roomName,
                                            lights: roomLights,
                                            onToggleLight: _toggleLight,
                                            connected: connected,
                                          ),
                                      transitionsBuilder:
                                          (
                                            context,
                                            animation,
                                            secondaryAnimation,
                                            child,
                                          ) {
                                            const begin = Offset(1.0, 0.0);
                                            const end = Offset.zero;
                                            const curve = Curves.easeOutCubic;
                                            var tween = Tween(
                                              begin: begin,
                                              end: end,
                                            ).chain(CurveTween(curve: curve));
                                            return SlideTransition(
                                              position: animation.drive(tween),
                                              child: FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              ),
                                            );
                                          },
                                      transitionDuration: const Duration(
                                        milliseconds: 400,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2a2a2a),
                                        Color(0xFF1a1a1a),
                                        Color(0xFF121212),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      stops: [0.0, 0.5, 1.0],
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFD4AF37),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFD4AF37,
                                        ).withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                        spreadRadius: 0,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.6),
                                        blurRadius: 24,
                                        offset: const Offset(0, 12),
                                        spreadRadius: -8,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    roomName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white,
                                                      letterSpacing: -0.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.25),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${roomLights.length} device${roomLights.length != 1 ? 's' : ''}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.25,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Icon(
                                                Icons.meeting_room_rounded,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: allOn
                                                ? const Color(
                                                    0xFFD4AF37,
                                                  ).withOpacity(0.3)
                                                : Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                allOn
                                                    ? Icons.lightbulb_rounded
                                                    : Icons
                                                          .lightbulb_outline_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                allOn ? 'All On' : 'Some Off',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 32,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons
                                                    .power_settings_new_rounded,
                                                size: 16,
                                                color: allOn
                                                    ? const Color(0xFFFFD700)
                                                    : Colors.white.withOpacity(
                                                        0.4,
                                                      ),
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  'Toggle All',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Transform.scale(
                                                scale: 0.75,
                                                child: Switch(
                                                  value: allOn,
                                                  onChanged:
                                                      roomLights.isEmpty ||
                                                          !connected
                                                      ? null
                                                      : (value) {
                                                          _toggleAllInRoom(
                                                            roomName,
                                                            value,
                                                          );
                                                        },
                                                  activeThumbColor: const Color(
                                                    0xFFFFD700,
                                                  ),
                                                  activeTrackColor: const Color(
                                                    0xFFD4AF37,
                                                  ).withOpacity(0.5),
                                                  inactiveThumbColor: Colors
                                                      .white
                                                      .withOpacity(0.4),
                                                  inactiveTrackColor: Colors
                                                      .white
                                                      .withOpacity(0.2),
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
                          );
                        },
                      ),
                    ),
                  ],
                )
              : ListView(
                  key: const ValueKey('settings'),
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: [
                    _buildSettingCard(
                      icon: Icons.wifi_tethering,
                      title: 'Broker Host',
                      subtitle: mqtt.lastServer ?? mqttHost,
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: Icons.settings_ethernet,
                      title: 'Broker Port',
                      subtitle: '${mqtt.lastPort ?? 1883}',
                    ),
                    const SizedBox(height: 12),
                    _buildSettingCard(
                      icon: connected ? Icons.cloud_done : Icons.cloud_off,
                      iconColor: connected ? Colors.green : Colors.red,
                      title: 'Connection Status',
                      subtitle: connected ? 'Online' : 'Offline',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isReconnecting ? null : _reconnect,
                        icon: _isReconnecting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFD4AF37),
                                  ),
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: const Text('Reconnect'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1a1a1a),
                          foregroundColor: const Color(0xFFD4AF37),
                          side: const BorderSide(color: Color(0xFFD4AF37)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Device Management',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showRoomManagement,
                        icon: const Icon(Icons.home_work),
                        label: const Text('Manage Rooms'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1a1a1a),
                          foregroundColor: const Color(0xFFD4AF37),
                          side: const BorderSide(color: Color(0xFFD4AF37)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showDeviceManagement,
                        icon: const Icon(Icons.lightbulb),
                        label: const Text('Manage Devices'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1a1a1a),
                          foregroundColor: const Color(0xFFD4AF37),
                          side: const BorderSide(color: Color(0xFFD4AF37)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: const Color(0xFF1a1a1a),
            indicatorColor: const Color(0xFFD4AF37).withOpacity(0.2),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded, color: Color(0xFF666666)),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFFFFD700)),
              label: 'Rooms',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings, color: Color(0xFF666666)),
              selectedIcon: Icon(Icons.settings, color: Color(0xFFFFD700)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAllInRoom(String roomName, bool turnOn) {
    final indices = <int>[];
    for (int i = 0; i < _lights.length; i++) {
      if (_lights[i]['room'] == roomName) {
        indices.add(i);
      }
    }

    setState(() {
      for (int i in indices) {
        _lights[i]['on'] = turnOn;
      }
    });

    for (int i in indices) {
      final room = _lights[i]['room'];
      final id = _lights[i]['id'];
      final topic = 'home/$room.light/$id';
      final payload = turnOn ? 'ON' : 'OFF';
      mqtt.publish(topic, payload);
    }
    _saveDevices();
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
      builder: (context) => _DeviceManagementDialog(
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
        color: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF333333)),
        ),
        child: ListTile(
          leading: Icon(icon, color: iconColor ?? const Color(0xFFD4AF37)),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF999999)),
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
  State<_RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<_RoomDetailPage> {
  late List<Map<String, dynamic>> _roomLights;

  @override
  void initState() {
    super.initState();
    _roomLights = List.from(widget.lights);
  }

  void _toggleLight(int index, bool value) {
    setState(() => _roomLights[index]['on'] = value);
    widget.onToggleLight(
      _findLightIndexInMain(_roomLights[index]['id']),
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
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
          ).createShader(bounds),
          child: Text(
            widget.roomName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1a1a1a),
        scrolledUnderElevation: 0,
        shadowColor: const Color(0xFFD4AF37).withOpacity(0.3),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFD4AF37).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a1a), Color(0xFF121212), Color(0xFF0a0a0a)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: ListView.builder(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.all(16),
          itemCount: _roomLights.length,
          itemBuilder: (context, i) {
            final light = _roomLights[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 4,
                color: Colors.transparent,
                shadowColor: light['on']
                    ? const Color(0xFFFFD700).withOpacity(0.3)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: light['on']
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFF333333),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: light['on']
                          ? [const Color(0xFF2a2a2a), const Color(0xFF1a1a1a)]
                          : [const Color(0xFF1a1a1a), const Color(0xFF121212)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: light['on']
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: SwitchListTile(
                      title: Text(
                        light['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        light['room'],
                        style: const TextStyle(color: Color(0xFF999999)),
                      ),
                      value: light['on'],
                      onChanged: widget.connected
                          ? (v) => _toggleLight(i, v)
                          : null,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: light['on']
                              ? const Color(0xFFD4AF37).withOpacity(0.3)
                              : const Color(0xFF333333).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          light['on']
                              ? Icons.lightbulb
                              : Icons.lightbulb_outline,
                          color: light['on']
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF666666),
                          size: 24,
                        ),
                      ),
                      activeThumbColor: const Color(0xFFFFD700),
                      activeTrackColor: const Color(
                        0xFFD4AF37,
                      ).withOpacity(0.5),
                      inactiveThumbColor: const Color(0xFF666666),
                      inactiveTrackColor: const Color(
                        0xFF333333,
                      ).withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoomManagementDialog extends StatefulWidget {
  final List<String> rooms;
  final Function(List<String>) onSave;

  const _RoomManagementDialog({required this.rooms, required this.onSave});

  @override
  State<_RoomManagementDialog> createState() => _RoomManagementDialogState();
}

class _RoomManagementDialogState extends State<_RoomManagementDialog> {
  late List<String> _rooms;
  final _newRoomController = TextEditingController();

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
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() => _rooms.removeAt(i));
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_newRoomController.text.isNotEmpty) {
                    setState(() {
                      _rooms.add(_newRoomController.text);
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

class _DeviceManagementDialog extends StatefulWidget {
  final List<Map<String, dynamic>> devices;
  final List<String> rooms;
  final Function(List<Map<String, dynamic>>) onSave;

  const _DeviceManagementDialog({
    required this.devices,
    required this.rooms,
    required this.onSave,
  });

  @override
  State<_DeviceManagementDialog> createState() =>
      _DeviceManagementDialogState();
}

class _DeviceManagementDialogState extends State<_DeviceManagementDialog> {
  late List<Map<String, dynamic>> _devices;
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  String? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _devices = List.from(widget.devices);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Devices'),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
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
                      subtitle: Text('${device['room']} (ID: ${device['id']})'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() => _devices.removeAt(i));
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _numberController,
                decoration: InputDecoration(
                  labelText: 'Device ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRoom,
                decoration: InputDecoration(
                  labelText: 'Room',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: widget.rooms
                    .map(
                      (room) =>
                          DropdownMenuItem(value: room, child: Text(room)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedRoom = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selectedRoom != null &&
                          _nameController.text.isNotEmpty &&
                          _numberController.text.isNotEmpty
                      ? () {
                          _devices.add({
                            'id': _numberController.text,
                            'name': _nameController.text,
                            'room': _selectedRoom,
                            'on': false,
                          });
                          setState(() {
                            _nameController.clear();
                            _numberController.clear();
                            _selectedRoom = null;
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
          onPressed: () => widget.onSave(_devices),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
