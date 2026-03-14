import 'dart:math';

import 'package:eduserveapp/core/constants/app_config.dart';
import 'package:eduserveapp/core/services/analytics_service.dart';
import 'package:eduserveapp/core/services/firestore_user_service.dart';
import 'package:eduserveapp/core/services/notification_center_service.dart';
import 'package:eduserveapp/core/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onCompleted,
  });

  final Future<void> Function() onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _ageController = TextEditingController();
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  DateTime? _dob;
  String? _department;
  int? _year;
  bool _saving = false;
  bool _introLoading = true;
  _AuthStage _stage = _AuthStage.choice;
  bool _showSuccess = false;
  bool _finalizing = false;
  bool _signupSyncedToCloud = false;

  static const List<String> _departments = <String>[
    'CSE',
    'ECE',
    'EEE',
    'IT',
    'Mechanical',
    'Civil',
    'Biotech',
    'MBA',
    'BSc',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _showIntroLoader();
  }

  Future<void> _showIntroLoader() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) {
      setState(() => _introLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _signupPasswordController.dispose();
    _ageController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1980),
      lastDate: now,
    );
    if (selected != null) {
      setState(() => _dob = selected);
    }
  }

  Future<void> _submit() async {
    if (_saving) {
      debugPrint('[onboarding] Submit ignored: already saving');
      return;
    }

    debugPrint('[onboarding] Submit clicked');
    if (!_formKey.currentState!.validate() ||
        _dob == null ||
        _department == null ||
        _year == null) {
      debugPrint('[onboarding] Validation failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final email = _emailController.text.trim().toLowerCase();
      final age = int.parse(_ageController.text.trim());
      final password = _signupPasswordController.text.trim();

      debugPrint('[onboarding] Creating Firebase Auth account for $email');
      late final UserCredential credential;
      try {
        credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password)
            .timeout(const Duration(seconds: 10));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email already registered. Please use Login.'),
            ),
          );
          return;
        }
        rethrow;
      }

      final uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        throw Exception('Unable to resolve authenticated user ID.');
      }
      debugPrint('[onboarding] Saving profile for uid=$uid');

      var syncedToCloud = false;
      try {
        await FirestoreUserService.instance
            .createOrUpdateUser(
              uid: uid,
              name: _nameController.text.trim(),
              email: email,
              dept: _department!,
              year: _year!,
              dob: _dob!,
              age: age,
              role: 'user',
            )
            .timeout(const Duration(seconds: 8));
        syncedToCloud = true;
        debugPrint('[onboarding] Firestore profile save success');
      } catch (e) {
        debugPrint(
          '[onboarding] Firestore profile sync failed, fallback to local completion: $e',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConfig.onboardingCompleteKey, true);
      await prefs.setString(AppConfig.profileDocIdKey, uid);
      await prefs.setBool(AppConfig.profileSyncPendingKey, !syncedToCloud);
      final greeting =
          AppConfig.loginGreetings[Random().nextInt(AppConfig.loginGreetings.length)];
      await NotificationCenterService.instance.appendLoginGreeting(greeting);
      await NotificationService.instance.showNow(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Welcome',
        body: greeting,
      );
      debugPrint('[onboarding] Local onboarding flags saved');

      await AnalyticsService.instance.logSignupCompleted();
      debugPrint('[onboarding] signup_completed analytics logged');

      if (!mounted) {
        return;
      }
      setState(() {
        _signupSyncedToCloud = syncedToCloud;
        _showSuccess = true;
      });
    } catch (e) {
      debugPrint('[onboarding] Submit failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlySignupError(e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _submitLogin() async {
    if (_saving) return;
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      final email = _loginEmailController.text.trim().toLowerCase();
      final password = _loginPasswordController.text.trim();

      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));

      final uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        throw Exception('Unable to resolve authenticated user ID.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConfig.onboardingCompleteKey, true);
      await prefs.setString(AppConfig.profileDocIdKey, uid);
      final greeting =
          AppConfig.loginGreetings[Random().nextInt(AppConfig.loginGreetings.length)];
      await NotificationCenterService.instance.appendLoginGreeting(greeting);
      await NotificationService.instance.showNow(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Welcome',
        body: greeting,
      );
      await widget.onCompleted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyLoginError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _friendlySignupError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'invalid-email':
          return 'Enter a valid ${AppConfig.kmailDomain} email.';
        case 'email-already-in-use':
          return 'Email already registered. Please use Login.';
        default:
          return 'Could not create account right now. Try again.';
      }
    }
    return 'Could not complete signup. Please try again.';
  }

  String _friendlyLoginError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No account found. Please create an account first.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        default:
          return 'Login failed. Please try again.';
      }
    }
    return 'Login failed. Please try again.';
  }

  Future<void> _finishOnboarding() async {
    if (_finalizing) return;
    debugPrint('[onboarding] Success continue pressed');

    setState(() => _finalizing = true);
    try {
      await widget.onCompleted().timeout(const Duration(seconds: 10));
      debugPrint('[onboarding] Parent completion callback success');
    } catch (e) {
      debugPrint('[onboarding] Parent completion callback failed: $e');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Almost done. Please tap continue again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _finalizing = false);
      }
    }
  }

  Widget _buildSuccessPage(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const CircleAvatar(
                        radius: 34,
                        backgroundColor: Color(0xFF111111),
                        child: Icon(Icons.check_rounded,
                            color: Colors.white, size: 34),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Signup Successful',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your profile is ready. Continue to your dashboard.',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _signupSyncedToCloud
                            ? 'Cloud sync completed successfully.'
                            : 'Cloud sync unavailable. Profile saved locally and will sync later.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _finalizing ? null : _finishOnboarding,
                          icon: _finalizing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                          label: Text(
                            _finalizing ? 'Please wait...' : 'Go to Dashboard',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_introLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showSuccess) {
      return _buildSuccessPage(context);
    }

    if (_stage == _AuthStage.choice) {
      return _buildAuthChoice(context);
    }

    if (_stage == _AuthStage.login) {
      return _buildLoginPage(context);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.school_outlined,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Fast Signup',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Welcome to EduServe Companion',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your student profile to continue.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const <Widget>[
                            _InfoChip(label: '2 min'),
                            _InfoChip(label: 'One-time setup'),
                            _InfoChip(label: 'Editable later'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF141414)
                                    : const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: AutofillGroup(
                            child: Column(
                              children: <Widget>[
                                TextFormField(
                                  controller: _nameController,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const <String>[
                                    AutofillHints.name
                                  ],
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                          ? 'Enter your name'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailController,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const <String>[
                                    AutofillHints.email
                                  ],
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  decoration: const InputDecoration(
                                    labelText: 'KMail',
                                    prefixIcon: Icon(Icons.alternate_email),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty) {
                                      return 'Enter your KMail';
                                    }
                                    if (!email
                                        .endsWith(AppConfig.kmailDomain)) {
                                      return 'Email must end with ${AppConfig.kmailDomain}';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _signupPasswordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.next,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                    hintText: 'enter Seraph Password !!',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                  validator: (value) {
                                    final password = (value ?? '').trim();
                                    if (password.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _ageController,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  decoration: const InputDecoration(
                                    labelText: 'Age',
                                    prefixIcon: Icon(Icons.cake_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    final age = int.tryParse(value ?? '');
                                    if (age == null ||
                                        age < AppConfig.minSignupAge ||
                                        age > 60) {
                                      return 'Minimum age is ${AppConfig.minSignupAge}';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _pickDob,
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          const Icon(Icons.calendar_month),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _dob == null
                                                  ? 'Select DOB'
                                                  : 'DOB: ${_dob!.toLocal().toString().split(' ').first}',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _department,
                                  decoration: const InputDecoration(
                                    labelText: 'Department',
                                    prefixIcon: Icon(Icons.account_balance),
                                  ),
                                  items: _departments
                                      .map(
                                        (dept) => DropdownMenuItem<String>(
                                          value: dept,
                                          child: Text(dept),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _department = value),
                                  validator: (value) => value == null
                                      ? 'Select department'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<int>(
                                  initialValue: _year,
                                  decoration: const InputDecoration(
                                    labelText: 'Year',
                                    prefixIcon: Icon(Icons.school_outlined),
                                  ),
                                  items: List<int>.generate(5, (i) => i + 1)
                                      .map(
                                        (year) => DropdownMenuItem<int>(
                                          value: year,
                                          child: Text('Year $year'),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _year = value),
                                  validator: (value) =>
                                      value == null ? 'Select year' : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _submit,
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Complete Signup'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => setState(
                                        () => _stage = _AuthStage.choice),
                                child: const Text('Back'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tip: Use your official KMail for profile syncing.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAuthChoice(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Welcome',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose how you want to continue.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () =>
                              setState(() => _stage = _AuthStage.signup),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Create Account (Signup)'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _stage = _AuthStage.login),
                          icon: const Icon(Icons.login),
                          label: const Text('Login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPage(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _loginFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Login',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use your Karunya email to continue.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _loginEmailController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'KMail',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (value) {
                            final email = (value ?? '').trim().toLowerCase();
                            if (email.isEmpty) {
                              return 'Enter your email';
                            }
                            if (!email.endsWith(AppConfig.kmailDomain)) {
                              return 'Email must end with ${AppConfig.kmailDomain}';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _loginPasswordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submitLogin(),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: 'enter Seraph Password !!',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Enter password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _saving ? null : _submitLogin,
                            child: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Login'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () =>
                                    setState(() => _stage = _AuthStage.choice),
                            child: const Text('Back'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}

enum _AuthStage { choice, signup, login }
