import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/ride_provider.dart';
import 'screens/login_screen.dart';
import 'screens/rider_dashboard.dart';
import 'screens/passenger_matching.dart';
import 'screens/profile_screen.dart';

// VisionOS/iOS 26 Style Colors
const iosBlack = Color(0xFF000000);
const iosDarkGray = Color(0xFF1C1C1E);
const iosOffWhite = Color(0xFFF2F2F7);
const iosWhite = Color(0xFFFFFFFF);
const iosBlue = Color(0xFF0A84FF);
const iosGreen = Color(0xFF30D158);
const iosRed = Color(0xFFFF453A);
const iosTextDark = Color(0xFF000000);
const iosTextLight = Color(0xFFFFFFFF);
const iosGrayText = Color(0xFF8E8E93);

void main() {
  runApp(const CoRideApp());
}

class CoRideApp extends StatelessWidget {
  const CoRideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RideProvider()),
      ],
      child: const CupertinoApp(
        title: 'CoRide',
        debugShowCheckedModeBanner: false,
        theme: CupertinoThemeData(
          brightness: Brightness.dark,
          primaryColor: iosBlue,
          primaryContrastingColor: iosWhite,
          barBackgroundColor: Color(0xAA1C1C1E), // Frosted glass effect placeholder
          scaffoldBackgroundColor: iosBlack,
          textTheme: CupertinoTextThemeData(
            primaryColor: iosBlue,
            textStyle: TextStyle(
              fontFamily: '.SF Pro Text', // Native iOS font fallback
              color: iosTextLight,
              fontSize: 17,
              letterSpacing: -0.4,
            ),
            navTitleTextStyle: TextStyle(
              fontFamily: '.SF Pro Display',
              color: iosTextLight,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
            navLargeTitleTextStyle: TextStyle(
              fontFamily: '.SF Pro Display',
              color: iosTextLight,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.0,
            ),
          ),
        ),
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        final user = authProvider.user;
        if (user == null) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        return AppHub(role: user['role']);
      },
    );
  }
}

class AppHub extends StatefulWidget {
  final String role;
  const AppHub({super.key, required this.role});

  @override
  State<AppHub> createState() => _AppHubState();
}

class _AppHubState extends State<AppHub> {
  @override
  Widget build(BuildContext context) {
    final showBoth = widget.role == 'Both';
    final showRider = widget.role == 'Rider' || showBoth;
    final showPassenger = widget.role == 'Passenger' || showBoth;

    final tabs = <Widget>[];
    final bottomTabs = <BottomNavigationBarItem>[];

    if (showPassenger) {
      tabs.add(const PassengerMatching());
      bottomTabs.add(const BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.search),
        label: 'Ride',
      ));
    }

    if (showRider) {
      tabs.add(const RiderDashboard());
      bottomTabs.add(const BottomNavigationBarItem(
        icon: Icon(CupertinoIcons.car_detailed),
        label: 'Drive',
      ));
    }

    // Profile tab for everyone
    tabs.add(const ProfileScreen());
    bottomTabs.add(const BottomNavigationBarItem(
      icon: Icon(CupertinoIcons.person_crop_circle),
      label: 'Profile',
    ));

    return CupertinoTabScaffold(
      backgroundColor: iosBlack,
      tabBar: CupertinoTabBar(
        backgroundColor: iosDarkGray.withOpacity(0.9),
        activeColor: iosBlue,
        inactiveColor: iosGrayText,
        items: bottomTabs,
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) => tabs[index],
        );
      },
    );
  }
}
