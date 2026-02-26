import 'dart:convert';
import 'dart:io';

class ApiValidationResult {
  final bool success;
  final String? error;

  const ApiValidationResult({required this.success, this.error});
}

/// Validates an LLM API key by making a lightweight HTTP call to the provider.
/// Returns quickly — uses short timeouts and minimal requests.
Future<ApiValidationResult> validateApiKey({
  required String provider,
  required String apiKey,
  required String model,
  String? apiBase,
}) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  try {
    switch (provider.toLowerCase()) {
      case 'openrouter':
        return await _validateOpenRouter(client, apiKey);
      case 'anthropic':
      case 'claude':
        return await _validateAnthropic(client, apiKey, model);
      case 'openai':
      case 'gpt':
        return await _validateOpenAI(client, apiKey);
      case 'groq':
        return await _validateBearer(
            client, apiKey, 'https://api.groq.com/openai/v1/models');
      case 'deepseek':
        return await _validateBearer(
            client, apiKey, 'https://api.deepseek.com/v1/models');
      case 'sambanova':
        return await _validateBearer(
            client, apiKey, 'https://api.sambanova.ai/v1/models');
      case 'gemini':
      case 'google':
        return await _validateGemini(client, apiKey);
      case 'custom':
        if (apiBase == null || apiBase.isEmpty) {
          return const ApiValidationResult(
              success: false, error: 'Base URL is required');
        }
        return await _validateCustom(client, apiKey, apiBase);
      default:
        return const ApiValidationResult(success: true);
    }
  } on SocketException catch (e) {
    return ApiValidationResult(
      success: false,
      error: 'Network error: ${e.message}',
    );
  } on HttpException catch (e) {
    return ApiValidationResult(
      success: false,
      error: 'HTTP error: ${e.message}',
    );
  } on HandshakeException {
    return const ApiValidationResult(
      success: false,
      error: 'SSL error — check your network connection',
    );
  } catch (e) {
    return ApiValidationResult(
      success: false,
      error: 'Connection failed: $e',
    );
  } finally {
    client.close();
  }
}

Future<ApiValidationResult> _validateOpenRouter(
  HttpClient client,
  String apiKey,
) async {
  final request = await client.getUrl(
    Uri.parse('https://openrouter.ai/api/v1/auth/key'),
  );
  request.headers.set('Authorization', 'Bearer $apiKey');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode == 200) {
    return const ApiValidationResult(success: true);
  }

  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final error = json['error'] ?? json['message'] ?? 'Invalid API key';
    return ApiValidationResult(success: false, error: error.toString());
  } catch (_) {
    return ApiValidationResult(
      success: false,
      error: 'Invalid API key (HTTP ${response.statusCode})',
    );
  }
}

Future<ApiValidationResult> _validateAnthropic(
  HttpClient client,
  String apiKey,
  String model,
) async {
  final request = await client.postUrl(
    Uri.parse('https://api.anthropic.com/v1/messages'),
  );
  request.headers.set('x-api-key', apiKey);
  request.headers.set('anthropic-version', '2023-06-01');
  request.headers.set('content-type', 'application/json');
  request.write(jsonEncode({
    'model':
        model.isNotEmpty ? model : 'claude-sonnet-4-5-20250929',
    'max_tokens': 1,
    'messages': [
      {'role': 'user', 'content': 'hi'}
    ],
  }));

  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode == 200) {
    return const ApiValidationResult(success: true);
  }

  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final error = json['error'] as Map<String, dynamic>?;
    final message = error?['message'] ?? 'Invalid API key';
    return ApiValidationResult(success: false, error: message.toString());
  } catch (_) {
    return ApiValidationResult(
      success: false,
      error: 'Invalid API key (HTTP ${response.statusCode})',
    );
  }
}

Future<ApiValidationResult> _validateOpenAI(
  HttpClient client,
  String apiKey,
) async {
  final request = await client.getUrl(
    Uri.parse('https://api.openai.com/v1/models'),
  );
  request.headers.set('Authorization', 'Bearer $apiKey');
  final response = await request.close();
  await response.drain<void>();

  if (response.statusCode == 200) {
    return const ApiValidationResult(success: true);
  }

  return ApiValidationResult(
    success: false,
    error: response.statusCode == 401
        ? 'Invalid API key'
        : 'Validation failed (HTTP ${response.statusCode})',
  );
}

/// Generic Bearer-token validation via GET /models — works for Groq,
/// DeepSeek, SambaNova, and any OpenAI-compatible provider.
Future<ApiValidationResult> _validateBearer(
  HttpClient client,
  String apiKey,
  String modelsUrl,
) async {
  final request = await client.getUrl(Uri.parse(modelsUrl));
  request.headers.set('Authorization', 'Bearer $apiKey');
  final response = await request.close();
  await response.drain<void>();

  if (response.statusCode == 200) {
    return const ApiValidationResult(success: true);
  }

  return ApiValidationResult(
    success: false,
    error: response.statusCode == 401
        ? 'Invalid API key'
        : 'Validation failed (HTTP ${response.statusCode})',
  );
}

/// Gemini uses query-param auth, not Bearer token.
Future<ApiValidationResult> _validateGemini(
  HttpClient client,
  String apiKey,
) async {
  final url =
      'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey';
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();
  await response.drain<void>();

  if (response.statusCode == 200) {
    return const ApiValidationResult(success: true);
  }

  return ApiValidationResult(
    success: false,
    error: response.statusCode == 400 || response.statusCode == 403
        ? 'Invalid API key'
        : 'Validation failed (HTTP ${response.statusCode})',
  );
}

/// Custom endpoint — try GET {base_url}/models with optional Bearer token.
Future<ApiValidationResult> _validateCustom(
  HttpClient client,
  String apiKey,
  String apiBase,
) async {
  final base = apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase;
  final request = await client.getUrl(Uri.parse('$base/models'));
  if (apiKey.isNotEmpty) {
    request.headers.set('Authorization', 'Bearer $apiKey');
  }
  final response = await request.close();
  await response.drain<void>();

  if (response.statusCode == 200) {
    return const ApiValidationResult(success: true);
  }

  return ApiValidationResult(
    success: false,
    error: 'Could not reach endpoint (HTTP ${response.statusCode})',
  );
}
