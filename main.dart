import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/firebase_options.dart';
import 'models/admin_models.dart';
import 'services/admin_data_service.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? startupError;
  try {
    await Firebase.initializeApp(options: AdminFirebaseOptions.web);
  } catch (error) {
    startupError = error;
  }
  runApp(AdminApp(startupError: startupError));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, this.startupError});
  final Object? startupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Corn Guard Admin',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF5F7F4),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B4D)),
      fontFamily: 'Georgia',
    ),
    home: startupError == null
        ? const AuthGate()
        : _StartupError(startupError!),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: AdminAuthService.instance.authStateChanges,
    builder: (context, snapshot) =>
        snapshot.data == null ? const LoginPage() : const AdminShell(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController(text: 'admin');
  final password = TextEditingController(text: 'admin123');
  bool busy = false;
  String? error;

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await AdminAuthService.instance.signIn(username.text, password.text);
    } catch (value) {
      if (mounted) setState(() => error = value.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandMark(),
              const SizedBox(height: 52),
              Text(
                'Welcome back',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF123C2F),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Sign in to monitor your crop health platform.'),
              const SizedBox(height: 32),
              TextField(
                controller: username,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                onSubmitted: (_) => submit(),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.eco, color: Color(0xFF176B4D), size: 34),
      SizedBox(width: 10),
      Text(
        'CORN GUARD',
        style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int index = 0;
  final titles = const [
    'Overview',
    'Users',
    'Detection activity',
    'Admin settings',
  ];

  Widget page() => switch (index) {
    0 => const DashboardPage(),
    1 => const UsersPage(),
    2 => const DetectionsPage(),
    _ => const SettingsPage(),
  };

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 850;
    final navigation = _Navigation(
      selected: index,
      onSelected: (value) {
        setState(() => index = value);
        if (compact) Navigator.pop(context);
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[index],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: AdminAuthService.instance.signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: compact ? Drawer(child: navigation) : null,
      body: Row(
        children: [
          if (!compact) SizedBox(width: 250, child: navigation),
          Expanded(child: page()),
        ],
      ),
    );
  }
}

class _Navigation extends StatelessWidget {
  const _Navigation({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  static const labels = ['Overview', 'Users', 'Detections', 'Settings'];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.people_outline,
    Icons.analytics_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF123C2F),
    padding: const EdgeInsets.fromLTRB(16, 28, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 14, bottom: 36),
          child: Row(
            children: [
              Icon(Icons.eco, color: Color(0xFFB7E3C6)),
              SizedBox(width: 10),
              Text(
                'CORN GUARD',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < labels.length; i++)
          ListTile(
            leading: Icon(
              icons[i],
              color: selected == i
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFB7CFC3),
            ),
            title: Text(
              labels[i],
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected == i ? const Color(0xFFF59E0B) : Colors.white,
              ),
            ),
            selected: selected == i,
            selectedTileColor: const Color(0xFF123C2F),
            tileColor: const Color(0xFF123C2F),
            textColor: selected == i ? const Color(0xFFF59E0B) : Colors.white,
            iconColor: selected == i
                ? const Color(0xFFF59E0B)
                : const Color(0xFFB7CFC3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onTap: () => onSelected(i),
          ),
      ],
    ),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<DetectionRecord>>(
    stream: AdminDataService.instance.watchDetections(),
    initialData: AdminDataService.instance.latestDetections,
    builder: (context, detectionSnap) {
      if (detectionSnap.hasError) {
        return _FirebaseError(detectionSnap.error!);
      }
      if (!detectionSnap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final records = detectionSnap.data!;
      final healthy = records
          .where((r) => r.diseaseName.toLowerCase().contains('healthy'))
          .length;
      final rejected = records
          .where((r) => r.diseaseName.toLowerCase().contains('not corn'))
          .length;
      final counts = <String, int>{};
      for (final record in records) {
        counts[record.diseaseName] = (counts[record.diseaseName] ?? 0) + 1;
      }
      return _Scroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LiveBadge(),
            const SizedBox(height: 21),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Metric(
                  'Detection results',
                  records.length,
                  Icons.analytics_outlined,
                  const Color(0xFFC77D2B),
                ),
                _Metric(
                  'Healthy leaves',
                  healthy,
                  Icons.spa_outlined,
                  const Color(0xFF5F9E62),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _Panel(
                  title: 'Disease distribution',
                  child: SizedBox(
                    width: 516,
                    child: counts.isEmpty
                        ? const _Message('No detection data yet.')
                        : SizedBox(
                            height: 108,
                            child: ListView(
                              children: [
                                for (final item in counts.entries)
                                  _Bar(item.key, item.value, records.length),
                              ],
                            ),
                          ),
                  ),
                ),
                _Panel(
                  title: 'Quality signals',
                  child: SizedBox(
                    width: 256,
                    child: Column(
                      children: [
                        _Signal('Non-corn rejections', rejected),
                        _Signal(
                          'Other classifications',
                          records.length - healthy - rejected,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Panel(
              title: 'Recent detection activity',
              child: _DetectionList(records.take(6).toList()),
            ),
          ],
        ),
      );
    },
  );
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => StreamBuilder<List<ManagedUser>>(
    stream: AdminDataService.instance.watchUsers(),
    builder: (context, snap) {
      if (snap.hasError) return _FirebaseError(snap.error!);
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final users = snap.data!
          .where(
            (u) => '${u.username} ${u.email}'.toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
      return _Scroll(
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search users',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _Panel(
              title: '${users.length} users',
              child: users.isEmpty
                  ? const _Message('No users match this search.')
                  : Column(
                      children: [
                        for (final user in users)
                          _UserRow(
                            user: user,
                            onDelete: () => deleteUser(user),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
  Future<void> deleteUser(ManagedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
          'This permanently removes ${user.username}, their Auth account, results, and stored images.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AdminDataService.instance.deleteUser(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deletion completed.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deletion failed: $error')));
      }
    }
  }
}

class DetectionsPage extends StatelessWidget {
  const DetectionsPage({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<List<DetectionRecord>>(
    stream: AdminDataService.instance.watchDetections(),
    initialData: AdminDataService.instance.latestDetections,
    builder: (context, snap) {
      if (snap.hasError) return _FirebaseError(snap.error!);
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final records = [...snap.data!]
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      return _Scroll(
        child: _Panel(
          title: '${records.length} records',
          child: _DetectionList(records),
        ),
      );
    },
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('admin_users')
        .doc(AdminAuthService.instance.currentUser?.uid)
        .get()
        .then((doc) {
          if (mounted) {
            username.text = doc.data()?['username'] as String? ?? 'admin';
          }
        });
  }

  @override
  Widget build(BuildContext context) => _Scroll(
    child: _Panel(
      title: 'Admin credentials',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update the username and password used to access this console.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: username,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New password',
                helperText: 'At least 8 characters',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.save_outlined),
              label: Text(busy ? 'Saving...' : 'Save credentials'),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> save() async {
    setState(() => busy = true);
    try {
      await AdminAuthService.instance.updateCredentials(
        username: username.text,
        password: password.text,
      );
      password.clear();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Credentials updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _Scroll extends StatelessWidget {
  const _Scroll({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(padding: const EdgeInsets.all(28), child: child);
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(21),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE3E8E2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF123C2F),
            ),
          ),
        if (title.isNotEmpty) const SizedBox(height: 17),
        child,
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 229,
    child: _Panel(
      title: '',
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.max);
  final String label;
  final int value;
  final int max;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: max == 0 ? 0 : value / max,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF3F9B63),
          backgroundColor: const Color(0xFFE4EEE6),
        ),
      ],
    ),
  );
}

class _Signal extends StatelessWidget {
  const _Signal(this.label, this.value);
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          '$value',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ],
    ),
  );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.circle, size: 10, color: Color(0xFF3F9B63)),
      SizedBox(width: 7),
      Text(
        'LIVE FIRESTORE DATA',
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3F9B63),
        ),
      ),
    ],
  );
}

class _DetectionList extends StatelessWidget {
  const _DetectionList(this.items);
  final List<DetectionRecord> items;
  @override
  Widget build(BuildContext context) => items.isEmpty
      ? const _Message('No detection records yet.')
      : SizedBox(
          height: 210,
          child: ListView(
            children: [
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _DetectionThumb(item),
                  title: Text(item.diseaseName),
                  subtitle: Text(
                    '${item.username.isNotEmpty
                        ? item.username
                        : item.email.isNotEmpty
                        ? item.email
                        : item.uid.isEmpty
                        ? 'Unknown user'
                        : 'User ${item.uid}'} | ${(item.confidence * 100).toStringAsFixed(1)}% confidence',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    item.createdAt == null
                        ? 'Pending'
                        : '${item.createdAt!.day}/${item.createdAt!.month}',
                  ),
                ),
            ],
          ),
        );
}

class _DetectionThumb extends StatelessWidget {
  const _DetectionThumb(this.item);
  final DetectionRecord item;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      backgroundColor: const Color(0xFFE7F2E8),
      child: Icon(
        item.diseaseName.toLowerCase().contains('healthy')
            ? Icons.spa_outlined
            : Icons.warning_amber_outlined,
        color: const Color(0xFF176B4D),
      ),
    );
    if (item.imageUrl.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        item.imageUrl,
        width: 47,
        height: 47,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.onDelete});
  final ManagedUser user;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      child: Text(user.username.isEmpty ? '?' : user.username[0].toUpperCase()),
    ),
    title: Text(user.username),
    subtitle: Text(
      '${user.email}\nJoined ${user.createdAt == null ? 'Unknown' : '${user.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}'}',
    ),
    isThreeLine: true,
    trailing: IconButton(
      tooltip: 'Delete user',
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: Text(text, style: const TextStyle(color: Colors.black54)),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError(this.error);
  final Object error;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: _Message(
      'Firebase initialization failed. Check the web configuration and reload.\n$error',
    ),
  );
}

class _FirebaseError extends StatelessWidget {
  const _FirebaseError(this.error);
  final Object error;

  @override
  Widget build(BuildContext context) =>
      _Message(AdminDataService.instance.describeError(error));
}
