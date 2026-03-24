import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../main_screen/home_page_screen.dart';

class PersonalInformationScreen extends StatefulWidget {
  final String userId;
  final double? liveLat;
  final double? liveLng;

  const PersonalInformationScreen({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
  });

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fnameController = TextEditingController();
  final TextEditingController _mnameController = TextEditingController();
  final TextEditingController _lnameController = TextEditingController();
  final TextEditingController _pnumberController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();

  String _gender = 'Male';
  XFile? _pickedImage;
  bool _loading = false;

  @override
  void dispose() {
    _fnameController.dispose();
    _mnameController.dispose();
    _lnameController.dispose();
    _pnumberController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  /// PICK IMAGE
  Future<void> _pickImage() async {
    final source = await _showImageSourcePicker();
    if (source == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      if (!mounted) return;
      setState(() => _pickedImage = image);
    }
  }

  Future<ImageSource?> _showImageSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.red),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.red),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  /// UPLOAD IMAGE TO SUPABASE STORAGE
  Future<String?> _uploadImage(XFile image) async {
    try {
      // ✅ Validate file type
      final allowedExtensions = ['jpg', 'jpeg', 'png'];
      final ext = image.name.split('.').last.toLowerCase();
      if (!allowedExtensions.contains(ext)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPG, JPEG, PNG files are accepted.'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }

      // ✅ Validate file size (max 5 MB)
      final fileSize = await image.length();
      if (fileSize > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File size must be 5 MB or less.'),
            backgroundColor: Colors.red,
          ),
        );
        return null;
      }

      final fileBytes = await image.readAsBytes();
      final fileName =
          '${widget.userId}_avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Upload to Supabase Storage bucket 'avatar'
      await supabase.storage.from('avatar').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final publicUrl = supabase.storage.from('avatar').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red),
      );
      return null;
    }
  }

  String? validateName(String? value, {bool required = true}) {
    final text = value?.trim() ?? '';

    if (required && text.isEmpty) return 'Required';
    if (!required && text.isEmpty) return null;
    if (text.length < 2) return 'Must be at least 2 characters';
    if (text.length > 50) return 'Must be 50 characters or less';

    final nameRegex = RegExp(r"^[A-Za-z]+(?:[ '-][A-Za-z]+)*$");
    if (!nameRegex.hasMatch(text)) {
      return 'Only letters, spaces, hyphens, and apostrophes are allowed';
    }

    return null;
  }

  String formatName(String input) {
    final cleaned = input.trim().replaceAll(RegExp(r'\s+'), ' ');

    return cleaned
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;

          if (word.contains('-')) {
            return word
                .split('-')
                .map((part) => part.isEmpty
                    ? part
                    : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
                .join('-');
          }

          if (word.contains("'")) {
            return word
                .split("'")
                .map((part) => part.isEmpty
                    ? part
                    : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
                .join("'");
          }

          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  String? validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';

    final phoneRegex = RegExp(r'^\d{10}$');
    if (!phoneRegex.hasMatch(text)) {
      return 'Enter a valid 10-digit mobile number';
    }

    return null;
  }

  Future<bool> _isDuplicateFullName({
    required String fname,
    required String mname,
    required String lname,
  }) async {
    final result = await supabase
        .from('users')
        .select('user_id')
        .eq('fname', fname)
        .eq('mname', mname)
        .eq('lname', lname)
        .neq('user_id', widget.userId)
        .limit(1);

    return (result as List).isNotEmpty;
  }

  /// SAVE DATA
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    final formattedFname = formatName(_fnameController.text);
    final formattedMname = _mnameController.text.trim().isEmpty
        ? ''
        : formatName(_mnameController.text);
    final formattedLname = formatName(_lnameController.text);
    final phoneNumber = _pnumberController.text.trim();

    _fnameController.text = formattedFname;
    _mnameController.text = formattedMname;
    _lnameController.text = formattedLname;
    _pnumberController.text = phoneNumber;

    setState(() => _loading = true);

    try {
      final isDuplicate = await _isDuplicateFullName(
        fname: formattedFname,
        mname: formattedMname,
        lname: formattedLname,
      );

      if (isDuplicate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This full name already exists in the database.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _loading = false);
        return;
      }

      // Compute age from birth date
      final birthDate = DateTime.parse(_birthDateController.text);
      final age = DateTime.now().year -
          birthDate.year -
          ((DateTime.now().month < birthDate.month ||
                  (DateTime.now().month == birthDate.month &&
                      DateTime.now().day < birthDate.day))
              ? 1
              : 0);

      String? profileUrl;
      if (_pickedImage != null) {
        profileUrl = await _uploadImage(_pickedImage!);
      }

      // Update users table
      await supabase.from('users').update({
        'fname': formattedFname,
        'mname': formattedMname,
        'lname': formattedLname,
        'pnumber': phoneNumber,
        'gender': _gender,
        'birth_date': _birthDateController.text.trim(),
        'age': age,
        if (profileUrl != null) 'profile_url': profileUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', widget.userId);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePageScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
        ),
      );
    } on PostgrestException catch (e) {
      final isUniqueViolation = e.code == '23505';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUniqueViolation
                ? 'This full name already exists in the database.'
                : 'Error saving information: ${e.message}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving information: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const fieldHeight = 58.0;

    InputDecoration fieldDecoration(String label, {Widget? suffixIcon}) {
      return InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD40000), width: 1.5),
        ),
        suffixIcon: suffixIcon,
      );
    }

    Widget genderOption({
      required String value,
      required IconData icon,
      required String label,
    }) {
      final bool isSelected = _gender == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _gender = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isSelected ? const Color(0xFFFFE3E3) : Colors.white,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD40000)
                    : const Color(0xFFDADADA),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD40000).withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 14,
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? const Color(0xFFB00000) : Colors.black54,
                  ),
                ),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? const Color(0xFFB00000) : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF800000), Color(0xFFFF0000)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          title: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Personal Information',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFF2F2F2),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Column(
                      children: [
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200, width: 2),
                          ),
                          child: _pickedImage == null
                              ? const Icon(Icons.add, size: 44, color: Colors.red)
                              : ClipOval(
                                  child: Image.file(
                                    File(_pickedImage!.path),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add Profile Photo',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: fieldHeight,
                          child: TextFormField(
                            controller: _fnameController,
                            decoration: fieldDecoration('First Name'),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(50),
                              FilteringTextInputFormatter.allow(
                                RegExp(r"[A-Za-z\s'-]"),
                              ),
                            ],
                            validator: (v) => validateName(v, required: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: fieldHeight,
                          child: TextFormField(
                            controller: _lnameController,
                            decoration: fieldDecoration('Last Name'),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(50),
                              FilteringTextInputFormatter.allow(
                                RegExp(r"[A-Za-z\s'-]"),
                              ),
                            ],
                            validator: (v) => validateName(v, required: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: fieldHeight,
                    child: TextFormField(
                      controller: _mnameController,
                      decoration: fieldDecoration('Middle Name'),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(50),
                        FilteringTextInputFormatter.allow(
                          RegExp(r"[A-Za-z\s'-]"),
                        ),
                      ],
                      validator: (v) => validateName(v, required: false),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: fieldHeight,
                    child: TextFormField(
                      controller: _pnumberController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: fieldDecoration(
                        'Phone Number',
                      ).copyWith(
                        prefixIcon: const Icon(Icons.phone_outlined),
                        prefixText: '+63 ',
                      ),
                      validator: validatePhone,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      genderOption(
                        value: 'Male',
                        icon: Icons.male_rounded,
                        label: 'Male',
                      ),
                      const SizedBox(width: 12),
                      genderOption(
                        value: 'Female',
                        icon: Icons.female_rounded,
                        label: 'Female',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: fieldHeight,
                    child: TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      decoration: fieldDecoration(
                        'Birthday',
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null) {
                          _birthDateController.text =
                              pickedDate.toIso8601String().split('T')[0];
                        }
                      },
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: _loading
                              ? [const Color(0xFFBDBDBD), const Color(0xFF9E9E9E)]
                              : [const Color(0xFFB00000), const Color(0xFFFF2B2B)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: _loading ? null : _saveData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'SAVE & PROCEED',
                                    style:
                                        TextStyle(fontSize: 18, color: Colors.white),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, color: Colors.white),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
