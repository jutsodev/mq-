import { v4 as uuid } from 'uuid';
import db from '../db.js';
import { createNotification } from '../routes/notifications.js';
import { sendPushToChat } from '../utils/push.js';

const onlineUsers = new Map();

export function getOnlineUsers() {
  return onlineUsers;
}

export function setupSocket(io) {
  io.on('connection', (socket) => {
    const userId = socket.userId;
    onlineUsers.set(userId, socket.id);

    db.prepare('UPDATE users SET status = ?, last_seen = ? WHERE id = ?')
      .run('online', Math.floor(Date.now() / 1000), userId);

    broadcastStatus(io, userId, 'online');
    joinUserChats(socket, userId);

    socket.on('message:send', (data, callback) => {
      handleSendMessage(io, socket, userId, data, callback);
    });

    socket.on('message:edit', (data) => {
      handleEditMessage(io, socket, userId, data);
    });

    socket.on('message:delete', (data) => {
      handleDeleteMessage(io, socket, userId, data);
    });

    socket.on('message:reaction', (data) => {
      handleReaction(io, socket, userId, data);
    });

    socket.on('message:read', (data) => {
      handleReadReceipt(io, socket, userId, data);
    });

    socket.on('typing:start', (data) => {
      socket.to(data.chat_id).emit('typing:start', {
        chat_id: data.chat_id,
        user_id: userId,
      });
    });

    socket.on('typing:stop', (data) => {
      socket.to(data.chat_id).emit('typing:stop', {
        chat_id: data.chat_id,
        user_id: userId,
      });
    });

    socket.on('chat:join', (data) => {
      socket.join(data.chat_id);
    });

    socket.on('chat:leave', (data) => {
      socket.leave(data.chat_id);
    });

    socket.on('call:initiate', (data) => {
      handleCallInitiate(io, socket, userId, data);
    });

    socket.on('call:accept', (data) => {
      handleCallAccept(io, socket, userId, data);
    });

    socket.on('call:reject', (data) => {
      handleCallReject(io, socket, userId, data);
    });

    socket.on('call:end', (data) => {
      handleCallEnd(io, socket, userId, data);
    });

    socket.on('presence:ping', () => {
      db.prepare('UPDATE users SET last_seen = ? WHERE id = ?')
        .run(Math.floor(Date.now() / 1000), userId);
    });

    socket.on('disconnect', () => {
      onlineUsers.delete(userId);
      db.prepare('UPDATE users SET status = ?, last_seen = ? WHERE id = ?')
        .run('offline', Math.floor(Date.now() / 1000), userId);
      broadcastStatus(io, userId, 'offline');
    });
  });
}

function joinUserChats(socket, userId) {
  const chats = db.prepare('SELECT chat_id FROM chat_members WHERE user_id = ?').all(userId);
  for (const c of chats) {
    socket.join(c.chat_id);
  }
}

function broadcastStatus(io, userId, status) {
  const contacts = db.prepare(`
    SELECT user_id FROM contacts WHERE contact_id = ?
    UNION
    SELECT cm2.user_id FROM chat_members cm1
    JOIN chat_members cm2 ON cm2.chat_id = cm1.chat_id AND cm2.user_id != cm1.user_id
    WHERE cm1.user_id = ?
  `).all(userId, userId);

  const user = db.prepare('SELECT show_online FROM users WHERE id = ?').get(userId);
  if (!user?.show_online) return;

  for (const c of contacts) {
    const sid = onlineUsers.get(c.user_id);
    if (sid) {
      io.to(sid).emit('user:status', { user_id: userId, status });
    }
  }
}

function handleSendMessage(io, socket, userId, data, callback) {
  const { chat_id, content, type, reply_to_id, media_url, media_type, format } = data;

  const member = db.prepare('SELECT * FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(chat_id, userId);
  if (!member) {
    if (callback) callback({ error: 'not_member' });
    return;
  }

  const chat = db.prepare('SELECT * FROM chats WHERE id = ?').get(chat_id);
  if (chat.type === 'channel' && !chat.members_can_post && !['owner', 'admin'].includes(member.role)) {
    if (callback) callback({ error: 'cannot_post' });
    return;
  }

  const msgId = uuid();
  const now = Math.floor(Date.now() / 1000);

  db.prepare(`
    INSERT INTO messages (id, chat_id, sender_id, type, content, media_url, media_type, reply_to_id, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `).run(msgId, chat_id, userId, type || 'text', content, media_url || null,
    media_type || null, reply_to_id || null, now, now);

  db.prepare('UPDATE chats SET updated_at = ? WHERE id = ?').run(now, chat_id);
  db.prepare('UPDATE chat_members SET unread_count = unread_count + 1 WHERE chat_id = ? AND user_id != ?')
    .run(chat_id, userId);

  const sender = db.prepare('SELECT display_name, avatar, username FROM users WHERE id = ?').get(userId);

  const message = {
    id: msgId,
    chat_id,
    sender_id: userId,
    sender_name: sender.display_name,
    sender_avatar: sender.avatar,
    sender_username: sender.username,
    type: type || 'text',
    content,
    format: format || 'plain',
    media_url: media_url || null,
    media_type: media_type || null,
    reply_to_id: reply_to_id || null,
    forwarded_from: null,
    is_edited: false,
    is_deleted: false,
    is_pinned: false,
    is_starred: false,
    read_by: [userId],
    delivered_to: [userId],
    reactions: {},
    created_at: now,
    updated_at: now,
  };

  if (reply_to_id) {
    message.reply_to = db.prepare(`
      SELECT m.id, m.content, m.type, u.display_name as sender_name
      FROM messages m LEFT JOIN users u ON u.id = m.sender_id WHERE m.id = ?
    `).get(reply_to_id);
  }

  io.to(chat_id).emit('message:new', message);

  const chatMembers = db.prepare(`
    SELECT user_id FROM chat_members WHERE chat_id = ? AND user_id != ? AND is_muted = 0
  `).all(chat_id, userId);

  for (const m of chatMembers) {
    const chatName = chat.type === 'private' ? sender.display_name : chat.name;
    createNotification(m.user_id, 'message', chatName, content || 'Media', {
      chat_id,
      message_id: msgId,
      sender_id: userId,
    });

    const sid = onlineUsers.get(m.user_id);
    if (sid) {
      io.to(sid).emit('notification:new', {
        type: 'message',
        title: chatName,
        body: content || 'Media',
        chat_id,
        message_id: msgId,
      });
    }
  }

  sendPushToChat(chat_id, userId, {
    title: chat.type === 'private' ? sender.display_name : chat.name,
    body: content || 'Media',
    data: { chat_id, message_id: msgId },
  }).catch(() => {});

  if (callback) callback({ message });
}

function handleEditMessage(io, socket, userId, data) {
  const { message_id, content } = data;
  const msg = db.prepare('SELECT * FROM messages WHERE id = ? AND sender_id = ?')
    .get(message_id, userId);
  if (!msg) return;

  const now = Math.floor(Date.now() / 1000);
  db.prepare('UPDATE messages SET content = ?, is_edited = 1, updated_at = ? WHERE id = ?')
    .run(content, now, message_id);

  io.to(msg.chat_id).emit('message:edited', {
    message_id,
    chat_id: msg.chat_id,
    content,
    updated_at: now,
  });
}

function handleDeleteMessage(io, socket, userId, data) {
  const { message_id } = data;
  const msg = db.prepare('SELECT * FROM messages WHERE id = ?').get(message_id);
  if (!msg) return;

  const member = db.prepare('SELECT role FROM chat_members WHERE chat_id = ? AND user_id = ?')
    .get(msg.chat_id, userId);

  if (msg.sender_id !== userId && (!member || !['owner', 'admin'].includes(member.role))) return;

  db.prepare('UPDATE messages SET is_deleted = 1, content = null, media_url = null WHERE id = ?')
    .run(message_id);

  io.to(msg.chat_id).emit('message:deleted', {
    message_id,
    chat_id: msg.chat_id,
  });
}

function handleReaction(io, socket, userId, data) {
  const { message_id, emoji } = data;
  const msg = db.prepare('SELECT * FROM messages WHERE id = ?').get(message_id);
  if (!msg) return;

  const reactions = JSON.parse(msg.reactions || '{}');
  if (!reactions[emoji]) reactions[emoji] = [];

  const idx = reactions[emoji].indexOf(userId);
  if (idx >= 0) {
    reactions[emoji].splice(idx, 1);
    if (reactions[emoji].length === 0) delete reactions[emoji];
  } else {
    reactions[emoji].push(userId);
  }

  db.prepare('UPDATE messages SET reactions = ? WHERE id = ?')
    .run(JSON.stringify(reactions), message_id);

  io.to(msg.chat_id).emit('message:reaction', {
    message_id,
    chat_id: msg.chat_id,
    reactions,
  });
}

function handleReadReceipt(io, socket, userId, data) {
  const { chat_id, message_id } = data;

  db.prepare('UPDATE chat_members SET unread_count = 0, last_read_message_id = ? WHERE chat_id = ? AND user_id = ?')
    .run(message_id, chat_id, userId);

  const msg = db.prepare('SELECT read_by FROM messages WHERE id = ?').get(message_id);
  if (msg) {
    const readBy = JSON.parse(msg.read_by || '[]');
    if (!readBy.includes(userId)) {
      readBy.push(userId);
      db.prepare('UPDATE messages SET read_by = ? WHERE id = ?')
        .run(JSON.stringify(readBy), message_id);
    }
  }

  socket.to(chat_id).emit('message:read', {
    chat_id,
    message_id,
    user_id: userId,
  });
}

function handleCallInitiate(io, socket, userId, data) {
  const { receiver_id, type } = data;
  const callId = uuid();
  const now = Math.floor(Date.now() / 1000);

  db.prepare(`
    INSERT INTO calls (id, caller_id, receiver_id, type, status, started_at)
    VALUES (?, ?, ?, ?, 'ringing', ?)
  `).run(callId, userId, receiver_id, type || 'voice', now);

  const caller = db.prepare('SELECT display_name, avatar FROM users WHERE id = ?').get(userId);
  const sid = onlineUsers.get(receiver_id);
  if (sid) {
    io.to(sid).emit('call:incoming', {
      call_id: callId,
      caller_id: userId,
      caller_name: caller.display_name,
      caller_avatar: caller.avatar,
      type: type || 'voice',
    });
  }

  socket.emit('call:ringing', { call_id: callId });
}

function handleCallAccept(io, socket, userId, data) {
  const { call_id } = data;
  db.prepare('UPDATE calls SET status = ? WHERE id = ?').run('active', call_id);

  const call = db.prepare('SELECT * FROM calls WHERE id = ?').get(call_id);
  if (call) {
    const sid = onlineUsers.get(call.caller_id);
    if (sid) io.to(sid).emit('call:accepted', { call_id });
  }
}

function handleCallReject(io, socket, userId, data) {
  const { call_id } = data;
  db.prepare('UPDATE calls SET status = ? WHERE id = ?').run('rejected', call_id);

  const call = db.prepare('SELECT * FROM calls WHERE id = ?').get(call_id);
  if (call) {
    const sid = onlineUsers.get(call.caller_id);
    if (sid) io.to(sid).emit('call:rejected', { call_id });
  }
}

function handleCallEnd(io, socket, userId, data) {
  const { call_id } = data;
  const now = Math.floor(Date.now() / 1000);
  const call = db.prepare('SELECT * FROM calls WHERE id = ?').get(call_id);
  if (!call) return;

  const duration = now - call.started_at;
  db.prepare('UPDATE calls SET status = ?, ended_at = ?, duration = ? WHERE id = ?')
    .run('ended', now, duration, call_id);

  const otherId = call.caller_id === userId ? call.receiver_id : call.caller_id;
  const sid = onlineUsers.get(otherId);
  if (sid) io.to(sid).emit('call:ended', { call_id, duration });
}
