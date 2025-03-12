import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:math' show pow;

// import 'package:shared_preferences/shared_preferences.dart';

class KohaService {
  Future<String> _getApiUrl() async {
    return 'http://192.168.1.68:8080/api/v1';
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    // Hardcoded credentials for testing
    const username = 'admin';
    const password = 'Zxcqwe123\$';
    
    String basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    return {
      'Authorization': basicAuth,
      'koha-authorization': '{"permissions":{"catalogue":"1"}}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Cookie': 'CGISESSID=YOUR_SESSION_ID',
      
    };
  }

  Future<Map<String, dynamic>?> getBookByRfid(String rfid) async {
    try {
      final apiUrl = await _getApiUrl();
      final headers = await _getAuthHeaders();
      if (kIsWeb) {
        headers['Access-Control-Allow-Origin'] = '*';
        headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS';
        headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization';
      }
      
      // First, get the item details using external_id
      final itemUrl = Uri.parse('$apiUrl/items?external_id=$rfid');
      final itemResponse = await http.get(itemUrl, headers: headers);

      if (itemResponse.statusCode == 200) {
        final itemData = json.decode(itemResponse.body);
        if (itemData.isEmpty) {
          throw 'RFID not registered to any book in the database';
        }

        final item = itemData[0];
        final biblioId = item['biblio_id'];
        
        // Add validation for biblioId
        if (biblioId == null || biblioId.toString().isEmpty) {
          return {
            'title': 'Error: No Biblio ID',
            'author': 'Debug Info:',
            'isbn': 'Item Data: ${json.encode(item)}',
            'biblio_id': 'biblioId: $biblioId',
            'publication_year': 'Status: Missing biblioId',
            'publisher': 'RFID: $rfid',
            'bookable': false,
          };
        }

        final isBookable = item['bookable'] ?? false;
        final biblioUrl = Uri.parse('$apiUrl/biblios/$biblioId');
        final biblioResponse = await http.get(biblioUrl, headers: headers);

        if (biblioResponse.statusCode == 200) {
          final biblioData = json.decode(biblioResponse.body);
          return {
            'title': biblioData['title'] ?? 'Unknown Title',
            'author': biblioData['author'] ?? 'Unknown Author',
            'isbn': biblioData['isbn'] ?? 'No ISBN',
            'biblio_id': biblioData['biblio_id']?.toString(),
            'publication_year': biblioData['publication_year'],
            'publisher': biblioData['publisher'],
            'bookable': isBookable,
          };
        } else {
          throw 'Failed to fetch book details';
        }
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }


  /// Extracts the identifier from the raw RFID data.
  ///
  /// The RFID data is expected to be in the format:
  ///   identifier: [byte1, byte2, ...]
  ///
  /// The function will extract the bytes, reverse them for little-endian order, and
  /// convert them to a single integer. If the bytes are not in the correct format,
  /// the original RFID data is returned.
  ///
  /// The returned string contains the original RFID data, the reversed bytes in
  /// hex format, the selected bytes in hex format, and the final integer value
  /// in decimal format. This is for debugging purposes only.
  ///
  /// For example, if the input is:
  ///   identifier: [0x01, 0x02, 0x03, 0x04]
  ///
  /// The returned string will be:
  ///   Hex: 01 02 03 04
  ///   Reversed: 04 03 02 01
  ///   Little-Endian Bytes: 03 02 01
  ///   Corrected RFID: 66051
  String extractIdentifier(String rfidData) {
    final RegExp identifierRegex = RegExp(r'identifier:\s*\[(.*?)\]');
    final match = identifierRegex.firstMatch(rfidData);
    
    if (match != null) {
      final bytes = match.group(1)?.split(',').map((s) => int.parse(s.trim())).toList() ?? [];
      if (bytes.isNotEmpty) {
        // Convert bytes to hex for debugging
        String hexString = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

        // Reverse the bytes for little-endian order
        final reversedBytes = bytes.reversed.toList();

        // Ensure we extract only the last 3 bytes safely
        final List<int> selectedBytes = reversedBytes.length > 3
            ? reversedBytes.sublist(1, 4)  // Remove first byte and keep last 3
            : reversedBytes.sublist(0, reversedBytes.length); // Fallback if less than 4 bytes

        // Convert selected bytes to a single hex string
        String hexRFID = selectedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
        
        // Convert hex string to decimal
        final rfid = int.parse(hexRFID, radix: 16);

        // Return all formats for debugging
        return 'Hex: $hexString\nReversed: ${reversedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}\nLittle-Endian Bytes: ${selectedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}\nCorrected RFID: $rfid';
      }
    }
    return rfidData;
  }

  /// Converts a list of bytes to a decimal integer.
  ///
  /// This function interprets the given list of bytes as a little-endian
  /// representation of an integer. Each byte in the list is multiplied
  /// by 256 raised to the power of its position in the list, and the
  /// results are summed to get the final integer value.
  ///
  /// - Parameter bytes: A list of integers representing bytes.
  /// - Returns: The integer value represented by the byte list.

  int convertToDecimal(List<int> bytes) {
    int rfid = 0;
    for (var i = 0; i < bytes.length; i++) {
      rfid += bytes[i] * pow(256, i).toInt();
    }
    return rfid;
  }

  Future<List<Map<String, dynamic>>> searchBooks(String searchTerm, String searchType) async {
    try {
      final apiUrl = await _getApiUrl();
      final headers = await _getAuthHeaders();
      
      // Add CORS headers if running on web - same as in getBookByRfid
      if (kIsWeb) {
        headers['Access-Control-Allow-Origin'] = '*';
        headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS';
        headers['Access-Control-Allow-Headers'] = 'Origin, Content-Type, Accept, Authorization';
      }
      
      final queryJson = searchType == 'isbn'
        ? {'isbn': searchTerm}
        : {searchType: {'-like': '%$searchTerm%'}};
      
      final encodedQuery = Uri.encodeQueryComponent(json.encode(queryJson));
      final Uri searchUrl = Uri.parse('$apiUrl/biblios?q=$encodedQuery');
      
      final response = await http.get(searchUrl,headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        return results.map((book) => {
          'title': book['title'] ?? 'Unknown Title',
          'author': book['author'] ?? 'Unknown Author',
          'isbn': book['isbn'] ?? 'No ISBN',
          'biblio_id': book['biblio_id']?.toString(),
        }).toList();
      } else {
        throw 'Search failed with status code: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

}