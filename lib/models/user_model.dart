class UserModel {
  final int id;
  final String username;

  const UserModel({required this.id, required this.username});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        // Gunakan num? untuk handle int/double/null dari server
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username};
}
