import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:torch_light/torch_light.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'gemini_api.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TerminalApp());
}

class TerminalApp extends StatelessWidget {
  const TerminalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Terminal Launcher',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.black,
        brightness: Brightness.dark,
      ),
      home: const Terminal(),
    );
  }
}

class Terminal extends StatefulWidget {
  const Terminal({super.key});

  @override
  State<Terminal> createState() => _TerminalState();
}

class _TerminalState extends State<Terminal> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Application> _installedApps = [];
  final List<Widget> _output = [];
  Battery battery = Battery();
  String username = 'guest';
  Timer? _uptimeTimer;
  Duration _uptime = Duration.zero;

  @override
  void initState() {
    super.initState();
    VolumeController().showSystemUI = false;
    _loadUsername();
    _loadInstalledApps();
    _loadStartupCommand(); 
    _startUptimeTimer();
  }


  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? 'guest';
    });
  }

  Future<void> _saveUsername(String newUsername) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', newUsername);
    setState(() {
      username = newUsername;
    });
  }

  void _startUptimeTimer() {
    _uptimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _uptime += const Duration(seconds: 1);
      });
    });
  }

  Future<void> getDeviceInfo() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      String deviceModel = androidInfo.model;
      _addOutputWidget(Text('Device Model: $deviceModel'));
    } catch (e) {
      _addOutputWidget(Text("Error fetching device info: $e"));
    }
  }

  Future<void> getBatteryPercentage() async {
    try {
      int batteryLevel = await battery.batteryLevel;
      _addOutputWidget(Text('Battery Percentage: $batteryLevel%'));
    } catch (e) {
      _addOutputWidget(Text("Error fetching battery info: $e"));
    }
  }

  void _loadInstalledApps() async {
    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      onlyAppsWithLaunchIntent: true,
      includeSystemApps: true,
    );

    apps.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

    setState(() {
      _installedApps = apps;
    });
  }

  void _executeCommand(String command) async {
    _addCommandOutput(command);
    List<String> parts = command.split(' ');

    if (parts.isNotEmpty) {
      String mainCommand = parts[0].toLowerCase();

      if (mainCommand == 'list') {
        _showInstalledAppsList();
      } else if (mainCommand == 'run' && parts.length >= 2) {
        String appName = parts.sublist(1).join(' ');
        _runApp(appName);
      } else if (mainCommand == 'deviceinfo') {
        await getDeviceInfo();
      } else if (mainCommand == 'setstartup') {
        if (parts.length > 1) {
          String startupCommand = parts.sublist(1).join(' ');
          await _saveStartupCommand(startupCommand); 
          _addOutputWidget(Text("Startup command set to: $startupCommand"));
        } else {
          _addOutputWidget(const Text("Usage: setstartup <command>"));
        }
      } else if (mainCommand == 'battery') {
        await getBatteryPercentage();
      } else if (mainCommand == 'flashlight') {
        if (parts.length > 1) {
          String action = parts[1].toLowerCase();
          if (action == 'on') {
            await _toggleFlashlight(true);
          } else if (action == 'off') {
            await _toggleFlashlight(false);
          } else {
            _addOutputWidget(const Text("Usage: flashlight [on/off]"));
          }
        } else {
          _addOutputWidget(const Text("Usage: flashlight [on/off]"));
        }
      } else if (mainCommand == 'help') {
        _showHelp();
      } else if (mainCommand == 'volume') {
        if (parts.length > 1) {
          String action = parts[1].toLowerCase();
          if (action == 'up') {
            _adjustVolume(0.1); 
          } else if (action == 'down') {
            _adjustVolume(-0.1); 
          } else {
            try {
              double volume = double.parse(action) / 100;
              _setVolume(volume); 
            } catch (e) {
              _addOutputWidget(const Text("Usage: volume [up/down/<0-100>]"));
            }
          }
        } else {
          _addOutputWidget(const Text("Usage: volume [up/down/<0-100>]"));
        }
      } else if (mainCommand == 'time') {
        _showCurrentTime();
      } else if (mainCommand == 'brightness') {
        if (parts.length > 1) {
          String action = parts[1].toLowerCase();
          if (action == 'up') {
            _adjustBrightness(0.1); 
          } else if (action == 'down') {
            _adjustBrightness(-0.1); 
          } else {
            try {
              double brightness = double.parse(action) / 100;
              _setBrightness(brightness); 
            } catch (e) {
              _addOutputWidget(const Text("Usage: brightness [up/down/<0-100>]"));
            }
          }
        } else {
          _addOutputWidget(const Text("Usage: brightness [up/down/<0-100>]"));
        }
      } else if (mainCommand == 'uptime') {
        _showUptime();
      } else if (mainCommand == 'sysinfo') {
        _showSysInfo();
      }else  if (mainCommand == 'ip') {
        await _getLocalIpAddress();
      } else if (mainCommand == 'connection') {
        await _getConnectionStatus();
      } else if (mainCommand == 'ping' && parts.length == 2) {
        String address = parts[1];
        await _pingAddress(address);
      } else if (mainCommand == 'traceroute' && parts.length == 2) {
        String address = parts[1];
        await _tracerouteAddress(address);
      } else if (mainCommand == 'nslookup' && parts.length == 2) {
        String address = parts[1];
        await _nslookupAddress(address);
      } else if (mainCommand == 'websearch' && parts.length >= 2) {
        String query = parts.sublist(1).join(' ');
        await _searchInBrowser(query);
        return;
      } else if (mainCommand == 'weather' && parts.length >= 2) {
        String location = parts.sublist(1).join(' ');
        await _getWeather(location);
      }else if (mainCommand == 'generate' && parts.length >= 2) {
        String prompt = parts.sublist(1).join(' ');
        String generatedContent = await GeminiApi.generateContent(prompt);
        _addOutputWidget(Text('Generated Content: $generatedContent'));
      } else if (mainCommand == 'echo') {
        if (parts.length > 1) {
          String message = parts.sublist(1).join(' ');
          _echo(message);
        } else {
          _addOutputWidget(const Text("Usage: echo <message>"));
        }
      } else if (mainCommand == 'clear') {
        _clearTerminal();
      } else if (mainCommand == 'restart') {
        _restartTerminal();
      } else if (mainCommand == 'set' && parts.length >= 2 && parts[1] == 'username') {
        if (parts.length == 3) {
          String newUsername = parts[2];
          await _saveUsername(newUsername);
          _addOutputWidget(Text("Username set to: $newUsername"));
        } else {
          _addOutputWidget(const Text("Usage: set username <new_username>"));
        }
      } else {
        _addOutputWidget(Text("Command not recognized: $command"));
      }
    } else {
      _addOutputWidget(const Text("No command entered."));
    }
  }
  
  void _echo(String message) {
    _addOutputWidget(Text(message));
  }
  
  Future<void> _getWeather(String location) async {
    final apiKey = dotenv.env['OPENWEATHER_API_KEY']; 
    final url = 'https://api.openweathermap.org/data/2.5/weather?q=$location&appid=$apiKey&units=metric';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final weatherDescription = data['weather'][0]['description'];
        final temperature = data['main']['temp'];
        final city = data['name'];

        _addOutputWidget(Text('Weather in $city: $weatherDescription, $temperature°C'));
      } else {
        _addOutputWidget(Text('Could not fetch weather data for $location.'));
      }
    } catch (e) {
      _addOutputWidget(Text('Error fetching weather: $e'));
    }
  }

  void _showCurrentTime() {
    DateTime now = DateTime.now();
    String formattedTime = '${now.toLocal()}';
    _addOutputWidget(Text('Current time: $formattedTime'));
  }

  void _showUptime() {
    String uptimeString = '${_uptime.inHours}:${(_uptime.inMinutes % 60).toString().padLeft(2, '0')}:${(_uptime.inSeconds % 60).toString().padLeft(2, '0')}';
    _addOutputWidget(Text('Uptime: $uptimeString'));
  }

  void _showSysInfo() {
    String sysInfo = 'Operating System: ${Platform.operatingSystem}\nOS Version: ${Platform.operatingSystemVersion}';
    _addOutputWidget(Text(sysInfo));
  }
  
  void _adjustVolume(double change) async {
    double currentVolume = await VolumeController().getVolume();
    double newVolume = (currentVolume + change).clamp(0.0, 1.0);
    VolumeController().setVolume(newVolume);
    _addOutputWidget(Text("Volume: ${(newVolume * 100).toInt()}%"));
  }

  void _setVolume(double volume) async {
    double newVolume = volume.clamp(0.0, 1.0);
    VolumeController().setVolume(newVolume);
    _addOutputWidget(Text("Volume set to: ${(newVolume * 100).toInt()}%"));
  }


  Future<void> _toggleFlashlight(bool turnOn) async {
    try {
      if (turnOn) {
        await TorchLight.enableTorch();
        _addOutputWidget(const Text("Flashlight turned on"));
      } else {
        await TorchLight.disableTorch();
        _addOutputWidget(const Text("Flashlight turned off"));
      }
    } catch (e) {
      _addOutputWidget(Text("Flashlight control error: $e"));
    }
  }

  void _adjustBrightness(double change) async {
    try {
      double currentBrightness = await ScreenBrightness().current;
      double newBrightness = (currentBrightness + change).clamp(0.0, 1.0);
      await ScreenBrightness().setScreenBrightness(newBrightness);
      _addOutputWidget(Text("Brightness: ${(newBrightness * 100).toInt()}%"));
    } catch (e) {
      _addOutputWidget(Text("Error adjusting brightness: $e"));
    }
  }

  void _setBrightness(double brightness) async {
    try {
      double newBrightness = brightness.clamp(0.0, 1.0);
      await ScreenBrightness().setScreenBrightness(newBrightness);
      _addOutputWidget(Text("Brightness set to: ${(newBrightness * 100).toInt()}%"));
    } catch (e) {
      _addOutputWidget(Text("Error setting brightness: $e"));
    }
  }

  Future<void> _saveStartupCommand(String command) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('startup_command', command);
  }
  
  Future<void> _loadStartupCommand() async {
    final prefs = await SharedPreferences.getInstance();
    String? command = prefs.getString('startup_command');
    if (command != null && command.isNotEmpty) {
      _executeCommand(command); 
    }
  }
 
  Future<void> _searchInBrowser(String query) async {
    final url = 'https://www.google.com/search?q=$query';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _addOutputWidget(const Text("Could not launch browser."));
    }
  }

  Future<void> _pingAddress(String address) async {
    try {
      ProcessResult result = await Process.run('ping', ['-c', '4', address]);
      _addOutputWidget(Text(result.stdout));
    } catch (e) {
      _addOutputWidget(Text("Failed to ping $address: $e"));
    }
  }
  
  Future<void> _getConnectionStatus() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    String status;
    if (connectivityResult == ConnectivityResult.mobile) {
      status = "Connected to Mobile Network";
    } else if (connectivityResult == ConnectivityResult.wifi) {
      status = "Connected to Wi-Fi";
    } else {
      status = "No Internet Connection";
    }
    _addOutputWidget(Text(status));
  }

  Future<void> _getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            _addOutputWidget(Text('Local IP Address: ${addr.address}'));
            return;
          }
        }
      }
    } catch (e) {
      _addOutputWidget(Text("Error fetching IP address: $e"));
    }
  }

  Future<void> _tracerouteAddress(String address) async {
    try {
      ProcessResult result = await Process.run('traceroute', [address]);
      _addOutputWidget(Text(result.stdout));
    } catch (e) {
      _addOutputWidget(Text("Failed to traceroute to $address: $e"));
    }
  }

  Future<void> _nslookupAddress(String address) async {
    try {
      ProcessResult result = await Process.run('nslookup', [address]);
      _addOutputWidget(Text(result.stdout));
    } catch (e) {
      _addOutputWidget(Text("Failed to nslookup $address: $e"));
    }
  }

  void _clearTerminal() {
    setState(() {
      _output.clear();
    });
  }

  void _restartTerminal() {
    setState(() {
      _output.clear(); 
    });
    _loadStartupCommand();
  }

  void _showInstalledAppsList() {
    if (_installedApps.isEmpty) {
      _addOutputWidget(const Text("No apps found."));
    } else {
      _addOutputWidget(const Text("Installed apps:"));
      for (var app in _installedApps) {
        _addOutputWidget(Text(app.appName));
      }
    }
  }

  void _runApp(String appName) async {
    Application? app = _installedApps.firstWhereOrNull(
      (installedApp) => installedApp.appName.toLowerCase().contains(appName.toLowerCase()),
    );

    if (app != null) {
      await DeviceApps.openApp(app.packageName);
    } else {
      _addOutputWidget(Text("App not found: $appName"));
    }
  }

  void _showHelp() {
    _addOutputWidget(const Text('Available commands:'));
    _addOutputWidget(const Text('help: Show this help message'));
    _addOutputWidget(const Text('echo <message>'));
    _addOutputWidget(const Text('list: List installed apps'));
    _addOutputWidget(const Text('run <app name>: Run a specific app'));
    _addOutputWidget(const Text('websearch <query>: Search in browser'));
    _addOutputWidget(const Text('generate <prompt>: Generate content'));
    _addOutputWidget(const Text('weather <city>: Show the weather for a specific city'));
    _addOutputWidget(const Text('deviceinfo: Show device information'));
    _addOutputWidget(const Text('battery: Show battery percentage'));
    _addOutputWidget(const Text('volume up/down: Increase or decrease volume by 10%'));
    _addOutputWidget(const Text('volume <0-100>: Set volume to a specific level'));
    _addOutputWidget(const Text('brightness up/down: Increase or decrease brightness by 10%'));
    _addOutputWidget(const Text('brightness <0-100>: Set brightness to a specific level'));
    _addOutputWidget(const Text('flashlight on/off: Toggle the flashlight'));
    _addOutputWidget(const Text('time: Show current time'));
    _addOutputWidget(const Text('uptime: Show app uptime'));
    _addOutputWidget(const Text('sysinfo: Show system information'));
    _addOutputWidget(const Text('ip: Show local IP address'));
    _addOutputWidget(const Text('connection: Show network connection status'));
    _addOutputWidget(const Text('ping <address>: Ping a specified address'));
    _addOutputWidget(const Text('traceroute <address>: Traceroute to a specified address'));
    _addOutputWidget(const Text('nslookup <address>: DNS lookup for a specified address'));
    _addOutputWidget(const Text('set username <new_username>: Set the username'));
    _addOutputWidget(const Text('setstartup <command>: Set a command to run on startup'));
    _addOutputWidget(const Text('restart: Restart the terminal'));
    _addOutputWidget(const Text('clear: Clear the terminal'));
  }

  void _addCommandOutput(String command) {
    _addOutputWidget(Text('$username@launcher\$ $command', style: const TextStyle(color: Colors.green)));
  }

  void _addOutputWidget(Widget widget) {
    setState(() {
      _output.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: widget),
          ],
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    });
  }


  @override
  void dispose() {
    _commandController.dispose();
    _uptimeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return false;
      },
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _output.length,
                  itemBuilder: (context, index) {
                    return _output[index];
                  },
                ),
              ),
              Center(
                child: Container(
                  width: 385,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 1.4),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commandController,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.green,
                            onSubmitted: (command) {
                              _executeCommand(command);
                              _commandController.clear();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Enter Command..',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
