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
    final Map<String, dynamic>? data = tag.data;
    if (data != null) {
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Section
          const Text(
            'Inventory Management',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Status: ',
                      style: TextStyle(fontSize: 16),
                    ),
                    if (isSearchingScanner)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Searching for Scanner...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        isReadyToScan ? 'Ready to Scan' : 'Not Ready',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isReadyToScan ? Colors.green : Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Books Scanned: $booksScanned',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),

          // Control Buttons
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: isReadyToScan ? null : _startScanning,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
              ElevatedButton.icon(
                onPressed: isReadyToScan ? _stopScanning : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
              ElevatedButton.icon(
                onPressed: scannedBooks.isEmpty ? null : () {
                  // Add sync functionality
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sync'),
              ),
            ],
          ),

          // Scanned Books List
          const SizedBox(height: 20),
          const Text(
            'Scanned Books',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: scannedBooks.isEmpty
                ? const Center(
                    child: Text('No books scanned yet'),
                  )
                : ListView.builder(
                    itemCount: scannedBooks.length,
                    itemBuilder: (context, index) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(scannedBooks[index]['title'] ?? 'Unknown Title'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${scannedBooks[index]['biblioId']}'),
                              Text('Author: ${scannedBooks[index]['author']}'),
                              Text('ISBN: ${scannedBooks[index]['isbn']}'),
                              Text(
                                'Status: ${scannedBooks[index]['availability']}',
                                style: TextStyle(
                                  color: scannedBooks[index]['availability'] == 'Available' 
                                    ? Colors.green 
                                    : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Timestamp: ${scannedBooks[index]['timestamp']}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}