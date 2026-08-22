import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:uuid/uuid.dart';

/// Beautiful dialog for adding a new family member
class AddPersonDialog extends StatefulWidget {
  final String familyTreeId;
  final Function(Person) onSave;

  const AddPersonDialog({
    Key? key,
    required this.familyTreeId,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<AddPersonDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  
  DateTime? _birthDate;
  DateTime? _deathDate;
  String? _gender;
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final person = Person(
        id: const Uuid().v4(),
        familyTreeId: widget.familyTreeId,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        birthDate: _birthDate,
        deathDate: _deathDate,
        gender: _gender,
        bio: _bioController.text.trim(),
        relationships: Relationships(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      widget.onSave(person);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 24 : 40,
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 600,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: ElegantColors.warmWhite,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ElegantColors.charcoal.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    padding: EdgeInsets.all(isMobile ? 20 : 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ElegantColors.terracotta,
                          ElegantColors.terracotta.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Family Member',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: isMobile ? 22 : 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Expand your family tree',
                                style: GoogleFonts.cormorantGaramond(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          color: Colors.white,
                          iconSize: 28,
                        ),
                      ],
                    ),
                  ),
                  
                  // Form content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 20 : 28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Name fields
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _firstNameController,
                                    label: 'First Name',
                                    hint: 'John',
                                    icon: Icons.person_outline_rounded,
                                    validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _lastNameController,
                                    label: 'Last Name',
                                    hint: 'Doe',
                                    icon: Icons.badge_outlined,
                                    validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Gender
                            _buildGenderSelector(),
                            const SizedBox(height: 20),
                            
                            // Dates
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateSelector(
                                    label: 'Birth Date',
                                    date: _birthDate,
                                    icon: Icons.cake_outlined,
                                    onTap: () => _selectBirthDate(context),
                                    onClear: () => setState(() => _birthDate = null),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDateSelector(
                                    label: 'Death Date',
                                    date: _deathDate,
                                    icon: Icons.event_outlined,
                                    optional: true,
                                    onTap: () => _selectDeathDate(context),
                                    onClear: () => setState(() => _deathDate = null),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Bio
                            _buildBioField(),
                            const SizedBox(height: 28),
                            
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      side: BorderSide(color: ElegantColors.champagne, width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.cormorantGaramond(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: ElegantColors.warmGray,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: _save,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ElegantColors.terracotta,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.add_circle_rounded, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Add Person',
                                          style: GoogleFonts.cormorantGaramond(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: GoogleFonts.cormorantGaramond(
        fontSize: 16,
        color: ElegantColors.charcoal,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: ElegantColors.terracotta.withOpacity(0.7)),
        filled: true,
        fillColor: ElegantColors.cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ElegantColors.champagne),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ElegantColors.champagne),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ElegantColors.terracotta, width: 2),
        ),
        labelStyle: GoogleFonts.cormorantGaramond(
          color: ElegantColors.warmGray,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ElegantColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ElegantColors.champagne),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wc_rounded, size: 18, color: ElegantColors.terracotta.withOpacity(0.7)),
              const SizedBox(width: 8),
              Text(
                'Gender',
                style: GoogleFonts.cormorantGaramond(
                  color: ElegantColors.warmGray,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildGenderOption('Male', 'male', Icons.male_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildGenderOption('Female', 'female', Icons.female_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _buildGenderOption('Other', 'other', Icons.transgender_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String label, String value, IconData icon) {
    final isSelected = _gender == value;
    return GestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? ElegantColors.terracotta : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? ElegantColors.terracotta : ElegantColors.champagne,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.white : ElegantColors.warmGray,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : ElegantColors.warmGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime? date,
    required IconData icon,
    bool optional = false,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ElegantColors.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ElegantColors.champagne),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: ElegantColors.terracotta.withOpacity(0.7)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.cormorantGaramond(
                    color: ElegantColors.warmGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (optional)
                  Text(
                    ' (optional)',
                    style: GoogleFonts.cormorantGaramond(
                      color: ElegantColors.warmGray.withOpacity(0.6),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const Spacer(),
                if (date != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.clear_rounded, size: 18, color: ElegantColors.warmGray),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              date != null
                  ? '${date.month}/${date.day}/${date.year}'
                  : 'Tap to select',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                color: date != null ? ElegantColors.charcoal : ElegantColors.warmGray.withOpacity(0.6),
                fontWeight: date != null ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioField() {
    return TextFormField(
      controller: _bioController,
      maxLines: 4,
      style: GoogleFonts.cormorantGaramond(
        fontSize: 15,
        color: ElegantColors.charcoal,
      ),
      decoration: InputDecoration(
        labelText: 'Biography (optional)',
        hintText: 'Share a brief story about this person...',
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: Icon(Icons.description_outlined, color: ElegantColors.terracotta.withOpacity(0.7)),
        ),
        filled: true,
        fillColor: ElegantColors.cream,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ElegantColors.champagne),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ElegantColors.champagne),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ElegantColors.terracotta, width: 2),
        ),
        labelStyle: GoogleFonts.cormorantGaramond(
          color: ElegantColors.warmGray,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1950),
      firstDate: DateTime(1800),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ElegantColors.terracotta,
              onPrimary: Colors.white,
              surface: ElegantColors.warmWhite,
              onSurface: ElegantColors.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _birthDate = date);
    }
  }

  Future<void> _selectDeathDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deathDate ?? DateTime.now(),
      firstDate: _birthDate ?? DateTime(1800),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ElegantColors.terracotta,
              onPrimary: Colors.white,
              surface: ElegantColors.warmWhite,
              onSurface: ElegantColors.charcoal,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _deathDate = date);
    }
  }
}
