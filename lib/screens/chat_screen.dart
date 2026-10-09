import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../services/backend.dart';
import '../services/inbox_controller.dart';
import '../utils/chat_policy.dart';
import '../widgets/link_text.dart';

/// One-to-one chat. Press and hold a message to copy, pin, edit or delete.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.me,
    required this.other,
    required this.inbox,
  });

  final AppUser me;
  final AppUser other;

  /// Passed in because this screen is a separate route and cannot see
  /// providers created inside the home screen.
  final InboxController inbox;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  late final String _chatId = chatIdFor(widget.me.uid, widget.other.uid);
  ChatMessage? _editing;
  String? _lastSeenId;

  @override
  void initState() {
    super.initState();
    widget.inbox.setOpen(_chatId);
  }

  @override
  void dispose() {
    widget.inbox.setOpen(null);
    _text.dispose();
    super.dispose();
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _send(List<ChatMessage> msgs) async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final backend = context.read<Backend>();
    final editing = _editing;
    try {
      if (editing != null) {
        if (!editing.canEdit(widget.me.uid, DateTime.now())) {
          _toast('Messages can only be edited for 15 minutes.');
          setState(() => _editing = null);
          _text.clear();
          return;
        }
        await backend.editMessage(
          _chatId,
          editing.id,
          text,
          isLast: msgs.isNotEmpty && msgs.last.id == editing.id,
        );
        setState(() => _editing = null);
      } else {
        await backend.sendMessage(
          _chatId,
          ChatMessage(
            id: '',
            senderId: widget.me.uid,
            text: text,
            sentAt: DateTime.now(),
          ),
        );
      }
      _text.clear();
    } catch (e) {
      _toast('Could not send: $e');
    }
  }

  Future<void> _showActions(ChatMessage m, List<ChatMessage> msgs) async {
    final backend = context.read<Backend>();
    final mine = m.senderId == widget.me.uid;
    final links = splitLinks(m.text).where((p) => p.link != null).toList();
    final isLast = msgs.isNotEmpty && msgs.last.id == m.id;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (!m.deleted)
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy text'),
                onTap: () => Navigator.pop(ctx, 'copy'),
              ),
            if (links.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Copy link'),
                onTap: () => Navigator.pop(ctx, 'link'),
              ),
            if (!m.deleted)
              ListTile(
                leading: Icon(
                  m.pinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(m.pinned ? 'Unpin' : 'Pin'),
                onTap: () => Navigator.pop(ctx, 'pin'),
              ),
            if (m.canEdit(widget.me.uid, DateTime.now()))
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
            if (mine && !m.deleted)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete for everyone'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      switch (action) {
        case 'copy':
          await Clipboard.setData(ClipboardData(text: m.text));
          _toast('Copied');
        case 'link':
          await Clipboard.setData(
            ClipboardData(text: links.first.link.toString()),
          );
          _toast('Link copied');
        case 'pin':
          await backend.setPinned(_chatId, m.id, !m.pinned);
        case 'edit':
          setState(() => _editing = m);
          _text.text = m.text;
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete this message?'),
              content: const Text('It will be deleted for everyone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (ok == true) {
            await backend.deleteMessage(_chatId, m.id, isLast: isLast);
            if (_editing?.id == m.id) {
              setState(() => _editing = null);
              _text.clear();
            }
          }
      }
    } catch (e) {
      if (mounted) _toast('Failed: $e');
    }
  }

  Future<void> _showPinned(List<ChatMessage> pinned) async {
    final backend = context.read<Backend>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Pinned messages')),
            for (final p in pinned.reversed)
              ListTile(
                leading: const Icon(Icons.push_pin),
                title: Text(
                  p.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(DateFormat('d MMM, h:mm a').format(p.sentAt)),
                trailing: IconButton(
                  tooltip: 'Unpin',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    backend.setPinned(_chatId, p.id, false);
                    Navigator.pop(ctx);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.read<Backend>();
    final scheme = Theme.of(context).colorScheme;
    final canSend = ChatPolicy.canChat(widget.me, widget.other);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.other.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${widget.other.role.label} · ${widget.other.department}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<ChatMessage>>(
        stream: backend.watchMessages(_chatId),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final last = all.isEmpty ? null : all.last;
          if (last != null &&
              last.id != _lastSeenId &&
              last.senderId != widget.me.uid) {
            _lastSeenId = last.id;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => widget.inbox.markRead(_chatId),
            );
          }
          final pinned = all.where((m) => m.pinned && !m.deleted).toList();
          final msgs = all.reversed.toList();
          return Column(
            children: [
              if (pinned.isNotEmpty)
                Material(
                  color: scheme.secondaryContainer,
                  child: ListTile(
                    key: const ValueKey('pinned-bar'),
                    dense: true,
                    leading: const Icon(Icons.push_pin, size: 20),
                    title: Text(
                      pinned.last.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: pinned.length > 1
                        ? Text('${pinned.length} pinned')
                        : null,
                    onTap: () => _showPinned(pinned),
                  ),
                ),
              Expanded(
                child: all.isEmpty
                    ? Center(child: Text('Say hi to ${widget.other.name} 👋'))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: msgs.length,
                        itemBuilder: (context, i) {
                          final m = msgs[i];
                          final mine = m.senderId == widget.me.uid;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () => _showActions(m, all),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.75,
                                ),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? scheme.primaryContainer
                                      : scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (m.deleted)
                                      Text(
                                        'This message was deleted',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      )
                                    else
                                      LinkText(m.text),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (m.pinned)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(
                                              Icons.push_pin,
                                              size: 12,
                                            ),
                                          ),
                                        Text(
                                          '${m.editedAt != null && !m.deleted ? 'edited · ' : ''}'
                                          '${DateFormat.jm().format(m.sentAt)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (!canSend)
                const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'You can no longer send messages to this person.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_editing != null)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.edit, size: 20),
                          title: const Text('Editing message'),
                          trailing: IconButton(
                            tooltip: 'Cancel edit',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() => _editing = null);
                              _text.clear();
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _text,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  hintText: 'Message',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onSubmitted: (_) => _send(all),
                              ),
                            ),
                            IconButton.filled(
                              tooltip: _editing != null ? 'Save' : 'Send',
                              onPressed: () => _send(all),
                              icon: Icon(
                                _editing != null ? Icons.check : Icons.send,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
