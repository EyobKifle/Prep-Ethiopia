/// Models and Exceptions for the Prep-Ethiopia API.
library api_models;

class AuthResponse {
  final dynamic user;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresAt;
  final String? tokenType;
  final bool? requireSignin;
  final String? message;

  AuthResponse({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.tokenType,
    this.requireSignin,
    this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: json['user'],
      accessToken: json['access_token'] ?? json['token'],
      refreshToken: json['refresh_token'],
      expiresAt: json['expires_at'],
      tokenType: json['token_type'],
      requireSignin: json['require_signin'],
      message: json['message'],
    );
  }
}

class FeatureFlag {
  final String id;
  final String name;
  final bool enabled;

  FeatureFlag({
    required this.id,
    required this.name,
    required this.enabled,
  });

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      enabled: json['enabled'] ?? false,
    );
  }
}

// Custom Exceptions
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});
  
  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException({required super.message})
      : super(statusCode: null);
}

class AuthException extends ApiException {
  AuthException({required super.message})
      : super(statusCode: 401);
}

class RateLimitException extends ApiException {
  RateLimitException({required super.message})
      : super(statusCode: 429);
}

class ServerException extends ApiException {
  final dynamic details;
  
  ServerException({required super.message, this.details})
      : super(statusCode: 500);
}
