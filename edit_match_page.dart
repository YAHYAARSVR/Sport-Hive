import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class EditMatchPage extends StatefulWidget {
  final DocumentReference? matchRef;
  final Map<String, dynamic>? matchData;
  final bool isNew;
  final bool isTeamMatch;

  const EditMatchPage({
    super.key,
    this.matchRef,
    this.matchData,
    this.isNew = false,
    this.isTeamMatch = false,
  });

  @override
  State<EditMatchPage> createState() => _EditMatchPageState();
}

class _EditMatchPageState extends State<EditMatchPage> {
  late TextEditingController _timeController;
  late TextEditingController _priceController;
  late TextEditingController _playersController;
  late TextEditingController _dateController;
  String? _gender;
  String? _location;
  String? _sport;
  String? _base64Image;

  final List<String> locations = [
    "National Soccer Stadium",
    "Jordan Field A",
    "Amman Sports Center",
    "Downtown Arena",
    "Al-Hussein Park",
  ];

  final List<String> sports = [
    "Soccer",
    "Basketball",
    "Volleyball",
    "Tennis",
    "Badminton",
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.matchData ?? {};

    _timeController = TextEditingController(text: data['time'] ?? '');
    _priceController = TextEditingController(text: data['price'] ?? '');
    _playersController = TextEditingController(
      text: (data['players']?.toString().split('/')[1]) ?? '0',
    );
    _dateController = TextEditingController(text: data['date'] ?? '');
    _gender = data['gender'] ?? 'Male';

    final loc = data['location'];
    if (loc != null && !locations.contains(loc)) {
      locations.add(loc);
    }
    _location = loc ?? locations.first;

    final spt = data['sport'];
    if (spt != null && !sports.contains(spt)) {
      sports.add(spt);
    }
    _sport = spt ?? sports.first;

    final imageData = data['imageUrl'];
    if (imageData != null && imageData.toString().startsWith('data:image')) {
      _base64Image = imageData;
    }
  }

  @override
  void dispose() {
    _timeController.dispose();
    _priceController.dispose();
    _playersController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _base64Image = 'data:image/png;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(widget.matchData?['date'] ?? '') ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      final formatted =
          "${_dayName(pickedDate.weekday)}, ${pickedDate.day} ${_monthName(pickedDate.month)}, ${pickedDate.year}";
      setState(() {
        _dateController.text = formatted;
      });
    }
  }

  String _dayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Future<void> _saveChanges() async {
    final String? newGender = _gender;
    final String newTime = _timeController.text.trim();
    final String newPrice = _priceController.text.trim();
    final String newPlayersCount = _playersController.text.trim();
    final String newDate = _dateController.text.trim();
    final String newLocation = _location ?? '';
    final String newSport = _sport ?? '';

    if (newTime.isEmpty ||
        newPrice.isEmpty ||
        newPlayersCount.isEmpty ||
        newGender == null ||
        newDate.isEmpty ||
        newLocation.isEmpty ||
        newSport.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      final playerValue =
          widget.isNew
              ? '0/$newPlayersCount'
              : '${widget.matchData?['players'].toString().split('/')[0]}/$newPlayersCount';

      final matchFields = {
        'time': newTime,
        'price': newPrice,
        'gender': newGender,
        'players': playerValue,
        'sport': newSport,
        'location': newLocation,
        'date': newDate,
        'imageUrl':
            _base64Image ??
            widget.matchData?['imageUrl'] ??
            'images/default.jpg',
        'ageRange': widget.matchData?['ageRange'] ?? '16-60',
      };

      if (widget.isNew) {
        final collection = widget.isTeamMatch ? 'team_matches' : 'sports';
        await FirebaseFirestore.instance
            .collection(collection)
            .add(matchFields);
      } else {
        await widget.matchRef!.update(matchFields);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isNew
                ? 'Match added successfully'
                : 'Match updated successfully',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving match: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Add Match' : 'Edit Match'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_base64Image != null)
                Image.memory(
                  base64Decode(_base64Image!.split(',').last),
                  height: 150,
                  fit: BoxFit.cover,
                ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pick Image"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Date'),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _sport,
                decoration: const InputDecoration(labelText: 'Sport'),
                items:
                    sports
                        .map(
                          (sport) => DropdownMenuItem(
                            value: sport,
                            child: Text(sport),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _sport = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _location,
                decoration: const InputDecoration(labelText: 'Location'),
                items:
                    locations
                        .map(
                          (loc) =>
                              DropdownMenuItem(value: loc, child: Text(loc)),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _location = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _timeController,
                decoration: const InputDecoration(labelText: 'Time'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                ],
                onChanged: (value) => setState(() => _gender = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _playersController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max Players'),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: Text(widget.isNew ? 'Add Match' : 'Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
