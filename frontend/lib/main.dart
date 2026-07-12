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
    // Curated DIU Premium Smart City Color Palette
    const primaryColor = Color(0xFF0F5132); // DIU Dark Forest Green
    const secondaryColor = Color(0xFF00B4D8); // Eye-catching Vibrant Cyan
    const darkSlate = Color(0xFF1E293B); // Navy Slate for Primary Text

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
      ],
      child: MaterialApp(
        title: 'CoRide',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            primary: primaryColor,
            secondary: secondaryColor,
            tertiary: darkSlate,
            background: const Color(0xFFF8F9FA), // Sleek Google Off-White
            surface: Colors.white,
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            color: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
            labelStyle: const TextStyle(color: darkSlate, fontWeight: FontWeight.w500),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          textTheme: const TextTheme(
            headlineMedium: TextStyle(color: darkSlate, fontWeight: FontWeight.bold, fontSize: 26),
            titleLarge: TextStyle(color: darkSlate, fontWeight: FontWeight.w600, fontSize: 18),
            bodyLarge: TextStyle(color: darkSlate, fontSize: 15),
            bodyMedium: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
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
    // Safely trigger auto login after post-frame binding
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
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F5132)),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Connecting to CoRide...',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontSize: 14),
              ),
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
    const primaryColor = Color(0xFF0F5132);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      // Clean Material 3 NavigationBar with pill indicators
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          elevation: 0,
          backgroundColor: Colors.white,
          indicatorColor: primaryColor.withOpacity(0.12),
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.search, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.search, color: primaryColor),
              label: 'Find Ride',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_road, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.add_road, color: primaryColor),
              label: 'Offer Ride',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.person, color: primaryColor),
              label: 'Profile',
            ),
          ],
        ),
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

    const primaryColor = Color(0xFF0F5132);
    const accentColor = Color(0xFF00B4D8);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Profile Banner
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, Color(0xFF1E5E41)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                ),
                Positioned(
                  top: 120,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 54,
                      backgroundColor: primaryColor.withOpacity(0.08),
                      child: const Icon(Icons.school, size: 48, color: primaryColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 64),

            // Profile info
            Text(
              user?['name'] ?? 'DIU Commuter',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                user?['email'] ?? 'student@diu.edu.bd',
                style: const TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Trust Score', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${user?['rating'] ?? '5.0'} ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B))),
                                const Icon(Icons.star, color: Colors.amber, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey.shade200),
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Role', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              user?['role'] ?? 'Both',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile list items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.badge_outlined,
                    title: 'Academic DIU ID',
                    value: user?['student_id'] ?? 'Not set',
                  ),
                  const SizedBox(height: 12),
                  _buildProfileTile(
                    icon: Icons.phone_android_outlined,
                    title: 'Phone Contact',
                    value: user?['phone'] ?? 'Not set',
                  ),
                  const SizedBox(height: 32),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade100, width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => authProvider.logout(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout Session', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F5132).withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF0F5132), size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 14)),
            ],
          )
        ],
      ),
    );
  }
}
