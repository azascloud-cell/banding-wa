class EmailModel {
  final String email;
  final String provider;
  final String sidToken;

  const EmailModel({
    required this.email,
    required this.provider,
    required this.sidToken,
  });

  @override
  String toString() => 'EmailModel(email: $email, provider: $provider)';
}
