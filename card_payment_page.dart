import 'package:flutter/material.dart';
import 'package:sport_hive/screens/sportpage.dart';
import 'profile.dart';
import 'booking_model.dart';
import 'booking_details.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CardPaymentPage extends StatefulWidget {
  final VoidCallback onPaymentSuccess;
  final Booking booking;

  const CardPaymentPage({
    super.key,
    required this.onPaymentSuccess,
    required this.booking,
  });

  @override
  State<CardPaymentPage> createState() => _CardPaymentPageState();
}

class _CardPaymentPageState extends State<CardPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final int _selectedIndex = -1;
  bool _isProcessing = false;

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SportsPage()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfilePage()),
      );
    }
  }

  /// 🔁 استدعاء الـ Stripe server
  Future<bool> _sendPaymentToApi() async {
    // على Android emulator نستخدم 10.0.2.2 بدل localhost
    final url = Uri.parse('http://10.0.2.2:5001/create-payment-intent');

    try {
      // مثال: "7 JD" → "7" → 7 → 700 (cents)
      final priceParts = widget.booking.price.split(' ');
      final rawPrice = priceParts.isNotEmpty ? priceParts[0] : '0';
      final numericPrice =
          int.tryParse(rawPrice.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final amountInCents = numericPrice * 100;

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "amount": amountInCents,
          "currency": "usd",
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        // لو حبيت في المستقبل تستخدم clientSecret:
        // final clientSecret = data['clientSecret'];
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment failed: ${data['message'] ?? 'Unknown error'}',
            ),
          ),
        );
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('API Error: $e')),
      );
      return false;
    }
  }

  Future<void> _saveBookingToFirebase(Booking booking) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cardNumber = _cardNumberController.text.trim();
    final last4 =
        cardNumber.length >= 4 ? cardNumber.substring(cardNumber.length - 4) : '';

    await FirebaseFirestore.instance.collection('bookings').add({
      'userId': user.uid,
      'userEmail': user.email,
      'userName': _nameController.text.trim(),
      'sportName': booking.sportName,
      'location': booking.location,
      'date': booking.date,
      'time': booking.time,
      'players': booking.players,
      'gender': booking.gender,
      'price': booking.price,
      'ageRange': booking.ageRange,
      'imageUrl': booking.imageUrl,
      'mapLocation': booking.mapLocation,
      'cardLast4': last4,
      'cardType': _detectCardType(cardNumber),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updatePlayersInMatchCollection(
      String location, String date, String time, String newPlayers) async {
    final isTeamMatch = widget.booking.isTeamMatch;
    final collection = isTeamMatch ? 'team_matches' : 'sports';
    final snapshot = await FirebaseFirestore.instance
        .collection(collection)
        .where('location', isEqualTo: location)
        .where('date', isEqualTo: date)
        .where('time', isEqualTo: time)
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.update({
        'players': newPlayers,
      });
    }
  }

  Future<void> _updatePlayersInSportCollection(
      String sportName, int addedPlayers) async {
    final sportDocRef =
        FirebaseFirestore.instance.collection('sports').doc(sportName.toLowerCase());

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(sportDocRef);

      if (!snapshot.exists) {
        transaction.set(sportDocRef, {
          'playersCount': addedPlayers,
        });
      } else {
        final currentPlayers = snapshot.get('playersCount') ?? 0;
        transaction.update(sportDocRef, {
          'playersCount': currentPlayers + addedPlayers,
        });
      }
    });
  }

  String _detectCardType(String cardNumber) {
    if (cardNumber.startsWith('4')) return 'Visa';
    if (cardNumber.startsWith('5')) return 'MasterCard';
    if (cardNumber.startsWith('3')) return 'American Express';
    return 'Unknown';
  }

  void _submitPayment() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isProcessing = true);

      bool success = await _sendPaymentToApi();
      if (!success) {
        setState(() => _isProcessing = false);
        return;
      }

      final parts = widget.booking.players.split('/');
      int registered = int.tryParse(parts[0]) ?? 0;
      int capacity = int.tryParse(parts[1]) ?? 0;

      if (widget.booking.isTeamMatch) {
        // حجز فريق واحد = نصف السعة
        registered += (capacity / 2).round();
      } else {
        registered++;
      }

      String updatedPlayers = '$registered/$capacity';
      Booking updatedBooking = Booking(
        sportName: widget.booking.sportName,
        date: widget.booking.date,
        time: widget.booking.time,
        location: widget.booking.location,
        gender: widget.booking.gender,
        price: widget.booking.price,
        ageRange: widget.booking.ageRange,
        players: updatedPlayers,
        imageUrl: widget.booking.imageUrl,
        mapLocation: widget.booking.mapLocation,
        isTeamMatch: widget.booking.isTeamMatch,
      );

      await _saveBookingToFirebase(updatedBooking);
      await _updatePlayersInMatchCollection(
        widget.booking.location,
        widget.booking.date,
        widget.booking.time,
        updatedPlayers,
      );

      await _updatePlayersInSportCollection(widget.booking.sportName, 1);

      widget.onPaymentSuccess();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReservationSuccessPage(booking: updatedBooking),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/background1.jpg',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    _buildBookingInfo(),
                    const SizedBox(height: 20),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.credit_card, color: Colors.amber),
                              SizedBox(width: 10),
                              Text(
                                "Card Payment Form",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextField(
                                        _nameController,
                                        "Full Name Of Card",
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 80,
                                      child: _buildTextField(
                                        _cvvController,
                                        "CVV",
                                        isPassword: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      child: _buildTextField(
                                        _expiryController,
                                        "mm/y",
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildTextField(
                                        _cardNumberController,
                                        "Card Number",
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isProcessing ? null : _submitPayment,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: _isProcessing
                                        ? const CircularProgressIndicator(
                                            color: Colors.black,
                                          )
                                        : const Text(
                                            'Pay',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.white,
        currentIndex: _selectedIndex < 0 ? 1 : _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Pay'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildBookingInfo() {
    IconData icon = Icons.sports;
    final name = widget.booking.sportName.toLowerCase();
    if (name.contains('tennis')) {
      icon = Icons.sports_tennis;
    } else if (name.contains('volleyball')) {
      icon = Icons.sports_volleyball;
    } else if (name.contains('badminton')) {
      icon = Icons.sports_tennis;
    } else if (name.contains('soccer') || name.contains('football')) {
      icon = Icons.sports_soccer;
    } else if (name.contains('basketball')) {
      icon = Icons.sports_basketball;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(
              widget.booking.sportName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          widget.booking.location,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const SizedBox(height: 10),
        _infoRow('Date', widget.booking.date),
        _infoRow('Time', widget.booking.time),
        _infoRow('Players', widget.booking.players.split('/')[0]),
        _infoRow('Price', widget.booking.price),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String labelText,
      {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: labelText == "Card Number" || labelText == "CVV"
          ? TextInputType.number
          : TextInputType.text,
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Required';

        if (labelText == "Full Name Of Card") {
          if (value.trim().split(" ").length < 2) return 'Enter full name';
        } else if (labelText == "Card Number") {
          final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
          if (digitsOnly.length != 16) {
            return 'Card number must be 16 digits';
          }
        } else if (labelText == "CVV") {
          if (value.length != 3 && value.length != 4) {
            return 'CVV must be 3 or 4 digits';
          }
        } else if (labelText == "mm/y") {
          if (!RegExp(r"^(0[1-9]|1[0-2])\/(2[4-9]|[3-9][0-9])$")
              .hasMatch(value)) {
            return 'Use format mm/yy';
          }
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class ReservationSuccessPage extends StatelessWidget {
  final Booking booking;

  const ReservationSuccessPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('images/background.jpeg', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('images/logo.webp', height: 80),
                  const SizedBox(height: 20),
                  const Text(
                    'Reserved',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Icon(Icons.check_circle,
                      size: 100, color: Colors.amber),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 160,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingDetailsPage(
                              booking: booking,
                              onBooked: () {},
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
