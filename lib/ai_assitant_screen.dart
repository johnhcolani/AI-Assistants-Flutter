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

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  AIAssistantService _aiAssistantService = AIAssistantService();
  File? _selectedImage;
  String? _imageAnalysisResult;
  bool _isTyping = false;
  String _aiTypingText = '';
  String _thinkingDots = '';

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

  void _addWelcomeMessage() {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': 'Welcome! I’m here to assist you with application development. Feel free to tell me about your business needs or share an image related to your interest.'
      });
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _messages.add({
          'role': 'user',
          'content': '[Image uploaded]',
          'image': _selectedImage?.path,
          'isUploading': true,
        });
      });

      String imageAnalysis = await analyzeImage(_selectedImage!);

      setState(() {
        _imageAnalysisResult = imageAnalysis;
        _messages[_messages.length - 1]['isUploading'] = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<String> analyzeImage(File imageFile) async {
    final String apiKey = "acc_6f050ab089fd18c";
    final String apiSecret = "4a49ffaac672d5223520cc1016b4a871";
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

  Future<void> _sendMessage() async {
    String userMessage = _controller.text;
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _controller.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    setState(() {
      _isTyping = true;
      _thinkingDots = '';
    });

    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: 500), () {
        setState(() {
          _thinkingDots += '.';
        });
      });
    }

    String aiResponse;
    if (_imageAnalysisResult != null) {
      aiResponse = await _aiAssistantService.getAIResponse(
        "User message: $userMessage\nImage analysis: $_imageAnalysisResult",
        isFirstInteraction: false,
      );
    } else {
      aiResponse = await _aiAssistantService.getAIResponse(userMessage, isFirstInteraction: false);
    }

    _startTypingEffect(aiResponse);
  }

  void _startTypingEffect(String aiResponse) async {
    setState(() {
      _isTyping = true;
      _aiTypingText = '';
      _thinkingDots = '';
    });

    for (int i = 0; i < aiResponse.length; i++) {
      await Future.delayed(Duration(milliseconds: 50));
      setState(() {
        _aiTypingText += aiResponse[i];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }

    setState(() {
      _isTyping = false;
      _messages.add({'role': 'assistant', 'content': _aiTypingText});
      _aiTypingText = '';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Assistant'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.cyanAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
                      return _buildTypingIndicator();
                    }

                    final message = _messages[index];
                    bool isUser = message['role'] == 'user';

                    if (message.containsKey('image')) {
                      return _buildImageCard(message, isUser);
                    }

                    return _buildMessageCard(message, isUser);
                  },
                ),
              ),
              _buildTextInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10),
      margin: EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        _thinkingDots.isEmpty ? _aiTypingText : _thinkingDots,
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildImageCard(Map<String, dynamic> message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.all(10),
        margin: EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: message['isUploading']
            ? Container(
          width: MediaQuery.of(context).size.width * 0.75,
          height: 200,
          color: Colors.grey[300],
          child: Center(child: CircularProgressIndicator()),
        )
            : Image.file(
          File(message['image']!),
          width: MediaQuery.of(context).size.width * 0.75,
          height: 200,
        ),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.all(20),
        margin: EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(colors: [Colors.blue[100]!, Colors.blue[300]!])
              : LinearGradient(colors: [Colors.green[100]!, Colors.green[300]!]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isUser ? Icon(Icons.person, color: Colors.blueAccent) : Icon(Icons.android, color: Colors.green),
            SizedBox(height: 5),
            Text(
              message['content'] ?? '',
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
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
            icon: Icon(Icons.photo, color: Colors.blueAccent),
            onPressed: _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              style: TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: Colors.blueAccent),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
