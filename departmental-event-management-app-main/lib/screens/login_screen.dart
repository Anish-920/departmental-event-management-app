import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:event_management/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  String _selectedRole = 'participant';
  bool _isRegister = false;
  bool _loading = false;

  // Branch → sections mapping (matches report_screen.dart _sectionToBranch)
  static const Map<String, List<String>> _branchSections = {
    'Computer Engineering': ['A', 'B'],
    'Cyber Security':       ['C'],
    'Information Technology': ['E'],
    'AI':                   ['F'],
    'CSBS':                 ['G'],
    'Civil':                ['H'],
    'Electrical':           ['I'],
    'ETC':                  ['J'],
    'IoT':                  ['K'],
    'Mechanical':           ['P'],
  };

  String? _selectedBranch;
  String? _selectedSection;

  // When branch changes → auto-fill section if only one option exists
  void _onBranchChanged(String? branch) {
    final sections = branch != null ? _branchSections[branch] ?? [] : <String>[];
    final autoSection = sections.length == 1 ? sections.first : null;
    setState(() {
      _selectedBranch = branch;
      _selectedSection = autoSection; // auto-fill if only 1 section
      _sectionCtrl.text = autoSection ?? '';
      _departmentCtrl.text = branch ?? '';
    });
  }

  // When section changes → always auto-fill branch from mapping
  void _onSectionChanged(String? section) {
    String? matchedBranch;
    if (section != null) {
      for (final entry in _branchSections.entries) {
        if (entry.value.contains(section)) {
          matchedBranch = entry.key;
          break;
        }
      }
    }
    setState(() {
      _selectedSection = section;
      _sectionCtrl.text = section ?? '';
      if (matchedBranch != null) {
        _selectedBranch = matchedBranch;
        _departmentCtrl.text = matchedBranch;
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _contactCtrl.dispose();
    _departmentCtrl.dispose();
    _designationCtrl.dispose();
    _yearCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    setState(() => _loading = true);
    final authService = context.read<AuthService>();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final name = _nameCtrl.text.trim();
    final contact = _contactCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty || (_isRegister && (name.isEmpty || contact.isEmpty))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields', style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent)
        );
      }
      setState(() => _loading = false);
      return;
    }

    try {
      if (_isRegister) {
        Map<String, dynamic> roleData = {};
        if (_selectedRole == 'teacher' || _selectedRole == 'organizer') {
          roleData['department'] = _departmentCtrl.text.trim();
          roleData['designation'] = _designationCtrl.text.trim();
        } else if (_selectedRole == 'participant') {
          roleData['department'] = _selectedBranch ?? _departmentCtrl.text.trim();
          roleData['branch']     = _selectedBranch ?? '';
          roleData['year']       = _yearCtrl.text.trim();
          roleData['section']    = _selectedSection ?? _sectionCtrl.text.trim();
        }
        await authService.registerWithEmail(
          email: email, 
          password: pass,
          name: name,
          contactNo: contact,
          role: _selectedRole,
          roleData: roleData,
        );
      } else {
        await authService.signInWithEmail(email, pass);
      }
    } catch(e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon / Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1424),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0A1128).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                    ]
                  ),
                  child: const Icon(Icons.event_seat_rounded, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 32),
                
                // Greeting
                Text(
                  _isRegister ? 'Create Account' : 'Welcome Back',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0E1424), letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRegister ? 'Sign up to manage your events.' : 'Sign in to access your dashboard.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
                    ]
                  ),
                  child: Column(
                    children: [
                      if (_isRegister) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(labelText: 'Register As', prefixIcon: Icon(Icons.badge_outlined, color: Colors.black54)),
                          items: const [
                            DropdownMenuItem(value: 'participant', child: Text('Participant')),
                            DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
                            DropdownMenuItem(value: 'organizer', child: Text('Organizer')),
                          ],
                          onChanged: (val) => setState(() => _selectedRole = val ?? 'participant'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: Color(0xFF0E1424)),
                          decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline, color: Colors.black54)),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _contactCtrl,
                          style: const TextStyle(color: Color(0xFF0E1424)),
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Contact Number', prefixIcon: Icon(Icons.phone_outlined, color: Colors.black54)),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedRole == 'teacher' || _selectedRole == 'organizer') ...[
                           TextField(
                             controller: _departmentCtrl,
                             style: const TextStyle(color: Color(0xFF0E1424)),
                             decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.domain, color: Colors.black54)),
                           ),
                           const SizedBox(height: 16),
                           TextField(
                             controller: _designationCtrl,
                             style: const TextStyle(color: Color(0xFF0E1424)),
                             decoration: const InputDecoration(labelText: 'Designation / Title', prefixIcon: Icon(Icons.work_outline, color: Colors.black54)),
                           ),
                           const SizedBox(height: 16),
                        ],
                        if (_selectedRole == 'participant') ...[
                          // ── Branch dropdown (scrollable) ──────────────────
                          DropdownButtonFormField<String>(
                            value: _selectedBranch,
                            isExpanded: true,
                            menuMaxHeight: 220,
                            decoration: const InputDecoration(
                              labelText: 'Branch',
                              prefixIcon: Icon(Icons.account_tree_outlined, color: Colors.black54),
                            ),
                            hint: const Text('Select Branch'),
                            items: _branchSections.keys.map((b) =>
                              DropdownMenuItem(value: b, child: Text(b)),
                            ).toList(),
                            onChanged: _onBranchChanged,
                          ),
                          const SizedBox(height: 16),
                          // ── Section dropdown (auto-filled from branch) ────
                          DropdownButtonFormField<String>(
                            value: _selectedSection,
                            isExpanded: true,
                            menuMaxHeight: 180,
                            decoration: const InputDecoration(
                              labelText: 'Section',
                              prefixIcon: Icon(Icons.group_outlined, color: Colors.black54),
                            ),
                            hint: const Text('Select Section'),
                            items: (_selectedBranch != null
                                ? _branchSections[_selectedBranch]!
                                : (List<String>.from(
                                    _branchSections.values.expand((s) => s).toSet(),
                                  )..sort()))
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                            onChanged: _onSectionChanged,
                          ),
                          const SizedBox(height: 16),
                          // ── Year ─────────────────────────────────────────
                          TextField(
                            controller: _yearCtrl,
                            style: const TextStyle(color: Color(0xFF0E1424)),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Year / Batch (e.g. 2, 3)', prefixIcon: Icon(Icons.school_outlined, color: Colors.black54)),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                      TextField(
                        controller: _emailCtrl,
                        style: const TextStyle(color: Color(0xFF0E1424)),
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.black54),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        style: const TextStyle(color: Color(0xFF0E1424)),
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.black54),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: _loading 
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC62828), // Crimson Button
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(_isRegister ? 'Register' : 'Login', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister ? 'Already have an account? Log in' : 'Don\'t have an account? Register',
                    style: const TextStyle(color: Color(0xFF0E1424), fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
