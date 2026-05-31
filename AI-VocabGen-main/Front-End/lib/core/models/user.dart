class UserModel {
  final int? id;
  final String name;
  final String email;
  final String? level;
  final String? interests;

  const UserModel({
    this.id,
    required this.name,
    required this.email,
    this.level,
    this.interests,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      level: json['level'],
      interests: json['interests'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      if (level != null) 'level': level,
      if (interests != null) 'interests': interests,
    };
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? level,
    String? interests,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      level: level ?? this.level,
      interests: interests ?? this.interests,
    );
  }
}
