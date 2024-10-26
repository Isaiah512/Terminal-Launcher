import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiApi {
  static Future<String> generateContent(String prompt) async {
    await dotenv.load(fileName: ".env");

    final apiKey = dotenv.env['API_KEY'];
    if (apiKey == null) {
      throw Exception('No \$API_KEY environment variable');
    }

    final generationConfig = GenerationConfig(
      maxOutputTokens: 1000,
      temperature: 0.9,
      topP: 0.1,
      topK: 16,
    );

    final model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: apiKey,
      generationConfig: generationConfig,
    );

    final content = [Content.text(prompt)];

    try {
      final response = await model.generateContent(content);
      return response.text ?? '';
    } catch (e) {
      throw Exception('Error generating content: $e');
    }
  }
}

