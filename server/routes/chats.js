import { Router } from 'express';
import { v4 as uuid } from 'uuid';
import db from '../db.js';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();
router.use(authMiddleware);

router.get('/', (req, res) => {
  const chats = db.prepare(`
    SELECT c.*, cm.is_muted, cm.is_pinned, cm.unread_count, cm.role,
           cm.last_read_message_id
    FROM chat_members cm
    JOIN chats c ON c.id = cm.chat_id
    WHERE cm.user_id = ?
    ORDER BY cm.is_pinned DESC, c.updated_at DESC
  `).all(req.userId);

  const result = chats.map(chat => {
    const lastMsg = db.prepare(`
      SELECT m.*, u.display_name as sender_name
      FROM messages m
      LEFT JOIN users u ON u.id = m.sender_id
      WHERE m.chat_id = ? AND m.is_deleted = 0
      ORDER BY m.created_at DESC LIMIT 1
    `).get(chat.id);

    const members = db.prepare(`
      SELECT u.id, u.display_name, u.username, u.avatar, u.status, u.last_seen, cm.role
      FROM chat_members cm
      JOIN users u ON u.id = cm.user_id
      WHERE cm.chat_id = ?
    `).all(chat.id);

    const memberCount = db.prepare('SELECT COUNT(*) as c FROM chat_members WHERE chat_id = ?').get(chat.id);

    let displayName = chat.name;
    let displayAvatar = chat.avatar;
    if (chat.type === 'private') {
      const other = members.find(m => m.id !== req.userId);
      if (other) {
        displayName = other.display_name;
        displayAvatar = other.avatar;
      }
    }

    return {
      id: chat.id,
      type: chat.type,
      name: displayName,
      description: chat.description,
      avatar: displayAvatar,
      owner_id: chat.owner_id,
      invite_link: chat.invite_link,
      is_public: !!chat.is_public,
      is_muted: !!chat.is_muted,
      is_pinned: !!chat.is_pinned,
      unread_count: chat.unread_count,
      role: chat.role,
      member_count: memberCount.c,
      members: members,
      last_message: lastMsg || null,
      pinned_message_id: chat.pinned_message_id,
      slow_mode: chat.slow_mode,
      members_can_post: !!chat.members_can_post,
      created_at: chat.created_at,
      updated_at: chat.updated_at,
    };
  });

  res.json({ chats: result });
});

router.post('/', (req, res) => {
  const { type, name, description, members, is_public } = req.body;
  if (!type) return res.status(400).json({ error: 'type_required' });

  if (type === 'private') {
    if (!members || members.length !== 1) {
      return res.status(400).json({ error: 'one_member_required' });
    }
    const otherId = members[0];
    const existing = db.prepare(`
      SELECT c.id FROM chats c
      JOIN chat_members cm1 ON cm1.chat_id = c.id AND cm1.user_id = ?
      JOIN chat_members cm2 ON cm2.chat_id = c.id AND cm2.user_id = ?
      WHERE c.type = 'private'
    `).get(req.userId, otherId);

    if (existing) return res.json({ chat_id: existing.id, existing: true });
  }

  const chatId = uuid();
  const inviteLink = type !== 'private' ? uuid().substring(0, 8) : null;

  db.prepare(`
    INSERT INTO chats (id, type, name, description, owner_id, invite_link, is_public, members_can_post)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `).run(chatId, type, name || null, description || null, req.userId, inviteLink,
    is_public ? 1 : 0, type === 'channel' ? 0 : 1);

  db.prepare('INSERT INTO chat_members (id, chat_id, user_id, role) VALUES (?, ?, ?, ?)')
    .run(uuid(), chatId, req.userId, 'owner');

  if (members && Array.isArray(members)) {
    const insertMember = db.prepare(
      'INSERT OR IGNORE INTO chat_members (id, chat_id, user_id, role) VALUES (?, ?, ?, ?)'
    );
    for (const mid of members) {
      insertMember.run(uuid(), chatId, mid, 'member');
    }
  }

  res.json({ chat_id: chatId });
});

router.get('/:chatId', (req, res) => {
  const chat = db.prepare('SELECT * FROM chats WHERE id = ?').get(req.params.chatId);
  if (!chat) return res.status(404).json({ error: 'not_found' });

  const member = db.prepare('SELECT * FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, req.userId);
  if (!member && !chat.is_public) return res.status(403).json({ error: 'not_member' });

  const members = db.prepare(`
    SELECT u.id, u.display_name, u.username, u.avatar, u.status, u.last_seen, cm.role
    FROM chat_members cm
    JOIN users u ON u.id = cm.user_id
    WHERE cm.chat_id = ?
  `).all(req.params.chatId);

  res.json({
    chat: { ...chat, is_public: !!chat.is_public, members_can_post: !!chat.members_can_post },
    members,
    my_role: member?.role || null,
  });
});

router.put('/:chatId', (req, res) => {
  const member = db.prepare('SELECT role FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, req.userId);
  if (!member || !['owner', 'admin'].includes(member.role)) {
    return res.status(403).json({ error: 'insufficient_permissions' });
  }

  const fields = ['name', 'description', 'avatar', 'is_public', 'slow_mode', 'members_can_post'];
  const updates = [];
  const values = [];

  for (const f of fields) {
    if (req.body[f] !== undefined) {
      updates.push(`${f} = ?`);
      values.push(typeof req.body[f] === 'boolean' ? (req.body[f] ? 1 : 0) : req.body[f]);
    }
  }

  if (updates.length === 0) return res.status(400).json({ error: 'no_fields' });
  updates.push('updated_at = ?');
  values.push(Math.floor(Date.now() / 1000));
  values.push(req.params.chatId);

  db.prepare(`UPDATE chats SET ${updates.join(', ')} WHERE id = ?`).run(...values);
  res.json({ ok: true });
});

router.delete('/:chatId', (req, res) => {
  const member = db.prepare('SELECT role FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, req.userId);
  if (!member || member.role !== 'owner') {
    return res.status(403).json({ error: 'only_owner' });
  }

  db.prepare('DELETE FROM messages WHERE chat_id = ?').run(req.params.chatId);
  db.prepare('DELETE FROM chat_members WHERE chat_id = ?').run(req.params.chatId);
  db.prepare('DELETE FROM chats WHERE id = ?').run(req.params.chatId);
  res.json({ ok: true });
});

router.post('/:chatId/members', (req, res) => {
  const { user_id, role } = req.body;
  const member = db.prepare('SELECT role FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, req.userId);
  if (!member || !['owner', 'admin'].includes(member.role)) {
    return res.status(403).json({ error: 'insufficient_permissions' });
  }

  const existing = db.prepare('SELECT id FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, user_id);
  if (existing) return res.status(409).json({ error: 'already_member' });

  const id = uuid();
  db.prepare('INSERT INTO chat_members (id, chat_id, user_id, role) VALUES (?, ?, ?, ?)')
    .run(id, req.params.chatId, user_id, role || 'member');

  db.prepare('UPDATE chats SET updated_at = ? WHERE id = ?')
    .run(Math.floor(Date.now() / 1000), req.params.chatId);

  res.json({ ok: true });
});

router.delete('/:chatId/members/:userId', (req, res) => {
  const isLeaving = req.params.userId === req.userId;
  if (!isLeaving) {
    const member = db.prepare('SELECT role FROM chat_members WHERE chat_id = ? AND user_id = ?')
      .get(req.params.chatId, req.userId);
    if (!member || !['owner', 'admin'].includes(member.role)) {
      return res.status(403).json({ error: 'insufficient_permissions' });
    }
  }

  db.prepare('DELETE FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .run(req.params.chatId, req.params.userId);
  res.json({ ok: true });
});

router.put('/:chatId/members/:userId/role', (req, res) => {
  const { role } = req.body;
  const member = db.prepare('SELECT role FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, req.userId);
  if (!member || member.role !== 'owner') {
    return res.status(403).json({ error: 'only_owner' });
  }

  db.prepare('UPDATE chat_members SET role = ? WHERE chat_id = ? AND user_id = ?')
    .run(role, req.params.chatId, req.params.userId);
  res.json({ ok: true });
});

router.put('/:chatId/mute', (req, res) => {
  const { is_muted, muted_until } = req.body;
  db.prepare('UPDATE chat_members SET is_muted = ?, muted_until = ? WHERE chat_id = ? AND user_id = ?')
    .run(is_muted ? 1 : 0, muted_until || null, req.params.chatId, req.userId);
  res.json({ ok: true });
});

router.put('/:chatId/pin', (req, res) => {
  const { is_pinned } = req.body;
  db.prepare('UPDATE chat_members SET is_pinned = ? WHERE chat_id = ? AND user_id = ?')
    .run(is_pinned ? 1 : 0, req.params.chatId, req.userId);
  res.json({ ok: true });
});

router.put('/:chatId/read', (req, res) => {
  const { message_id } = req.body;
  db.prepare(`
    UPDATE chat_members SET unread_count = 0, last_read_message_id = ?
    WHERE chat_id = ? AND user_id = ?
  `).run(message_id, req.params.chatId, req.userId);
  res.json({ ok: true });
});

router.get('/:chatId/messages', (req, res) => {
  const { before, limit = 50 } = req.query;

  const member = db.prepare('SELECT * FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, req.userId);

  const chat = db.prepare('SELECT * FROM chats WHERE id = ?').get(req.params.chatId);
  if (!member && !chat?.is_public) return res.status(403).json({ error: 'not_member' });

  let query = `
    SELECT m.*, u.display_name as sender_name, u.avatar as sender_avatar, u.username as sender_username
    FROM messages m
    LEFT JOIN users u ON u.id = m.sender_id
    WHERE m.chat_id = ?
  `;
  const params = [req.params.chatId];

  if (before) {
    query += ' AND m.created_at < ?';
    params.push(Number(before));
  }

  query += ' ORDER BY m.created_at DESC LIMIT ?';
  params.push(Number(limit));

  const messages = db.prepare(query).all(...params);

  const enriched = messages.map(m => {
    let replyTo = null;
    if (m.reply_to_id) {
      replyTo = db.prepare(`
        SELECT m.id, m.content, m.type, u.display_name as sender_name
        FROM messages m LEFT JOIN users u ON u.id = m.sender_id
        WHERE m.id = ?
      `).get(m.reply_to_id);
    }
    return {
      ...m,
      is_edited: !!m.is_edited,
      is_deleted: !!m.is_deleted,
      is_pinned: !!m.is_pinned,
      is_starred: !!m.is_starred,
      read_by: JSON.parse(m.read_by || '[]'),
      delivered_to: JSON.parse(m.delivered_to || '[]'),
      reactions: JSON.parse(m.reactions || '{}'),
      reply_to: replyTo,
    };
  });

  res.json({ messages: enriched.reverse() });
});

router.post('/:chatId/messages', (req, res) => {
  const { content, type, reply_to_id, forwarded_from, media_url, media_type, format } = req.body;

  const member = db.prepare('SELECT * FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, req.userId);
  const chat = db.prepare('SELECT * FROM chats WHERE id = ?').get(req.params.chatId);

  if (!member) return res.status(403).json({ error: 'not_member' });
  if (chat.type === 'channel' && !chat.members_can_post && !['owner', 'admin'].includes(member.role)) {
    return res.status(403).json({ error: 'cannot_post' });
  }

  const msgId = uuid();
  const now = Math.floor(Date.now() / 1000);

  db.prepare(`
    INSERT INTO messages (id, chat_id, sender_id, type, content, media_url, media_type, reply_to_id, forwarded_from, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(msgId, req.params.chatId, req.userId, type || 'text', content || null,
    media_url || null, media_type || null, reply_to_id || null, forwarded_from || null, now, now);

  db.prepare('UPDATE chats SET updated_at = ? WHERE id = ?').run(now, req.params.chatId);

  db.prepare(`
    UPDATE chat_members SET unread_count = unread_count + 1
    WHERE chat_id = ? AND user_id != ?
  `).run(req.params.chatId, req.userId);

  const sender = db.prepare('SELECT display_name, avatar, username FROM users WHERE id = ?').get(req.userId);
  const message = {
    id: msgId,
    chat_id: req.params.chatId,
    sender_id: req.userId,
    sender_name: sender.display_name,
    sender_avatar: sender.avatar,
    sender_username: sender.username,
    type: type || 'text',
    content,
    format: format || 'plain',
    media_url: media_url || null,
    media_type: media_type || null,
    reply_to_id: reply_to_id || null,
    forwarded_from: forwarded_from || null,
    is_edited: false,
    is_deleted: false,
    is_pinned: false,
    is_starred: false,
    read_by: [],
    delivered_to: [],
    reactions: {},
    created_at: now,
    updated_at: now,
  };

  if (reply_to_id) {
    message.reply_to = db.prepare(`
      SELECT m.id, m.content, m.type, u.display_name as sender_name
      FROM messages m LEFT JOIN users u ON u.id = m.sender_id
      WHERE m.id = ?
    `).get(reply_to_id);
  }

  res.json({ message });
});

router.put('/:chatId/messages/:messageId', (req, res) => {
  const { content } = req.body;
  const msg = db.prepare('SELECT * FROM messages WHERE id = ? AND chat_id = ?')
    .get(req.params.messageId, req.params.chatId);

  if (!msg) return res.status(404).json({ error: 'not_found' });
  if (msg.sender_id !== req.userId) return res.status(403).json({ error: 'not_sender' });

  const now = Math.floor(Date.now() / 1000);
  db.prepare('UPDATE messages SET content = ?, is_edited = 1, updated_at = ? WHERE id = ?')
    .run(content, now, req.params.messageId);

  res.json({ ok: true });
});

router.delete('/:chatId/messages/:messageId', (req, res) => {
  const msg = db.prepare('SELECT * FROM messages WHERE id = ? AND chat_id = ?')
    .get(req.params.messageId, req.params.chatId);

  if (!msg) return res.status(404).json({ error: 'not_found' });

  const member = db.prepare('SELECT role FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, req.userId);

  if (msg.sender_id !== req.userId && (!member || !['owner', 'admin'].includes(member.role))) {
    return res.status(403).json({ error: 'not_allowed' });
  }

  db.prepare('UPDATE messages SET is_deleted = 1, content = null, media_url = null WHERE id = ?')
    .run(req.params.messageId);
  res.json({ ok: true });
});

router.post('/:chatId/messages/:messageId/reaction', (req, res) => {
  const { emoji } = req.body;
  const msg = db.prepare('SELECT reactions FROM messages WHERE id = ?').get(req.params.messageId);
  if (!msg) return res.status(404).json({ error: 'not_found' });

  const reactions = JSON.parse(msg.reactions || '{}');
  if (!reactions[emoji]) reactions[emoji] = [];

  const idx = reactions[emoji].indexOf(req.userId);
  if (idx >= 0) {
    reactions[emoji].splice(idx, 1);
    if (reactions[emoji].length === 0) delete reactions[emoji];
  } else {
    reactions[emoji].push(req.userId);
  }

  db.prepare('UPDATE messages SET reactions = ? WHERE id = ?')
    .run(JSON.stringify(reactions), req.params.messageId);
  res.json({ reactions });
});

router.put('/:chatId/messages/:messageId/pin', (req, res) => {
  const { is_pinned } = req.body;
  const member = db.prepare('SELECT role FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(req.params.chatId, req.userId);

  if (!member || !['owner', 'admin'].includes(member.role)) {
    return res.status(403).json({ error: 'insufficient_permissions' });
  }

  db.prepare('UPDATE messages SET is_pinned = ? WHERE id = ?')
    .run(is_pinned ? 1 : 0, req.params.messageId);

  if (is_pinned) {
    db.prepare('UPDATE chats SET pinned_message_id = ? WHERE id = ?')
      .run(req.params.messageId, req.params.chatId);
  }
  res.json({ ok: true });
});

router.put('/:chatId/messages/:messageId/star', (req, res) => {
  const msg = db.prepare('SELECT is_starred FROM messages WHERE id = ?').get(req.params.messageId);
  if (!msg) return res.status(404).json({ error: 'not_found' });

  db.prepare('UPDATE messages SET is_starred = ? WHERE id = ?')
    .run(msg.is_starred ? 0 : 1, req.params.messageId);
  res.json({ is_starred: !msg.is_starred });
});

router.post('/:chatId/messages/:messageId/forward', (req, res) => {
  const { target_chat_ids } = req.body;
  const msg = db.prepare('SELECT * FROM messages WHERE id = ?').get(req.params.messageId);
  if (!msg) return res.status(404).json({ error: 'not_found' });

  const now = Math.floor(Date.now() / 1000);
  const forwarded = [];

  for (const targetId of target_chat_ids) {
    const isMember = db.prepare('SELECT id FROM chat_members WHERE chat_id = ? AND user_id = ?')
      .get(targetId, req.userId);
    if (!isMember) continue;

    const newId = uuid();
    db.prepare(`
      INSERT INTO messages (id, chat_id, sender_id, type, content, media_url, media_type, forwarded_from, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(newId, targetId, req.userId, msg.type, msg.content, msg.media_url, msg.media_type,
      msg.sender_id, now, now);
    forwarded.push(newId);
  }

  res.json({ forwarded_ids: forwarded });
});

router.get('/:chatId/messages/search', (req, res) => {
  const { q, limit = 20 } = req.query;
  if (!q) return res.json({ messages: [] });

  const messages = db.prepare(`
    SELECT m.*, u.display_name as sender_name
    FROM messages m
    LEFT JOIN users u ON u.id = m.sender_id
    WHERE m.chat_id = ? AND m.content LIKE ? AND m.is_deleted = 0
    ORDER BY m.created_at DESC LIMIT ?
  `).all(req.params.chatId, `%${q}%`, Number(limit));

  res.json({ messages });
});

router.get('/:chatId/media', (req, res) => {
  const media = db.prepare(`
    SELECT * FROM messages
    WHERE chat_id = ? AND media_url IS NOT NULL AND is_deleted = 0
    ORDER BY created_at DESC
  `).all(req.params.chatId);
  res.json({ media });
});

router.post('/join/:inviteLink', (req, res) => {
  const chat = db.prepare('SELECT * FROM chats WHERE invite_link = ?').get(req.params.inviteLink);
  if (!chat) return res.status(404).json({ error: 'invalid_link' });

  const existing = db.prepare('SELECT id FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(chat.id, req.userId);
  if (existing) return res.json({ chat_id: chat.id, already_member: true });

  db.prepare('INSERT INTO chat_members (id, chat_id, user_id, role) VALUES (?, ?, ?, ?)')
    .run(uuid(), chat.id, req.userId, 'member');
  res.json({ chat_id: chat.id });
});

export default router;
