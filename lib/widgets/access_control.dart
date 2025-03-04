import 'package:digisala_pos/widgets/admin_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:digisala_pos/database/product_db_helper.dart';
import 'package:digisala_pos/models/user_model.dart';

class UserAccessControlDialog extends StatefulWidget {
  final FocusNode searchBarFocusNode;

  const UserAccessControlDialog({Key? key, required this.searchBarFocusNode})
      : super(key: key);
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
    _roleController.text = _roles.first;
  }

  Future<void> _loadUsers() async {
    final dbHelper = DatabaseHelper.instance;
    final users = await dbHelper.getAllUsers();
    setState(() {
      _users = users;
    });
  }

  Future<void> _addUser() async {
    // Request PIN before proceeding
    final authorized = await _showPinDialog();
    if (authorized != true) return;

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Username and password are required');
      return;
    }

    // Check for duplicate username
    if (_users.any((user) => user.username == _usernameController.text)) {
      _showSnackBar('Username already exists. Please choose another username.');
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    final user = User(
      username: _usernameController.text,
      password: _passwordController.text,
      role: _roleController.text,
    );
    await dbHelper.insertUser(user);
    _showSnackBar('User added successfully');
    _loadUsers();
    _clearFields();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: message.contains('error') || message.contains('exists')
            ? Colors.red.shade800
            : Colors.green.shade800,
      ),
    );
  }

  void _clearFields() {
    _usernameController.clear();
    _passwordController.clear();
    _roleController.text = _roles.first;
  }

  Future<void> _updateUser(User user) async {
    // Request PIN before proceeding
    final authorized = await _showPinDialog();
    if (authorized != true) return;

    // Check for duplicate username
    if (_users.any((u) => u.username == user.username && u.id != user.id)) {
      _showSnackBar('Username already exists. Please choose another username.');
      return;
    }

    final dbHelper = DatabaseHelper.instance;
    await dbHelper.updateUser(user);
    _showSnackBar('User updated successfully');
    _loadUsers();
  }

  Future<void> _deleteUser(User user) async {
    // Request PIN before proceeding
    final authorized = await _showPinDialog();
    if (authorized != true) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color.fromRGBO(2, 10, 27, 1),
          title: Text('Confirm Delete', style: TextStyle(color: Colors.white)),
          content: Text('Are you sure you want to delete this user?',
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.blueGrey.withAlpha(200),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Delete', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withAlpha(200),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.deleteUser(user.id!);
      _showSnackBar('User deleted successfully');
      _loadUsers();
    }
  }

  Future<bool?> _showPinDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PinConfirmationDialog(
          onPinComplete: (pin) {
            // PIN validation should be handled in PinConfirmationDialog
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: AlertDialog(
        backgroundColor: Color.fromRGBO(2, 10, 27, 1),
        title: Text(
          'User Access Control',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // New user form
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(10, 20, 40, 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New User',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Color.fromRGBO(5, 15, 35, 1),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Color.fromRGBO(5, 15, 35, 1),
                      ),
                      obscureText: true,
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _roleController.text,
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
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Color.fromRGBO(5, 15, 35, 1),
                      ),
                      dropdownColor: Color.fromRGBO(2, 10, 27, 1),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: Icon(Icons.person_add),
                      label: Text('Add User',
                          style: TextStyle(color: Colors.white)),
                      onPressed: _addUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey.withAlpha(200),
                        shadowColor: Colors.blue,
                        iconColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // User list
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(10, 20, 40, 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        Color.fromRGBO(20, 30, 50, 1),
                      ),
                      columnSpacing: 16,
                      columns: [
                        DataColumn(
                          label: Text('Username',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Password',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Role',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('Actions',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                      rows: List.generate(_users.length, (index) {
                        final user = _users[index];
                        final isFirstRecord = index == 0;

                        return DataRow(cells: [
                          DataCell(
                            isFirstRecord
                                ? Text(
                                    user.username,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  )
                                : TextField(
                                    controller: TextEditingController(
                                        text: user.username),
                                    style: TextStyle(color: Colors.white),
                                    onSubmitted: (value) {
                                      if (value.isEmpty) {
                                        _showSnackBar(
                                            'Username cannot be empty');
                                        return;
                                      }
                                      user.username = value;
                                      _updateUser(user);
                                    },
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                  ),
                          ),
                          DataCell(
                            isFirstRecord
                                ? Text(
                                    '********',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  )
                                : TextField(
                                    controller: TextEditingController(
                                        text: user.password),
                                    style: TextStyle(color: Colors.white),
                                    onSubmitted: (value) {
                                      if (value.isEmpty) {
                                        _showSnackBar(
                                            'Password cannot be empty');
                                        return;
                                      }
                                      user.password = value;
                                      _updateUser(user);
                                    },
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                    ),
                                  ),
                          ),
                          DataCell(
                            isFirstRecord
                                ? Text(
                                    user.role,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  )
                                : DropdownButton<String>(
                                    value: _roles.contains(user.role)
                                        ? user.role
                                        : _roles.first,
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
                                    underline: Container(height: 0),
                                  ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isFirstRecord) ...[
                                  IconButton(
                                    icon: Icon(Icons.save, color: Colors.green),
                                    onPressed: () => _updateUser(user),
                                    tooltip: 'Save',
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteUser(user),
                                    tooltip: 'Delete',
                                  ),
                                ] else
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'Protected',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ]);
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.searchBarFocusNode.requestFocus();
            },
            child: Text('Close', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blueGrey.withAlpha(200),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
