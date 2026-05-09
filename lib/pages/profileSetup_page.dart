import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ai_interview/config/app_routes.dart';
// import 'package:ai_interview/services/auth_service.dart';
import 'package:ai_interview/services/user_service.dart';

class ProfileSetupPage extends StatefulWidget {
  final String? initialUsername;
  const ProfileSetupPage({super.key, this.initialUsername});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _profileImage;
  final _usernameController = TextEditingController();
  String? _selectedJobField;
  String? _selectedTargetPosition;
  String? _selectedExperience;
  String? _activeDropdown;
  bool _isLoading = false;

  // Dropdown options matching the design
  final List<String> _jobFields = [
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

  List<String> get _targetPositions => _selectedJobField != null
      ? _targetPositionsMap[_selectedJobField!] ?? []
      : [];

  final List<String> _experienceLevels = [
    'Junior',
    'Mid',
    'Senior',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null && widget.initialUsername!.isNotEmpty) {
      _usernameController.text = widget.initialUsername!;
    }
  }

  @override
  void dispose() {
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
                  leading: const Icon(Icons.camera_alt, color: Colors.white),
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
                  leading: const Icon(Icons.photo_library, color: Colors.white),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value ?? label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
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
                        fontSize: 16,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Skip Button at top right
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushReplacementNamed(AppRoutes.main);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                const Text(
                  'Profile Setup',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 32),
                // Profile Picture with Edit Icon
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[300],
                      ),
                      child: ClipOval(
                        child: _profileImage != null
                            ? (kIsWeb
                                ? Image.network(
                                    _profileImage!.path,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_profileImage!.path),
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ))
                            : Container(
                                width: 120,
                                height: 120,
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.person_outline,
                                  size: 52,
                                  color: Colors.grey[600],
                                ),
                              ),
                      ),
                    ),
                    // Blue circular camera icon badge
                    Material(
                      color: const Color(0xFF1E83FF),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _showImageSourceDialog,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Username Field
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: 'Username',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Icon(
                        Icons.person_outline,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Select Job Field Dropdown
                const SizedBox(height: 20),
                // Select Job Field Dropdown
                _buildCustomDropdown(
                  label: 'Select Job field',
                  value: _selectedJobField,
                  items: _jobFields,
                  identifier: 'job',
                  onChanged: (value) {
                    setState(() {
                      _selectedJobField = value;
                      if (_selectedTargetPosition != null &&
                          !_targetPositions.contains(_selectedTargetPosition)) {
                        _selectedTargetPosition = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),
                // Select Target Position Dropdown
                _buildCustomDropdown(
                  label: 'Select Target Position',
                  value: _selectedTargetPosition,
                  items: _targetPositions,
                  identifier: 'app',
                  onChanged: (value) {
                    setState(() {
                      _selectedTargetPosition = value;
                    });
                  },
                ),
                const SizedBox(height: 20),
                // Experience Dropdown
                _buildCustomDropdown(
                  label: 'Experience',
                  value: _selectedExperience,
                  items: _experienceLevels,
                  identifier: 'exp',
                  onChanged: (value) {
                    setState(() {
                      _selectedExperience = value;
                    });
                  },
                ),
                const SizedBox(height: 40),
                // Continue Button with Gradient
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E83FF), Color(0xFF0066CC)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_selectedJobField == null ||
                                _selectedTargetPosition == null ||
                                _selectedExperience == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please select your Job Field, Target Position, and Experience Level'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setState(() => _isLoading = true);

                            final result = await UserService.setupProfile(
                              jobField: _selectedJobField!,
                              experienceLevel: _selectedExperience!,
                              targetRole: _selectedTargetPosition!,
                              name: _usernameController.text.trim(),
                            );

                            if (!mounted) return;
                            setState(() => _isLoading = false);

                            if (result['success'] == true) {
                              Navigator.of(context)
                                  .pushReplacementNamed(AppRoutes.main);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result['message'] ??
                                      'Failed to setup profile'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
