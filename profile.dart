import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sport_hive/screens/signinscreen.dart';
import 'sportpage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Uint8List? _profileImageBytes;
  String _favoriteSport = 'Badminton';
  String _name = '';
  String _email = '';
  String _phone = '';
  DateTime? _birthDate;
  String _gender = '';

  final Map<String, int> _sportsPlayed = {
    'Badminton': 0,
    'Basketball': 0,
    'Soccer': 0,
    'Tennis': 0,
    'Volleyball': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserBookings();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
        final data = doc.data();

        if (data != null) {
          setState(() {
            _name = data['name'] ?? '';
            _email = data['email'] ?? user.email ?? '';
            _phone = data['phone'] ?? '';
            _gender = data['gender'] ?? '';
            _favoriteSport = data['favoriteSport'] ?? 'Badminton';
            final birthStr = data['birthDate'] ?? '';
            _birthDate =
                birthStr.isNotEmpty ? DateTime.tryParse(birthStr) : null;

            final profileEncoded = data['profileImage'];
            if (profileEncoded != null &&
                profileEncoded is String &&
                profileEncoded.isNotEmpty) {
              _profileImageBytes = base64Decode(profileEncoded);
            }
          });
        }
      } catch (e) {
        print('❌ Error loading user data: $e');
      }
    }
  }

  Future<void> _loadUserBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot =
            await FirebaseFirestore.instance
                .collection('bookings')
                .where('userId', isEqualTo: user.uid)
                .get();

        final countMap = <String, int>{};
        for (var doc in snapshot.docs) {
          final data = doc.data();
          if (!data.containsKey('sport')) continue;
          final rawSport = data['sport'] ?? '';
          final sport = _normalizeSportName(rawSport);
          countMap[sport] = (countMap[sport] ?? 0) + 1;
        }

        setState(() {
          _sportsPlayed.updateAll((key, _) => countMap[key] ?? 0);
        });
      } catch (e) {
        print('❌ Error loading bookings: $e');
      }
    }
  }

  String _normalizeSportName(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.contains('soccer') || normalized.contains('football'))
      return 'Soccer';
    if (normalized.contains('basketball')) return 'Basketball';
    if (normalized.contains('tennis')) return 'Tennis';
    if (normalized.contains('volleyball')) return 'Volleyball';
    if (normalized.contains('badminton')) return 'Badminton';
    return 'Other';
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _profileImageBytes = bytes);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'profileImage': base64Encode(bytes)});
      }
    }
  }

  void _editProfileDialog() {
    final nameController = TextEditingController(text: _name);
    final phoneController = TextEditingController(text: _phone);
    final passwordController = TextEditingController();
    String selectedSport = _favoriteSport;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Edit Profile"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage:
                          _profileImageBytes != null
                              ? MemoryImage(_profileImageBytes!)
                              : const AssetImage('images/profile.jpeg')
                                  as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSport,
                    decoration: const InputDecoration(
                      labelText: 'Favorite Sport',
                    ),
                    items:
                        _sportsPlayed.keys.map((sport) {
                          return DropdownMenuItem(
                            value: sport,
                            child: Text(sport),
                          );
                        }).toList(),
                    onChanged: (val) => selectedSport = val ?? selectedSport,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    if (passwordController.text.trim().isNotEmpty) {
                      await user.updatePassword(passwordController.text.trim());
                    }
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                          'name': nameController.text.trim(),
                          'phone': phoneController.text.trim(),
                          'favoriteSport': selectedSport,
                        });
                    setState(() {
                      _name = nameController.text.trim();
                      _phone = phoneController.text.trim();
                      _favoriteSport = selectedSport;
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("Save Changes"),
              ),
            ],
          ),
    );
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SportsPage()),
      );
    }
  }

  IconData _getSportIcon() {
    switch (_favoriteSport.toLowerCase()) {
      case 'basketball':
        return Icons.sports_basketball;
      case 'soccer':
        return Icons.sports_soccer;
      case 'tennis':
        return Icons.sports_tennis;
      case 'volleyball':
        return Icons.sports_volleyball;
      case 'badminton':
      default:
        return Icons.sports_tennis;
    }
  }

  int _getTotalReservations() {
    return _sportsPlayed.values.fold(0, (sum, value) => sum + value);
  }

  Widget _infoBlock(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange),
        const SizedBox(width: 10),
        Text(
          text.isEmpty ? 'Loading...' : text,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getSportEmoji(String sport) {
    switch (sport.toLowerCase()) {
      case 'basketball':
        return '🏀';
      case 'soccer':
        return '⚽';
      case 'tennis':
        return '🎾';
      case 'volleyball':
        return '🏐';
      case 'badminton':
        return '🏸';
      default:
        return '🏅';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('images/background1.jpg', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage:
                            _profileImageBytes != null
                                ? MemoryImage(_profileImageBytes!)
                                : const AssetImage('images/profile.jpeg')
                                    as ImageProvider,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _name.isEmpty ? 'Loading...' : _name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getSportIcon(), color: Colors.orange, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        _favoriteSport,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _infoBlock(
                              'Reservations',
                              '${_getTotalReservations()}',
                            ),
                            _infoBlock('Favorite', _favoriteSport),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.email, _email),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.phone, _phone),
                        const SizedBox(height: 10),
                        _buildInfoRow(Icons.person, _gender),
                        const SizedBox(height: 10),
                        if (_birthDate != null)
                          _buildInfoRow(
                            Icons.cake,
                            '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}',
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Image.asset(
                              'images/logo.webp',
                              width: 100,
                              height: 100,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children:
                                      _sportsPlayed.entries.map((entry) {
                                        return Text(
                                          '${_getSportEmoji(entry.key)}  ${entry.key}   ${entry.value}',
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        SizedBox(
                          width: screenW,
                          child: ElevatedButton(
                            onPressed: _editProfileDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: screenW,
                          child: ElevatedButton(
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AuthScreen(),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white,
        currentIndex: 2,
        onTap: (index) => _onItemTapped(index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.sports), label: 'Fields'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
