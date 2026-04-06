import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sport_hive/screens/Soccer.dart';
import 'package:sport_hive/screens/basketball.dart';
import 'package:sport_hive/screens/badminton.dart';
import 'package:sport_hive/screens/tennis.dart';
import 'package:sport_hive/screens/vollyball.dart';
import 'package:sport_hive/screens/profile.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ],
      ),
      body: user?.email == "yahyahaitham87@gmail.com"
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Center(
                  child: Column(
                    children: [
                      Icon(Icons.admin_panel_settings, size: 80, color: Colors.orange),
                      SizedBox(height: 20),
                      Text(
                        'Welcome, Admin!',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'You have full access to all sport pages.',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
                _buildNavButton(context, '⚽ Soccer Page', const SoccerPage()),
                _buildNavButton(context, '🏀 Basketball Page', const BasketballPage()),
                _buildNavButton(context, '🏸 Badminton Page', const BadmintonPage()),
                _buildNavButton(context, '🎾 Tennis Page', const TennisPage()),
                _buildNavButton(context, '🏐 Volleyball Page', const VolleyballPage()),
                _buildNavButton(context, '👤 Profile Page', const ProfilePage()),
              ],
            )
          : const Center(
              child: Text(
                'Access Denied',
                style: TextStyle(fontSize: 20, color: Colors.red),
              ),
            ),
    );
  }

  Widget _buildNavButton(BuildContext context, String title, Widget page) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.arrow_forward_ios),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 18),
        ),
        label: Text(title),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }
}
