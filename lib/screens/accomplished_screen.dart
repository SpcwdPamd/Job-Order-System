import 'package:flutter/material.dart';
import 'package:job_order/widgets/ds.dart';
import 'package:job_order/core/theme/theme_provider.dart';
import 'package:job_order/data/admin_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// This screen shows all jobs that have been marked as accomplished or completed
class AccomplishedScreen extends StatefulWidget {
  const AccomplishedScreen({super.key});

  @override
  State<AccomplishedScreen> createState() => _AccomplishedScreenState();
}

class _AccomplishedScreenState extends State<AccomplishedScreen> {
  // Shortcut to access the current theme styles
  Tk get _tk => context.tk;

  // Holds every job loaded from the database before any filtering is applied
  List<Map<String, dynamic>> _allJobs = [];

  // Holds only the jobs that pass the current search text and date filter
  List<Map<String, dynamic>> _filteredJobs = [];

  // List of all personnel fetched from the database
  List<Map<String, dynamic>> _personnel = [];

  // List of all teams fetched from the database
  List<Map<String, dynamic>> _teams = [];

  // Maps a user id number to that users full name and username
  Map<int, Map<String, String>> _usersMap = {};

  // Controls whether the loading spinner is shown while data is being fetched
  bool _isLoading = true;

  // Controls the text inside the search bar
  final TextEditingController _searchController = TextEditingController();

  // The currently selected month for filtering, null means show all months
  int? _filterMonth;

  // The currently selected year for filtering, defaults to the current year
  int _filterYear = DateTime.now().year;

  // Builds a list of work type options from the global work types notifier
  List<Map<String, String>> get workTypes => workTypesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name})
      .toList();

  // Builds a list of damaged space options from the global damage spaces notifier
  List<Map<String, String>> get damagedOptions => damageSpacesNotifier.items
      .map((e) => {'code': e.code, 'name': e.name})
      .toList();

  // Returns the display name of a work type using its code, falls back to the code itself if not found
  String _workTypeName(String? code) {
    if (code == null) return '—';
    return workTypes.firstWhere(
          (e) => e['code'] == code,
      orElse: () => {'code': code, 'name': code},
    )['name']!;
  }

  // Returns the display name of a damaged space using its code, falls back to the code itself if not found
  String _damagedName(String? code) {
    if (code == null) return '—';
    return damagedOptions.firstWhere(
          (e) => e['code'] == code,
      orElse: () => {'code': code, 'name': code},
    )['name']!;
  }

  // The three available shift time options shown in dropdowns
  final List<String> shiftTimes = [
    '6:00 AM – 2:00 PM',
    '8:00 AM – 5:00 PM',
    '2:00 PM – 10:00 PM',
  ];

  // The list of barangay addresses available when editing a job
  final List<String> addresses = [
    'Bagong Bayan I-C', 'Bagong Pook VI-C', 'Barangay I-A', 'Barangay I-B',
    'Barangay II-A', 'Barangay II-B', 'Barangay II-C', 'Barangay II-D',
    'Barangay II-E', 'Barangay II-F', 'Barangay III-A', 'Barangay III-B',
    'Barangay III-C', 'Barangay III-D', 'Barangay III-E', 'Barangay III-F',
    'Barangay IV-A', 'Barangay IV-B', 'Barangay IV-C', 'Barangay V-A',
    'Barangay V-B', 'Barangay V-C', 'Barangay V-D', 'Barangay VI-A',
    'Barangay VI-B', 'Barangay VI-D', 'Barangay VI-E', 'Barangay VII-A',
    'Barangay VII-B', 'Barangay VII-C', 'Barangay VII-D', 'Barangay VII-E',
    'Bautista', 'Concepcion', 'Del Remedio', 'Dolores',
    'San Antonio I', 'San Antonio II', 'San Bartolome', 'San Buenaventura',
    'San Crispin', 'San Cristobal', 'San Diego', 'San Francisco',
    'San Gabriel', 'San Gregorio', 'San Ignacio', 'San Isidro',
    'San Joaquin', 'San Jose', 'San Juan', 'San Lorenzo',
    'San Lucas I', 'San Lucas II', 'San Marcos', 'San Mateo',
    'San Miguel', 'San Nicolas', 'San Pedro', 'San Rafael',
    'San Roque', 'San Vicente', 'Sta Ana', 'Sta Catalina',
    'Sta Cruz', 'Sta Felomina', 'Sta Isabel', 'Sta Ma. Magdalena',
    'Sta Veronica', 'Santiago I', 'Santiago II', 'Stmo. Rosario',
    'Sto Angel', 'Sto Cristo', 'Sto Nino', 'Soledad',
    'Sta Monica', 'Sta Maria', 'Sta Elena', 'Others / No Address Listed',
  ];

  // Returns the text shown on the filter button, either a month and year or the word Overall
  String get _filterLabel {
    if (_filterMonth == null) return 'Overall';
    return DateFormat('MMMM yyyy').format(DateTime(_filterYear, _filterMonth!));
  }

  // Runs when the screen first opens, loads all needed data and starts listening to search input
  @override
  void initState() {
    super.initState();
    _loadPersonnel();
    _loadTeams();
    _loadUsers();
    _fetchAccomplishedJobs();
    // Re-run the filter every time the user types something in the search bar
    _searchController.addListener(_filterJobs);
  }

  // Cleans up the search controller when this screen is removed from memory
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetches all users from the database and stores them in a map keyed by their id
  Future<void> _loadUsers() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('id, full_name, username');
      if (mounted) {
        final map = <int, Map<String, String>>{};
        for (final u in res as List<dynamic>) {
          map[u['id'] as int] = {
            'full_name': u['full_name'] as String? ?? '',
            'username': u['username'] as String? ?? '',
          };
        }
        setState(() => _usersMap = map);
      }
    } catch (_) {}
  }

  // Fetches all personnel from the database ordered by name
  Future<void> _loadPersonnel() async {
    try {
      final res = await Supabase.instance.client
          .from('personnel')
          .select('id, name, profile_pic_url')
          .order('name');
      if (mounted) {
        setState(() => _personnel = List<Map<String, dynamic>>.from(res));
      }
    } catch (e) {
      _showError('Failed to load personnel: $e');
    }
  }

  // Fetches all teams from the database and also loads each teams member details
  Future<void> _loadTeams() async {
    try {
      final teamsRes = await Supabase.instance.client.from('teams').select('''
            id, team_name, foreman_id, personnel_ids, driver_id,
            foreman:foreman_id (name, profile_pic_url),
            driver:driver_id (name, profile_pic_url)
          ''').order('team_name');

      final teamsWithMembers = <Map<String, dynamic>>[];
      for (final team in teamsRes) {
        // For each team, load the full details of each member using their ids
        final membersRes = await Supabase.instance.client
            .from('personnel')
            .select('id, name, profile_pic_url')
            .inFilter('id', team['personnel_ids'] ?? []);
        teamsWithMembers.add({...team, 'members': membersRes});
      }
      if (mounted) setState(() => _teams = teamsWithMembers);
    } catch (e) {
      _showError('Error loading teams: $e');
    }
  }

  // Fetches both regular accomplished jobs and completed skeletal jobs from the database at the same time
  Future<void> _fetchAccomplishedJobs() async {
    setState(() => _isLoading = true);
    try {
      // Query for regular job orders with status accomplished
      final regularFuture = Supabase.instance.client
          .from('job_orders')
          .select('''
            id, jo_number, shift_index, shift_time, team_id,
            team:team_id (team_name, foreman_id, personnel_ids, driver_id,
              foreman:foreman_id (name, profile_pic_url),
              driver:driver_id (name, profile_pic_url)
            ),
            leader_id, member_ids,
            work_type_code, work_type_name, difficulty_level,
            damaged_space_code, damaged_space_name, address, remarks,
            zone, created_at, completed_at, job_photo_url, status,
            created_by_user_id, edited_by_user_id, edited_at,
            accomplished_by_user_id
          ''')
          .eq('status', 'accomplished')
          .order('completed_at', ascending: false);

      // Query for skeletal jobs with status completed
      final skeletalFuture = Supabase.instance.client
          .from('skeletal_job')
          .select('''
            id, name, leader_id, member_ids, driver_id,
            work_type_code, work_type_name, difficulty_level,
            damaged_space_code, damaged_space_name, address, remarks,
            created_at, completed_at, status
          ''')
          .eq('status', 'completed')
          .order('completed_at', ascending: false);

      // Run both queries at the same time to save loading time
      final results = await Future.wait([regularFuture, skeletalFuture]);

      // Tag each regular job with its type and a display id using the jo number
      final regularJobs = (results[0] as List<dynamic>)
          .map((j) => {
        ...Map<String, dynamic>.from(j),
        'type': 'regular',
        'display_id': j['jo_number'] ?? '—',
        'display_title': j['jo_number'] ?? 'Regular Job',
        'is_skeletal': false,
      })
          .toList();

      // Tag each skeletal job with its type and a display id using the name field
      final skeletalJobs = (results[1] as List<dynamic>)
          .map((j) => {
        ...Map<String, dynamic>.from(j),
        'type': 'skeletal',
        'display_id': j['name'] ??
            'SK-${(j['id'] as String?)?.substring(0, 8) ?? 'unknown'}',
        'display_title': j['name'] ?? 'Skeletal Assignment',
        'team': null,
        'jo_number': null,
        'job_photo_url': null,
        'shift_time': '—',
        'is_skeletal': true,
      })
          .toList();

      // Combine both lists and sort them so the most recently completed job appears first
      final merged = [...regularJobs, ...skeletalJobs]
        ..sort((a, b) {
          final aTime = a['completed_at'] as String?;
          final bTime = b['completed_at'] as String?;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return DateTime.parse(bTime).compareTo(DateTime.parse(aTime));
        });

      if (mounted) {
        setState(() {
          _allJobs = merged;
          _isLoading = false;
        });
        // Apply the current filter immediately after loading so the list is correct
        _applyFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading accomplished jobs: $e');
      }
    }
  }

  // Filters the full job list using the selected month and year, then applies the search text on top
  void _applyFilter() {
    List<Map<String, dynamic>> dateFiltered;

    // If no month is selected, use all jobs without any date restriction
    if (_filterMonth == null) {
      dateFiltered = List.from(_allJobs);
    } else {
      // Keep only jobs whose completed date matches the selected month and year
      dateFiltered = _allJobs.where((job) {
        final ts = job['completed_at'] as String?;
        if (ts == null) return false;
        final dt = DateTime.parse(ts).toLocal();
        return dt.year == _filterYear && dt.month == _filterMonth;
      }).toList();
    }

    final query = _searchController.text.toLowerCase().trim();

    // If the search bar is empty, show all date filtered jobs with no further filtering
    if (query.isEmpty) {
      setState(() => _filteredJobs = dateFiltered);
    } else {
      // Keep only jobs where the id, team name, work type, address, or name contains the search text
      setState(() {
        _filteredJobs = dateFiltered.where((job) {
          final id = (job['display_id'] ?? '').toString().toLowerCase();
          final team =
          (job['team']?['team_name'] ?? '').toString().toLowerCase();
          final type =
          (job['work_type_name'] ?? '').toString().toLowerCase();
          final addr = (job['address'] ?? '').toString().toLowerCase();
          final name = (job['name'] ?? '').toString().toLowerCase();
          return id.contains(query) ||
              team.contains(query) ||
              type.contains(query) ||
              addr.contains(query) ||
              name.contains(query);
        }).toList();
      });
    }
  }

  // Called every time the search bar text changes, re-runs the filter
  void _filterJobs() => _applyFilter();

  // Opens a dialog that lets the user pick a month and year to filter by, or choose overall
  void _showMonthYearPicker() {
    final isDark = _tk.dark;
    final nowYear = DateTime.now().year;

    // Temporary variables used inside the dialog before the user confirms their selection
    int selYear = _filterYear;
    int? selMonth = _filterMonth;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          // Color values change based on whether the app is in dark mode
          final surfColor =
          isDark ? const Color(0xFF101827) : Colors.white;
          final surf2Color =
          isDark ? const Color(0xFF161F30) : const Color(0xFFF7FAFD);
          final bdColor =
          isDark ? const Color(0xFF1E2E47) : const Color(0xFFDDE6F0);
          final txtHead =
          isDark ? const Color(0xFFEDF2FF) : const Color(0xFF0D1F3C);
          final txtMuted =
          isDark ? const Color(0xFF475F7E) : const Color(0xFF7A93B4);
          final txtNorm =
          isDark ? const Color(0xFFAFC4DE) : const Color(0xFF2D4263);
          const accent = Color(0xFF059669);

          return Dialog(
            backgroundColor: surfColor,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            elevation: 24,
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row with icon, title text, and a close button
                    Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [accent, Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                                color: accent.withOpacity(0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ],
                        ),
                        child: const Icon(Icons.filter_alt_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Filter by Period',
                                    style: TextStyle(
                                        color: txtHead,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800)),
                                Text('Select month & year or overall',
                                    style: TextStyle(
                                        color: txtMuted, fontSize: 11.5)),
                              ])),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                              color: bdColor,
                              borderRadius: BorderRadius.circular(8)),
                          child:
                          Icon(Icons.close_rounded, color: txtMuted, size: 16),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // Tapping this chip sets the selected month to null which means show all time
                    GestureDetector(
                      onTap: () => setModal(() => selMonth = null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: selMonth == null
                              ? const LinearGradient(
                            colors: [accent, Color(0xFF047857)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : null,
                          color: selMonth != null ? surf2Color : null,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selMonth == null
                                ? accent
                                : bdColor,
                            width: selMonth == null ? 0 : 1,
                          ),
                          boxShadow: selMonth == null
                              ? [
                            BoxShadow(
                                color: accent.withOpacity(0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 3))
                          ]
                              : null,
                        ),
                        child: Row(children: [
                          Icon(Icons.public_rounded,
                              color:
                              selMonth == null ? Colors.white : txtMuted,
                              size: 16),
                          const SizedBox(width: 10),
                          Text('Overall (All Time)',
                              style: TextStyle(
                                  color: selMonth == null
                                      ? Colors.white
                                      : txtNorm,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          // Show a checkmark icon only when overall is currently selected
                          if (selMonth == null)
                            Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded,
                                  color: accent, size: 12),
                            ),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section label for the year selector
                    Text('YEAR',
                        style: TextStyle(
                            color: txtMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 8),

                    // Row with left and right arrows to decrease or increase the selected year
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: surf2Color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: bdColor),
                      ),
                      child: Row(children: [
                        // Left arrow decreases the year but will not go below 2020
                        GestureDetector(
                          onTap: selYear > 2020
                              ? () => setModal(() => selYear--)
                              : null,
                          child: Container(
                            width: 44,
                            height: 46,
                            child: Center(
                                child: Icon(Icons.chevron_left_rounded,
                                    color: selYear > 2020
                                        ? const Color(0xFF059669)
                                        : bdColor,
                                    size: 22)),
                          ),
                        ),
                        Container(width: 1, height: 26, color: bdColor),
                        // Shows the currently selected year in the center
                        Expanded(
                            child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Text('$selYear',
                                      key: ValueKey(selYear),
                                      style: TextStyle(
                                          color: txtHead,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                ))),
                        Container(width: 1, height: 26, color: bdColor),
                        // Right arrow increases the year with no upper limit
                        GestureDetector(
                          onTap: () => setModal(() => selYear++),
                          child: Container(
                            width: 44,
                            height: 46,
                            child: Center(
                                child: Icon(Icons.chevron_right_rounded,
                                    color: const Color(0xFF059669), size: 22)),
                          ),
                        ),
                      ]),
                    ),

                    const SizedBox(height: 16),

                    // Section label for the month grid
                    Text('MONTH',
                        style: TextStyle(
                            color: txtMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 8),

                    // Grid of 12 month buttons, the selected one is highlighted in green
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.1,
                      children: List.generate(12, (i) {
                        final month = i + 1;
                        final label =
                        DateFormat('MMM').format(DateTime(2000, month));
                        final isSel = selMonth == month;
                        return GestureDetector(
                          onTap: () => setModal(() => selMonth = month),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            decoration: BoxDecoration(
                              gradient: isSel
                                  ? const LinearGradient(
                                colors: [accent, Color(0xFF047857)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                                  : null,
                              color: isSel ? null : surf2Color,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                  color: isSel ? accent : bdColor,
                                  width: isSel ? 0 : 1),
                              boxShadow: isSel
                                  ? [
                                BoxShadow(
                                    color: accent.withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                                  : null,
                            ),
                            child: Center(
                                child: Text(label,
                                    style: TextStyle(
                                        color: isSel ? Colors.white : txtNorm,
                                        fontSize: 12.5,
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.w500))),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 20),

                    // Bottom row with a cancel button and an apply button
                    Row(children: [
                      // Cancel closes the dialog without saving any changes
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 44,
                          padding:
                          const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: surf2Color,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: bdColor),
                          ),
                          child: Center(
                              child: Text('Cancel',
                                  style: TextStyle(
                                      color: txtNorm,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Apply saves the selected month and year and re-runs the filter
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _filterMonth = selMonth;
                              _filterYear = selYear;
                            });
                            _applyFilter();
                          },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [accent, Color(0xFF047857)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: [
                                BoxShadow(
                                    color: accent.withOpacity(0.4),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: const Center(
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_rounded,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text('Apply Filter',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700)),
                                    ])),
                          ),
                        ),
                      ),
                    ]),
                  ]),
            ),
          );
        },
      ),
    );
  }

  // Shows a red snackbar at the bottom of the screen with the given error message
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFFDC2626)),
      );
    }
  }

  // Converts a raw timestamp string into a readable date and optional time format
  String _formatDate(dynamic timestamp, {bool showTime = true}) {
    if (timestamp == null) return '—';
    final date = DateTime.parse(timestamp.toString()).toLocal();
    return DateFormat(showTime ? 'MMM d, yyyy • h:mm a' : 'MMM d, yyyy')
        .format(date);
  }

  // Looks up a user by their id and returns their full name and username as a single string
  String _resolveUser(dynamic userId) {
    if (userId == null) return '—';
    final id =
    userId is int ? userId : int.tryParse(userId.toString());
    if (id == null) return '—';
    final u = _usersMap[id];
    if (u == null) return '—';
    final name =
    u['full_name']!.isNotEmpty ? u['full_name']! : u['username']!;
    final uname =
    u['username']!.isNotEmpty ? ' (@${u['username']})' : '';
    return '$name$uname';
  }

  // Builds a small rounded label with a colored background used on job cards
  Widget _buildCompactTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  // Builds the card shown in the list for a single job, tapping it opens the detail dialog
  Widget _buildCompactCard(Map<String, dynamic> job) {
    // Skeletal jobs use orange and regular jobs use green as their accent color
    final isSkeletal = job['is_skeletal'] == true;
    final accent =
    isSkeletal ? Colors.orange.shade700 : Colors.green.shade700;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: _tk.dark ? 0 : 2,
      color: _tk.dark ? const Color(0xFF101827) : null,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: _tk.dark
                  ? const Color(0xFF1E2E47)
                  : Colors.transparent)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showJobDetailDialog(job),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left colored box showing the job id or name
              Container(
                width: 90,
                padding: const EdgeInsets.symmetric(
                    vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [accent, accent.withOpacity(0.85)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    job['display_id'] ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Middle section showing shift time, team name, work type, and address
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${job['shift_time'] ?? '—'} • ${isSkeletal ? "Skeletal" : (job['team']?['team_name'] ?? '—')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: _tk.dark
                              ? const Color(0xFFEDF2FF)
                              : Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['work_type_name'] ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: _tk.dark
                              ? const Color(0xFF475F7E)
                              : const Color(0xFF94A3B8)),
                    ),
                    if ((job['address'] ?? '').toString().trim().isNotEmpty)
                      Text(
                        job['address']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: _tk.dark
                                ? const Color(0xFF475F7E)
                                : const Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Right section showing difficulty tag, damaged space initial, and a chevron arrow
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCompactTag(
                          {
                            1: 'Minor',
                            2: 'Moderate',
                            3: 'Major'
                          }[job['difficulty_level']] ??
                              'L${job['difficulty_level'] ?? '?'}',
                          Colors.deepPurple),
                      const SizedBox(width: 6),
                      // Shows only the first letter of the damaged space name as a short label
                      _buildCompactTag(
                        (job['damaged_space_name'] ?? '?')
                            .toString()
                            .substring(0, 1),
                        Colors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Icon(Icons.chevron_right_rounded, color: accent, size: 28),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Opens a full detail dialog for the given job showing all its information
  void _showJobDetailDialog(Map<String, dynamic> job) {
    final isSkeletal = job['is_skeletal'] == true;
    final photoUrl = job['job_photo_url'] as String?;
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;
    final teamName = isSkeletal
        ? 'Skeletal Assignment'
        : (job['team']?['team_name'] as String? ?? '—');

    // Green accent for regular jobs, orange for skeletal jobs
    final Color accentA =
    isSkeletal ? const Color(0xFFF97316) : const Color(0xFF059669);
    final Color accentB =
    isSkeletal ? const Color(0xFFEA580C) : const Color(0xFF047857);
    const Color driverAccent = Color(0xFF0284C7);

    // Resolve the leader name and photo from personnel or from the team foreman field
    String? leaderName, leaderPic;
    if (isSkeletal) {
      final ldr = _personnel.firstWhere(
              (p) => p['id'] == job['leader_id'],
          orElse: () => {'name': '—', 'profile_pic_url': null});
      leaderName = ldr['name'] as String?;
      leaderPic = ldr['profile_pic_url'] as String?;
    } else {
      final ldrData = job['team']?['foreman'] as Map<String, dynamic>?;
      leaderName = ldrData?['name'] as String?;
      leaderPic = ldrData?['profile_pic_url'] as String?;
    }

    // Resolve the driver name and photo from personnel or from the team driver field
    String? driverName, driverPic;
    if (isSkeletal) {
      final driverId = job['driver_id'] as String?;
      if (driverId != null) {
        final drv = _personnel.firstWhere(
              (p) => p['id'] == driverId,
          orElse: () => {'name': '—', 'profile_pic_url': null},
        );
        driverName = drv['name'] as String?;
        driverPic = drv['profile_pic_url'] as String?;
      }
    } else {
      final drvData = job['team']?['driver'] as Map<String, dynamic>?;
      if (drvData != null) {
        driverName = drvData['name'] as String?;
        driverPic = drvData['profile_pic_url'] as String?;
      }
    }

    // Get the list of member ids from either the skeletal job or the team depending on the type
    final memberIds = isSkeletal
        ? (job['member_ids'] as List<dynamic>?)?.cast<String>() ?? []
        : (job['team']?['personnel_ids'] as List<dynamic>?)?.cast<String>() ??
        [];

    // Maps a difficulty level number to a label and a display color
    final diffMap = {1: 'Minor', 2: 'Moderate', 3: 'Major'};
    final diffColorMap = {
      1: const Color(0xFF0891B2),
      2: const Color(0xFFD97706),
      3: const Color(0xFFDC2626),
    };
    final diffLevel = job['difficulty_level'] as int? ?? 2;
    final diffLabel = diffMap[diffLevel] ?? 'Level $diffLevel';
    final diffColor = diffColorMap[diffLevel] ?? const Color(0xFFD97706);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
        const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: ConstrainedBox(
          constraints:
          const BoxConstraints(maxWidth: 580, maxHeight: 820),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: Column(children: [
                // Gradient header banner with job id, status badge, and team info chips
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentA, accentB],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(children: [
                    // Decorative dot pattern drawn behind the header content
                    Positioned.fill(
                        child: CustomPaint(painter: _HeroDotPainter())),
                    Padding(
                      padding:
                      const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              // Badge showing whether this is a skeletal or accomplished job
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.25)),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                          isSkeletal
                                              ? Icons.bolt_rounded
                                              : Icons.verified_rounded,
                                          color: Colors.white,
                                          size: 13),
                                      const SizedBox(width: 5),
                                      Text(
                                          isSkeletal
                                              ? 'SKELETAL'
                                              : 'ACCOMPLISHED',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2)),
                                    ]),
                              ),
                              const Spacer(),
                              // Edit button closes the detail dialog and opens the edit dialog
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _showEditAccomplishedDialog(job);
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color:
                                        Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 17),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Close button dismisses the detail dialog
                              GestureDetector(
                                onTap: () => Navigator.pop(ctx),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color:
                                        Colors.white.withOpacity(0.25)),
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 20),
                            Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.end,
                                children: [
                                  // Trophy icon box on the left side of the header
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color:
                                      Colors.white.withOpacity(0.22),
                                      borderRadius:
                                      BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.white
                                              .withOpacity(0.3)),
                                    ),
                                    child: const Icon(
                                        Icons.emoji_events_rounded,
                                        color: Colors.white,
                                        size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  // Job id as the main heading and completed date below it
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                job['display_id'] ?? 'No ID',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.6)),
                                            const SizedBox(height: 2),
                                            Row(children: [
                                              const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: Colors.white,
                                                  size: 13),
                                              const SizedBox(width: 5),
                                              Text(
                                                  'Completed  ${_formatDate(job['completed_at'])}',
                                                  style: TextStyle(
                                                      color: Colors.white
                                                          .withOpacity(0.88),
                                                      fontSize: 12)),
                                            ]),
                                          ])),
                                ]),
                            const SizedBox(height: 18),
                            // Small chips at the bottom of the header showing team, shift, and address
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              _heroChip(Icons.groups_rounded, teamName),
                              if ((job['shift_time'] ?? '')
                                  .toString()
                                  .isNotEmpty &&
                                  !isSkeletal)
                                _heroChip(Icons.access_time_rounded,
                                    job['shift_time']),
                              _heroChip(Icons.location_on_rounded,
                                  job['address'] ?? '—'),
                            ]),
                          ]),
                    ),
                  ]),
                ),

                // Scrollable body below the header containing all detail cards
                Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show the job photo if one exists
                            if (hasPhoto) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.network(photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFFE2E8F0),
                                        child: const Icon(
                                            Icons.broken_image_rounded,
                                            size: 60,
                                            color: Color(0xFFCBD5E1)),
                                      )),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Card showing work type, address, damaged space, difficulty, zone, and remarks
                            _infoCard(
                              icon: Icons.assignment_rounded,
                              title: 'Job Details',
                              accent: accentA,
                              children: [
                                _infoRow('Work Type',
                                    job['work_type_name'] ?? '—',
                                    Icons.build_rounded),
                                _infoRow('Address', job['address'] ?? '—',
                                    Icons.location_on_rounded),
                                _infoRow(
                                    'Damaged Space',
                                    job['damaged_space_name'] ?? '—',
                                    Icons.foundation_rounded),
                                // Difficulty uses a colored pill badge instead of plain text
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(children: [
                                    const Icon(Icons.speed_rounded,
                                        size: 15,
                                        color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 10),
                                    const SizedBox(
                                        width: 110,
                                        child: Text('Difficulty',
                                            style: TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 13))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: diffColor.withOpacity(0.10),
                                        borderRadius:
                                        BorderRadius.circular(20),
                                        border: Border.all(
                                            color:
                                            diffColor.withOpacity(0.30)),
                                      ),
                                      child: Text(diffLabel,
                                          style: TextStyle(
                                              color: diffColor,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ]),
                                ),
                                if ((job['zone'] ?? '').toString().trim().isNotEmpty)
                                  _infoRow('Zone', job['zone'].toString(),
                                      Icons.map_rounded),
                                if ((job['remarks'] ?? '').toString().trim().isNotEmpty)
                                  _infoRow('Remarks', job['remarks'].toString(),
                                      Icons.notes_rounded),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Card showing the leader, driver, and all team members with their photos
                            _infoCard(
                              icon: Icons.groups_rounded,
                              title: isSkeletal ? 'Skeletal Team' : 'Team',
                              accent: accentA,
                              children: [
                                _memberRow(
                                  label: 'Leader',
                                  name: leaderName ?? '—',
                                  picUrl: leaderPic,
                                  isLeader: true,
                                  accent: accentA,
                                ),

                                // Show the driver row only if a driver exists for this job
                                if (driverName != null) ...[
                                  const SizedBox(height: 4),
                                  _memberRow(
                                    label: 'Driver',
                                    name: driverName,
                                    picUrl: driverPic,
                                    isDriver: true,
                                    accent: driverAccent,
                                  ),
                                ],

                                // Show member chips only if there is at least one member
                                if (memberIds.isNotEmpty) ...[
                                  const Padding(
                                    padding:
                                    EdgeInsets.only(top: 4, bottom: 12),
                                    child: Divider(
                                        height: 1,
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  Text(
                                      'Members (${memberIds.length})',
                                      style: const TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5)),
                                  const SizedBox(height: 12),
                                  // Build an avatar chip for each member id by looking them up in the personnel list
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: memberIds.map((id) {
                                      final m = _personnel.firstWhere(
                                              (p) => p['id'] == id,
                                          orElse: () => {
                                            'name': 'Unknown',
                                            'profile_pic_url': null
                                          });
                                      return _avatarChip(
                                        name: m['name'] as String? ?? '—',
                                        picUrl: m['profile_pic_url'] as String?,
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Card showing when the job was created and when it was completed
                            _infoCard(
                              icon: Icons.timeline_rounded,
                              title: 'Timeline',
                              accent: accentA,
                              children: [
                                _timelineRow('Created',
                                    _formatDate(job['created_at']),
                                    isFirst: true),
                                _timelineRow(
                                    'Completed',
                                    _formatDate(job['completed_at']),
                                    isLast: true,
                                    color: accentA),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Card showing which users created, edited, and accomplished the job, regular only
                            if (!isSkeletal)
                              _infoCard(
                                icon: Icons.manage_accounts_rounded,
                                title: 'Activity',
                                accent: const Color(0xFF6366F1),
                                children: [
                                  _infoRow(
                                      'Created by',
                                      _resolveUser(
                                          job['created_by_user_id']),
                                      Icons.person_add_rounded),
                                  if (job['edited_by_user_id'] != null)
                                    _infoRow(
                                        'Edited by',
                                        _resolveUser(
                                            job['edited_by_user_id']),
                                        Icons.edit_rounded),
                                  _infoRow(
                                      'Accomplished by',
                                      _resolveUser(
                                          job['accomplished_by_user_id']),
                                      Icons.how_to_reg_rounded),
                                ],
                              ),
                            const SizedBox(height: 8),
                          ]),
                    )),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // Builds a small white chip with an icon and label used in the detail dialog header
  Widget _heroChip(IconData icon, String label) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border:
      Border.all(color: Colors.white.withOpacity(0.22)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 12),
      const SizedBox(width: 5),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w600)),
      ),
    ]),
  );

  // Builds a white rounded card with a title row and a list of child widgets inside it
  Widget _infoCard({
    required IconData icon,
    required String title,
    required Color accent,
    required List<Widget> children,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EFF6)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Small colored icon box used as the card section header icon
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 15),
                ),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),
              ...children,
            ]),
      );

  // Builds a single labeled row with an icon, a fixed width label, and a value on the right
  Widget _infoRow(String label, String value, IconData icon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 10),
              SizedBox(
                  width: 110,
                  child: Text(label,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 13))),
              Expanded(
                  child: Text(value,
                      style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600))),
            ]),
      );

  // Builds a row showing a person with their avatar, role label, name, and a badge
  Widget _memberRow({
    required String label,
    required String name,
    required String? picUrl,
    bool isLeader = false,
    bool isDriver = false,
    required Color accent,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Stack(children: [
            // Circle avatar showing the persons photo or a default person icon
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage:
              picUrl != null ? NetworkImage(picUrl) : null,
              child: picUrl == null
                  ? const Icon(Icons.person_rounded,
                  color: Color(0xFF94A3B8), size: 22)
                  : null,
            ),
            // Small badge in the bottom right of the avatar showing a star for leader or car for driver
            if (isLeader || isDriver)
              Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      isLeader
                          ? Icons.star_rounded
                          : Icons.directions_car_rounded,
                      color: Colors.white,
                      size: 9,
                    ),
                  )),
          ]),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Small grey label above the name showing the role
                    Text(label,
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11.5)),
                    Text(name,
                        style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ])),
          // Pill badge on the right showing Leader or Driver text
          if (isLeader || isDriver)
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: Text(
                isLeader ? 'Leader' : 'Driver',
                style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
        ]),
      );

  // Builds a small rounded chip showing a persons avatar and name side by side
  Widget _avatarChip(
      {required String name, required String? picUrl}) =>
      Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFFE2E8F0),
            backgroundImage:
            picUrl != null ? NetworkImage(picUrl) : null,
            child: picUrl == null
                ? const Icon(Icons.person_rounded,
                color: Color(0xFF94A3B8), size: 12)
                : null,
          ),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  // Builds one row in the timeline card with a dot, a connecting line, a label, and a timestamp
  Widget _timelineRow(String label, String time,
      {bool isFirst = false,
        bool isLast = false,
        Color color = const Color(0xFF94A3B8)}) =>
      IntrinsicHeight(
        child: Row(children: [
          SizedBox(
              width: 24,
              child: Column(children: [
                // Line above the dot, hidden for the first item
                if (!isFirst)
                  Expanded(
                      child: Container(
                          width: 2,
                          color: const Color(0xFFE2E8F0))),
                // Dot is colored and glowing for the last item
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isLast ? color : const Color(0xFFCBD5E1),
                    shape: BoxShape.circle,
                    boxShadow: isLast
                        ? [
                      BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 6)
                    ]
                        : null,
                  ),
                ),
                // Line below the dot, hidden for the last item
                if (!isLast)
                  Expanded(
                      child: Container(
                          width: 2,
                          color: const Color(0xFFE2E8F0))),
              ])),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11.5)),
                  // The last item uses the accent color to highlight the completed date
                  Text(time,
                      style: TextStyle(
                          color: isLast ? color : const Color(0xFF1E293B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                ]),
          ),
        ]),
      );

  // Opens a dialog that lets the admin edit the details of an accomplished or skeletal job
  void _showEditAccomplishedDialog(Map<String, dynamic> job) {
    final isSkeletal = job['is_skeletal'] == true;
    final accent =
    isSkeletal ? Colors.orange.shade700 : Colors.green.shade700;

    // Pre-fill all controllers and variables with the jobs current saved values
    final remarksController =
    TextEditingController(text: job['remarks'] as String? ?? '');
    String? selectedWorkTypeCode = job['work_type_code'] as String?;
    String? selectedWorkTypeName = job['work_type_name'] as String? ??
        (selectedWorkTypeCode != null
            ? _workTypeName(selectedWorkTypeCode)
            : null);
    int selectedDifficulty = (job['difficulty_level'] as int?) ?? 2;
    String? selectedDamagedCode = job['damaged_space_code'] as String?;
    String? selectedDamagedName = job['damaged_space_name'] as String? ??
        (selectedDamagedCode != null
            ? _damagedName(selectedDamagedCode)
            : null);
    String? selectedAddress = job['address'] as String?;

    String? selectedTeamId =
    isSkeletal ? null : (job['team_id'] as String?);
    int selectedShiftIndex =
    shiftTimes.indexOf(job['shift_time'] as String? ?? shiftTimes[0]);
    if (selectedShiftIndex == -1) selectedShiftIndex = 0;
    final joNumberController =
    TextEditingController(text: job['jo_number'] as String? ?? '');

    String? selectedLeaderId =
    isSkeletal ? (job['leader_id'] as String?) : null;
    String? selectedDriverId = job['driver_id'] as String?;
    List<String> selectedMemberIds = isSkeletal
        ? List<String>.from(
        (job['member_ids'] as List<dynamic>?)?.whereType<String>() ?? [])
        : [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Build the address dropdown items and prepend the current address if it is not in the standard list
            final addressItems = <DropdownMenuItem<String?>>[
              ...addresses.map(
                      (a) => DropdownMenuItem<String?>(value: a, child: Text(a))),
            ];
            if (selectedAddress != null &&
                !addresses.contains(selectedAddress)) {
              addressItems.insert(
                0,
                DropdownMenuItem<String?>(
                    value: selectedAddress,
                    child: Text('$selectedAddress (current)')),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              title: Row(children: [
                Icon(Icons.edit_note_rounded, color: accent),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                        'Edit ${isSkeletal ? "Skeletal" : "Regular"} Job')),
              ]),
              content: SizedBox(
                width: 600,
                height: MediaQuery.of(context).size.height * 0.80,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Regular jobs show a job order number field, skeletal jobs show the name as plain text
                      if (!isSkeletal) ...[
                        TextField(
                          controller: joNumberController,
                          decoration: InputDecoration(
                            labelText: 'Job Order Number',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.numbers),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        Text(
                          "Skeletal Job: ${job['name'] ?? 'Unnamed'}",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Regular jobs let the user change the team, skeletal jobs let them change leader, driver, and members
                      if (!isSkeletal) ...[
                        const Text('Team',
                            style:
                            TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          value: selectedTeamId,
                          isExpanded: true,
                          decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(12))),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('— Select Team —')),
                            ..._teams.map((t) => DropdownMenuItem(
                              value: t['id'] as String?,
                              child: Text(t['team_name'] as String),
                            )),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => selectedTeamId = v),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        // Leader dropdown for skeletal jobs
                        const Text('Leader',
                            style:
                            TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          value: selectedLeaderId,
                          isExpanded: true,
                          decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(12))),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('— None —')),
                            ..._personnel.map((p) => DropdownMenuItem(
                              value: p['id'] as String?,
                              child: Text(p['name'] as String),
                            )),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => selectedLeaderId = v),
                        ),
                        const SizedBox(height: 24),

                        // Driver dropdown for skeletal jobs
                        const Text('Driver',
                            style:
                            TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          value: selectedDriverId,
                          isExpanded: true,
                          decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(12)),
                              prefixIcon: const Icon(
                                  Icons.directions_car_rounded)),
                          items: [
                            const DropdownMenuItem(
                                value: null,
                                child: Text('— None —')),
                            ..._personnel.map((p) => DropdownMenuItem(
                              value: p['id'] as String?,
                              child: Text(p['name'] as String),
                            )),
                          ],
                          onChanged: (v) =>
                              setDialogState(() => selectedDriverId = v),
                        ),
                        const SizedBox(height: 24),

                        // Up to 4 optional member dropdowns for skeletal jobs, each filters out already selected members
                        const Text('Members (optional)',
                            style:
                            TextStyle(fontWeight: FontWeight.w600)),
                        ...List.generate(4, (i) {
                          final current = i < selectedMemberIds.length
                              ? selectedMemberIds[i]
                              : null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String?>(
                              value: current,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12))),
                              hint: Text('Member ${i + 1} (optional)'),
                              items: [
                                const DropdownMenuItem(
                                    value: null,
                                    child: Text('— None —')),
                                // Filter out the leader and any member already selected in another slot
                                ..._personnel.where((p) {
                                  final pid = p['id'] as String?;
                                  if (pid == selectedLeaderId)
                                    return false;
                                  if (selectedMemberIds.contains(pid) &&
                                      selectedMemberIds
                                          .indexOf(pid!) !=
                                          i) return false;
                                  return true;
                                }).map((p) => DropdownMenuItem(
                                  value: p['id'] as String?,
                                  child: Text(p['name'] as String),
                                )),
                              ],
                              onChanged: (v) {
                                setDialogState(() {
                                  // Grow the list if needed then set the value at this slot
                                  while (selectedMemberIds.length <= i)
                                    selectedMemberIds.add('');
                                  selectedMemberIds[i] = v ?? '';
                                  // Remove trailing empty slots so the list stays clean
                                  selectedMemberIds.removeWhere((id) =>
                                  id.isEmpty &&
                                      selectedMemberIds.last == '');
                                });
                              },
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 32),
                      const Text('Shift Time',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      // Regular jobs can change the shift, skeletal jobs show a not applicable message
                      if (!isSkeletal)
                        DropdownButtonFormField<int>(
                          value: selectedShiftIndex,
                          isExpanded: true,
                          decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(12))),
                          items: shiftTimes
                              .asMap()
                              .entries
                              .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null)
                              setDialogState(
                                      () => selectedShiftIndex = v);
                          },
                        )
                      else
                        const Text(
                            '— Not applicable for skeletal —',
                            style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      const Text('Type of Work',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      // Tapping this opens a bottom sheet to pick the work type
                      InkWell(
                        onTap: () => _showWorkTypeBottomSheet(
                            setDialogState, selectedWorkTypeCode,
                                (code) {
                              setDialogState(() {
                                selectedWorkTypeCode = code;
                                selectedWorkTypeName = code != null
                                    ? _workTypeName(code)
                                    : null;
                              });
                            }),
                        child: InputDecorator(
                          decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(12))),
                          child: Text(
                              selectedWorkTypeName ?? 'Select type...'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Difficulty Level',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      // Three filter chips for minor, moderate, and major difficulty
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          for (final entry in [
                            [1, 'Minor'],
                            [2, 'Moderate'],
                            [3, 'Major'],
                          ] as List<List<Object>>)
                            Builder(builder: (ctx) {
                              final level = entry[0] as int;
                              final lbl = entry[1] as String;
                              final isSel = selectedDifficulty == level;
                              return FilterChip(
                                label: Text(lbl),
                                selected: isSel,
                                showCheckmark: true,
                                checkmarkColor: Colors.white,
                                selectedColor:
                                Theme.of(context).colorScheme.primary,
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSel
                                      ? Colors.white
                                      : Colors.grey[800],
                                  fontWeight: isSel
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                                onSelected: (_) => setDialogState(
                                        () => selectedDifficulty = level),
                              );
                            }),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('Damaged Space',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      // Tapping this opens a bottom sheet to pick the damaged space
                      InkWell(
                        onTap: () => _showDamagedSpaceBottomSheet(
                            setDialogState, selectedDamagedCode,
                                (code) {
                              setDialogState(() {
                                selectedDamagedCode = code;
                                selectedDamagedName = code != null
                                    ? _damagedName(code)
                                    : null;
                              });
                            }),
                        child: InputDecorator(
                          decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius:
                                  BorderRadius.circular(12))),
                          child: Text(selectedDamagedName ??
                              'Select damaged space...'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Address',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      DropdownButtonFormField<String?>(
                        value: selectedAddress,
                        isExpanded: true,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(12))),
                        items: addressItems,
                        onChanged: (v) =>
                            setDialogState(() => selectedAddress = v),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: remarksController,
                        decoration: InputDecoration(
                          labelText: 'Remarks',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 24),
                      // Zone field is only shown for regular jobs
                      if (!isSkeletal) ...[
                        TextField(
                          controller: TextEditingController(
                              text: job['zone']?.toString() ?? ''),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Zone',
                            border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(12)),
                            prefixIcon:
                            const Icon(Icons.pin_drop_outlined),
                          ),
                          // Saves the typed zone number back into the job map as an integer
                          onChanged: (v) =>
                          job['zone'] = int.tryParse(v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                // Save button collects all edited values and sends them to the correct database table
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    // Build the update map with fields common to both job types
                    final updates = <String, dynamic>{
                      'work_type_code': selectedWorkTypeCode,
                      'work_type_name': selectedWorkTypeName,
                      'difficulty_level': selectedDifficulty,
                      'damaged_space_code': selectedDamagedCode,
                      'damaged_space_name': selectedDamagedName,
                      'address': selectedAddress,
                      'remarks': remarksController.text.trim(),
                    };

                    // Add extra fields that only apply to regular or only to skeletal jobs
                    if (!isSkeletal) {
                      updates.addAll({
                        'jo_number': joNumberController.text.trim(),
                        'shift_index': selectedShiftIndex,
                        'shift_time': shiftTimes[selectedShiftIndex],
                        'team_id': selectedTeamId,
                        'zone': job['zone'],
                      });
                    } else {
                      updates.addAll({
                        'leader_id': selectedLeaderId,
                        'driver_id': selectedDriverId,
                        // Remove any empty strings before saving the member ids list
                        'member_ids': selectedMemberIds
                            .where((id) => id.isNotEmpty)
                            .toList(),
                      });
                    }

                    try {
                      // Send the update to the correct table based on the job type
                      if (isSkeletal) {
                        await Supabase.instance.client
                            .from('skeletal_job')
                            .update(updates)
                            .eq('id', job['id']);
                      } else {
                        await Supabase.instance.client
                            .from('job_orders')
                            .update(updates)
                            .eq('id', job['id']);
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Job updated successfully'),
                              backgroundColor: Color(0xFF059669)),
                        );
                        Navigator.pop(context);
                        // Reload the job list so the updated values appear immediately
                        await _fetchAccomplishedJobs();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Update failed: $e'),
                              backgroundColor:
                              const Color(0xFFDC2626)),
                        );
                      }
                    }
                  },
                ),
              ],
              actionsPadding:
              const EdgeInsets.fromLTRB(24, 16, 24, 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            );
          },
        );
      },
    );
  }

  // Opens a bottom sheet listing all available work types, the currently selected one shows a checkmark
  void _showWorkTypeBottomSheet(StateSetter setStateDialog,
      String? current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: workTypes.isEmpty
              ? [const ListTile(title: Text('No work types available'))]
              : workTypes.map((wt) {
            final selected = wt['code'] == current;
            return ListTile(
              leading: selected
                  ? const Icon(Icons.check_circle,
                  color: Colors.green)
                  : const Icon(Icons.circle_outlined),
              title: Text('${wt['code']}: ${wt['name']}'),
              // Calls onSelect with the chosen code and closes the bottom sheet
              onTap: () {
                onSelect(wt['code']!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  // Opens a bottom sheet listing all damaged space options, the currently selected one shows a checkmark
  void _showDamagedSpaceBottomSheet(StateSetter setStateDialog,
      String? current, Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: damagedOptions.isEmpty
              ? [
            const ListTile(
                title: Text('No damage options available'))
          ]
              : damagedOptions.map((opt) {
            final selected = opt['code'] == current;
            return ListTile(
              leading: selected
                  ? const Icon(Icons.check_circle,
                  color: Colors.green)
                  : const Icon(Icons.circle_outlined),
              title: Text('${opt['code']}: ${opt['name']}'),
              // Calls onSelect with the chosen code and closes the bottom sheet
              onTap: () {
                onSelect(opt['code']!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
      },
    );
  }

  // Builds the main scaffold with a header, filter bar, search bar, and the scrollable job list
  @override
  Widget build(BuildContext context) {
    final accent = _tk.green;
    final isDark = _tk.dark;
    final isOverall = _filterMonth == null;

    return Scaffold(
      backgroundColor: _tk.bg,
      body: Column(
        children: [
          // Top header with title, subtitle, and the filter period button
          DsHeader(
            title: 'Accomplished',
            subtitle: isOverall
                ? 'All completed jobs • Overall'
                : 'Jobs in $_filterLabel',
            icon: Icons.verified_rounded,
            accent: _tk.green,
            actions: [
              // Animated pill button that shows the current filter and opens the month year picker on tap
              GestureDetector(
                onTap: _showMonthYearPicker,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: isOverall
                        ? LinearGradient(
                      colors: [accent, accent.withOpacity(0.80)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: isOverall
                        ? null
                        : (isDark
                        ? const Color(0xFF161F30)
                        : const Color(0xFFF7FAFD)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOverall
                          ? accent
                          : (isDark
                          ? const Color(0xFF1E2E47)
                          : const Color(0xFFDDE6F0)),
                      width: 1.5,
                    ),
                    boxShadow: isOverall
                        ? [
                      BoxShadow(
                          color: accent.withOpacity(0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]
                        : null,
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOverall
                              ? Icons.public_rounded
                              : Icons.calendar_today_rounded,
                          color: isOverall
                              ? Colors.white
                              : _tk.txtMuted,
                          size: 14,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _filterLabel,
                          style: TextStyle(
                            color: isOverall
                                ? Colors.white
                                : _tk.txtHead,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color:
                          isOverall ? Colors.white : _tk.txtMuted,
                          size: 16,
                        ),
                      ]),
                ),
              ),

              // X button appears only when a month filter is active, tapping it resets to overall
              if (!isOverall) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    setState(() => _filterMonth = null);
                    _applyFilter();
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161F30)
                          : const Color(0xFFF7FAFD),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF1E2E47)
                              : const Color(0xFFDDE6F0)),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: _tk.txtMuted, size: 15),
                  ),
                ),
              ],
              const SizedBox(width: 8),
            ],
          ),

          // Bar below the header showing the active filter label and the total job count
          Container(
            color: _tk.surf,
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(children: [
              // Blue badge showing which period is currently being shown
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0C1E3D)
                      : const Color(0xFFEBF3FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF1A3869)
                          : const Color(0xFFBDD6FF)),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.filter_list_rounded,
                          size: 12, color: _tk.blue),
                      const SizedBox(width: 5),
                      Text('Showing: ',
                          style: TextStyle(
                              color: _tk.txtMuted, fontSize: 11.5)),
                      Text(_filterLabel,
                          style: TextStyle(
                              color: _tk.blue,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
              const SizedBox(width: 10),
              // Green badge showing how many jobs match the current filter
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border:
                  Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Text(
                  '${_filteredJobs.length} job${_filteredJobs.length == 1 ? '' : 's'}',
                  style: TextStyle(
                      color: accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              // Quick shortcut chip to filter by the current month
              _QuickMonthTab(
                label: 'This Month',
                isActive: _filterMonth == DateTime.now().month &&
                    _filterYear == DateTime.now().year,
                color: accent,
                onTap: () {
                  final now = DateTime.now();
                  setState(() {
                    _filterMonth = now.month;
                    _filterYear = now.year;
                  });
                  _applyFilter();
                },
              ),
              const SizedBox(width: 6),
              // Quick shortcut chip to clear the filter and show all jobs
              _QuickMonthTab(
                label: 'Overall',
                isActive: isOverall,
                color: _tk.blue,
                onTap: () {
                  setState(() => _filterMonth = null);
                  _applyFilter();
                },
              ),
            ]),
          ),

          Divider(height: 1, color: _tk.bd),

          // Search input that filters jobs as the user types
          Padding(
            padding:
            const EdgeInsets.fromLTRB(24, 14, 24, 8),
            child: DsSearchBar(
                controller: _searchController,
                hint: 'Search by ID, team, type, address…',
                onClear: () => _applyFilter()),
          ),

          // Main content area showing a spinner while loading, an empty state, or the job list
          Expanded(
            child: _isLoading
                ? const DsLoading()
                : _filteredJobs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 120,
                      color: accent.withOpacity(0.3)),
                  const SizedBox(height: 24),
                  Text(
                    _searchController.text.isEmpty
                        ? 'No completed jobs${isOverall ? '' : ' in $_filterLabel'}'
                        : 'No matching jobs',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _tk.txt),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _searchController.text.isEmpty
                        ? (isOverall
                        ? 'Finished jobs will appear here'
                        : 'Try a different month')
                        : 'Try different keywords',
                    style: TextStyle(
                        fontSize: 16, color: _tk.txtMuted),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(30)),
                    ),
                    onPressed: _fetchAccomplishedJobs,
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchAccomplishedJobs,
              color: accent,
              // Builds each job card as the user scrolls through the list
              child: ListView.builder(
                padding: const EdgeInsets.only(
                    top: 8, bottom: 24),
                itemCount: _filteredJobs.length,
                itemBuilder: (context, index) =>
                    _buildCompactCard(_filteredJobs[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Small chip widget used in the filter bar to quickly switch between This Month and Overall
class _QuickMonthTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  const _QuickMonthTab(
      {required this.label,
        required this.isActive,
        required this.color,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return GestureDetector(
      onTap: onTap,
      // Animates the background and border color when the chip becomes active or inactive
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color.withOpacity(0.40) : tk.bd,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? color : tk.txtMuted,
            fontSize: 11.5,
            fontWeight:
            isActive ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// Custom painter that draws a faint dot grid and two large ring outlines behind the detail dialog header
class _HeroDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Paint settings for the small dots spread across the entire header area
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.fill;
    const step = 28.0;
    // Draw a dot at every grid intersection across the full width and height
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
    // Paint settings for the two large decorative ring outlines
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    // First ring near the top right corner
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.2), 60, ringPaint);
    // Second larger ring near the bottom right corner
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.8), 90, ringPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}