import 'package:flutter/material.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  int availableSpots = 10;
  int reservedSpots = 0;

  void _bookSpot() {
    if (reservedSpots < availableSpots) {
      setState(() {
        reservedSpots++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Event Booking")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Available Spots: ${availableSpots - reservedSpots}"),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _bookSpot, child: Text("Book Spot"))
          ],
        ),
      ),
    );
  }
}
