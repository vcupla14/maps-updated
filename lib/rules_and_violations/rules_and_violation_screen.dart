import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main_screen/home_page_screen.dart';
import '../maps/screens/map_screen.dart';
import '../parcels/parcel1.dart';
import '../profile/profile_screen.dart';

class RulesAndViolationScreen extends StatefulWidget {
  final String userId;
  final double? liveLat;
  final double? liveLng;
  final int initialTab;

  const RulesAndViolationScreen({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
    this.initialTab = 0,
  });

  @override
  State<RulesAndViolationScreen> createState() => _RulesAndViolationScreenState();
}

class _RulesAndViolationScreenState extends State<RulesAndViolationScreen> {
  int _selectedIndex = 2;
  int _selectedTab = 0;
  int _tabDirection = 1;
  static const Color _darkRed = Color.fromARGB(255, 225, 7, 7);
  bool _isCategoryLoading = false;
  String? _categoryError;
  List<String> _categories = [];
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
    _loadCategoriesForCurrentTab();
  }

  void _navigateWithTransition(Widget page, int index) {
    if (index == _selectedIndex) return;
    final bool slideLeft = index < _selectedIndex;
    setState(() => _selectedIndex = index);

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, animation, __) => page,
        transitionsBuilder: (_, animation, __, child) {
          final slideAnimation = Tween<Offset>(
            begin: Offset(slideLeft ? -0.15 : 0.15, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );

          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            ),
          );

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(
              opacity: fadeAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        _navigateWithTransition(
          HomePageScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
      case 1:
        _navigateWithTransition(
          MapScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
      case 3:
        _navigateWithTransition(
          ParcelsPage(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
      case 4:
        _navigateWithTransition(
          ProfileScreen(
            userId: widget.userId,
            liveLat: widget.liveLat,
            liveLng: widget.liveLng,
          ),
          index,
        );
        break;
    }
  }

  void _switchTab(int nextTab) {
    if (nextTab == _selectedTab) return;
    setState(() {
      _tabDirection = nextTab > _selectedTab ? 1 : -1;
      _selectedTab = nextTab;
    });
    _loadCategoriesForCurrentTab();
  }

  Future<void> _loadCategoriesForCurrentTab() async {
    final tableName = _selectedTab == 0 ? 'road_rules' : 'violation_fines';
    setState(() {
      _isCategoryLoading = true;
      _categoryError = null;
      _categories = [];
      _selectedCategory = null;
    });



    try {
      final response =
          await Supabase.instance.client.from(tableName).select('type');
      final rows = (response as List<dynamic>);
      final unique = <String, String>{};

      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final raw = (row['type'] ?? '').toString().trim();
        if (raw.isEmpty) continue;
        final key = raw.toLowerCase();
        unique.putIfAbsent(key, () => raw);
      }

      final categories = unique.values.toList()..sort();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategory = categories.isNotEmpty ? categories.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _categoryError = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _isCategoryLoading = false);
    }
  }

    Future<List<Map<String, dynamic>>> _fetchRoadRules() async {
    if (_selectedCategory == null) return [];
    
    try {
      final response = await Supabase.instance.client
          .from('road_rules')
          .select()
          .eq('type', _selectedCategory!);
      
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error fetching road rules: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchViolationFines() async {
  if (_selectedCategory == null) return [];
  
  try {
    final response = await Supabase.instance.client
        .from('violation_fines')
        .select()
        .eq('type', _selectedCategory!);
    
    return List<Map<String, dynamic>>.from(response as List);
  } catch (e) {
    print('Error fetching violation fines: $e');
    return [];
  }
}

    Widget _buildRoadRuleCard(Map<String, dynamic> rule) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon on the left
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  rule['icon_url'] ?? '',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported, size: 60);
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name and Meaning on the right
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule['name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rule['meaning'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildViolationFineCard(Map<String, dynamic> violation) {
  return _ViolationFineCardItem(violation: violation);
}

  Widget _buildCategoryTabs() {
    if (_isCategoryLoading) {
      return const SizedBox(
        height: 42,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_categoryError != null) {
      return SizedBox(
        height: 42,
        child: Center(
          child: Text(
            'Failed to load categories',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox(
        height: 42,
        child: Center(
          child: Text(
            'No categories found',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCategory = category),
            selectedColor: _darkRed.withOpacity(0.15),
            labelStyle: TextStyle(
              color: selected ? _darkRed : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            side: BorderSide(
              color: selected ? _darkRed : Colors.grey.shade400,
            ),
            shape: StadiumBorder(
              side: BorderSide(
                color: selected ? _darkRed : Colors.grey.shade400,
              ),
            ),
            backgroundColor: Colors.white,
            showCheckmark: false,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFD40000),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3E3E3), Color(0xFFD40000)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Container(
              height: 240,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF800000), Color(0xFFFF0000)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
            ),
            const SafeArea(
              child: SizedBox(
                height: 70,
                child: Center(
                  child: Text(
                    "Rules & Violations",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 104, 20, 20),
                child: Container(  // 👈 Changed from Column to just Container
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromARGB(80, 255, 0, 0),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Stack(
                            children: [
                              AnimatedAlign(
                                alignment: _selectedTab == 0
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                child: FractionallySizedBox(
                                  widthFactor: 0.5,
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _darkRed,
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () => _switchTab(0),
                                      child: SizedBox(
                                        height: 40,
                                        child: Center(
                                          child: Text(
                                            "Road Rules",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _selectedTab == 0
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () => _switchTab(1),
                                      child: SizedBox(
                                        height: 40,
                                        child: Center(
                                          child: Text(
                                            "Violation Fines",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _selectedTab == 1
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _selectedTab == 0
                                ? "Road Rules Categories"
                                : "Violation Fines Categories",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildCategoryTabs(),
                        const SizedBox(height: 14),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final beginOffset = Offset(
                              _tabDirection > 0 ? 0.12 : -0.12,
                              0,
                            );
                            final slide = Tween<Offset>(
                              begin: beginOffset,
                              end: Offset.zero,
                            ).animate(animation);
                            return SlideTransition(
                              position: slide,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _selectedTab == 0
                              ? FutureBuilder<List<Map<String, dynamic>>>(
                                  key: ValueKey<String>('road_rules_$_selectedCategory'),
                                  future: _fetchRoadRules(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Error loading rules',
                                          style: TextStyle(color: Colors.red.shade700),
                                        ),
                                      );
                                    }
                                    
                                    final rules = snapshot.data ?? [];
                                    
                                    if (rules.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'No rules found for this category',
                                          style: TextStyle(color: Colors.black54),
                                        ),
                                      );
                                    }
                                    
                                    return ListView.builder(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      itemCount: rules.length,
                                      itemBuilder: (context, index) {
                                        return _buildRoadRuleCard(rules[index]);
                                      },
                                    );
                                  },
                                )
                              : FutureBuilder<List<Map<String, dynamic>>>(
                                  key: ValueKey<String>('violation_fines_$_selectedCategory'),
                                  future: _fetchViolationFines(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    
                                    if (snapshot.hasError) {
                                      return Center(
                                        child: Text(
                                          'Error loading violations',
                                          style: TextStyle(color: Colors.red.shade700),
                                        ),
                                      );
                                    }
                                    
                                    final violations = snapshot.data ?? [];
                                    
                                    if (violations.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'No violations found for this category',
                                          style: TextStyle(color: Colors.black54),
                                        ),
                                      );
                                    }
                                    
                                    return ListView.builder(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      itemCount: violations.length,
                                      itemBuilder: (context, index) {
                                        return _buildViolationFineCard(violations[index]);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
              ],
                    ),
                  ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB(255, 247, 139, 150),
              blurRadius: 40,
              spreadRadius: 10,
              offset: Offset(0, -10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.grey.shade200,
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.red,
            unselectedItemColor: Colors.black54,
            onTap: _onItemTapped,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.location_on), label: "Location"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.warning), label: "Rules"),
              BottomNavigationBarItem(
                  icon: Icon(Icons.local_shipping), label: "Parcels"),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            ],
          ),
        ),
      ),
    );
  }
}
class _ViolationFineCardItem extends StatefulWidget {
  final Map<String, dynamic> violation;

  const _ViolationFineCardItem({required this.violation});

  @override
  State<_ViolationFineCardItem> createState() => _ViolationFineCardItemState();
}

class _ViolationFineCardItemState extends State<_ViolationFineCardItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final firstOffense = widget.violation['first_offense'];
    final secondOffense = widget.violation['second_offense'];
    final thirdOffense = widget.violation['third_offense'];
    final subsequentOffense = widget.violation['subsequent_offense'];
    final description = widget.violation['description'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name
          Text(
            widget.violation['name'] ?? 'Unknown',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          
          // Offenses
          if (firstOffense != null) ...[
            _buildOffenseRow('First Offense', firstOffense),
            const SizedBox(height: 4),
          ],
          if (secondOffense != null) ...[
            _buildOffenseRow('Second Offense', secondOffense),
            const SizedBox(height: 4),
          ],
          if (thirdOffense != null) ...[
            _buildOffenseRow('Third Offense', thirdOffense),
            const SizedBox(height: 4),
          ],
          if (subsequentOffense != null) ...[
            _buildOffenseRow('Subsequent Offense', subsequentOffense),
          ],
          
          // Description dropdown
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Row(
                children: [
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildOffenseRow(String label, dynamic value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
