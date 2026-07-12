import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'screens/login_screen.dart';
import 'screens/rider_dashboard.dart';
import 'screens/passenger_matching.dart';

void main() {
  runApp(const CoRideApp());
}

class CoRideApp extends StatelessWidget {
  const CoRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F5132); // DIU Green

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
      ],
      child: MaterialApp(
        title: 'CoRide',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading && !authProvider.isAuthenticated) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF0F5132)),
              SizedBox(height: 16),
              Text('Initializing CoRide...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return authProvider.isAuthenticated ? const AppHub() : const LoginScreen();
  }
}

class AppHub extends StatefulWidget {
  const AppHub({super.key});

  @override
  State<AppHub> createState() => _AppHubState();
}

class _AppHubState extends State<AppHub> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    PassengerMatching(),
    RiderDashboard(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0F5132); // DIU Green

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Find Ride',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Offer Ride',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    const primaryColor = Color(0xFF0F5132); // DIU Green

    return Scaffold(
      appBar: AppBar(
        title: const Text('DIU Commuter Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(
              radius: 50,
              backgroundColor: primaryColor,
              child: Icon(Icons.school, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              user?['name'] ?? 'DIU Member',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              user?['email'] ?? 'student@diu.edu.bd',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Rating', style: TextStyle(color: Colors.grey)),
                        Text('${user?['rating'] ?? '5.0'} ★', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Role', style: TextStyle(color: Colors.grey)),
                        Text(user?['role'] ?? 'Both', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.badge, color: primaryColor),
              title: const Text('Academic ID'),
              subtitle: Text(user?['student_id'] ?? 'Not set'),
            ),
            ListTile(
              leading: const Icon(Icons.phone, color: primaryColor),
              title: const Text('Phone Contact'),
              subtitle: Text(user?['phone'] ?? 'Not set'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[800],
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  authProvider.logout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout Session'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
