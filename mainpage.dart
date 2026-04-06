import 'package:flutter/material.dart';
import 'package:sport_hive/screens/signinscreen.dart'; 

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Sport Hive',
         style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, 
        elevation: 0,
      ),
      body: Stack(
        children: [
         
          Positioned.fill(
            child: Image.asset(
              'images/background1.jpg', 
              fit: BoxFit.cover,
            ),
          ),
          

          Positioned(
            top: 80, 
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'images/logo.webp', 
                width: 150,  
                height: 150, 
              ),
            ),
          ),
          
         
          Center(
            child: ElevatedButton(
              onPressed: () {
               
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AuthScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: TextStyle(fontSize: 18),
              ),
              child: Text('LoginPage'),
            ),
          ),
        ],
      ),
    );
  }
}
