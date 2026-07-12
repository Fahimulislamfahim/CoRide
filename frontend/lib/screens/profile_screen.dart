import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';
import '../main.dart'; // import ios colors

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Profile', style: TextStyle(color: iosTextLight, fontWeight: FontWeight.w700)),
        backgroundColor: iosBlack.withOpacity(0.8),
      ),
      backgroundColor: iosBlack,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: iosBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: iosDarkGray, width: 4),
                ),
                child: Center(
                  child: Text(
                    user?['name']?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 40, color: iosWhite, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                user?['name'] ?? 'User',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: iosTextLight),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(CupertinoIcons.star_fill, color: iosBlue, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${user?['rating'] ?? 5.0} Trust Score',
                    style: const TextStyle(color: iosBlue, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildSectionHeader('Personal Info'),
            Container(
              decoration: BoxDecoration(
                color: iosDarkGray,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildProfileRow(CupertinoIcons.mail, 'Email', user?['email'] ?? ''),
                  _buildDivider(),
                  _buildProfileRow(CupertinoIcons.badge_plus_radiowaves_right, 'Academic ID', user?['student_id'] ?? ''),
                  _buildDivider(),
                  _buildProfileRow(CupertinoIcons.phone, 'Phone', user?['phone'] ?? ''),
                  _buildDivider(),
                  _buildProfileRow(CupertinoIcons.person_crop_circle, 'Role', user?['role'] ?? ''),
                ],
              ),
            ),

            const SizedBox(height: 32),
            _buildSectionHeader('History'),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const RideHistoryScreen()));
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iosDarkGray,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.time, color: iosWhite, size: 20),
                        SizedBox(width: 12),
                        Text('Past Commutes', style: TextStyle(color: iosTextLight, fontSize: 17)),
                      ],
                    ),
                    Icon(CupertinoIcons.chevron_right, color: iosGrayText, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
            CupertinoButton(
              color: iosDarkGray,
              child: const Text('Sign Out', style: TextStyle(color: iosRed, fontWeight: FontWeight.w600)),
              onPressed: () => authProvider.logout(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: iosGrayText, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: iosWhite, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: iosTextLight, fontSize: 17)),
          const Spacer(),
          Text(value, style: const TextStyle(color: iosGrayText, fontSize: 17)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 48),
      height: 1,
      color: const Color(0x33FFFFFF),
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

    showCupertinoDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return CupertinoAlertDialog(
            title: Text('Rate $revieweeName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () => setStateDialog(() => rating = index + 1),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          index < rating ? CupertinoIcons.star_fill : CupertinoIcons.star,
                          color: iosBlue,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                CupertinoTextField(
                  placeholder: 'Optional comment',
                  style: const TextStyle(color: iosTextLight),
                  decoration: BoxDecoration(color: iosDarkGray, borderRadius: BorderRadius.circular(8)),
                  maxLines: 3,
                  onChanged: (val) => comment = val,
                )
              ],
            ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final success = await Provider.of<RideProvider>(context, listen: false).submitReview(rideId, revieweeId, rating, comment);
                  if (success && mounted) {
                    showCupertinoDialog(
                      context: context,
                      builder: (c) => CupertinoAlertDialog(
                        title: const Text('Success'),
                        content: const Text('Review submitted.'),
                        actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.of(c).pop())],
                      )
                    );
                  }
                },
                child: const Text('Submit'),
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

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Ride History', style: TextStyle(color: iosTextLight)),
        backgroundColor: iosBlack.withOpacity(0.8),
        previousPageTitle: 'Profile',
      ),
      backgroundColor: iosBlack,
      child: SafeArea(
        child: rideProvider.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : rideProvider.rideHistory.isEmpty
            ? const Center(child: Text('No past rides found.', style: TextStyle(color: iosGrayText)))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rideProvider.rideHistory.length,
                itemBuilder: (context, index) {
                  final ride = rideProvider.rideHistory[index];
                  final isRider = ride['rider_id'] == user?['id'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: iosDarkGray,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(ride['status'], style: TextStyle(fontWeight: FontWeight.bold, color: ride['status'] == 'Completed' ? iosGreen : iosRed)),
                            Text(ride['departure_time'].substring(0, 10), style: const TextStyle(color: iosGrayText, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${ride['origin_name']} ➔ ${ride['destination_name']}', style: const TextStyle(color: iosTextLight, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        if (!isRider && ride['status'] == 'Completed')
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              color: iosBlue.withOpacity(0.1),
                              padding: EdgeInsets.zero,
                              onPressed: () => _showReviewDialog(ride['id'], ride['rider_id'], ride['rider_name']),
                              child: Text('Review Rider (${ride['rider_name']})', style: const TextStyle(color: iosBlue, fontWeight: FontWeight.w600)),
                            ),
                          )
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
