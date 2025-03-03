class UserModel {
  final String id;
  final String name;
  final String email;

  UserModel({required this.id, required this.name, required this.email});

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(id: data['id'], name: data['name'], email: data['email']);
  }
}
