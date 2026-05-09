import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ai_interview/config/app_routes.dart';
import 'package:ai_interview/widgets/custom_bottom_nav.dart';
import 'package:ai_interview/services/auth_service.dart';
import 'package:ai_interview/services/user_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _profileImage;
  bool _isEditMode = false;

  // Snapshot variables for reverting changes
  String _initialEmail = '';
  String _initialUsername = '';
  String? _initialIndustry;
  String? _initialTargetPosition;
  String? _initialExperience;
  String? _activeDropdown;

  // Loading state
  bool _isPageLoading = true;

  String? _resumeIndustry(String? resume) {
    if (resume == null || resume.trim().isEmpty) return null;
    final parts = resume.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.first : null;
  }

  String? _resumeTargetRole(String? resume) {
    if (resume == null || resume.trim().isEmpty) return null;
    final parts = resume.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return parts.length > 1 ? parts[1] : null;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isPageLoading = true);
    final userProfile = await UserService.getProfile();
    final userName = await AuthService.getUserName();

    if (mounted) {
      if (userProfile != null) {
        final resume = userProfile['resume'] as String?;
        final jobField = userProfile['job_field'] as String?;
        final targetRole = userProfile['target_role'] as String?;
        setState(() {
          _emailController.text = userProfile['email'] ?? '';
          _usernameController.text = userProfile['name'] ?? userName;
          _selectedIndustry = jobField ?? _resumeIndustry(resume);
          _selectedTargetPosition = targetRole ?? _resumeTargetRole(resume);
          _selectedExperience = userProfile['experience_level'];
        });
      } else {
        setState(() {
          _usernameController.text = userName;
        });
      }
      setState(() => _isPageLoading = false);
    }
  }

  void _startEditing() {
    setState(() {
      _initialEmail = _emailController.text;
      _initialUsername = _usernameController.text;
      _initialIndustry = _selectedIndustry;
      _initialTargetPosition = _selectedTargetPosition;
      _initialExperience = _selectedExperience;
      _isEditMode = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _emailController.text = _initialEmail;
      _usernameController.text = _initialUsername;
      _selectedIndustry = _initialIndustry;
      _selectedTargetPosition = _initialTargetPosition;
      _selectedExperience = _initialExperience;
      _isEditMode = false;
    });
  }

  Future<void> _saveEditing() async {
    setState(() => _isPageLoading = true);
    final result = await UserService.updateProfile(
      name: _usernameController.text.trim(),
      fieldOfInterest: _selectedIndustry,
      targetRole: _selectedTargetPosition,
      experienceLevel: _selectedExperience,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message'] ?? 'Profile updated'),
            backgroundColor: Colors.green),
      );
      setState(() {
        _isEditMode = false;
        _isPageLoading = false;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message'] ?? 'Update failed'),
            backgroundColor: Colors.red),
      );
      setState(() => _isPageLoading = false);
    }
  }

  // Controllers for editable fields
  final _emailController = TextEditingController(text: '');
  final _usernameController = TextEditingController(text: '');
  String? _selectedIndustry;
  String? _selectedTargetPosition;
  String? _selectedExperience;

  final List<String> _industries = [
    'Technology',
    'Design',
    'Engineering',
    'Marketing',
  ];

  static const Map<String, List<String>> _targetPositionsMap = {
    'Technology': [
      'Software engineer',
      'Data analyst',
      'Mobile Developer',
      'Cybersecurity specialist',
    ],
    'Design': [
      'Graphic Design',
      'UI/UX Designer',
      'Motion Graphic Designer',
      '3D Designer',
    ],
    'Engineering': [
      'Petroleum engineer',
      'Civil engineer',
      'Electrical engineer',
      'Mechanical engineer',
    ],
    'Marketing': [
      'Marketing Specialist',
      'Digital Marketing',
      'Business Analyst',
      'HR Specialist',
    ],
  };

  List<String> get _targetPositions => _selectedIndustry != null
      ? _targetPositionsMap[_selectedIndustry!] ?? []
      : [];

  final List<String> _experienceLevels = [
    'Junior',
    'Mid',
    'Senior',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        _showImageConfirmationDialog(image);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImageConfirmationDialog(XFile imageFile) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? Image.network(
                          imageFile.path,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(imageFile.path),
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Save this photo?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _profileImage = imageFile;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E83FF),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF374151),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: _buildAppBar(context),
            ),
            Expanded(
              child: _isPageLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF1E83FF)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          _buildProfileCard(context),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: CustomBottomNav(activeRoute: AppRoutes.profile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.black54,
            ),
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        // Settings button
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined,
                size: 18, color: Color(0xFF4B5563)),
            padding: EdgeInsets.zero,
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.settings);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isEditMode ? null : _startEditing,
                child: _isEditMode
                    ? const SizedBox.shrink()
                    : Material(
                        color: const Color(0xFFE9F2FF),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _startEditing,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: Color(0xFF1E83FF),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundImage: _profileImage != null
                      ? (kIsWeb
                          ? NetworkImage(_profileImage!.path)
                          : FileImage(File(_profileImage!.path))
                              as ImageProvider)
                      : null,
                  backgroundColor: const Color(0xFFE5E7EB),
                  child: _profileImage == null
                      ? const Icon(
                          Icons.person_outline,
                          size: 34,
                          color: Color(0xFF9CA3AF),
                        )
                      : null,
                ),
                Material(
                  color: const Color(0xFF1E83FF),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _showImageSourceDialog,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionLabel('Email'),
          const SizedBox(height: 8),
          _isEditMode
              ? _buildEditableField(
                  controller: _emailController,
                  icon: Icons.email_outlined,
                )
              : _buildInfoField(
                  icon: Icons.email_outlined,
                  text: _emailController.text,
                ),
          const SizedBox(height: 18),
          _buildSectionLabel('Username'),
          const SizedBox(height: 8),
          _isEditMode
              ? _buildEditableField(
                  controller: _usernameController,
                  icon: Icons.person_outline,
                )
              : _buildInfoField(
                  icon: Icons.person_outline,
                  text: _usernameController.text,
                ),
          const SizedBox(height: 18),
          _buildSectionLabel('Industry'),
          const SizedBox(height: 8),
          _isEditMode
              ? _buildCustomDropdown(
                  label: 'Industry',
                  value: _selectedIndustry,
                  items: _industries,
                  identifier: 'industry',
                  onChanged: (value) {
                    setState(() {
                      _selectedIndustry = value;
                      if (_selectedTargetPosition != null &&
                          !_targetPositions.contains(_selectedTargetPosition)) {
                        _selectedTargetPosition = null;
                      }
                    });
                  },
                )
              : _buildInfoField(
                  icon: Icons.work_outline_rounded,
                  text: _selectedIndustry ?? 'Not Set',
                ),
          const SizedBox(height: 18),
          _buildSectionLabel('Target Position'),
          const SizedBox(height: 8),
          _isEditMode
              ? _buildCustomDropdown(
                  label: 'Target Position',
                  value: _selectedTargetPosition,
                  items: _targetPositions,
                  identifier: 'position',
                  onChanged: (value) {
                    setState(() {
                      _selectedTargetPosition = value;
                    });
                  },
                )
              : _buildInfoField(
                  icon: Icons.flag_outlined,
                  text: _selectedTargetPosition ?? 'Not Set',
                ),
          const SizedBox(height: 18),
          _buildSectionLabel('Experience'),
          const SizedBox(height: 8),
          _isEditMode
              ? _buildCustomDropdown(
                  label: 'Experience',
                  value: _selectedExperience,
                  items: _experienceLevels,
                  identifier: 'experience',
                  onChanged: (value) {
                    setState(() {
                      _selectedExperience = value;
                    });
                  },
                )
              : _buildInfoField(
                  icon: Icons.timeline_outlined,
                  text: _selectedExperience ?? 'Not Set',
                ),
          if (_isEditMode) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelEditing,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveEditing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E83FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoField({required IconData icon, required String text}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.black, fontSize: 13),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 10),
            child: Icon(icon, size: 18, color: Colors.grey[600]),
          ),
          filled: true,
          fillColor: Colors.grey[200],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
    );
  }

  // Removed _buildDropdownField as it is replaced by _buildCustomDropdown

  Widget _buildCustomDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required String identifier,
    required Function(String) onChanged,
  }) {
    final isOpen = _activeDropdown == identifier;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _activeDropdown = isOpen ? null : identifier;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      identifier == 'industry'
                          ? Icons.work_outline_rounded
                          : identifier == 'position'
                              ? Icons.flag_outlined
                              : Icons.timeline_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 10),
                    Text(
                      value ?? label,
                      style: TextStyle(
                        color: value == null ? Colors.grey[600] : Colors.black,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: isOpen ? const Color(0xFF1E83FF) : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isOpen)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                return InkWell(
                  onTap: () {
                    onChanged(item);
                    setState(() {
                      _activeDropdown = null; // Close after selection
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
