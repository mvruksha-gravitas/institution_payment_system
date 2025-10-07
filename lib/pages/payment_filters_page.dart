import 'package:flutter/material.dart';
import '../theme.dart';
import '../firestore/firestore_data_schema.dart';

class PaymentFiltersPage extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final String currentQuick;
  final DateTimeRange? currentCustomRange;
  final String currentStatus;
  final String? currentRoom;
  final String? currentStudentId;

  const PaymentFiltersPage({
    Key? key,
    required this.students,
    required this.currentQuick,
    this.currentCustomRange,
    required this.currentStatus,
    this.currentRoom,
    this.currentStudentId,
  }) : super(key: key);

  @override
  State<PaymentFiltersPage> createState() => _PaymentFiltersPageState();
}

class _PaymentFiltersPageState extends State<PaymentFiltersPage> {
  late String _quick;
  DateTimeRange? _customRange;
  late String _status;
  String? _room;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    _quick = widget.currentQuick;
    _customRange = widget.currentCustomRange;
    _status = widget.currentStatus;
    _room = widget.currentRoom;
    _studentId = widget.currentStudentId;
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.students
        .map((s) => (s[StudentSchema.roomNumber] as String?) ?? '')
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final List<Map<String, dynamic>> studentsForDropdown = (_room != null && _room!.isNotEmpty)
        ? widget.students.where((s) => (((s[StudentSchema.roomNumber] as String?) ?? '') == _room)).toList()
        : widget.students;

    // Sort students alphabetically by name
    studentsForDropdown.sort((a, b) {
      final aFirst = (a[StudentSchema.firstName] as String?)?.trim() ?? '';
      final aLast = (a[StudentSchema.lastName] as String?)?.trim() ?? '';
      final aName = ('$aFirst $aLast').trim().toLowerCase();

      final bFirst = (b[StudentSchema.firstName] as String?)?.trim() ?? '';
      final bLast = (b[StudentSchema.lastName] as String?)?.trim() ?? '';
      final bName = ('$bFirst $bLast').trim().toLowerCase();

      return aName.compareTo(bName);
    });

    String _rangeLabel() {
      DateTimeRange? range;
      final now = DateTime.now();
      switch (_quick) {
        case 'this_week':
          final weekday = now.weekday;
          final startOfWeek = now.subtract(Duration(days: weekday - 1));
          range = DateTimeRange(
            start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
            end: now,
          );
          break;
        case 'this_month':
          range = DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          );
          break;
        case 'custom':
          range = _customRange;
          break;
        default:
          range = null;
      }
      
      if (range == null) return 'All time';
      String formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      return '${formatDate(range.start)} - ${formatDate(range.end)}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Filters'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filter Criteria', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    
                    // Duration Filter
                    DropdownButtonFormField<String>(
                      value: _quick,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Duration',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Time')),
                        DropdownMenuItem(value: 'this_week', child: Text('This Week')),
                        DropdownMenuItem(value: 'this_month', child: Text('This Month')),
                        DropdownMenuItem(value: 'custom', child: Text('Custom Range')),
                      ],
                      onChanged: (v) async {
                        if (v == 'custom') {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDateRange: _customRange,
                          );
                          if (picked != null) {
                            setState(() {
                              _quick = 'custom';
                              _customRange = picked;
                            });
                          }
                        } else {
                          setState(() {
                            _quick = v ?? 'all';
                            _customRange = null;
                          });
                        }
                      },
                    ),
                    
                    if (_quick == 'custom' && _customRange != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.date_range, size: 16),
                            const SizedBox(width: 8),
                            Text(_rangeLabel(), style: const TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Status Filter
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Payment Status',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Payments')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(value: 'pending', child: Text('Unpaid')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'all'),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Room Filter
                    if (rooms.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        value: _room,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Room',
                          prefixIcon: Icon(Icons.meeting_room),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All Rooms')),
                          ...rooms.map((r) => DropdownMenuItem<String?>(value: r, child: Text('Room $r')))
                        ],
                        onChanged: (v) => setState(() {
                          _room = v;
                          // Reset student selection when room changes
                          if (_studentId != null) {
                            final student = widget.students.firstWhere(
                              (s) => s[StudentSchema.id] == _studentId,
                              orElse: () => {},
                            );
                            final studentRoom = (student[StudentSchema.roomNumber] as String?) ?? '';
                            if (v != null && studentRoom != v) {
                              _studentId = null;
                            }
                          }
                        }),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Student Filter
                    DropdownButtonFormField<String?>(
                      value: _studentId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Student',
                        prefixIcon: Icon(Icons.person),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Students'),
                        ),
                        ...studentsForDropdown.map((s) {
                          final first = (s[StudentSchema.firstName] as String?)?.trim() ?? '';
                          final last = (s[StudentSchema.lastName] as String?)?.trim() ?? '';
                          final name = ('$first $last').trim().isNotEmpty 
                              ? ('$first $last').trim() 
                              : ((s[StudentSchema.phoneNumber] as String?) ?? '-');
                          return DropdownMenuItem<String?>(
                            value: s[StudentSchema.id] as String?,
                            child: Text(name, overflow: TextOverflow.ellipsis),
                          );
                        })
                      ],
                      onChanged: (id) => setState(() => _studentId = id),
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _quick = 'all';
                        _customRange = null;
                        _status = 'all';
                        _room = null;
                        _studentId = null;
                      });
                    },
                    child: const Text('Reset Filters'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, {
                        'quick': _quick,
                        'customRange': _customRange,
                        'status': _status,
                        'room': _room,
                        'studentId': _studentId,
                      });
                    },
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}