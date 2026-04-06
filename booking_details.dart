import 'package:flutter/material.dart';
import 'package:sport_hive/screens/sportpage.dart';
import 'booking_model.dart';
import 'card_payment_page.dart';
import 'profile.dart';
import 'badminton.dart';
import 'tennis.dart';
import 'vollyball.dart';
import 'basketball.dart';
import 'soccer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class BookingDetailsPage extends StatefulWidget {
  final Booking booking;
  final VoidCallback onBooked;

  const BookingDetailsPage({
    super.key,
    required this.booking,
    this.onBooked = _defaultOnBooked,
  });

  static void _defaultOnBooked() {}

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  late int registered;
  late int capacity;
  final int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    final parts = widget.booking.players.split('/');
    registered = int.tryParse(parts[0]) ?? 0;
    capacity = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  }
  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SportsPage()),
      );
    } else if (index == 1) {
      final sport = widget.booking.sportName.toLowerCase();
      if (sport.contains('tennis')) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TennisPage()));
      } else if (sport.contains('volleyball')) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolleyballPage()));
      } else if (sport.contains('basketball')) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BasketballPage()));
      } else if (sport.contains('soccer') || sport.contains('football')) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SoccerPage()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BadmintonPage()));
      }
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    }
  }

  void _openMap(String location) async {
    final query = Uri.encodeComponent(location);
    final googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$query";

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ لم يتم فتح الموقع')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final isTeamMatch = widget.booking.isTeamMatch;
    final collection = isTeamMatch ? 'team_matches' : 'sports';
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'images/background1.jpg',
                fit: BoxFit.cover,
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  SizedBox(
                    height: screenH * 0.28,
                    width: screenW,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            widget.booking.imageUrl,
                            width: screenW,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 16,
                          top: 16,
                          child: Image.asset(
                            'images/logo.webp',
                            height: 40,
                          ),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.booking.date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(widget.booking.time, style: const TextStyle(color: Colors.white)),
                              Text(widget.booking.location, style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _infoCard(Icons.male, 'Gender', widget.booking.gender),
                  _infoCard(Icons.attach_money, 'Price', widget.booking.price),
                  _infoCard(Icons.groups, 'Booking Type', isTeamMatch ? 'Team Match' : 'Individual Match'),
                  _infoCard(Icons.cake, 'Age', widget.booking.ageRange),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(collection)
                        .where('location', isEqualTo: widget.booking.location)
                        .where('date', isEqualTo: widget.booking.date)
                        .where('time', isEqualTo: widget.booking.time)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                        final players = data['players']?.toString().split('/') ?? ['0', '0'];
                        final currentRegistered = int.tryParse(players[0]) ?? 0;
                        final currentCapacity = int.tryParse(players[1]) ?? 0;

                        if (isTeamMatch) {
                          int perTeam = (currentCapacity / 2).round();
                          int team1 = currentRegistered >= perTeam ? perTeam : currentRegistered;
                          int team2 = currentRegistered >= perTeam ? currentRegistered - perTeam : 0;
                          return _infoCard(Icons.people, 'Team Players', 'Team A: $team1 | Team B: $team2');
                        } else {
                          return _infoCard(Icons.people, 'Players', '$currentRegistered/$currentCapacity');
                        }
                      } else {
                        if (isTeamMatch) {
                          int perTeam = (capacity / 2).round();
                          int team1 = registered >= perTeam ? perTeam : registered;
                          int team2 = registered >= perTeam ? registered - perTeam : 0;
                          return _infoCard(Icons.people, 'Team Players', 'Team A: $team1 | Team B: $team2');
                        } else {
                          return _infoCard(Icons.people, 'Players', '$registered/$capacity');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Icon(
                    _sportIcon(),
                    color: Colors.orangeAccent,
                    size: 50,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openMap(widget.booking.mapLocation),
                    child: Column(
                      children: [
                        Image.asset(
                          'images/location2.png',
                          height: screenH * 0.15,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "View Location",
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: registered < capacity ? _bookNow : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: registered < capacity ? Colors.orange : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: registered < capacity
                          ? const Text('BOOK NOW', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                          : const Text('FULL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white,
        currentIndex: _selectedIndex < 0 ? 1 : _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.stadium), label: 'Fields'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.orange, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Text(
            '$title: ',
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  void _bookNow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardPaymentPage(
          booking: widget.booking,
          onPaymentSuccess: () async {
            await _updatePlayerCount();

            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              await FirebaseFirestore.instance.collection('bookings').add({
                'userId': currentUser.uid,
                'sport': widget.booking.sportName.trim().toLowerCase(),
                'location': widget.booking.location,
                'date': widget.booking.date,
                'time': widget.booking.time,
                'timestamp': FieldValue.serverTimestamp(),
              });
            }

            setState(() {
              registered++;
            });
            widget.onBooked();
          },
        ),
      ),
    );
  }

  Future<void> _updatePlayerCount() async {
    try {
      final isTeamMatch = widget.booking.isTeamMatch;
      final collection = isTeamMatch ? 'team_matches' : 'sports';

      final sportDoc = await FirebaseFirestore.instance
          .collection(collection)
          .where('location', isEqualTo: widget.booking.location)
          .where('date', isEqualTo: widget.booking.date)
          .where('time', isEqualTo: widget.booking.time)
          .get();

      if (sportDoc.docs.isNotEmpty) {
        final docRef = sportDoc.docs.first.reference;
        final currentPlayers = sportDoc.docs.first['players']?.toString().split('/') ?? ['0', '0'];
        int registeredPlayers = int.tryParse(currentPlayers[0]) ?? 0;
        int capacityPlayers = int.tryParse(currentPlayers[1]) ?? 0;

        if (registeredPlayers < capacityPlayers) {
          registeredPlayers += 1;
          await docRef.update({'players': '$registeredPlayers/$capacityPlayers'});
        }
      }
    } catch (e) {
      print('Error updating players count: $e');
    }
  }

  IconData _sportIcon() {
    final name = widget.booking.sportName.toLowerCase();
    if (name.contains('tennis')) return Icons.sports_tennis;
    if (name.contains('volleyball')) return Icons.sports_volleyball;
    if (name.contains('badminton')) return Icons.sports_tennis;
    if (name.contains('soccer') || name.contains('football')) return Icons.sports_soccer;
    if (name.contains('basketball')) return Icons.sports_basketball;
    return Icons.sports;
  }
}
