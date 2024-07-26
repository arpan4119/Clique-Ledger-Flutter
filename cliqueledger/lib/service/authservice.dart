import 'dart:convert';

import 'package:cliqueledger/models/auth0_id_token.dart';
import 'package:cliqueledger/utility/constant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart';

class _LoginInfo extends ChangeNotifier {
  var _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  set isLoggedIn(bool value) {
    _isLoggedIn = value;
    notifyListeners();
  }
}

@immutable
class Authservice {
  static final Authservice instance = Authservice._internal();
  factory Authservice() {
    return instance;
  }

  Authservice._internal();

  final _loginInfo = _LoginInfo();
  get loginInfo => _loginInfo;

  final appAuth = FlutterAppAuth();
  Auth0IdToken? idToken;
  String? accessToken;

  FlutterSecureStorage? secureStorage = const FlutterSecureStorage();

  bool isAuthResultValid(TokenResponse? result) {
    return result != null && result.idToken != null;
  }

  init() async {
    if (secureStorage == null) return false;

    final secureRefreshToken =
        await secureStorage!.read(key: REFRESH_TOKEN_KEY);

    print(secureRefreshToken);
    if (secureRefreshToken == null) return false;

    final response = await appAuth.token(TokenRequest(
        AUTH0_CLIENT_ID, AUTH0_REDIRECT_URI,
        issuer: AUTH0_ISSUER, refreshToken: secureRefreshToken));

    final result = await _setLocalVariables(response);

    return result == "Success";
  }

  Future<String> _setLocalVariables(TokenResponse? result) async {
    if (isAuthResultValid(result)) {
      accessToken = result!.accessToken!;
      idToken = parseIdToken(result.idToken!);

      if (secureStorage != null && result.refreshToken != null) {
        await secureStorage!.write(
          key: REFRESH_TOKEN_KEY,
          value: result.refreshToken,
        );
      }
      _loginInfo.isLoggedIn = true;

      return 'Success';
    }
    return 'Something is Wrong!';
  }

  Future<String> login() async {
    final authorizationTokenRequest = AuthorizationTokenRequest(
        AUTH0_CLIENT_ID, AUTH0_REDIRECT_URI,
        issuer: AUTH0_ISSUER,
        scopes: ['openid', 'profile', 'email', 'offline_access'],
        promptValues: ["login"]
        );

    final result =
        await appAuth.authorizeAndExchangeCode(authorizationTokenRequest);

    if (isAuthResultValid(result)) {
      final auth0IdToken = parseIdToken(result!.idToken!);
      print(auth0IdToken);
      _loginInfo.isLoggedIn = true;
    }

    return _setLocalVariables(result);
  }

  Future<void> logout() async {
    if (secureStorage != null) {
      // final request = EndSessionRequest(
      //   idTokenHint: jsonEncode(idToken!.toJson()),
      //   issuer: AUTH0_ISSUER,
      //   postLogoutRedirectUrl: AUTH0_REDIRECT_URI
      // );
      //await appAuth.endSession(request);
      await secureStorage!.delete(key: REFRESH_TOKEN_KEY);
      _loginInfo.isLoggedIn = false;
      
    }
  }

  Auth0IdToken parseIdToken(String idToken) {
    final parts = idToken.split(r'.');

    final Map<String, dynamic> json = jsonDecode(
      utf8.decode(
        base64Url.decode(
          base64Url.normalize(parts[1]), //body
        ),
      ),
    );

    return Auth0IdToken.fromJson(json);
  }
}
