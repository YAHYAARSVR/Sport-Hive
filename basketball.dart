import 'package:flutter/material.dart';
import 'package:sport_hive/screens/sportpage.dart';
import 'booking_details.dart';
import 'booking_model.dart';
import 'profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_match_page.dart';
import 'package:url_launcher/url_launcher.dart';

class BasketballPage extends StatefulWidget {
  const BasketballPage({super.key});

  @override
  State<BasketballPage> createState() => _BasketballPageState();
}

class _BasketballPageState extends State<BasketballPage> with SingleTickerProviderStateMixin {
  int selectedDayIndex = 0;
  final int _selectedIndex = 1;
  late Map<int, List<int>> registrationCounts;
  bool isAdmin = false;
  late TabController _tabController;

  final List<Map<String, String>> days = [
    {"day": "Sun", "date": "1 Apr"},
    {"day": "Mon", "date": "2 Apr"},
    {"day": "Tue", "date": "3 Apr"},
    {"day": "Wed", "date": "4 Apr"},
    {"day": "Thu", "date": "5 Apr"},
    {"day": "Fri", "date": "6 Apr"},
    {"day": "Sat", "date": "7 Apr"},
  ];

  final List<String> fullDates = [
    "Sunday, 1 April, 2025",
    "Monday, 2 April, 2025",
    "Tuesday, 3 April, 2025",
    "Wednesday, 4 April, 2025",
    "Thursday, 5 April, 2025",
    "Friday, 6 April, 2025",
    "Saturday, 7 April, 2025",
  ];
  final List<int> capacities = [10, 10, 10, 10, 10];

  final List<String> matchImages = [
    'images/basket1.jpg',
    'images/basket2.jpg',
    'images/basket3.jpg',
    'images/basket4.jpg',
    'images/basket5.jpg',
  ];

  final List<String> mapLocations = [
    "https://maps.app.goo.gl/basket1",
    "https://maps.app.goo.gl/basket2",
    "https://maps.app.goo.gl/basket3",
    "https://maps.app.goo.gl/basket4",
    "https://maps.app.goo.gl/basket5",
  ];

  int _monthNumber(String name) {
    const months = {
      'January': 1, 'February': 2, 'March': 3, 'April': 4,
      'May': 5, 'June': 6, 'July': 7, 'August': 8,
      'September': 9, 'October': 10, 'November': 11, 'December': 12
    };
    return months[name] ?? 1;
  }

  @override
  void initState() {
    super.initState();
    registrationCounts = {
      for (int i = 0; i < days.length; i++) i: List.filled(5, 0)
    };
    _tabController = TabController(length: 2, vsync: this);
    checkIfAdmin();
    ensureMatchesExist();
    fetchTotalPlayers();
  }

  Future<void> checkIfAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && doc.exists && doc.data()?['role'] == 'admin') {
        setState(() {
          isAdmin = true;
        });
      }
    }
  }

  Future<void> ensureMatchesExist() async {
    for (int dayIndex = 0; dayIndex < fullDates.length; dayIndex++) {
      for (int matchIndex = 0; matchIndex < 5; matchIndex++) {
        final matchDate = fullDates[dayIndex];
        final matchTime = _getMatchTime(matchIndex);
        final stadium = "National Basketball Arena";

        final snapshot = await FirebaseFirestore.instance
            .collection('sports')
            .where('date', isEqualTo: matchDate)
            .where('time', isEqualTo: matchTime)
            .where('location', isEqualTo: stadium)
            .get();

        if (snapshot.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('sports').add({
            'sport': 'Basketball',
            'date': matchDate,
            'time': matchTime,
            'location': stadium,
            'mapLocation': mapLocations[matchIndex],
            'gender': matchIndex % 2 == 0 ? 'Male' : 'Female',
            'price': matchIndex % 2 == 0 ? '5 JD' : '7 JD',
            'ageRange': '16-60',
            'players': '0/${capacities[matchIndex]}',
            'imageUrl': matchImages[matchIndex],
          });
        }
      }
    }
  }

  Future<void> fetchTotalPlayers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('sports')
        .where('sport', isEqualTo: 'Basketball')
        .get();

    if (snapshot.docs.isNotEmpty) {
      for (var doc in snapshot.docs) {
        String location = doc['location'] ?? '';
        String date = doc['date'] ?? '';
        String time = doc['time'] ?? '';
        String players = doc['players'] ?? '0/0';

        for (int dayIndex = 0; dayIndex < fullDates.length; dayIndex++) {
          if (date == fullDates[dayIndex]) {
            for (int matchIndex = 0; matchIndex < 5; matchIndex++) {
              if (_getMatchTime(matchIndex) == time &&
                  location == "National Basketball Arena") {
                final splitPlayers = players.split('/');
                registrationCounts[dayIndex]![matchIndex] =
                    int.tryParse(splitPlayers[0]) ?? 0;
              }
            }
          }
        }
      }
      if (mounted) setState(() {});
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SportsPage()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
    }
  }

  String _getMatchTime(int index) {
    switch (index) {
      case 0:
        return "7:00 PM - 8:30 PM";
      case 1:
        return "8:45 PM - 10:15 PM";
      case 2:
        return "10:30 PM - 12:00 AM";
      case 3:
        return "12:15 AM - 1:45 AM";
      case 4:
        return "2:00 PM - 3:30 PM";
      default:
        return "Time N/A";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'images/background1.jpg',
            fit: BoxFit.cover,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Basketball Matches', style: TextStyle(color: Colors.white)),
            centerTitle: true,
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.orange,
              tabs: const [
                Tab(text: 'Individual Matches'),
                Tab(text: 'Team Matches'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMatchesTab(collectionName: 'sports', isTeamTab: false),
              _buildMatchesTab(collectionName: 'team_matches', isTeamTab: true),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: Colors.black,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.white,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.sports_basketball), label: 'Fields'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchesTab({
    required String collectionName,
    required bool isTeamTab,
  }) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isTeamTab ? 'Team Matches' : 'Individual Matches',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: Colors.orange, size: 28),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditMatchPage(
                            isNew: true,
                            isTeamMatch: isTeamTab,
                            matchData: {
                              'date': fullDates[selectedDayIndex],
                              'sport': 'Basketball',
                              'location': 'National Basketball Arena',
                              'ageRange': '16-60',
                            },
                          ),
                        ),
                      );
                      if (result == true) {
                        await fetchTotalPlayers();
                        if (mounted) setState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: days.length,
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => setState(() => selectedDayIndex = index),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.only(left: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: index == selectedDayIndex
                        ? Colors.orange
                        : Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(days[index]['day']!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(days[index]['date']!,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  fullDates[selectedDayIndex],
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(collectionName)
                .where('sport', isEqualTo: 'Basketball')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final selectedDate = DateTime(2025, 4, 1)
                  .add(Duration(days: selectedDayIndex));

              final docs = snapshot.data!.docs.where((doc) {
                try {
                  final matchDateStr = doc['date'] ?? '';
                  final parts = matchDateStr.split(',');
                  if (parts.length < 3) return false;

                  final dateParts = parts[1].trim().split(' ');
                  final day = int.tryParse(dateParts[0]) ?? 0;
                  final month = _monthNumber(dateParts[1].trim());
                  final year = int.tryParse(parts[2].trim()) ?? 0;
                  final docDate = DateTime(year, month, day);

                  return docDate.day == selectedDate.day &&
                      docDate.month == selectedDate.month &&
                      docDate.year == selectedDate.year &&
                      doc['location'] == "National Basketball Arena";
                } catch (_) {
                  return false;
                }
              }).toList();

              return Column(
                key: ValueKey<int>(selectedDayIndex),
                children: List.generate(docs.length, (index) {
                  final doc = docs[index];
                  return _buildMatchCard(
                    context: context,
                    docRef: doc.reference,
                    initialData: doc.data() as Map<String, dynamic>,
                    imagePath: matchImages[index % matchImages.length],
                    matchTitle: "Match ${index + 1}",
                    matchIndex: index,
                    isTeamMatch: collectionName == 'team_matches',
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  Widget _buildMatchCard({
    required BuildContext context,
    required DocumentReference docRef,
    required Map<String, dynamic> initialData,
    required String imagePath,
    required String matchTitle,
    required int matchIndex,
    required bool isTeamMatch,
  }) {
    final matchDate = initialData['date'] ?? '';
    final matchTime = initialData['time'] ?? '';
    final stadium = initialData['location'] ?? '';
    final mapLocation = initialData['mapLocation'] ?? stadium;
    final price = initialData['price'] ?? '0 JD';
    final players = initialData['players']?.toString().split('/') ?? ['0', '0'];
    final registered = int.tryParse(players[0]) ?? 0;
    final capacity = int.tryParse(players[1]) ?? 10;
    final teamInfo = matchIndex.isEven ? 'Basketball Club A' : 'Basketball Club B';

    String displayText = isTeamMatch
        ? 'Team A: $registered | Team B: ${capacity - registered}'
        : (registered < capacity
            ? "$registered/$capacity players"
            : "Booking Full");

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: Colors.black.withValues(alpha: 0.3),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 100,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  image: DecorationImage(
                    image: AssetImage(imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(matchDate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(matchTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(matchTime, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(teamInfo, style: const TextStyle(fontSize: 14, color: Colors.white)),
                      Text(stadium, style: const TextStyle(fontSize: 14, color: Colors.white60)),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () async {
                          final Uri url = Uri.parse(mapLocation);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("❌ Could not open the link")),
                              );
                            }
                          }
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.location_pin, color: Colors.orange, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                "Open Map",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.orange,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      displayText,
                      style: TextStyle(
                        color: registered < capacity ? Colors.orange : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: registered < capacity
                          ? () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookingDetailsPage(
                                    booking: Booking(
                                      sportName: 'Basketball',
                                      date: matchDate,
                                      time: matchTime,
                                      location: stadium,
                                      mapLocation: mapLocation,
                                      gender: matchIndex % 2 == 0 ? 'Male' : 'Female',
                                      price: price,
                                      ageRange: '16-60',
                                      players: '$registered/$capacity',
                                      imageUrl: imagePath,
                                      isTeamMatch: isTeamMatch,
                                    ),
                                    onBooked: () async {
                                      await docRef.update({
                                        'players': '${registered + (isTeamMatch ? (capacity ~/ 2) : 1)}/$capacity'
                                      });
                                    },
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: const Text('Join'),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditMatchPage(
                                matchRef: docRef,
                                matchData: initialData,
                              ),
                            ),
                          );
                          if (result == true) {
                            await fetchTotalPlayers();
                            setState(() {});
                          }
                        },
                        child: const Text('Edit'),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () async {
                          await docRef.delete();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Match deleted")),
                            );
                            setState(() {});
                          }
                        },
                        child: const Text('Delete'),
                      ),
                    ]
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
