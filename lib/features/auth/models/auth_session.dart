import 'user_model.dart';

class AuthSession {
  final String token;
  final UserModel user;

  const AuthSession({required this.token, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: (json['token'] ?? json['accessToken'] ?? '') as String,
      user: UserModel.fromJson((json['user'] ?? json) as Map<String, dynamic>),
    );
  }
}
