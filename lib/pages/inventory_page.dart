import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'dart:async';
import '../services/koha_service.dart';
import 'package:intl/intl.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final KohaService _kohaService = KohaService();
  
  bool isReadyToScan = false;
  bool isSearchingScanner = false;  
  int booksScanned = 0;
  List<Map<String, String>> scannedBooks = [];

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  Future<void> _checkNfcAvailability() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NFC is not available on this device'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _processScannedTag(NfcTag tag) async {
    final Map<String, dynamic> data = tag.data;
    try {
      // Extract and convert the RFID value first
      String rfidValue = _kohaService.extractIdentifier(data.toString());
      
      // Extract just the numeric RFID from the debug string
      final RegExp rfidRegex = RegExp(r'Corrected RFID: (\d+)');
      final match = rfidRegex.firstMatch(rfidValue);
      final convertedRfid = match?.group(1) ?? '';

      // Use the converted RFID to fetch book data
      final bookData = await _kohaService.getBookByRfid(convertedRfid);
      
      // // Add debug display
      // showDialog(
      //   context: context,
      //   builder: (context) => AlertDialog(
      //     title: const Text('Book Data Debug Info'),
      //     content: SingleChildScrollView(
      //       child: Column(
      //         crossAxisAlignment: CrossAxisAlignment.start,
      //         mainAxisSize: MainAxisSize.min,
      //         children: [
      //           Text('RFID: $convertedRfid'),
      //           const Divider(),
      //           Text('Raw Book Data:'),
      //           Text(bookData.toString()),
      //         ],
      //       ),
      //     ),
      //     actions: [
      //       TextButton(
      //         onPressed: () => Navigator.pop(context),
      //         child: const Text('Close'),
      //       ),
      //     ],
      //   ),
      // );
      
      setState(() {
        scannedBooks.add({
          'title': bookData?['title'] ?? 'Unknown Title',
          'isbn': bookData?['isbn'] ?? 'No ISBN',
          'author': bookData?['author'] ?? 'Unknown Author',
          'biblioId': bookData?['biblio_id']?.toString() ?? '',
          'availability': bookData?['bookable'] == true ? 'Available' : 'Not Available',
          'timestamp': DateFormat('MMMM d, yyyy \'at\' h:mma').format(DateTime.now()),
        });
        booksScanned++;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('RFID not registered') 
                // ? 'RFID not registered.\nTag data formats:\n${_kohaService.extractIdentifier(data.toString())}'
                ? 'RFID not registered to any book in the database.'
                : 'Error fetching book data',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5), // 
          ),
        );
      }
    }
    }

  Future<void> _startScanning() async {
    setState(() {
      isSearchingScanner = true;
    });

    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        throw Exception('NFC not available');
      }

      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          setState(() {
            isSearchingScanner = false;
            isReadyToScan = true;
          });
          
          await _processScannedTag(tag);
        },
        onError: (error) async {
          setState(() {
            isSearchingScanner = false;
            isReadyToScan = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
      setState(() {
        isSearchingScanner = false;
        isReadyToScan = true;
      });

    } catch (e) {
      setState(() {
        isSearchingScanner = false;
        isReadyToScan = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      await _stopScanning();
    }
  }

  Future<void> _stopScanning() async {
    // Stop NFC session
    await NfcManager.instance.stopSession();
    setState(() {
      isReadyToScan = false;
    });
  }

  @override

  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // Show help dialog
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusCard(),
            _buildControlPanel(),
            _buildScannedBooksList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isReadyToScan ? _stopScanning : _startScanning,
        icon: Icon(isReadyToScan ? Icons.stop : Icons.play_arrow),
        label: Text(isReadyToScan ? 'Stop' : 'Start'),
        backgroundColor: isReadyToScan ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withAlpha((0.8 * 255).toInt()),
            Theme.of(context).primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.3 * 255).toInt()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isReadyToScan ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSearchingScanner ? 'Searching...' : 
                      (isReadyToScan ? 'Scanner Ready' : 'Scanner Off'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$booksScanned books scanned',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (isSearchingScanner) ...[
                const Spacer(),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.refresh,
            label: 'Clear',
            onPressed: scannedBooks.isNotEmpty ? () {
              setState(() {
                scannedBooks.clear();
                booksScanned = 0;
              });
            } : null,
          ),
          _buildActionButton(
            icon: Icons.sync,
            label: 'Sync',
            onPressed: scannedBooks.isNotEmpty ? () {
              // Add sync functionality
            } : null,
          ),
          _buildActionButton(
            icon: Icons.save,
            label: 'Export',
            onPressed: scannedBooks.isNotEmpty ? () {
              // Add export functionality
            } : null,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildScannedBooksList() {
    return Expanded(
      child: scannedBooks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No books scanned yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: scannedBooks.length,
              itemBuilder: (context, index) {
                final book = scannedBooks[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: book['availability'] == 'Available'
                          ? Colors.green[100]
                          : Colors.red[100],
                      child: Icon(
                        Icons.book,
                        color: book['availability'] == 'Available'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    title: Text(
                      book['title'] ?? 'Unknown Title',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(book['author'] ?? 'Unknown Author'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBookDetail('ID', book['biblioId']),
                            _buildBookDetail('ISBN', book['isbn']),
                            _buildBookDetail('Status', book['availability']),
                            _buildBookDetail('Scanned', book['timestamp']),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBookDetail(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}