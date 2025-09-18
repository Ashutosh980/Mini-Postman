import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:curl_parser/curl_parser.dart';
import 'dart:convert';

import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';

void main() {
  runApp(const ApiTesterApp());
}

class ApiTesterApp extends StatelessWidget {
  const ApiTesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Postman Clone',
      theme: ThemeData.dark(useMaterial3: true),
      home: const ApiTesterPage(),
    );
  }
}

class ApiTesterPage extends StatefulWidget {
  const ApiTesterPage({super.key});

  @override
  State<ApiTesterPage> createState() => _ApiTesterPageState();
}
class _ApiTesterPageState extends State<ApiTesterPage> {
  final TextEditingController _curlController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  Map<String, String> editableHeaders = {};
  String requestInfo = '';
  String responseInfo = '';
  String formattedResponse = '';

  // Default selected HTTP method
  String _selectedMethod = "GET";

  String sanitizeCurl(String curl) {
    var cleaned = curl.replaceAll("--location", "");

    final badHeaders = ["user-agent:", "accept-encoding:", "content-length:", "host:"];
    for (var header in badHeaders) {
      cleaned = cleaned.replaceAllMapped(
        RegExp(r"--header\s+'" + header + r"[^']*'"),
        (m) => "",
      );
    }

    cleaned = cleaned.replaceAll("--data-raw", "-d");
    cleaned = cleaned.replaceAll("--data-binary", "-d");
    return cleaned.trim();
  }
  String _prettyPrint(dynamic data) {
  try {
    final jsonBody = data is String ? json.decode(data) : data;
    return const JsonEncoder.withIndent('  ').convert(jsonBody);
  } catch (_) {
    return data.toString(); // fallback for non-JSON
  }
}

  Future<void> _parseAndSend() async {
    final curl = _curlController.text.trim();

    try {
      String url = _urlController.text.trim();
      String method = _selectedMethod;

     if (curl.isNotEmpty) {
  final curlRequest = Curl.parse(sanitizeCurl(curl));

  final detectedMethod = curlRequest.method.isNotEmpty
      ? curlRequest.method
      : _selectedMethod;

  final detectedUrl = curlRequest.uri.toString().isNotEmpty
      ? curlRequest.uri.toString()
      : url;

  setState(() {
    _selectedMethod = detectedMethod; // ✅ dropdown updates now
    _urlController.text = detectedUrl; // auto-fill URL field
    editableHeaders = Map<String, String>.from(curlRequest.headers ?? {});
    _bodyController.text = curlRequest.data?.toString() ?? "";
  });

  // Use these for sending request
  url = detectedUrl;
  method = detectedMethod;
}


      if (url.isEmpty) {
        setState(() => responseInfo = "Error: URL is required");
        return;
      }

      setState(() {
        requestInfo = '''
Method: $method
URL: $url
Headers: $editableHeaders
Body: ${_bodyController.text}
        ''';
        responseInfo = "Sending request...";
      });

      final dio = Dio();
      final response = await dio.request(
        url,
        data: _bodyController.text.isNotEmpty ? jsonDecode(_bodyController.text) : null,
        options: Options(
          method: method,
          headers: editableHeaders,
        ),
      );
final body = _prettyPrint(response.data);

      setState(() {
        responseInfo = '''
Status: ${response.statusCode}
Headers: ${response.headers}
Body: ${response.data}
        ''';

        formattedResponse = body;
      });
    } catch (e) {
      setState(() {
        responseInfo = "Error: $e";
      });
    }
  }

  void _updateHeader(String oldKey, String newKey, String newValue) {
    setState(() {
      editableHeaders.remove(oldKey);
      editableHeaders[newKey] = newValue;
    });
  }

  void _addHeader() {
    setState(() {
      editableHeaders[""] = "";
    });
  }

  void _removeHeader(String key) {
    setState(() {
      editableHeaders.remove(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mini Postman")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Dropdown + URL row
            Row(
              children: [
                DropdownButton<String>(
                  value: _selectedMethod,
                  items: ["GET", "POST", "PUT", "DELETE", "PATCH"]
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedMethod = value;
                      });
                    }
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: "Enter request URL",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Curl input (optional)
            TextField(
              controller: _curlController,
              decoration: const InputDecoration(
                hintText: "Paste your curl command here (optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _parseAndSend,
              child: const Text("Send Request"),
            ),
            const SizedBox(height: 12),

            // Headers + Body + Response
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Editable headers UI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Editable Headers:",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.green),
                          onPressed: _addHeader,
                        ),
                      ],
                    ),
                    ...editableHeaders.entries.map((e) {
                      final keyController = TextEditingController(text: e.key);
                      final valueController = TextEditingController(text: e.value);

                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: keyController,
                              decoration: const InputDecoration(labelText: "Key"),
                              onChanged: (newKey) =>
                                  _updateHeader(e.key, newKey, valueController.text),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: valueController,
                              decoration: const InputDecoration(labelText: "Value"),
                              onChanged: (newVal) =>
                                  _updateHeader(keyController.text, keyController.text, newVal),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeHeader(e.key),
                          ),
                        ],
                      );
                    }),
                    const Divider(),

                    const Text("Editable Body (JSON):",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Edit JSON body here",
                      ),
                      maxLines: 6,
                    ),
                    const Divider(),
                    Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      responseInfo,
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    if (formattedResponse.isNotEmpty) ...[
      const SizedBox(height: 8),
     Container(
  width: double.infinity,
  height: 300, // 🔥 give it a fixed height so it scrolls vertically
  decoration: BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.circular(8),
  ),
  child: SingleChildScrollView(
    scrollDirection: Axis.vertical, // 👈 vertical scrolling
    child: HighlightView(
      formattedResponse,
      language: 'json',
      theme: monokaiSublimeTheme,
      padding: const EdgeInsets.all(12),
      textStyle: const TextStyle(
        fontSize: 14,
        fontFamily: 'monospace',
      ),
    ),
  ),
)

    ],
  ],
),
        //             Builder(
        //   builder: (context) {
        //     String formatted = responseInfo;

        //     // ✅ Try to pretty-print if response is JSON
        //     try {
        //       final jsonObj = jsonDecode(responseInfo);
        //       formatted = const JsonEncoder.withIndent('  ').convert(jsonObj);
        //     } catch (_) {
        //       // not JSON, leave as-is
        //     }

        //     return Container(
        //       width: double.infinity,
        //       padding: const EdgeInsets.all(8),
        //       decoration: BoxDecoration(
        //         color: const Color(0xfff6f8fa),
        //         borderRadius: BorderRadius.circular(8),
        //       ),
        //       child: HighlightView(
        //         formatted,
        //         language: 'json', // syntax highlighting
        //         theme: monokaiSublimeTheme, // you can try vsTheme, atomOneDarkTheme etc.
        //         padding: const EdgeInsets.all(12),
        //         textStyle: const TextStyle(
        //           fontFamily: 'monospace',
        //           fontSize: 14,
        //         ),
        //       ),
        //     );
        //   },
        // ),

                    // const Text("Response:",
                    //     style: TextStyle(fontWeight: FontWeight.bold)),
                    // Text(responseInfo),
                    
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// class _ApiTesterPageState extends State<ApiTesterPage> {
//   final TextEditingController _curlController = TextEditingController();
//   final TextEditingController _bodyController = TextEditingController();

//   Map<String, String> editableHeaders = {};
//   String requestInfo = '';
//   String responseInfo = '';

//   String sanitizeCurl(String curl) {
//     var cleaned = curl.replaceAll("--location", "");

//     final badHeaders = ["user-agent:", "accept-encoding:", "content-length:", "host:"];
//     for (var header in badHeaders) {
//       cleaned = cleaned.replaceAllMapped(
//         RegExp(r"--header\s+'" + header + r"[^']*'"),
//         (m) => "",
//       );
//     }

//     cleaned = cleaned.replaceAll("--data-raw", "-d");
//     cleaned = cleaned.replaceAll("--data-binary", "-d");
//     return cleaned.trim();
//   }

//   Future<void> _parseAndSend() async {
//     final curl = _curlController.text.trim();
//     if (curl.isEmpty) return;

//     try {
//       final curlRequest = Curl.parse(sanitizeCurl(curl));

//       // Load editable headers + body
//       setState(() {
//         editableHeaders = Map<String, String>.from(curlRequest.headers);
//         _bodyController.text = curlRequest.data?.toString() ?? "";
//         requestInfo = '''
// Method: ${curlRequest.method}
// URL: ${curlRequest.uri}
// Headers: ${curlRequest.headers}
// Body: ${curlRequest.data}
//         ''';
//         responseInfo = "Sending request...";
//       });

//       final dio = Dio();
//       final response = await dio.request(
//         curlRequest.uri.toString(),
//         data: _bodyController.text.isNotEmpty ? jsonDecode(_bodyController.text) : null,
//         options: Options(
//           method: curlRequest.method,
//           headers: editableHeaders,
//         ),
//       );

//       setState(() {
//         responseInfo = '''
// Status: ${response.statusCode}
// Headers: ${response.headers}
// Body: ${response.data}
//         ''';
//       });
//     } catch (e) {
//       setState(() {
//         responseInfo = "Error: $e";
//       });
//     }
//   }

//   void _updateHeader(String oldKey, String newKey, String newValue) {
//     setState(() {
//       editableHeaders.remove(oldKey);
//       editableHeaders[newKey] = newValue;
//     });
//   }

//   void _addHeader() {
//     setState(() {
//       editableHeaders[""] = "";
//     });
//   }

//   void _removeHeader(String key) {
//     setState(() {
//       editableHeaders.remove(key);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Mini Postman")),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Curl Input
//             TextField(
//               controller: _curlController,
//               decoration: const InputDecoration(
//                 hintText: "Paste your curl command here",
//                 border: OutlineInputBorder(),
//               ),
//               maxLines: 4,
//             ),
//             const SizedBox(height: 12),
//             ElevatedButton(
//               onPressed: _parseAndSend,
//               child: const Text("Parse & Send"),
//             ),
//             const SizedBox(height: 12),

//             // Editable Headers Section
//             Expanded(
//               child: SingleChildScrollView(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         const Text("Editable Headers:",
//                             style: TextStyle(fontWeight: FontWeight.bold)),
//                         IconButton(
//                           icon: const Icon(Icons.add, color: Colors.green),
//                           onPressed: _addHeader,
//                         ),
//                       ],
//                     ),
//                     ...editableHeaders.entries.map((e) {
//                       final keyController = TextEditingController(text: e.key);
//                       final valueController = TextEditingController(text: e.value);

//                       return Row(
//                         children: [
//                           Expanded(
//                             child: TextField(
//                               controller: keyController,
//                               decoration: const InputDecoration(labelText: "Key"),
//                               onChanged: (newKey) =>
//                                   _updateHeader(e.key, newKey, valueController.text),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: TextField(
//                               controller: valueController,
//                               decoration: const InputDecoration(labelText: "Value"),
//                               onChanged: (newVal) =>
//                                   _updateHeader(keyController.text, keyController.text, newVal),
//                             ),
//                           ),
//                           IconButton(
//                             icon: const Icon(Icons.delete, color: Colors.red),
//                             onPressed: () => _removeHeader(e.key),
//                           ),
//                         ],
//                       );
//                     }),
//                     const Divider(),

//                     // Editable Body
//                     const Text("Editable Body (JSON):",
//                         style: TextStyle(fontWeight: FontWeight.bold)),
//                     TextField(
//                       controller: _bodyController,
//                       decoration: const InputDecoration(
//                         border: OutlineInputBorder(),
//                         hintText: "Edit JSON body here",
//                       ),
//                       maxLines: 6,
//                     ),
//                     const Divider(),

//                     // Response
//                     const Text("Response:",
//                         style: TextStyle(fontWeight: FontWeight.bold)),
//                     Text(responseInfo),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
