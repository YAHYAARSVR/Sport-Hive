import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:sport_hive/screens/sportpage.dart';
import 'package:sport_hive/screens/email_verification_screen.dart';
import 'package:sport_hive/screens/admin_page.dart'; // Ensure this exists
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // LOGIN Controllers
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // SIGNUP Controllers
  final TextEditingController _signUpNameController = TextEditingController();
  final TextEditingController _signUpEmailController = TextEditingController();
  final TextEditingController _signUpPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedGender;
  String? _selectedSport;
  DateTime? _selectedDate;
  Uint8List? _profileImage;
  Uint8List? _faceImageBytes;
  bool _isLoading = false;

  final List<String> _sports = [
    'Soccer',
    'Basketball',
    'Tennis',
    'Badminton',
    'Volleyball'
  ];

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // --- Actions ---

  Future<void> _captureFaceIdForSignUp() async {
    final picker = ImagePicker();
    final status = await Permission.camera.request();

    if (!mounted) return;

    if (!status.isGranted) {
      _showErrorDialog('Camera permission is required.');
      return;
    }

    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _faceImageBytes = bytes);
      _showMessageDialog('✅ Face image captured from camera!');
    } else {
      if (!mounted) return;
      _showErrorDialog('No image captured.');
    }
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _profileImage = bytes);
    }
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _signUpEmailController.text.trim(),
        password: _signUpPasswordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        await user.sendEmailVerification();

        String email = _signUpEmailController.text.trim();
        String role = email == "yahyahaitham87@gmail.com" ? "admin" : "user";

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': _signUpNameController.text.trim(),
          'email': email,
          'phone': _phoneController.text.trim(),
          'gender': _selectedGender ?? '',
          'birthDate': _selectedDate?.toIso8601String() ?? '',
          'favoriteSport': _selectedSport ?? 'Not Selected',
          'profileImage':
              _profileImage != null ? base64Encode(_profileImage!) : '',
          'faceImageBase64':
              _faceImageBytes != null ? base64Encode(_faceImageBytes!) : '',
          'role': role,
        });

        if (_faceImageBytes != null) {
          final url = Uri.parse('http://192.168.1.170:5000/api/register-face');
          await http.post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "image": base64Encode(_faceImageBytes!),
              "email": email,
            }),
          );
        }

        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const EmailVerificationScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog(e.toString());
      }
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text.trim(),
      );
      final user = userCredential.user;
      if (user != null && user.emailVerified) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = doc.data();

        if (!mounted) return;

        if (data != null && data['role'] == 'admin') {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const AdminPage()));
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => const SportsPage()));
        }
      } else {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          _showErrorDialog(
              'Please verify your email address before logging in.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithFaceId() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);
      final url = Uri.parse('http://192.168.1.170:5000/api/verify-face');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"image": base64Image}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          String email = data['email'];
          final userCredential =
              await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: "faceid_dummy_password",
          );

          final user = userCredential.user;
          if (user != null && user.emailVerified) {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            final data = doc.data();

            if (!mounted) return;

            if (data != null && data['role'] == 'admin') {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const AdminPage()));
            } else {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const SportsPage()));
            }
          } else {
            if (mounted) _showErrorDialog('Email not verified');
          }
        } else {
          if (mounted) {
            _showErrorDialog(data['message'] ?? 'Face not recognized');
          }
        }
      } else {
        if (mounted) _showErrorDialog('Server error');
      }
    } catch (e) {
      if (mounted) _showErrorDialog(e.toString());
    }
  }

  void _showForgotPasswordDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Enter your email'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isNotEmpty) {
                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  _showMessageDialog('Password reset link sent! Check your email.');
                } catch (e) {
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  _showErrorDialog(e.toString());
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error', style: TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showMessageDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Info'),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Image with dark overlay
        Positioned.fill(
          child: Image.asset('images/background1.jpg', fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),

        // Main Content
        Scaffold(
          backgroundColor: Colors.transparent,
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          Hero(
                            tag: 'logo',
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  )
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'images/logo.webp',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Glassmorphic Card
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: SizedBox(
                                height: 550, // Fixed height for constraints
                                child: DefaultTabController(
                                  length: 2,
                                  child: Column(
                                    children: [
                                      // Tab Bar
                                      Container(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        child: TabBar(
                                          indicatorColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          indicatorWeight: 3,
                                          labelColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          unselectedLabelColor: Colors.grey,
                                          labelStyle: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          tabs: const [
                                            Tab(text: "Log In"),
                                            Tab(text: "Sign Up"),
                                          ],
                                        ),
                                      ),
                                      // Tab Views
                                      Expanded(
                                        child: TabBarView(
                                          children: [
                                            // Login Tab
                                            SingleChildScrollView(
                                              padding: const EdgeInsets.all(24.0),
                                              child: _buildLoginTab(),
                                            ),
                                            // Signup Tab
                                            SingleChildScrollView(
                                              padding: const EdgeInsets.all(24.0),
                                              child: _buildSignUpTab(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLoginTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginEmailController,
          decoration: const InputDecoration(
            labelText: "Email",
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _loginPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Password",
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            child: const Text("Forgot password?"),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _login,
          child: const Text("LOG IN"),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.face),
          label: const Text("Log in with Face ID"),
          onPressed: _loginWithFaceId,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Profile Image Picker
        Center(
          child: GestureDetector(
            onTap: _pickProfileImage,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                image: _profileImage != null
                    ? DecorationImage(
                        image: MemoryImage(_profileImage!), fit: BoxFit.cover)
                    : null,
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              child: _profileImage == null
                  ? Icon(Icons.camera_alt,
                      size: 40, color: Colors.grey[400])
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _signUpNameController,
          decoration: const InputDecoration(
            labelText: "Full Name",
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _signUpEmailController,
          decoration: const InputDecoration(
            labelText: "Email",
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _signUpPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: "Password",
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: "Phone Number",
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 16),

        // Gender Selection
        DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          decoration: const InputDecoration(
            labelText: "Gender",
            prefixIcon: Icon(Icons.people_outline),
          ),
          items: ['Male', 'Female'].map((gender) {
            return DropdownMenuItem(value: gender, child: Text(gender));
          }).toList(),
          onChanged: (val) => setState(() => _selectedGender = val),
        ),
        const SizedBox(height: 16),

        // Sport Selection
        DropdownButtonFormField<String>(
          initialValue: _selectedSport,
          decoration: const InputDecoration(
            labelText: "Favorite Sport",
            prefixIcon: Icon(Icons.sports_soccer),
          ),
          items: _sports.map((sport) {
            return DropdownMenuItem(value: sport, child: Text(sport));
          }).toList(),
          onChanged: (val) => setState(() => _selectedSport = val),
        ),
        const SizedBox(height: 16),

        // Date Picker
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(2000),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: "Date of Birth",
              prefixIcon: Icon(Icons.calendar_today),
            ),
            child: Text(
              _selectedDate == null
                  ? 'Select Date'
                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
            ),
          ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _signUp,
          child: const Text("SIGN UP"),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.face_retouching_natural),
          label: const Text("Register Face ID"),
          onPressed: _captureFaceIdForSignUp,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
