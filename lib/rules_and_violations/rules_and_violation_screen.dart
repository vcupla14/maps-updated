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

  const RulesAndViolationScreen({
    super.key,
    required this.userId,
    this.liveLat,
    this.liveLng,
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
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 670,
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
                            child: Center(
                              key: ValueKey<int>(_selectedTab),
                              child: Text(
                                _selectedTab == 0
                                    ? (_selectedCategory == null
                                        ? "Road Rules Content"
                                        : "Road Rules • $_selectedCategory")
                                    : (_selectedCategory == null
                                        ? "Violation Fines Content"
                                        : "Violation Fines • $_selectedCategory"),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
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
