// lib/views/home_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final user = FirebaseAuth.instance.currentUser!;

  // Method to handle user logout
  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate back to LoginPage and remove all previous routes
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      // Show error message if logout fails
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout failed: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts Backup'),
        centerTitle: true,
        elevation: 2,
        actions: [
          // Add Logout Button here
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _signOut(context), // Call the sign out method
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // Ensure cards stretch
          children: [
            _buildUserCard(),
            const SizedBox(height: 32),
            _buildActionGrid(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: const Icon(Icons.person, color: Colors.blue),
        ),
        title: Text(
          user.displayName ??
              user.email ??
              'Unknown user', // Show display name if available
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Welcome back!'),
      ),
    );
  }

  // Grid is removed to make space for direct action buttons
  Widget _buildActionGrid(BuildContext context) {
    // You can keep the grid or replace it with direct buttons as shown above
    // If keeping the grid, ensure it doesn't overflow
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true, // Important if inside a Column
      physics: const NeverScrollableScrollPhysics(), // Disable grid scrolling
      children: [
        _buildActionCard(
          icon: Icons.contacts,
          label: 'View Contacts',
          onTap: () => Navigator.pushNamed(context, '/contacts'),
        ),
        _buildActionCard(
          icon: Icons.sms,
          label: 'View SMS',
          onTap: () => Navigator.pushNamed(context, '/sms'),
        ),
        _buildActionCard(
          icon: Icons.favorite,
          label: 'Favorites',
          onTap: () => Navigator.pushNamed(context, '/favorites'),
        ),
        _buildActionCard(
          icon: Icons.info_outline,
          label: 'About',
          onTap: () {
            /* TODO: Implement About Page */
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: Colors.blue),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
