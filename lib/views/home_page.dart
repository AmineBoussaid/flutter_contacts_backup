// lib/views/home_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatelessWidget {
  HomePage({Key? key}) : super(key: key);

  final user = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts Backup'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            _buildUserCard(),
            const SizedBox(height: 32),
            _buildActionGrid(context),
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
          user.email ?? 'Unknown user',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Welcome back!'),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return Expanded(
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildActionCard(
            icon: Icons.upload,
            label: 'Selective Backup',
            onTap: () => Navigator.pushNamed(context, '/backup'),
          ),
          _buildActionCard(
            icon: Icons.download,
            label: 'Selective Restore',
            onTap: () => Navigator.pushNamed(context, '/restore'),
          ),
          _buildActionCard(
            icon: Icons.sms,
            label: 'Backup SMS',
            onTap: () => Navigator.pushNamed(context, '/sms_backup'),
          ),
          _buildActionCard(
            icon: Icons.sms_failed,
            label: 'Restore SMS',
            onTap: () => Navigator.pushNamed(context, '/sms_restore'),
          ),
        ],
      ),
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
