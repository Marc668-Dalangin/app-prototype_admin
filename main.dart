import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'core/firebase_options.dart';
import 'models/admin_models.dart';
import 'services/admin_data_service.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? startupError;
  try {
    await Firebase.initializeApp(options: AdminFirebaseOptions.web);
    await AdminAuthService.instance.configureSessionPersistence();
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
    builder: (context, snapshot) => snapshot.data == null
        ? LoginPage(
            securityMessage: AdminAuthService.instance.pendingSignOutMessage,
          )
        : const AdminShell(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.securityMessage});
  final String? securityMessage;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    username.clear();
    password.clear();
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

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
                autofillHints: const [AutofillHints.newUsername],
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
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => submit(),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.securityMessage != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3D6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.securityMessage!,
                    style: const TextStyle(color: Color(0xFF704900)),
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
  static const _inactivityTimeout = Duration(minutes: 15);
  int index = 0;
  Timer? _inactivityTimer;
  final titles = const [
    'Overview',
    'Users',
    'Detection activity',
    'Admin settings',
  ];

  @override
  void initState() {
    super.initState();
    _resetInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityTimeout, () {
      AdminAuthService.instance.signOut(
        loginMessage: 'You were signed out after 15 minutes of inactivity.',
      );
    });
  }

  void _recordActivity() => _resetInactivityTimer();

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
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _recordActivity();
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => _recordActivity(),
        onPointerMove: (_) => _recordActivity(),
        onPointerHover: (_) => _recordActivity(),
        onPointerSignal: (_) => _recordActivity(),
        child: Scaffold(
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
        ),
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
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
  final Set<String> _deletingUserIds = <String>{};
  final Set<String> _deletedUserIds = <String>{};

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ManagedUser>>(
    stream: AdminDataService.instance.watchUsers(),
    builder: (context, snap) {
      if (snap.hasError) return _FirebaseError(snap.error!);
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final users = snap.data!
          .where((user) => !_deletedUserIds.contains(user.uid))
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
                            isDeleting: _deletingUserIds.contains(user.uid),
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
    if (_deletingUserIds.contains(user.uid)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
          'This permanently removes ${user.username}, their detection records, and profile.',
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

    setState(() => _deletingUserIds.add(user.uid));
    try {
      await AdminDataService.instance.deleteUser(user.uid);
      if (mounted) {
        AdminDataService.instance.removeUserDetectionsLocally(user.uid);
        setState(() => _deletedUserIds.add(user.uid));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'User profile and all detection records purged from database.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Deletion failed'),
            content: Text(_deleteErrorMessage(error)),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingUserIds.remove(user.uid));
    }
  }

  String _deleteErrorMessage(Object error) {
    final errorText = error.toString().toLowerCase();
    if (error is FirebaseException &&
        const {
          'unavailable',
          'network-request-failed',
          'deadline-exceeded',
        }.contains(error.code)) {
      return 'A network issue prevented deletion. Check your connection and try again.';
    }
    if (errorText.contains('unavailable') ||
        errorText.contains('network-request-failed') ||
        errorText.contains('timed out')) {
      return 'A network issue affected one or more deletion steps. Check your connection and retry; any remaining user data may still exist.';
    }
    return 'The user and their data could not be deleted. $error';
  }
}

class DetectionsPage extends StatefulWidget {
  const DetectionsPage({super.key});

  @override
  State<DetectionsPage> createState() => _DetectionsPageState();
}

class _DetectionsPageState extends State<DetectionsPage> {
  late final Stream<List<DetectionRecord>> _detectionStream;
  late final Future<Map<String, ManagedUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _detectionStream = AdminDataService.instance.watchDetections();
    _usersFuture = AdminDataService.instance.loadUsersById();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<DetectionRecord>>(
    stream: _detectionStream,
    initialData: AdminDataService.instance.latestDetections,
    builder: (context, detectionSnap) {
      if (detectionSnap.hasError) return _FirebaseError(detectionSnap.error!);
      if (detectionSnap.connectionState == ConnectionState.waiting &&
          !detectionSnap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final records = [...?detectionSnap.data]
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      return FutureBuilder<Map<String, ManagedUser>>(
        future: _usersFuture,
        builder: (context, userSnap) {
          if (userSnap.hasError) return _FirebaseError(userSnap.error!);
          if (userSnap.connectionState == ConnectionState.waiting &&
              userSnap.data == null &&
              AdminDataService.instance.usersById.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading user details...'),
                ],
              ),
            );
          }
          return _DetectionRecordsList(
            records: records,
            users: (userSnap.data ?? AdminDataService.instance.usersById).values
                .toList(),
          );
        },
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

class _DetectionList extends StatelessWidget {
  const _DetectionList(this.items);
  final List<DetectionRecord> items;

  Map<String, List<DetectionRecord>> _groupByUser() {
    final groups = <String, List<DetectionRecord>>{};
    for (final item in items) {
      final key = item.uid.isNotEmpty
          ? item.uid
          : item.email.isNotEmpty
          ? item.email
          : item.username.isNotEmpty
          ? item.username
          : 'unknown';
      groups.putIfAbsent(key, () => <DetectionRecord>[]).add(item);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, ManagedUser>>(
    future: AdminDataService.instance.loadUsersById(),
    initialData: AdminDataService.instance.usersById,
    builder: (context, snapshot) {
      final usersById = {
        ...AdminDataService.instance.usersById,
        ...?snapshot.data,
      };
      String userLabel(DetectionRecord item) {
        final user = usersById[item.uid];
        final profileUsername = user?.username.trim() ?? '';
        final name =
            profileUsername.isNotEmpty && profileUsername != 'Unnamed user'
            ? user!.username
            : user?.displayName.isNotEmpty == true
            ? user!.displayName
            : item.username.isNotEmpty
            ? item.username
            : item.email.isNotEmpty
            ? item.email
            : 'Unknown User';
        final email = user?.email.isNotEmpty == true ? user!.email : item.email;
        return email.isNotEmpty && email != name ? '$name · $email' : name;
      }

      if (items.isEmpty) return const _Message('No detection records yet.');
      return SizedBox(
        height: 210,
        child: ListView(
          children: [
            for (final group in _groupByUser().entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  '${userLabel(group.value.first)} · ${group.value.length} detection${group.value.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF176B4D),
                  ),
                ),
              ),
              for (final item in group.value)
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 12),
                  leading: _DetectionThumb(item),
                  title: Text(item.diseaseName),
                  subtitle: Text(
                    '${(item.confidence * 100).toStringAsFixed(1)}% confidence · '
                    '${item.createdAt == null ? 'Timestamp unavailable' : DateFormat('MMM d, yyyy, h:mm:ss a').format(item.createdAt!.toLocal())}',
                  ),
                  isThreeLine: true,
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _DetectionRecordsList extends StatelessWidget {
  const _DetectionRecordsList({required this.records, required this.users});

  final List<DetectionRecord> records;
  final List<ManagedUser> users;

  Map<String, List<DetectionRecord>> _groupByUser() {
    final groups = <String, List<DetectionRecord>>{};
    for (final record in records) {
      final key = record.uid.isNotEmpty
          ? record.uid
          : record.email.isNotEmpty
          ? 'email:${record.email}'
          : 'unknown';
      groups.putIfAbsent(key, () => <DetectionRecord>[]).add(record);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const _Message('No detection records yet.');

    final usersByUid = {
      ...AdminDataService.instance.usersById,
      for (final user in users) user.uid: user,
    };
    final groups = _groupByUser().entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(28),
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _Panel(
              title: '${records.length} detection records',
              child: Text('${groups.length} user accounts'),
            ),
          );
        }
        final group = groups[index - 1];
        return _UserDetectionTile(
          userKey: group.key,
          user: usersByUid[group.key],
          records: group.value,
        );
      },
    );
  }
}

class _UserDetectionTile extends StatelessWidget {
  const _UserDetectionTile({
    required this.userKey,
    required this.user,
    required this.records,
  });

  final String userKey;
  final ManagedUser? user;
  final List<DetectionRecord> records;

  @override
  Widget build(BuildContext context) {
    final firstRecord = records.firstOrNull;
    final profileUsername = user?.username.trim() ?? '';
    final displayName = user?.displayName.trim() ?? '';
    final email = user?.email.trim().isNotEmpty == true
        ? user!.email.trim()
        : firstRecord?.email.trim() ?? '';
    final username =
        profileUsername.isNotEmpty && profileUsername != 'Unnamed user'
        ? profileUsername
        : displayName.isNotEmpty
        ? displayName
        : firstRecord?.username.trim().isNotEmpty == true
        ? firstRecord!.username.trim()
        : email.isNotEmpty
        ? email
        : 'Unknown User';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: PageStorageKey<String>('detection-account-$userKey'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        title: Text(
          '${email.isNotEmpty && email != username ? '$username • $email' : username} — ${records.length} Scan${records.length == 1 ? '' : 's'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF123C2F),
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: records.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No detection records available.'),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: records
                        .map((record) => _DetectionResultRow(record: record))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DetectionResultRow extends StatefulWidget {
  const _DetectionResultRow({required this.record});

  final DetectionRecord record;

  @override
  State<_DetectionResultRow> createState() => _DetectionResultRowState();
}

class _DetectionResultRowState extends State<_DetectionResultRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final detectedAt = widget.record.createdAt;
    final dateLabel = detectedAt == null
        ? 'Date unavailable'
        : DateFormat('MMM d, yyyy • h:mm a').format(detectedAt.toLocal());
    final confidenceBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F2E8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${(widget.record.confidence * 100).toStringAsFixed(1)}% Confidence',
        style: const TextStyle(
          color: Color(0xFF176B4D),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final date = Text(
      dateLabel,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Color(0xFF66736C), fontSize: 13),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final disease = Text(
          widget.record.diseaseName,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF26332C),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: SizedBox(
            width: double.infinity,
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: _hovered ? const Color(0xFFF6FAF7) : Colors.white,
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFE5E9E6)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          disease,
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [confidenceBadge, date],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: disease),
                          const SizedBox(width: 16),
                          confidenceBadge,
                          const SizedBox(width: 20),
                          SizedBox(width: 190, child: date),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
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
  const _UserRow({
    required this.user,
    required this.isDeleting,
    required this.onDelete,
  });
  final ManagedUser user;
  final bool isDeleting;
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
      onPressed: isDeleting ? null : onDelete,
      icon: isDeleting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.delete_outline, color: Colors.redAccent),
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
