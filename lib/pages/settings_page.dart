import 'package:flutter/material.dart';
import '../services/setting_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingsService = SettingsService();
  final TextEditingController _apiUrlController = TextEditingController();
  final TextEditingController _apiTokenController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedReaderType = 'USB';
  int _selectedInterval = 1000;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _visualNotificationsEnabled = true;

  final List<int> _intervalOptions = [500, 1000, 2000, 3000, 5000];
  final List<String> _readerTypes = ['USB', 'Bluetooth', 'Network'];

  @override
  void initState() {
    super.initState();
    // Initialize with default or saved values
    _apiUrlController.text = 'http://192.168.1.68:8080/api/v1/';
    _apiTokenController.text = '**********************';
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final soundEnabled = await _settingsService.isSoundEnabled();
    // final vibrationEnabled = await _settingsService.isVibrationEnabled();
    final visualEnabled = await _settingsService.isVisualNotificationsEnabled();

    setState(() {
      _soundEnabled = soundEnabled;
      // _vibrationEnabled = vibrationEnabled;
      _visualNotificationsEnabled = visualEnabled;
    });
  }

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  _showEditDialog(label, controller);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(String label, TextEditingController controller) {
    final TextEditingController tempController = 
        TextEditingController(text: controller.text);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: tempController,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                controller.text = tempController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          _buildEditableField('Koha API URL', _apiUrlController),
          _buildEditableField('API Token', _apiTokenController),

          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'KOHA Username',
              border: OutlineInputBorder(),
            ),
            obscureText: false,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'KOHA Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),

          const SizedBox(height: 16),
          const Text(
            'RFID Reader Type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          DropdownButton<String>(
            value: _selectedReaderType,
            isExpanded: true,
            items: _readerTypes.map((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedReaderType = newValue;
                });
              }
            },
          ),

          const SizedBox(height: 16),
          const Text(
            'Scan Interval',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          DropdownButton<int>(
            value: _selectedInterval,
            isExpanded: true,
            items: _intervalOptions.map((int interval) {
              return DropdownMenuItem<int>(
                value: interval,
                child: Text('${interval}ms'),
              );
            }).toList(),
            onChanged: (int? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedInterval = newValue;
                });
              }
            },
          ),

          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(
              'Notifications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Sound Notifications'),
            subtitle: const Text('Play sound when books are found'),
            value: _soundEnabled,
            onChanged: (bool value) {
              setState(() => _soundEnabled = value);
              _settingsService.setSoundEnabled(value);
            },
          ),
          SwitchListTile(
            title: const Text('Visual Notifications'),
            subtitle: const Text('Show pop-up when books are found'),
            value: _visualNotificationsEnabled,
            onChanged: (bool value) {
              setState(() => _visualNotificationsEnabled = value);
              _settingsService.setVisualNotificationsEnabled(value);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _apiTokenController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}