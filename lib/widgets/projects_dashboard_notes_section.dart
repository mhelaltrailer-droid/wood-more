import 'package:flutter/material.dart';

import '../models/projects_dashboard_note_model.dart';
import '../models/user_model.dart';
import '../services/api_storage_service.dart';

class ProjectsDashboardNotesSection extends StatefulWidget {
  final UserModel currentUser;
  final String variant;
  final ApiStorageService api;
  final ProjectsDashboardNoteModel? latestPeerNote;
  final ProjectsDashboardNoteModel? latestTechnicalOfficeNote;
  final ProjectsDashboardNoteModel? latestOperationManagerNote;
  final Future<void> Function() onChanged;

  const ProjectsDashboardNotesSection({
    super.key,
    required this.currentUser,
    required this.variant,
    required this.api,
    required this.onChanged,
    this.latestPeerNote,
    this.latestTechnicalOfficeNote,
    this.latestOperationManagerNote,
  });

  @override
  State<ProjectsDashboardNotesSection> createState() =>
      _ProjectsDashboardNotesSectionState();
}

class _ProjectsDashboardNotesSectionState
    extends State<ProjectsDashboardNotesSection> {
  final _noteController = TextEditingController();
  bool _postingNote = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String get _peerLabel {
    if (widget.currentUser.isTechnicalOffice) return 'مدير العمليات';
    if (widget.currentUser.isOperationManager) return 'المكتب الفني';
    return 'الطرف الآخر';
  }

  Future<void> _postNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    setState(() => _postingNote = true);
    try {
      await widget.api.addProjectsDashboardNote(
        userId: widget.currentUser.id,
        userName: widget.currentUser.name,
        body: text,
        variant: widget.variant,
      );
      _noteController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الملاحظة')),
      );
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _postingNote = false);
    }
  }

  Future<void> _openAllNotes() async {
    try {
      final List<ProjectsDashboardNoteModel> notes;
      if (widget.currentUser.canViewAllProjectsDashboardNotes) {
        final toNotes = await widget.api.listProjectsDashboardNotes(
          userId: widget.currentUser.id,
          authorRole: 'technical_office',
          variant: widget.variant,
        );
        final omNotes = await widget.api.listProjectsDashboardNotes(
          userId: widget.currentUser.id,
          authorRole: 'operation_manager',
          variant: widget.variant,
        );
        notes = [...toNotes, ...omNotes]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        notes = await widget.api.listProjectsDashboardNotes(
          userId: widget.currentUser.id,
          authorRole: widget.currentUser.projectsDashboardPeerNotesRole,
          variant: widget.variant,
        );
      }
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _AllNotesSheet(
          notes: notes,
          canDelete: widget.currentUser.canDeleteProjectsDashboardNotes,
          onDelete: (id) async {
            await widget.api.deleteProjectsDashboardNote(
              noteId: id,
              requesterEmail: widget.currentUser.email,
            );
            if (ctx.mounted) Navigator.pop(ctx);
            await widget.onChanged();
            if (mounted) _openAllNotes();
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _notePreviewTile({
    required String? title,
    required ProjectsDashboardNoteModel? note,
  }) {
    if (note == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title ?? 'لا توجد ملاحظات بعد'),
        subtitle: title == null ? null : const Text('لا توجد ملاحظات بعد'),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title != null ? '$title: ${note.body}' : note.body),
      subtitle: Text(note.createdAtDisplay),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.currentUser.canViewAllProjectsDashboardNotes) ...[
              const Text(
                'آخر الملاحظات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _notePreviewTile(
                title: 'المكتب الفني',
                note: widget.latestTechnicalOfficeNote,
              ),
              const SizedBox(height: 8),
              _notePreviewTile(
                title: 'مدير العمليات',
                note: widget.latestOperationManagerNote,
              ),
            ] else ...[
              Text(
                'ملاحظات $_peerLabel',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _notePreviewTile(title: null, note: widget.latestPeerNote),
            ],
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _openAllNotes,
                child: Text(
                  widget.currentUser.canViewAllProjectsDashboardNotes
                      ? 'عرض جميع الملاحظات (الطرفين)'
                      : 'عرض جميع الملاحظات',
                ),
              ),
            ),
            const Divider(),
            const Text(
              'إضافة ملاحظة',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'اكتب ملاحظتك هنا…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: _postingNote ? null : _postNote,
                child: _postingNote
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إرسال الملاحظة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllNotesSheet extends StatelessWidget {
  final List<ProjectsDashboardNoteModel> notes;
  final bool canDelete;
  final Future<void> Function(int id) onDelete;

  const _AllNotesSheet({
    required this.notes,
    required this.canDelete,
    required this.onDelete,
  });

  String _roleLabel(String role) {
    switch (role) {
      case 'technical_office':
        return 'المكتب الفني';
      case 'operation_manager':
        return 'مدير العمليات';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Material(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'جميع الملاحظات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: notes.isEmpty
                    ? const Center(child: Text('لا توجد ملاحظات'))
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: notes.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final note = notes[index];
                          return ListTile(
                            title: Text(note.body),
                            subtitle: Text(
                              '${_roleLabel(note.authorRole)} — ${note.userName}\n${note.createdAtDisplay}',
                            ),
                            isThreeLine: true,
                            trailing: canDelete
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('حذف الملاحظة'),
                                          content: const Text(
                                            'هل تريد حذف هذه الملاحظة؟',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('إلغاء'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('حذف'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) await onDelete(note.id);
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
