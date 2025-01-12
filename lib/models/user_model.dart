class User {
  final int? id;
  String role;
  String username;
  String password;

  User(
      {this.id,
      required this.role,
      required this.username,
      required this.password});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role,
      'username': username,
      'password': password,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      role: map['role'],
      username: map['username'],
      password: map['password'],
    );
  }
}
