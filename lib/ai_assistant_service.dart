
import 'dart:convert';


import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
class AIAssistantService {

  final String apiKey = dotenv.env['API_KEY'] ?? '';
  final String baseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> getAIResponse(String userPrompt, {required bool isFirstInteraction}) async {
    // Pass userPrompt and instruct the model to ask specific questions and reply in the same language
    String systemPrompt = """
      You are an intelligent AI assistant. Your task is to ask the user about their business needs, 
      explain the benefits of using cross-platform app development, and gather information about 
      their project requirements. 
      You should always respond in the same language as the user's input. Detect the language of the user and answer accordingly.
    """;

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4', // Use GPT-4 or GPT-3.5, depending on your setup
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            // Provide context to the model
            {'role': 'user', 'content': userPrompt},
            // User's input
          ],
          'max_tokens': 200, // Adjust token length if needed
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString();
      } else {
        print('Failed with status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        return 'Failed to get response: ${response.statusCode}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}