import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:async';

const String mqttHost = '10.0.2.2'; // Android emulator -> host machine

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginPage(),
    );
  }
}

/// Simple MQTT manager (singleton) for connecting and publishing messages.

/// Simple MQTT manager (singleton) for connecting and publishing messages.
class MQTTManager {
  MQTTManager._internal();
  static final MQTTManager _instance = MQTTManager._internal();
  factory MQTTManager() => _instance;

  late MqttServerClient client;
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  Future<void> connect({required String server, int port = 1883}) async {
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
      client.disconnect();
      connected.value = false;
      return;
    }

    if (client.connectionStatus?.state == MqttConnectionState.connected) {
      connected.value = true;
    } else {
      connected.value = false;
      client.disconnect();
    }
  }

  void _onConnected() => connected.value = true;
  void _onDisconnected() => connected.value = false;

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
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _loading = false;

  void _tryLogin() async {
    final username = _userController.text.trim();
    final password = _passController.text;

    if (username == 'admin' && password == 'password') {
      setState(() => _loading = true);
      try {
        // Connect MQTT with 5 second timeout
        await MQTTManager()
            .connect(server: mqttHost, port: 1883)
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _loading ? null : _tryLogin,
                      child: _loading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ],
                ),
              ],
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
  final List<Map<String, dynamic>> _lights = [
    {'id': '1', 'name': 'Living Room', 'on': false},
    {'id': '2', 'name': 'Kitchen', 'on': false},
    {'id': '3', 'name': 'Bedroom', 'on': false},
    {'id': '4', 'name': 'Porch', 'on': false},
    {'id': '5', 'name': 'class', 'on': false},
  ];

  final mqtt = MQTTManager();

  @override
  void initState() {
    super.initState();
    // If not connected (e.g., user logged in without waiting), try connect again
    if (!mqtt.connected.value) {
      mqtt.connect(server: mqttHost, port: 1883);
    }
    mqtt.connected.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() => setState(() {});

  @override
  void dispose() {
    mqtt.connected.removeListener(_onConnectionChanged);
    super.dispose();
  }

  void _toggleLight(int index, bool value) {
    setState(() => _lights[index]['on'] = value);
    final id = _lights[index]['id'];
    final topic = 'home/light/$id';
    final payload = value ? 'ON' : 'OFF';
    mqtt.publish(topic, payload);
  }

  void _logout() {
    mqtt.disconnect();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = mqtt.connected.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Lights'),
        centerTitle: true,
        actions: [
          Icon(
            connected ? Icons.cloud_done : Icons.cloud_off,
            color: connected ? Colors.greenAccent : Colors.redAccent,
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _lights.length,
        itemBuilder: (context, i) {
          final light = _lights[i];
          return Card(
            child: SwitchListTile(
              title: Text(light['name']),
              value: light['on'],
              onChanged: (v) => _toggleLight(i, v),
              secondary: Icon(
                light['on'] ? Icons.lightbulb : Icons.lightbulb_outline,
                color: light['on'] ? Colors.amber : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
