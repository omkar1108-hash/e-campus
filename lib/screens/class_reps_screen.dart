import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../services/backend.dart';
import '../utils/class_rep_policy.dart';

/// The head of department chooses their department's class representatives:
/// at most two girls and two boys.
class ClassRepsScreen extends StatelessWidget {
  const ClassRepsScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    return StreamBuilder<List<AppUser>>(
      stream: backend.watchUsers(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        final students =
            all
                .where(
                  (u) =>
                      u.active &&
                      u.department == user.department &&
                      (u.role == UserRole.student ||
                          u.role == UserRole.classRep),
                )
                .toList()
              ..sort((a, b) {
                if (a.role != b.role) {
                  return a.role == UserRole.classRep ? -1 : 1;
                }
                return a.name.compareTo(b.name);
              });
        final girls = ClassRepPolicy.count(all, user.department, Gender.female);
        final boys = ClassRepPolicy.count(all, user.department, Gender.male);
        return Column(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: ListTile(
                leading: const Icon(Icons.how_to_reg),
                title: Text('${user.department} class representatives'),
                subtitle: Text(
                  'Girls: $girls/${ClassRepPolicy.maxPerGender}   ·   '
                  'Boys: $boys/${ClassRepPolicy.maxPerGender}',
                ),
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('No students in your department'))
                  : ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, i) {
                        final s = students[i];
                        final isRep = s.role == UserRole.classRep;
                        return SwitchListTile(
                          secondary: CircleAvatar(
                            child: Text(s.name.isEmpty ? '?' : s.name[0]),
                          ),
                          title: Text(s.name),
                          subtitle: Text(
                            '${s.gender?.label ?? 'Gender not set'} · '
                            '${isRep ? 'Class representative' : 'Student'}',
                          ),
                          value: isRep,
                          onChanged: (on) async {
                            final messenger = ScaffoldMessenger.of(context);
                            if (on) {
                              final problem = ClassRepPolicy.canPromote(all, s);
                              if (problem != null) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(problem)),
                                );
                                return;
                              }
                            }
                            try {
                              await backend.setUserRole(
                                s.uid,
                                on ? UserRole.classRep : UserRole.student,
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Failed: $e')),
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
