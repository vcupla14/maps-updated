import 'dart:io';
import 'package:flutter/material.dart';
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

  /// PICK IMAGE
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _pickedImage = image);
    }
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

  /// SAVE DATA
  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
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
        'fname': _fnameController.text.trim(),
        'mname': _mnameController.text.trim(),
        'lname': _lnameController.text.trim(),
        'pnumber': _pnumberController.text.trim(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving information: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving information: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const fieldHeight = 60.0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
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
          title: const Text(
            'Personal Information',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold), // bold + white
          ),
          centerTitle: true,
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // IMAGE PICKER (plus + icon)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.shade50,
                      border:
                          Border.all(color: Colors.red.shade200, width: 2),
                    ),
                    child: _pickedImage == null
                        ? const Icon(Icons.add, size: 50, color: Colors.red)
                        : ClipOval(
                            child: Image.file(
                              File(_pickedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // FIRST, MIDDLE, LAST NAME
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: fieldHeight,
                        child: TextFormField(
                          controller: _fnameController,
                          decoration: InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: fieldHeight,
                        child: TextFormField(
                          controller: _mnameController,
                          decoration: InputDecoration(
                            labelText: 'Middle Name',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: fieldHeight,
                        child: TextFormField(
                          controller: _lnameController,
                          decoration: InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // PHONE NUMBER
                SizedBox(
                  height: fieldHeight,
                  child: TextFormField(
                    controller: _pnumberController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(height: 16),

                // GENDER selection side by side
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Male'),
                        value: 'Male',
                        groupValue: _gender,
                        onChanged: (val) {
                          setState(() => _gender = val!);
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Female'),
                        value: 'Female',
                        groupValue: _gender,
                        onChanged: (val) {
                          setState(() => _gender = val!);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // BIRTHDAY
                SizedBox(
                  height: fieldHeight,
                  child: TextFormField(
                    controller: _birthDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Birthday (YYYY-MM-DD)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                const SizedBox(height: 30),

                // SAVE & PROCEED BUTTON
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _saveData,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30))),
                    child: _loading
                        ? const CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)
                        : const Text('SAVE & PROCEED',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
