import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:scanner/services/setting_service.dart';
// import 'package:vibration/vibration.dart';
import '../services/koha_service.dart';
import 'package:nfc_manager/nfc_manager.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final KohaService _kohaService = KohaService();
  String _searchType = 'title';
  bool _hasSearched = false;
  List<Map<String, String>> _searchResults = [];
  int? _selectedBookIndex;
  bool _isLoading = false;
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> _notifyBookFound() async {
    final settings = SettingsService();

    // Visual notification
    if (await settings.isVisualNotificationsEnabled()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Books found!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    // Sound notification
    if (await settings.isSoundEnabled()) {
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    }

    // // Vibration notification
    // if (await settings.isVibrationEnabled() && 
    //     (await Vibration.hasVibrator() ?? false)) {
    //   Vibration.vibrate(duration: 200);
    // }
  }

  Future<void> _performSearch() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _searchResults = [];
      _selectedBookIndex = null;
    });

    try {
      final results = await _kohaService.searchBooks(
        _searchController.text,
        _searchType,
      );

      setState(() {
        _searchResults = results.map((book) => <String, String>{
          'title': book['title']?.toString() ?? '',
          'author': book['author']?.toString() ?? '',
          'isbn': book['isbn']?.toString() ?? '',
          'biblio_id': book['biblio_id']?.toString() ?? '',
        }).toList();
      });

      if (results.isNotEmpty) {
        await _notifyBookFound();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No results found for your search criteria.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      String errorMessage;
      if (e.toString().contains('status code: 401')) {
        errorMessage = 'Authentication failed. Please check API credentials.';
      } else if (e.toString().contains('status code: 403')) {
        errorMessage = 'Access forbidden. Please check your permissions.';
      } else if (e.toString().contains('status code: 500')) {
        errorMessage = 'Server error. Please try again later.';
      } else if (e.toString().contains('Failed host lookup')) {
        errorMessage = 'Cannot connect to server. Please check your network connection.';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Book Search',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Search Input Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Enter search term...',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _searchController.clear();
                      _searchResults.clear();
                      _hasSearched = false;
                    }),
                  )
                : null,
            ),
          ),
          const SizedBox(height: 16),

          // Search Type Selection
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'title',
                    label: Text('Title'),
                    icon: Icon(Icons.title),
                  ),
                  ButtonSegment<String>(
                    value: 'author',
                    label: Text('Author'),
                    icon: Icon(Icons.person),
                  ),
                  ButtonSegment<String>(
                    value: 'isbn',
                    label: Text('ISBN'),
                    icon: Icon(Icons.qr_code),
                  ),
                ],
                selected: {_searchType},
                onSelectionChanged: (Set<String> selection) {
                  setState(() => _searchType = selection.first);
                },
              ),
            ),
          ),

          // Search and Scan Buttons
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.icon(
                onPressed: _performSearch,
                icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Icon(Icons.search),
                label: Text(_isLoading ? 'Searching...' : 'Search'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    bool isAvailable = await NfcManager.instance.isAvailable();
                    if (!isAvailable) {
                      throw Exception('NFC not available');
                    }

                    setState(() => _isLoading = true);

                    await NfcManager.instance.startSession(
                      onDiscovered: (NfcTag tag) async {
                        try {
                          final Map<String, dynamic>? data = tag.data;
                          if (data != null) {
                            // Extract and convert the RFID value
                            String rfidValue = _kohaService.extractIdentifier(data.toString());
                            
                            // Extract numeric RFID from debug string
                            final RegExp rfidRegex = RegExp(r'Corrected RFID: (\d+)');
                            final match = rfidRegex.firstMatch(rfidValue);
                            final convertedRfid = match?.group(1) ?? '';

                            // Get book data using the RFID
                            final bookData = await _kohaService.getBookByRfid(convertedRfid);
                            
                            if (bookData != null) {
                              setState(() {
                                _searchResults = [{
                                  'title': bookData['title']?.toString() ?? '',
                                  'author': bookData['author']?.toString() ?? '',
                                  'isbn': bookData['isbn']?.toString() ?? '',
                                  'biblio_id': bookData['biblio_id']?.toString() ?? '',
                                }];
                                _hasSearched = true;
                              });
                              
                              await _notifyBookFound();
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().contains('RFID not registered') 
                                  ? 'RFID not registered to any book in the database.'
                                  : 'Error fetching book data: ${e.toString()}',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        } finally {
                          await NfcManager.instance.stopSession();
                          setState(() => _isLoading = false);
                        }
                      },
                    );
                  } catch (e) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Icon(Icons.nfc),
                label: Text(_isLoading ? 'Scanning...' : 'Scan RFID'),
              ),
            ],
          ),

          // Search Results Header
          if (_hasSearched) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _searchResults.isEmpty ? Icons.info : Icons.list_alt,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Found ${_searchResults.length} results',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],

          // Search Results List
          const SizedBox(height: 16),
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Text(
                      _hasSearched ? 'No results found' : 'Search for books',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final book = _searchResults[index];
                      return Card(
                        elevation: 2,
                        color: _selectedBookIndex == index
                            ? theme.colorScheme.primaryContainer
                            : null,
                        child: ListTile(
                          leading: Icon(
                            Icons.book,
                            color: _selectedBookIndex == index
                                ? theme.colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            '${book['biblio_id']} - ${book['title'] ?? ''}',
                            style: theme.textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            '${book['author']} - ${book['isbn']}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          onTap: () => setState(() => _selectedBookIndex = index),
                        ),
                      );
                    },
                  ),
          ),

          // Track Selected Book Button
          if (_selectedBookIndex != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: FilledButton.icon(
                onPressed: () {
                  // Add tracking logic here
                },
                icon: const Icon(Icons.location_on),
                label: const Text('Track Selected Book'),
                style: ButtonStyle(
                  minimumSize: MaterialStateProperty.all(
                    const Size(double.infinity, 48),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}