import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';
import 'package:institutation_payment_system/services/accommodation_repository.dart';

class ManageRoomsPage extends StatefulWidget {
  final String instId;
  const ManageRoomsPage({super.key, required this.instId});
  @override
  State<ManageRoomsPage> createState() => _ManageRoomsPageState();
}

class _ManageRoomsPageState extends State<ManageRoomsPage> {
  final _repo = FirebaseAccommodationRepository();
  bool _loading = true;
  List<Map<String, dynamic>> _rooms = [];
  Map<String, dynamic>? _selectedRoom;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rooms = await _repo.listRooms(instId: widget.instId);
    rooms.sort((a, b) {
      final ra = (a[RoomSchema.roomNumber] as String?) ?? '';
      final rb = (b[RoomSchema.roomNumber] as String?) ?? '';
      final ia = int.tryParse(ra);
      final ib = int.tryParse(rb);
      if (ia != null && ib != null) return ia.compareTo(ib);
      return ra.compareTo(rb);
    });
    if (!mounted) return;
    setState(() { _rooms = rooms; _loading = false; });
  }

  Future<void> _openAdd() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddRoomPage(instId: widget.instId)));
    await _load();
  }

  Future<void> _openEdit() async {
    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room to edit')),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditRoomPage(instId: widget.instId, roomId: _selectedRoom![RoomSchema.id] as String, roomNumber: (_selectedRoom![RoomSchema.roomNumber] as String?) ?? '', category: (_selectedRoom![RoomSchema.category] as String?) ?? 'two_sharing')));
    await _load();
  }

  Future<void> _openDelete() async {
    if (_selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a room to delete')),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeleteRoomPage(instId: widget.instId, roomId: _selectedRoom![RoomSchema.id] as String, roomNumber: (_selectedRoom![RoomSchema.roomNumber] as String?) ?? '')));
    await _load();
  }

  String _labelForCategory(String category) {
    switch (category) {
      case 'single': return 'Single';
      case 'two_sharing': return 'Two Sharing';
      case 'three_sharing': return 'Three Sharing';
      case 'four_sharing': return 'Four Sharing';
      default: return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Rooms'),
      ),
      body: Column(
        children: [
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Room'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedRoom != null ? _openEdit : null,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Room'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedRoom != null ? _openDelete : null,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete Room', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
          // Room list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rooms.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No rooms yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('Use the Add Room button above to get started', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final r = _rooms[i];
                          final id = r[RoomSchema.id] as String;
                          final rn = (r[RoomSchema.roomNumber] as String?) ?? '';
                          final category = (r[RoomSchema.category] as String?) ?? 'two_sharing';
                          final capacity = (r[RoomSchema.capacity] as int?) ?? 2;
                          final isSelected = _selectedRoom != null && _selectedRoom![RoomSchema.id] == id;
                          
                          return Card(
                            color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                            child: ListTile(
                              leading: Icon(
                                Icons.meeting_room, 
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.blue
                              ),
                              title: Text('Room $rn', overflow: TextOverflow.ellipsis),
                              subtitle: FutureBuilder<(int total, int occupied)>(
                                future: _repo.roomStats(instId: widget.instId, roomId: id),
                                builder: (c, snap) {
                                  final total = snap.data?.$1 ?? capacity;
                                  final occ = snap.data?.$2 ?? 0;
                                  final free = total - occ;
                                  return Text('${_labelForCategory(category)} • Beds: $occ/$total occupied • Available: $free', overflow: TextOverflow.ellipsis);
                                },
                              ),
                              trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                              onTap: () {
                                setState(() {
                                  _selectedRoom = isSelected ? null : r;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class AddRoomPage extends StatefulWidget {
  final String instId;
  const AddRoomPage({super.key, required this.instId});
  @override
  State<AddRoomPage> createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage> {
  final _repo = FirebaseAccommodationRepository();
  final _room = TextEditingController();
  String _category = 'two_sharing';
  bool _saving = false;

  @override
  void dispose() { _room.dispose(); super.dispose(); }

  Future<void> _save() async {
    final rn = _room.text.trim();
    if (rn.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _repo.createRoom(instId: widget.instId, roomNumber: rn, category: _category);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room added')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Room')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _room, decoration: const InputDecoration(labelText: 'Room number', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Single')),
              DropdownMenuItem(value: 'two_sharing', child: Text('Two Sharing')),
              DropdownMenuItem(value: 'three_sharing', child: Text('Three Sharing')),
              DropdownMenuItem(value: 'four_sharing', child: Text('Four Sharing')),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
            decoration: const InputDecoration(labelText: 'Sharing', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Save')),
        ],
      ),
    );
  }
}

class EditRoomPage extends StatefulWidget {
  final String instId; final String roomId; final String roomNumber; final String category;
  const EditRoomPage({super.key, required this.instId, required this.roomId, required this.roomNumber, required this.category});
  @override
  State<EditRoomPage> createState() => _EditRoomPageState();
}

class _EditRoomPageState extends State<EditRoomPage> {
  final _repo = FirebaseAccommodationRepository();
  late TextEditingController _room;
  late String _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _room = TextEditingController(text: widget.roomNumber);
    _category = widget.category;
  }

  @override
  void dispose() { _room.dispose(); super.dispose(); }

  Future<void> _save() async {
    final rn = _room.text.trim(); if (rn.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _repo.updateRoom(instId: widget.instId, roomId: widget.roomId, newRoomNumber: rn, newCategory: _category);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room updated')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Room')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _room, decoration: const InputDecoration(labelText: 'Room number', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Single')),
              DropdownMenuItem(value: 'two_sharing', child: Text('Two Sharing')),
              DropdownMenuItem(value: 'three_sharing', child: Text('Three Sharing')),
              DropdownMenuItem(value: 'four_sharing', child: Text('Four Sharing')),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
            decoration: const InputDecoration(labelText: 'Sharing', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Save')),
        ],
      ),
    );
  }
}

class DeleteRoomPage extends StatefulWidget {
  final String instId; final String roomId; final String roomNumber;
  const DeleteRoomPage({super.key, required this.instId, required this.roomId, required this.roomNumber});
  @override
  State<DeleteRoomPage> createState() => _DeleteRoomPageState();
}

class _DeleteRoomPageState extends State<DeleteRoomPage> {
  final _repo = FirebaseAccommodationRepository();
  bool _loading = true; List<Map<String, dynamic>> _assigned = [];
  bool _deleting = false; String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _repo.listAssignedStudents(instId: widget.instId, roomId: widget.roomId);
      if (!mounted) return; setState(() { _assigned = list; _loading = false; });
    } catch (e) {
      if (!mounted) return; setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await _repo.deleteRoomAndCleanup(instId: widget.instId, roomId: widget.roomId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Room ${widget.roomNumber} deleted')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _deleting = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete Room')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Room ${widget.roomNumber}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)) else ...[
                  if (_assigned.isEmpty) const Text('No students are assigned to this room.') else ...[
                    const Text('The following students are currently assigned and will be detached:'),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _assigned.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _assigned[i];
                          final name = ('${s[StudentSchema.firstName] ?? ''} ${s[StudentSchema.lastName] ?? ''}').trim();
                          final phone = (s[StudentSchema.phoneNumber] as String?) ?? '';
                          return ListTile(leading: const Icon(Icons.person, color: Colors.blue), title: Text(name.isEmpty ? phone : name, overflow: TextOverflow.ellipsis), subtitle: Text(phone, overflow: TextOverflow.ellipsis));
                        },
                      ),
                    ),
                  ]
                ],
                const SizedBox(height: 12),
                Row(children: [
                  OutlinedButton.icon(onPressed: _deleting ? null : () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.blue), label: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: _deleting ? null : _delete, icon: _deleting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.delete), label: const Text('Delete')),
                ])
              ]),
      ),
    );
  }
}
