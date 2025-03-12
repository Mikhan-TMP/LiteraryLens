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
  // final TextEditingController _apiTokenController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _selectedReaderType = 'USB';
  int _selectedInterval = 1000;
  // bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _visualNotificationsEnabled = true;

  final List<int> _intervalOptions = [500, 1000, 2000, 3000, 5000];
  final List<String> _readerTypes = ['USB', 'Bluetooth', 'Network'];

  @override
  void initState() {
    super.initState();
    // Initialize with default or saved values
    _apiUrlController.text = 'http://192.168.1.68:8080/api/v1/';
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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // API Configuration Section
          _buildSectionHeader('API Configuration', Icons.api),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEditableField('Koha API URL', _apiUrlController),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Authentication Section
          _buildSectionHeader('Authentication', Icons.security),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'KOHA Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'KOHA Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // RFID Reader Configuration
          _buildSectionHeader('RFID Reader Configuration', Icons.settings_input_antenna),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDropdownField(
                    'Reader Type',
                    _selectedReaderType,
                    _readerTypes,
                    (String? value) {
                      if (value != null) {
                        setState(() => _selectedReaderType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Scan Interval',
                    _selectedInterval,
                    _intervalOptions,
                    (int? value) {
                      if (value != null) {
                        setState(() => _selectedInterval = value);
                      }
                    },
                    suffix: 'ms',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader('Notifications', Icons.notifications),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Sound Notifications'),
                  subtitle: const Text('Play sound when books are found'),
                  secondary: Icon(Icons.volume_up, color: theme.colorScheme.primary),
                  value: _soundEnabled,
                  onChanged: (bool value) {
                    setState(() => _soundEnabled = value);
                    _settingsService.setSoundEnabled(value);
                  },
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Visual Notifications'),
                  subtitle: const Text('Show pop-up when books are found'),
                  secondary: Icon(Icons.visibility, color: theme.colorScheme.primary),
                  value: _visualNotificationsEnabled,
                  onChanged: (bool value) {
                    setState(() => _visualNotificationsEnabled = value);
                    _settingsService.setVisualNotificationsEnabled(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>(
    String label,
    T value,
    List<T> items,
    Function(T?) onChanged, {
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              underline: const SizedBox(),
              items: items.map((T item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(suffix != null ? '$item$suffix' : item.toString()),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _apiUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}