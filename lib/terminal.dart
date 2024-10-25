import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:collection/collection.dart';  

class Terminal extends StatefulWidget {
  const Terminal({super.key});

  @override
  State<Terminal> createState() => _TerminalState();
}

class _TerminalState extends State<Terminal> {
  final TextEditingController _commandController = TextEditingController();
  List<Application> _installedApps = [];
  final List<Widget> _output = [];
  Battery battery = Battery();

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> getDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    String deviceModel = androidInfo.model;
    _addOutputWidget(Text('Device Model: $deviceModel'));
  }

  Future<void> getBatteryPercentage() async {
    int batteryLevel = await battery.batteryLevel;
    _addOutputWidget(Text('Battery Percentage: $batteryLevel%'));
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
      String mainCommand = parts[0];
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
      } else {
        _addOutputWidget(Text("Command not recognized: $command"));
      }
    } else {
      _addOutputWidget(Text("No command entered."));
    }
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
    _addOutputWidget(Text('  - list: List installed apps'));
    _addOutputWidget(Text('  - run <app name>: Run a specific app'));
    _addOutputWidget(Text('  - deviceinfo: Show device information'));
    _addOutputWidget(Text('  - battery: Show battery percentage'));
    _addOutputWidget(Text('  - help: Show this help message'));
  }

  void _addCommandOutput(String command) {
    _output.add(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('guest@launcher:', style: TextStyle(color: Colors.white)),
          Row(
            children: [
              const Text(' ~ \$', style: TextStyle(color: Colors.green)),
              Text(' $command', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  void _addOutputWidget(Widget widget) {
    setState(() {
      _output.add(
        DefaultTextStyle(
          style: const TextStyle(color: Colors.white), 
          child: widget,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              color: Colors.black,
              child: ListView(
                children: _output,
              ),
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: <Widget>[
                const Text(
                  'guest@launcher:',
                  style: TextStyle(color: Colors.white),
                ),
                const Text(
                  ' ~ \$',
                  style: TextStyle(color: Colors.green),
                ),
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Enter a command...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (command) {
                      _executeCommand(command);
                      _commandController.clear();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

