class Booking {
  final String sportName;
  final String date;
  final String time;
  final String location;
  final String mapLocation;
  final String gender;
  final String price;
  final String ageRange;
  final String players;
  final String imageUrl;
  final bool isTeamMatch;

  Booking({
    required this.sportName,
    required this.date,
    required this.time,
    required this.location,
    required this.mapLocation,
    required this.gender,
    required this.price,
    required this.ageRange,
    required this.players,
    required this.imageUrl,
    this.isTeamMatch = false,
  });

  factory Booking.fromMap(Map<String, dynamic> data) {
    return Booking(
      sportName: data['sportName'] ?? data['sport'] ?? '',
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      location: data['location'] ?? '',
      mapLocation: data['mapLocation'] ?? data['location'] ?? '',
      gender: data['gender'] ?? '',
      price: data['price'] ?? '',
      ageRange: data['ageRange'] ?? '',
      players: data['players'] ?? '0/0',
      imageUrl: data['imageUrl'] ?? 'images/default.jpg',
      isTeamMatch: data['isTeamMatch'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sportName': sportName,
      'date': date,
      'time': time,
      'location': location,
      'mapLocation': mapLocation,
      'gender': gender,
      'price': price,
      'ageRange': ageRange,
      'players': players,
      'imageUrl': imageUrl,
      'isTeamMatch': isTeamMatch,
    };
  }
}
