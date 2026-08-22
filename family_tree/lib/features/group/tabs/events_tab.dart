import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:family_tree/core/theme/app_theme.dart';
import 'package:family_tree/core/theme/elegant_theme.dart';
import 'package:family_tree/data/models/appointment.dart';
import 'package:family_tree/data/repositories/group_repository.dart';
import 'package:family_tree/features/auth/providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:family_tree/data/services/notification_service.dart';

/// Provider for appointments stream
final appointmentsProvider = StreamProvider.family<List<Appointment>, String>((ref, familyTreeId) {
  final repository = GroupRepository();
  return repository.watchAppointments(familyTreeId);
});

/// Events tab for family appointments and gatherings
class EventsTab extends ConsumerStatefulWidget {
  final bool isDark;
  
  const EventsTab({Key? key, this.isDark = true}) : super(key: key);

  @override
  ConsumerState<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<EventsTab> {
  final GroupRepository _repository = GroupRepository();
  bool _isCalendarView = false; // Toggle between list and calendar view

  void _toggleRSVP(String appointmentId, String userId, String status) async {
    await _repository.toggleRSVP(appointmentId, userId, status);
  }

  void _deleteAppointment(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repository.deleteAppointment(appointmentId);
    }
  }

  String _getRSVPStatus(Appointment appointment, String userId) {
    if (appointment.attendees.contains(userId)) return 'yes';
    if (appointment.maybes?.contains(userId) ?? false) return 'maybe';
    if (appointment.declined?.contains(userId) ?? false) return 'no';
    return '';
  }

  Widget _buildRSVPOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editEvent(Appointment appointment) {
    final titleController = TextEditingController(text: appointment.title);
    final descController = TextEditingController(text: appointment.description ?? '');
    final locationController = TextEditingController(text: appointment.location ?? '');
    DateTime selectedDate = appointment.date;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: widget.isDark ? AppTheme.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Event', style: GoogleFonts.playfairDisplay(
            color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
            fontWeight: FontWeight.w700,
          )),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: GoogleFonts.inter(
                    color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Event Title',
                    labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: widget.isDark ? AppTheme.backgroundDark : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: GoogleFonts.inter(
                    color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Description',
                    labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: widget.isDark ? AppTheme.backgroundDark : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  style: GoogleFonts.inter(
                    color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Location',
                    labelStyle: GoogleFonts.inter(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: widget.isDark ? AppTheme.backgroundDark : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_today, color: AppTheme.primaryLight),
                  title: Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(selectedDate),
                    style: GoogleFonts.inter(
                      color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                    ),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDate = DateTime(
                            date.year, date.month, date.day,
                            time.hour, time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                
                final updated = appointment.copyWith(
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  location: locationController.text.trim(),
                  date: selectedDate,
                );
                await _repository.updateAppointment(updated);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryLight),
              child: Text('Save', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCalendar(Appointment appointment) {
    final event = Event(
      title: appointment.title,
      description: appointment.description ?? '',
      location: appointment.location ?? '',
      startDate: appointment.dateTime,
      endDate: appointment.dateTime.add(const Duration(hours: 1)),
      allDay: false,
    );
    Add2Calendar.addEvent2Cal(event);
  }

  void _setReminder(Appointment appointment) async {
    final result = await showDialog<Duration>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Set Reminder', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        backgroundColor: widget.isDark ? AppTheme.surfaceDark : Colors.white,
        children: [
          SimpleDialogOption(
            child: Text('15 minutes before', style: GoogleFonts.inter(color: widget.isDark ? Colors.white : Colors.black)),
            onPressed: () => Navigator.pop(context, const Duration(minutes: 15)),
          ),
          SimpleDialogOption(
            child: Text('1 hour before', style: GoogleFonts.inter(color: widget.isDark ? Colors.white : Colors.black)),
            onPressed: () => Navigator.pop(context, const Duration(hours: 1)),
          ),
          SimpleDialogOption(
            child: Text('1 day before', style: GoogleFonts.inter(color: widget.isDark ? Colors.white : Colors.black)),
            onPressed: () => Navigator.pop(context, const Duration(days: 1)),
          ),
        ],
      ),
    );

    if (result != null) {
      final scheduledDate = appointment.dateTime.subtract(result);
      if (scheduledDate.isBefore(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot set reminder in the past')),
          );
        }
        return;
      }

      await NotificationService().scheduleNotification(
        id: appointment.id.hashCode,
        title: 'Upcoming Event: ${appointment.title}',
        body: 'Starting in ${result.inMinutes >= 60 ? "${result.inHours} hours" : "${result.inMinutes} minutes"}',
        scheduledDate: scheduledDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder set!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    const familyTreeId = 'main-family-tree';
    final appointmentsAsync = ref.watch(appointmentsProvider(familyTreeId));

    return Column(
      children: [
        // View toggle
        Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: Row(
            children: [
              Text(
                'Events',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                decoration: AppTheme.glassDecoration(),
                child: Row(
                  children: [
                    _buildViewToggleButton(
                      icon: Icons.list,
                      isSelected: !_isCalendarView,
                      onTap: () => setState(() => _isCalendarView = false),
                    ),
                    _buildViewToggleButton(
                      icon: Icons.calendar_month,
                      isSelected: _isCalendarView,
                      onTap: () => setState(() => _isCalendarView = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: appointmentsAsync.when(
            data: (appointments) {
              if (appointments.isEmpty) {
                return _buildEmptyState();
              }

              return _isCalendarView
                  ? _buildCalendarView(appointments, user?.uid ?? '')
                  : _buildListView(appointments, user?.uid ?? '');
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text(
                'Error loading events: $error',
                style: GoogleFonts.inter(color: AppTheme.error),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceSm),
          decoration: BoxDecoration(
            gradient: isSelected ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Appointment> appointments, String currentUserId) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(appointmentsProvider(currentUserId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          final isCreator = appointment.createdBy == currentUserId;
          final isAttending = appointment.attendees.contains(currentUserId);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: _buildEventCard(appointment, currentUserId, isCreator, isAttending),
          );
        },
      ),
    );
  }

  Widget _buildCalendarView(List<Appointment> appointments, String currentUserId) {
    // Group appointments by month
    final grouped = <String, List<Appointment>>{};
    for (final apt in appointments) {
      final monthKey = DateFormat('MMMM yyyy').format(apt.dateTime);
      grouped.putIfAbsent(monthKey, () => []).add(apt);
    }

    final sortedMonths = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMMM yyyy').parse(a);
        final dateB = DateFormat('MMMM yyyy').parse(b);
        return dateA.compareTo(dateB);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      itemCount: sortedMonths.length,
      itemBuilder: (context, index) {
        final month = sortedMonths[index];
        final monthAppointments = grouped[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
              child: Text(
                month,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                ),
              ),
            ),

            // Events in this month
            ...monthAppointments.map((appointment) {
              final isCreator = appointment.createdBy == currentUserId;
              final isAttending = appointment.attendees.contains(currentUserId);

              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: _buildEventCard(appointment, currentUserId, isCreator, isAttending),
              );
            }),

            const SizedBox(height: AppTheme.spaceMd),
          ],
        );
      },
    );
  }

  Widget _buildEventCard(Appointment appointment, String currentUserId, bool isCreator, bool isAttending) {
    final dateStr = DateFormat('MMM dd, yyyy').format(appointment.dateTime);
    final timeStr = DateFormat('h:mm a').format(appointment.dateTime);
    final isPast = appointment.dateTime.isBefore(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: AppTheme.glassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and menu
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSm),
                decoration: BoxDecoration(
                  gradient: isPast
                      ? LinearGradient(colors: [Colors.grey, Colors.grey.shade700])
                      : AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.event, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '$dateStr · $timeStr',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                color: widget.isDark ? AppTheme.surfaceDark : Colors.white,
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteAppointment(appointment.id);
                  } else if (value == 'edit') {
                    _editEvent(appointment);
                  } else if (value == 'calendar') {
                    _addToCalendar(appointment);
                  } else if (value == 'reminder') {
                    _setReminder(appointment);
                  }
                },
                itemBuilder: (context) => [
                  if (isCreator) ...[
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: AppTheme.primaryLight),
                          const SizedBox(width: 8),
                          Text('Edit Event', style: GoogleFonts.inter(
                            color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                          )),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Delete', style: GoogleFonts.inter(
                            color: Colors.red,
                          )),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ],
                  PopupMenuItem(
                    value: 'calendar',
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryLight),
                        const SizedBox(width: 8),
                        Text('Add to Calendar', style: GoogleFonts.inter(
                          color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                        )),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reminder',
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active, size: 18, color: AppTheme.accentGold),
                        const SizedBox(width: 8),
                        Text('Set Reminder', style: GoogleFonts.inter(
                          color: widget.isDark ? AppTheme.textPrimary : ElegantColors.charcoal,
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Description
          if (appointment.description != null && appointment.description!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              appointment.description!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ],

          // Location
          if (appointment.location != null && appointment.location!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppTheme.accentCyan),
                const SizedBox(width: AppTheme.spaceXs),
                Expanded(
                  child: Text(
                    appointment.location!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                // Open in Maps button
                if (appointment.mapLink != null && appointment.mapLink!.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.map, color: AppTheme.primaryLight),
                    tooltip: 'Open in Maps',
                    onPressed: () async {
                      final uri = Uri.parse(appointment.mapLink!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open map link')),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppTheme.spaceMd),

          // Attendees and RSVP button
          Row(
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                '${appointment.attendees.length} attending',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              // RSVP buttons (Yes/Maybe/No)
              if (!isPast)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primaryLight.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildRSVPOption(
                        label: 'Yes',
                        icon: Icons.check,
                        isSelected: isAttending,
                        color: AppTheme.success,
                        onTap: () => _toggleRSVP(appointment.id, currentUserId, 'yes'),
                      ),
                      _buildRSVPOption(
                        label: 'Maybe',
                        icon: Icons.help_outline,
                        isSelected: _getRSVPStatus(appointment, currentUserId) == 'maybe',
                        color: Colors.orange,
                        onTap: () => _toggleRSVP(appointment.id, currentUserId, 'maybe'),
                      ),
                      _buildRSVPOption(
                        label: 'No',
                        icon: Icons.close,
                        isSelected: _getRSVPStatus(appointment, currentUserId) == 'no',
                        color: Colors.red,
                        onTap: () => _toggleRSVP(appointment.id, currentUserId, 'no'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_outlined,
            size: 64,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'No events yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Create an event to get started!',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
