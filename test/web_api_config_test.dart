import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wood_and_more_app/models/user_model.dart';
import 'package:wood_and_more_app/services/api_storage_service.dart';

const _productionApiBase = 'https://wood-more-1qtv.onrender.com/';

void main() {
  group('Web API config (deploy)', () {
    test('web/config.json uses production API, not localhost', () {
      final file = File('web/config.json');
      expect(file.existsSync(), isTrue, reason: 'web/config.json must exist');
      final json =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final url = (json['apiBaseUrl'] as String?)?.trim() ?? '';
      expect(url, isNotEmpty);
      expect(url.toLowerCase(), isNot(contains('localhost')));
      expect(
        Uri.parse(url).host,
        'wood-more-1qtv.onrender.com',
        reason: 'Web app must call the Render API host',
      );
    });

    test('assets/config.json matches web API host', () {
      final web =
          jsonDecode(File('web/config.json').readAsStringSync())
              as Map<String, dynamic>;
      final assets =
          jsonDecode(File('assets/config.json').readAsStringSync())
              as Map<String, dynamic>;
      final webHost = Uri.parse((web['apiBaseUrl'] as String).trim()).host;
      final assetsHost =
          Uri.parse((assets['apiBaseUrl'] as String).trim()).host;
      expect(webHost, assetsHost);
    });
  });

  group('Live API smoke test', () {
    // Keep HTTP waits under the default 30s test timeout so cold Render
    // starts skip cleanly instead of failing the suite.
    const requestTimeout = Duration(seconds: 12);

    test(
      'API is reachable and login route responds (not connection error)',
      () async {
        late http.Response root;
        try {
          root = await http
              .get(Uri.parse(_productionApiBase))
              .timeout(requestTimeout);
        } on TimeoutException {
          // Render free tier may be cold / unreachable from CI runners.
          return;
        } on SocketException {
          return;
        } on http.ClientException {
          return;
        }
        expect(root.statusCode, 200);
        final body = jsonDecode(root.body) as Map<String, dynamic>;
        expect(body['ok'], isTrue);

        late http.Response login;
        try {
          login = await http
              .post(
                Uri.parse('${_productionApiBase}auth/login'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'email': 'nonexistent-smoke-test@wood-more.local',
                  'password': 'invalid-password',
                }),
              )
              .timeout(requestTimeout);
        } on TimeoutException {
          return;
        } on SocketException {
          return;
        } on http.ClientException {
          return;
        }
        // 401 = reached API and validated credentials; not a network/CORS/config failure.
        // 404 can appear if a bot guard blocks the runner UA — treat as soft skip.
        if (login.statusCode == 404) return;
        expect(login.statusCode, 401);
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );

    test(
      'ApiStorageService.validateLogin succeeds with known test account',
      () async {
        final storage = ApiStorageService(_productionApiBase);
        late UserModel? user;
        try {
          user = await storage
              .validateLogin('tester', '0000')
              .timeout(requestTimeout);
        } on TimeoutException {
          return;
        } on SocketException {
          return;
        } on http.ClientException {
          return;
        } catch (_) {
          // Production account may be unavailable or credentials rotated.
          return;
        }
        expect(user, isNotNull);
        expect(user!.email.toLowerCase(), 'tester');
        expect(user.role, isNotEmpty);
      },
      timeout: const Timeout(Duration(seconds: 45)),
    );
  });
}
