import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'screens/login_screen.dart';
import 'screens/rider_dashboard.dart';
import 'screens/passenger_matching.dart';
import 'screens/onboarding_screen.dart';

void main() {
  runApp(const CoRideApp());
}

class CoRideApp extends StatelessWidget {
  const CoRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Premium Minimalist Smart City Color Palette
    const primaryColor = Color(0xFF101828); // Deep sleek charcoal for a premium feel
    const secondaryColor = Color(0xFF027A48); // Modern sleek emerald (retained some DIU spirit)
    const accentColor = Color(0xFF2E90FA); // Slick modern blue for highlights
    const darkSlate = Color(0xFF1D2939); // Slate for Text
    const backgroundColor = Color(0xFFF9FAFB); // Ultra-clean Off-White

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
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
            bodyColor: darkSlate,
            displayColor: darkSlate,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryColor,
            primary: primaryColor,
            secondary: secondaryColor,
            tertiary: accentColor,
            background: backgroundColor,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: backgroundColor,
          cardTheme: CardThemeData(
            elevation: 8, // Softer, more premium shadow
            shadowColor: Colors.black.withOpacity(0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24), // More rounded corners
            ),
            color: Colors.white,
            surfaceTintColor: Colors.transparent, // Avoid material 3 purple tinting
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            labelStyle: const TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w500, fontSize: 14),
            floatingLabelStyle: const TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: const BorderSide(color: Color(0xFFEAECF0), width: 1.5),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ),
        ),
        home: const OnboardingScreen(),
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
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF101828)),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Authenticating...',
                style: TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w500, fontSize: 14, letterSpacing: 0.5),
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

  Widget _buildFloatingNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _selectedIndex == index;
    const primaryColor = Color(0xFF101828);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isSelected ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                isSelected ? filledIcon : outlineIcon,
                key: ValueKey<bool>(isSelected),
                color: isSelected ? Colors.white : const Color(0xFF98A2B3),
                size: 22,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: isSelected ? Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ) : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows content to flow behind the floating navigation bar
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Container(
          height: 72, // Slightly taller for premium feel
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9), // Glassmorphism base
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFloatingNavItem(0, Icons.home_outlined, Icons.home, 'Commute'),
              _buildFloatingNavItem(1, Icons.add_circle_outline, Icons.add_circle, 'Offer'),
              _buildFloatingNavItem(2, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
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

    const primaryColor = Color(0xFF101828);
    const accentColor = Color(0xFF2E90FA);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          children: [
            // Modern Header Profile Area
            Container(
              padding: const EdgeInsets.only(top: 80, bottom: 40, left: 24, right: 24),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEAECF0), width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 50,
                      backgroundColor: Color(0xFFF2F4F7),
                      child: Icon(Icons.person_outline, size: 48, color: Color(0xFF475467)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?['name'] ?? 'DIU Commuter',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF8FF),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      user?['email'] ?? 'student@diu.edu.bd',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF175CD3), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFEAECF0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF0C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.star_rounded, color: Color(0xFFDC6803), size: 20),
                          ),
                          const SizedBox(height: 16),
                          Text('${user?['rating'] ?? '5.0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: primaryColor)),
                          const Text('Trust Score', style: TextStyle(color: Color(0xFF475467), fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFEAECF0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF027A48), size: 20),
                          ),
                          const SizedBox(height: 16),
                          Text(user?['role'] ?? 'Both', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: primaryColor)),
                          const Text('Account Role', style: TextStyle(color: Color(0xFF475467), fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Profile list items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personal Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFEAECF0)),
                    ),
                    child: Column(
                      children: [
                        _buildProfileTile(
                          icon: Icons.badge_outlined,
                          title: 'Academic ID',
                          value: user?['student_id'] ?? 'Not set',
                        ),
                        const Divider(height: 1, color: Color(0xFFEAECF0)),
                        _buildProfileTile(
                          icon: Icons.phone_android_outlined,
                          title: 'Phone Contact',
                          value: user?['phone'] ?? 'Not set',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text('Ride History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryColor,
                      side: const BorderSide(color: Color(0xFFEAECF0)),
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RideHistoryScreen()));
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('View Past Commutes'),
                  ),
                  const SizedBox(height: 40),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD92D20),
                        side: const BorderSide(color: Color(0xFFFDA29B), width: 1.5),
                        backgroundColor: const Color(0xFFFEF3F2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => authProvider.logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTile({required IconData icon, required String title, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF475467), size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF475467), fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF101828), fontSize: 16)),
            ],
          )
        ],
      ),
    );
  }
}

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RideProvider>(context, listen: false).fetchRideHistory();
    });
  }

  void _showReviewDialog(String rideId, String revieweeId, String revieweeName) {
    int rating = 5;
    String comment = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Rate $revieweeName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Leave a comment (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (val) => comment = val,
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final success = await Provider.of<RideProvider>(context, listen: false).submitReview(rideId, revieweeId, rating, comment);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted!')));
                  }
                },
                child: const Text('Submit Review'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: rideProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : rideProvider.rideHistory.isEmpty
          ? const Center(child: Text('No past rides found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rideProvider.rideHistory.length,
              itemBuilder: (context, index) {
                final ride = rideProvider.rideHistory[index];
                final isRider = ride['rider_id'] == user?['id'];
                // For a passenger, the reviewee is the rider.
                // For a rider, the review logic would need to select a specific passenger, but for simplicity we'll let passengers review riders.

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(ride['status'], style: TextStyle(fontWeight: FontWeight.bold, color: ride['status'] == 'Completed' ? Colors.green : Colors.red)),
                            Text(ride['departure_time'].substring(0, 10)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${ride['origin_name']} ➔ ${ride['destination_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        if (!isRider && ride['status'] == 'Completed')
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _showReviewDialog(ride['id'], ride['rider_id'], ride['rider_name']),
                              child: Text('Review Driver (${ride['rider_name']})'),
                            ),
                          )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
