import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
    _loadUsername();
    _loadInstalledApps();
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
    _uptimeTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _uptime += Duration(seconds: 1);
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
      } else if (mainCommand == 'battery') {
        await getBatteryPercentage();
      } else if (mainCommand == 'help') {
        _showHelp();
      } else if (mainCommand == 'time') {
        _showCurrentTime();
      } else if (mainCommand == 'uptime') {
        _showUptime();
      } else if (mainCommand == 'sysinfo') {
        _showSysInfo();
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
      } else if (mainCommand == 'restart') {
        _restartTerminal();
      } else if (mainCommand == 'set' && parts.length >= 2 && parts[1] == 'username') {
        if (parts.length == 3) {
          String newUsername = parts[2];
          await _saveUsername(newUsername);
          _addOutputWidget(Text("Username set to: $newUsername"));
        } else {
          _addOutputWidget(Text("Usage: set username <new_username>"));
        }
      } else {
        _addOutputWidget(Text("Command not recognized: $command"));
      }
    } else {
      _addOutputWidget(Text("No command entered."));
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

  Future<void> _searchInBrowser(String query) async {
    final url = 'https://www.google.com/search?q=$query';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      _addOutputWidget(Text("Could not launch browser."));
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

  void _restartTerminal() {
    setState(() {
      _output.clear();
    });
    _addOutputWidget(Text("Terminal restarted."));
  }

  void _showInstalledAppsList() {
    if (_installedApps.isEmpty) {
      _addOutputWidget(Text("No apps found."));
    } else {
      _addOutputWidget(Text("Installed apps:"));
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
    _addOutputWidget(Text('Available commands:'));
    _addOutputWidget(Text('  - help: Show this help message'));
    _addOutputWidget(Text('  - list: List installed apps'));
    _addOutputWidget(Text('  - run <app name>: Run a specific app'));
    _addOutputWidget(Text('  - websearch <query>: Search in browser'));
    _addOutputWidget(Text('  - deviceinfo: Show device information'));
    _addOutputWidget(Text('  - battery: Show battery percentage'));
    _addOutputWidget(Text('  - time: Show current time'));
    _addOutputWidget(Text('  - uptime: Show app uptime'));
    _addOutputWidget(Text('  - sysinfo: Show system information'));
    _addOutputWidget(Text('  - ping <address>: Ping a specified address'));
    _addOutputWidget(Text('  - traceroute <address>: Traceroute to a specified address'));
    _addOutputWidget(Text('  - nslookup <address>: DNS lookup for a specified address'));
    _addOutputWidget(Text('  - restart: Restart the terminal'));
    _addOutputWidget(Text('  - set username <new_username>: Set the username'));
  }

  void _addCommandOutput(String command) {
    _addOutputWidget(Text('$username@launcher\$ $command', style: TextStyle(color: Colors.green)));
  }

  void _addOutputWidget(Widget widget) {
    setState(() {
      _output.add(widget);
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
  return GestureDetector(
    onTap: () {
      FocusScope.of(context).unfocus(); 
    },
    child: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._output,
                ],
              ),
            ),
          ),
          Center( 
            child: Container(
              width: 365, 
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
  );
}
}
