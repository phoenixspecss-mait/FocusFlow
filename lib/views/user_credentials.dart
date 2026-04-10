import 'package:flutter/material.dart';

class form extends StatefulWidget {
  const form({super.key});

  @override
  State<form> createState() => _formState();
}

class _formState extends State<form> {
  late final TextEditingController _name;
  String? selectedBloodGroup;
  final List<String> bloodgroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  @override
  void initState() {
    _name = TextEditingController();
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(padding: EdgeInsetsGeometry.all(20)),
          Center(
            child: Text(
              'User Credentials',
              style: TextStyle(
                fontSize: 30,
                fontFamily: 'medifont',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(padding: EdgeInsetsGeometry.all(30)),
          SizedBox(
            width: 350,
            child: TextField(
              decoration: InputDecoration(
                hint: const Text('Name'),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(padding: EdgeInsets.all(15)),
          SizedBox(
            width: 350,
            child: TextField(
              decoration: InputDecoration(
                hint: const Text('Age'),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(padding: EdgeInsets.all(15)),
          SizedBox(
            width: 350,
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Blood Group',
                border: OutlineInputBorder(), // Makes it a squared box
                prefixIcon: const Icon(Icons.bloodtype, color: Colors.red),
              ),
              initialValue: selectedBloodGroup,
              items: bloodgroups.map((String group) {
                return DropdownMenuItem<String>(
                  value: group,
                  child: Text(group),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  selectedBloodGroup = newValue;
                });
                print('User selected: $newValue');
              },
              validator: (value) =>
                  value == null ? 'Please select a group' : null,
            ),
          ),
          Padding(padding: EdgeInsets.all(15)),
          TextButton(onPressed: () {}, 
          style: TextButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)
            )
          ),
          child: const Text('Submit')
          ),
        ],
      ),
    );
  }
}
