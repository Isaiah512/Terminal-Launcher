import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';

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
      _addErrorOutput("Error fetching device info: $e");
    }
  }

  Future<void> getBatteryPercentage() async {
    try {
      int batteryLevel = await battery.batteryLevel;
      _addOutputWidget(Text('Battery Percentage: $batteryLevel%'));
    } catch (e) {
      _addErrorOutput("Error fetching battery info: $e");
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
    if (parts.isEmpty) {
      _addOutputWidget(Text("No command entered."));
      return;
    }

    String mainCommand = parts[0].toLowerCase();

    switch (mainCommand) {
      case 'list':
        _showInstalledAppsList();
        break;
      case 'run':
        if (parts.length >= 2) {
          _runApp(parts.sublist(1).join(' '));
        } else {
          _addOutputWidget(Text("Usage: run <app name>"));
        }
        break;
      case 'deviceinfo':
        await getDeviceInfo();
        break;
      case 'battery':
        await getBatteryPercentage();
        break;
      case 'help':
        _showHelp();
        break;
      case 'time':
        _showCurrentTime();
        break;
      case 'uptime':
        _showUptime();
        break;
      case 'sysinfo':
        _showSysInfo();
        break;
      case 'ping':
        if (parts.length == 2) {
          await _pingAddress(parts[1]);
        } else {
          _addOutputWidget(Text("Usage: ping <address>"));
        }
        break;
      case 'traceroute':
        if (parts.length == 2) {
          await _tracerouteAddress(parts[1]);
        } else {
          _addOutputWidget(Text("Usage: traceroute <address>"));
        }
        break;
      case 'nslookup':
        if (parts.length == 2) {
          await _nslookupAddress(parts[1]);
        } else {
          _addOutputWidget(Text("Usage: nslookup <address>"));
        }
        break;
      case 'restart':
        _restartTerminal();
        break;
      case 'set':
        if (parts.length >= 2 && parts[1] == 'username') {
          if (parts.length == 3) {
            String newUsername = parts[2];
            await _saveUsername(newUsername);
            _addOutputWidget(Text("Username set to: $newUsername"));
          } else {
            _addOutputWidget(Text("Usage: set username <new_username>"));
          }
        }
        break;
      default:
        _addOutputWidget(Text("Command not recognized: $command"));
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

  Future<void> _pingAddress(String address) async {
    try {
      ProcessResult result = await Process.run('ping', ['-c', '4', address]);
      _addOutputWidget(Text(result.stdout));
    } catch (e) {
      _addErrorOutput("Failed to ping $address: $e");
    }
  }

  Future<void> _tracerouteAddress(String address) async {
    try {
      ProcessResult result = await Process.run('traceroute', [address]);
      _addOutputWidget(Text(result.stdout));
    } catch (e) {
      _addErrorOutput("Failed to traceroute to $address: $e");
    }
  }

  Future<void> _nslookupAddress(String address) async {
    try {
      ProcessResult result = await Process.run('nslookup', [address]);
      _addOutputWidget(Text(result.stdout));
    } catch (e) {
      _addErrorOutput("Failed to nslookup $address: $e");
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

  void _addOutputWidget(Widget widget) {
    setState(() {
      _output.add(widget);
      _scrollToBottom();
    });
  }

  void _addCommandOutput(String command) {
    _addOutputWidget(Text("$username@launcher\$ $command"));
  }

  void _addErrorOutput(String message) {
    _addOutputWidget(Text(message, style: TextStyle(color: Colors.red)));
  }

  void _scrollToBottom() {
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _output.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: _output[index],
                  );
                },
              ),
            ),
            Divider(color: Colors.white),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commandController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Enter command...',
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                      onSubmitted: (command) {
                        _executeCommand(command);
                        _commandController.clear();
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      _executeCommand(_commandController.text);
                      _commandController.clear();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commandController.dispose();
    _uptimeTimer?.cancel();
    super.dispose();
  }
}

