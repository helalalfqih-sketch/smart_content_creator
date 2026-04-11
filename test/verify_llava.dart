import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

void main() async {
  final uri = Uri.parse('http://127.0.0.1:8001/generate');
  final req = http.MultipartRequest('POST', uri);
  req.fields['prompt'] = 'Test Prompt';
  req.files.add(http.MultipartFile.fromBytes('image', [0,1,2,3], filename: 'test.jpg'));

  try {
    final res = await req.send();
    final body = await res.stream.bytesToString();
    debugPrint('Status: ${res.statusCode}');
    debugPrint('Body: $body');
  } catch (e) {
    debugPrint('Error: $e');
  }
}
