import 'package:flutter/material.dart';
import 'package:mynotes2/constants/routes.dart';
import 'package:mynotes2/enums/menu_action.dart';
import 'package:mynotes2/extensions/buildcontext/loc.dart';
import 'package:mynotes2/services/auth/auth_service.dart';
import 'package:mynotes2/services/auth/bloc/auth_bloc.dart';
import 'package:mynotes2/services/auth/bloc/auth_event.dart';
import 'package:mynotes2/services/cloud/cloud_note.dart';
import 'package:mynotes2/services/cloud/firebase_cloud_storage.dart';
import 'package:mynotes2/utilities/dialogs/logout_dialog.dart';
import 'package:mynotes2/views/notes/notes_list_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show ReadContext;
import 'package:lucide_icons/lucide_icons.dart';

extension Count<T extends Iterable> on Stream<T> {
  Stream<int> get getLength => map((event) => event.length);
}

class NotesView extends StatefulWidget {
  const NotesView({Key? key}) : super(key: key);

  @override
  _NotesViewState createState() => _NotesViewState();
}

class _NotesViewState extends State<NotesView> {
  late final FirebaseCloudStorage _notesService;
  String get userId => AuthService.firebase().currentUser!.id;

  bool _isSyncing = false;

  @override
  void initState() {
    _notesService = FirebaseCloudStorage();
    super.initState();

    // Simulating the syncing mechanism
    // In a real scenario, this could be based on an event or a status from the database
    _simulateSyncStatus();
  }

  // Simulated sync status toggle
  void _simulateSyncStatus() async {
    setState(() {
      _isSyncing = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isSyncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<int>(
          stream: _notesService.allNotes(ownerUserId: userId).getLength,
          builder: (context, snapshot) {
            final noteCount = snapshot.data ?? 0;
            final text = context.loc.notes_title(noteCount);
            return Text(
              text,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            );
          },
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pushNamed(createOrUpdateNoteRoute);
            },
            icon: Icon(
              LucideIcons.plusCircle,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          PopupMenuButton<MenuAction>(
            icon: Icon(
              LucideIcons.moreVertical,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onSelected: (value) async {
              if (value == MenuAction.logout) {
                final shouldLogout = await showLogOutDialog(context);
                if (shouldLogout) {
                  context.read<AuthBloc>().add(const AuthEventLogOut());
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<MenuAction>(
                value: MenuAction.logout,
                child: Text(
                  context.loc.logout_button,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Sync status indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            color: _isSyncing ? Colors.yellow[100] : Colors.green[100],
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isSyncing
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.yellow[800]!,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.check_circle,
                        color: Colors.green[800],
                        size: 18,
                      ),
                const SizedBox(width: 8),
                Text(
                  _isSyncing ? 'Syncing changes...' : 'All changes saved',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _isSyncing
                            ? Colors.yellow[800]
                            : Colors.green[800],
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: StreamBuilder<Iterable<CloudNote>>(
                stream: _notesService.allNotes(ownerUserId: userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      snapshot.connectionState == ConnectionState.active) {
                    if (snapshot.hasData) {
                      final allNotes = snapshot.data!;
                      return NotesListView(
                        notes: allNotes,
                        onDeleteNote: (note) async {
                          await _notesService.deleteNote(
                              documentId: note.documentId);
                          _simulateSyncStatus();
                        },
                        onTap: (note) {
                          Navigator.of(context).pushNamed(
                            createOrUpdateNoteRoute,
                            arguments: note,
                          );
                          _simulateSyncStatus();
                        },
                      );
                    } else {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                  }
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed(createOrUpdateNoteRoute);
          _simulateSyncStatus();
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(
          LucideIcons.plus,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
