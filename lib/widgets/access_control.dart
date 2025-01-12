import 'package:flutter/material.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/user_model.dart';

class UserAccessControlDialog extends StatefulWidget {
  @override
  _UserAccessControlDialogState createState() =>
      _UserAccessControlDialogState();
}

class _UserAccessControlDialogState extends State<UserAccessControlDialog> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  List<User> _users = [];
  final List<String> _roles = ['Cashier', 'Admin'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final dbHelper = DatabaseHelper.instance;
    final users = await dbHelper.getAllUsers();
    setState(() {
      _users = users;
    });
  }

  Future<void> _addUser() async {
    final dbHelper = DatabaseHelper.instance;
    final user = User(
      username: _usernameController.text,
      password: _passwordController.text,
      role:
          _roleController.text.isNotEmpty ? _roleController.text : _roles.first,
    );
    await dbHelper.insertUser(user);
    _loadUsers();
    _clearFields();
  }

  void _clearFields() {
    _usernameController.clear();
    _passwordController.clear();
    _roleController.clear();
  }

  Future<void> _updateUser(User user) async {
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.updateUser(user);
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Color.fromRGBO(2, 10, 27, 1),
      title: Text('User Access Control', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              labelStyle: TextStyle(color: Colors.white),
            ),
            style: TextStyle(color: Colors.white),
          ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(color: Colors.white),
            ),
            obscureText: true,
            style: TextStyle(color: Colors.white),
          ),
          DropdownButtonFormField<String>(
            value: _roleController.text.isNotEmpty
                ? _roleController.text
                : _roles.first,
            items: _roles
                .map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _roleController.text = value ?? _roles.first;
              });
            },
            decoration: InputDecoration(
              labelText: 'Role',
              labelStyle: TextStyle(color: Colors.white),
            ),
            dropdownColor: Color.fromRGBO(2, 10, 27, 1),
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 20),
          DataTable(
            columns: [
              DataColumn(
                  label:
                      Text('Username', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label:
                      Text('Password', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label: Text('Role', style: TextStyle(color: Colors.white))),
              DataColumn(
                  label:
                      Text('Actions', style: TextStyle(color: Colors.white))),
            ],
            rows: _users.map((user) {
              return DataRow(cells: [
                DataCell(
                  TextField(
                    controller: TextEditingController(text: user.username),
                    style: TextStyle(color: Colors.white),
                    onSubmitted: (value) {
                      user.username = value;
                      _updateUser(user);
                    },
                  ),
                ),
                DataCell(
                  TextField(
                    controller: TextEditingController(text: user.password),
                    style: TextStyle(color: Colors.white),
                    onSubmitted: (value) {
                      user.password = value;
                      _updateUser(user);
                    },
                  ),
                ),
                DataCell(DropdownButton<String>(
                  value: _roles.contains(user.role) ? user.role : _roles.first,
                  items: _roles
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      user.role = value ?? user.role;
                      _updateUser(user);
                    });
                  },
                  dropdownColor: Color.fromRGBO(2, 10, 27, 1),
                  style: TextStyle(color: Colors.white),
                )),
                DataCell(IconButton(
                  icon: Icon(Icons.save, color: Colors.white),
                  onPressed: () => _updateUser(user),
                )),
              ]);
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        TextButton(
          onPressed: _addUser,
          child: Text('Add User', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
