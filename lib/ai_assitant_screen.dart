import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'ai_assistant_service.dart'; // Your AI assistant service class

class AIAssistantScreen extends StatefulWidget {
  @override
  _AIAssistantScreenState createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  AIAssistantService _aiAssistantService = AIAssistantService();
  File? _selectedImage;
  String? _imageAnalysisResult; // Store image analysis result
  bool _isTyping = false; // Track if AI is typing
  String _aiTypingText = ''; // To display AI typing effect
  String _thinkingDots = ''; // For showing the thinking dots

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Add welcome message
  void _addWelcomeMessage() {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': 'Welcome! I’m here to assist you with application development. Feel free to tell me about your business needs or share an image related to your interest.'
      });
    });
  }

  // Scroll to bottom of the ListView
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Helper function to detect language and return appropriate text style
  TextStyle getTextStyle(String text) {
    if (_isChinese(text)) {
      return TextStyle(fontFamily: 'NotoSansSC', fontSize: 18);
    } else if (_isArabic(text) || _isTurkish(text)) {
      return TextStyle(fontFamily: 'NotoSans', fontSize: 18); // Use a general NotoSans font
    } else {
      // Default to NotoSans for other languages
      return TextStyle(fontFamily: 'NotoSans', fontSize: 18);
    }
  }

  bool _isChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  bool _isArabic(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(text);
  }

  bool _isTurkish(String text) {
    return RegExp(r'[şŞıİçÇğĞöÖüÜ]').hasMatch(text);
  }




  // Pick an image and start analysis
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _messages.add({
          'role': 'user',
          'content': '[Image uploaded]', // Placeholder text
          'image': _selectedImage?.path,
          'isUploading': true, // Track individual upload state
        });
      });

      // Analyze the image using Imagga API
      String imageAnalysis = await analyzeImage(_selectedImage!);

      // Store the image analysis for future use, update the message's upload state
      setState(() {
        _imageAnalysisResult = imageAnalysis; // Store the result for later AI use
        _messages[_messages.length - 1]['isUploading'] = false; // Update the message's upload state
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  // Analyze the image with Imagga API
  Future<String> analyzeImage(File imageFile) async {
    final String apiKey = "acc_6f050ab089fd18c"; // Replace with your API key
    final String apiSecret = "4a49ffaac672d5223520cc1016b4a871"; // Replace with your API secret
    final String apiUrl = "https://api.imagga.com/v2/tags";

    var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
    String basicAuth = 'Basic ' + base64Encode(utf8.encode('$apiKey:$apiSecret'));
    request.headers['Authorization'] = basicAuth;
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      final result = await http.Response.fromStream(response);
      final Map<String, dynamic> jsonResponse = jsonDecode(result.body);

      if (jsonResponse['result'] != null && jsonResponse['result']['tags'] != null) {
        List<dynamic> tags = jsonResponse['result']['tags'];
        String parsedResult = "Detected tags:\n";

        for (var tag in tags) {
          String tagName = tag['tag']['en'];
          double confidence = tag['confidence'];
          parsedResult += "$tagName (Confidence: ${confidence.toStringAsFixed(2)}%)\n";
        }
        return parsedResult;
      } else {
        return "No tags found";
      }
    } else {
      return 'Error: ${response.statusCode}';
    }
  }

  // Send message and incorporate image analysis if available
  Future<void> _sendMessage() async {
    String userMessage = _controller.text;
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(); // Scroll to the bottom after sending a message
    });

    // Show thinking dots animation
    setState(() {
      _isTyping = true; // Set AI as typing
      _thinkingDots = ''; // Reset the thinking dots
    });

    // Show thinking animation for 2 seconds before starting to type the response
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: 500), () {
        setState(() {
          _thinkingDots += '.';
        });
      });
    }

    // Send user question along with image analysis if available
    String aiResponse;
    if (_imageAnalysisResult != null) {
      aiResponse = await _aiAssistantService.getAIResponse(
        "User message: $userMessage\nImage analysis: $_imageAnalysisResult",
        isFirstInteraction: false,
      );
    } else {
      aiResponse = await _aiAssistantService.getAIResponse(userMessage, isFirstInteraction: false);
    }

    // Start typing effect
    _startTypingEffect(aiResponse);
  }

  // Typing effect function to display AI response character by character
  void _startTypingEffect(String aiResponse) async {
    setState(() {
      _isTyping = true; // Set AI as typing
      _aiTypingText = ''; // Start with empty text
      _thinkingDots = ''; // Clear the thinking dots
    });

    // Simulate typing by adding one character at a time
    for (int i = 0; i < aiResponse.length; i++) {
      await Future.delayed(Duration(milliseconds: 50)); // Delay between characters
      setState(() {
        _aiTypingText += aiResponse[i]; // Add one character at a time
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }

    // After typing effect finishes, mark AI as no longer typing and store the response
    setState(() {
      _isTyping = false;
      _messages.add({'role': 'assistant', 'content': _aiTypingText});
      _aiTypingText = ''; // Clear the temporary text
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(); // Scroll to the bottom after AI response
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Assistant')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Column(
            children: [
              Expanded(
                child: DefaultTextStyle(
                  style: TextStyle(fontFamily: 'NotoSans', fontSize: 18), // Default font for the entire chat area
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length + (_isTyping ? 1 : 0), // Add extra item for typing effect
                    itemBuilder: (context, index) {

                      if (index == _messages.length && _isTyping) {
                        // Show thinking dots or typing indicator
                        return Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(10),
                          margin: EdgeInsets.symmetric(vertical: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: MediaQuery.of(context).size.width, // Full width for AI response
                                height: 100, // Set specific height for the card
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    _thinkingDots.isEmpty ? _aiTypingText : _thinkingDots,
                                    style: getTextStyle(_thinkingDots.isEmpty ? _aiTypingText : _thinkingDots),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final message = _messages[index];
                      bool isUser = message['role'] == 'user';

                      // Show uploaded image for user instead of text if available
                      if (message.containsKey('image')) {
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            padding: EdgeInsets.all(10),
                            margin: EdgeInsets.symmetric(vertical: 5),
                            child: message['isUploading']
                                ? Container(
                              width: MediaQuery.of(context).size.width * 0.75, // Three-quarters of the screen
                              height: 200, // Adjust the height as needed
                              color: Colors.grey[300],
                              child: Center(
                                child: CircularProgressIndicator(), // Show progress indicator for image upload
                              ),
                            )
                                : Image.file(
                              File(message['image']!),
                              width: MediaQuery.of(context).size.width * 0.75, // Three-quarters of the screen
                              height: 200, // Adjust the height as needed
                            ),
                          ),
                        );
                      }

                      // Display user and assistant messages
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.all(10),
                          margin: EdgeInsets.symmetric(vertical: 5),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blue[100] : Colors.green[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            message['content'] ?? '',
                            style: getTextStyle(message['content'] ?? ''),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              _buildTextInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextInputArea() {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.photo),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1, // Minimum number of lines to display
              maxLines: 5, // Maximum number of lines to display
              style: TextStyle(fontFamily: 'NotoSans', fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[300],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
