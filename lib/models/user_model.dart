class UserModel {
  final int id;
  final String username;

  const UserModel({required this.id, required this.username});

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        username: json['username'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'username': username};
}
