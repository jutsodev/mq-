import Database from 'better-sqlite3';
import path from 'path';
import { fileURLToPath } from 'url';
import { v4 as uuid } from 'uuid';
import bcrypt from 'bcryptjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const db = new Database(path.join(__dirname, 'messenger.db'));

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

export function initDB() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      phone TEXT UNIQUE NOT NULL,
      username TEXT UNIQUE,
      display_name TEXT,
      avatar TEXT,
      bio TEXT DEFAULT '',
      status TEXT DEFAULT 'online',
      last_seen INTEGER,
      language TEXT DEFAULT 'ru',
      theme TEXT DEFAULT 'light',
      wallpaper TEXT DEFAULT 'default',
      font_size INTEGER DEFAULT 16,
      show_online INTEGER DEFAULT 1,
      show_last_seen INTEGER DEFAULT 1,
      show_read_receipts INTEGER DEFAULT 1,
      show_typing INTEGER DEFAULT 1,
      two_step_enabled INTEGER DEFAULT 0,
      two_step_pin TEXT,
      blocked_users TEXT DEFAULT '[]',
      notification_sound TEXT DEFAULT 'default',
      notification_vibrate INTEGER DEFAULT 1,
      notification_preview INTEGER DEFAULT 1,
      push_subscription TEXT,
      created_at INTEGER DEFAULT (unixepoch()),
      updated_at INTEGER DEFAULT (unixepoch())
    );

    CREATE TABLE IF NOT EXISTS contacts (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      contact_id TEXT NOT NULL,
      nickname TEXT,
      is_favorite INTEGER DEFAULT 0,
      is_blocked INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT (unixepoch()),
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (contact_id) REFERENCES users(id),
      UNIQUE(user_id, contact_id)
    );

    CREATE TABLE IF NOT EXISTS chats (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL DEFAULT 'private',
      name TEXT,
      description TEXT,
      avatar TEXT,
      owner_id TEXT,
      invite_link TEXT,
      is_public INTEGER DEFAULT 0,
      pinned_message_id TEXT,
      slow_mode INTEGER DEFAULT 0,
      members_can_post INTEGER DEFAULT 1,
      created_at INTEGER DEFAULT (unixepoch()),
      updated_at INTEGER DEFAULT (unixepoch()),
      FOREIGN KEY (owner_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS chat_members (
      id TEXT PRIMARY KEY,
      chat_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      role TEXT DEFAULT 'member',
      is_muted INTEGER DEFAULT 0,
      is_pinned INTEGER DEFAULT 0,
      muted_until INTEGER,
      unread_count INTEGER DEFAULT 0,
      last_read_message_id TEXT,
      joined_at INTEGER DEFAULT (unixepoch()),
      FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id),
      UNIQUE(chat_id, user_id)
    );

    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      chat_id TEXT NOT NULL,
      sender_id TEXT NOT NULL,
      type TEXT DEFAULT 'text',
      content TEXT,
      media_url TEXT,
      media_type TEXT,
      reply_to_id TEXT,
      forwarded_from TEXT,
      is_edited INTEGER DEFAULT 0,
      is_deleted INTEGER DEFAULT 0,
      is_pinned INTEGER DEFAULT 0,
      is_starred INTEGER DEFAULT 0,
      read_by TEXT DEFAULT '[]',
      delivered_to TEXT DEFAULT '[]',
      reactions TEXT DEFAULT '{}',
      created_at INTEGER DEFAULT (unixepoch()),
      updated_at INTEGER DEFAULT (unixepoch()),
      FOREIGN KEY (chat_id) REFERENCES chats(id) ON DELETE CASCADE,
      FOREIGN KEY (sender_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      type TEXT NOT NULL,
      title TEXT,
      body TEXT,
      data TEXT DEFAULT '{}',
      is_read INTEGER DEFAULT 0,
      created_at INTEGER DEFAULT (unixepoch()),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS stories (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      type TEXT DEFAULT 'text',
      content TEXT,
      media_url TEXT,
      bg_color TEXT DEFAULT '#000000',
      viewers TEXT DEFAULT '[]',
      expires_at INTEGER,
      created_at INTEGER DEFAULT (unixepoch()),
      FOREIGN KEY (user_id) REFERENCES users(id)
    );

    CREATE TABLE IF NOT EXISTS calls (
      id TEXT PRIMARY KEY,
      caller_id TEXT NOT NULL,
      receiver_id TEXT,
      chat_id TEXT,
      type TEXT DEFAULT 'voice',
      status TEXT DEFAULT 'missed',
      duration INTEGER DEFAULT 0,
      started_at INTEGER DEFAULT (unixepoch()),
      ended_at INTEGER,
      FOREIGN KEY (caller_id) REFERENCES users(id)
    );

    CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id, created_at);
    CREATE INDEX IF NOT EXISTS idx_chat_members_user ON chat_members(user_id);
    CREATE INDEX IF NOT EXISTS idx_chat_members_chat ON chat_members(chat_id);
    CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, is_read);
    CREATE INDEX IF NOT EXISTS idx_contacts_user ON contacts(user_id);
    CREATE INDEX IF NOT EXISTS idx_stories_user ON stories(user_id);
    CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
    CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
  `);

  seedDemoData();
}

function seedDemoData() {
  const count = db.prepare('SELECT COUNT(*) as c FROM users').get();
  if (count.c > 0) return;

  const demoUsers = [
    { phone: '+79001234567', username: 'alice', display_name: 'Alice', bio: 'Hey there!', avatar: null },
    { phone: '+79001234568', username: 'bob', display_name: 'Bob', bio: 'Available', avatar: null },
    { phone: '+79001234569', username: 'charlie', display_name: 'Charlie', bio: 'At work', avatar: null },
    { phone: '+79001234570', username: 'diana', display_name: 'Diana', bio: 'Busy', avatar: null },
    { phone: '+79001234571', username: 'eva', display_name: 'Eva', bio: 'On vacation', avatar: null },
    { phone: '+79001234572', username: 'frank', display_name: 'Frank', bio: 'Gaming', avatar: null },
    { phone: '+79001234573', username: 'grace', display_name: 'Grace', bio: 'Reading', avatar: null },
    { phone: '+79001234574', username: 'henry', display_name: 'Henry', bio: 'Coding', avatar: null },
  ];

  const insertUser = db.prepare(`
    INSERT INTO users (id, phone, username, display_name, bio, avatar, status, last_seen)
    VALUES (?, ?, ?, ?, ?, ?, 'offline', ?)
  `);

  const userIds = [];
  for (const u of demoUsers) {
    const id = uuid();
    userIds.push(id);
    insertUser.run(id, u.phone, u.username, u.display_name, u.bio, u.avatar, Date.now());
  }

  const groupChat = uuid();
  db.prepare(`
    INSERT INTO chats (id, type, name, description, owner_id, is_public)
    VALUES (?, 'group', 'MQ Team', 'Official group', ?, 1)
  `).run(groupChat, userIds[0]);

  const channel = uuid();
  db.prepare(`
    INSERT INTO chats (id, type, name, description, owner_id, is_public, members_can_post)
    VALUES (?, 'channel', 'MQ News', 'Latest updates', ?, 1, 0)
  `).run(channel, userIds[0]);

  const insertMember = db.prepare(`
    INSERT INTO chat_members (id, chat_id, user_id, role) VALUES (?, ?, ?, ?)
  `);

  for (let i = 0; i < 5; i++) {
    insertMember.run(uuid(), groupChat, userIds[i], i === 0 ? 'owner' : 'member');
    insertMember.run(uuid(), channel, userIds[i], i === 0 ? 'owner' : 'member');
  }

  const insertMessage = db.prepare(`
    INSERT INTO messages (id, chat_id, sender_id, content, created_at) VALUES (?, ?, ?, ?, ?)
  `);

  const now = Math.floor(Date.now() / 1000);
  const groupMessages = [
    { sender: 0, content: 'Welcome to MQ Team!', offset: -3600 },
    { sender: 1, content: 'Thanks for the invite!', offset: -3500 },
    { sender: 2, content: 'Hello everyone!', offset: -3400 },
    { sender: 3, content: 'Nice to be here', offset: -3300 },
    { sender: 0, content: 'Let me share the roadmap', offset: -3200 },
  ];

  for (const m of groupMessages) {
    insertMessage.run(uuid(), groupChat, userIds[m.sender], m.content, now + m.offset);
  }

  const channelMessages = [
    { content: 'MQ Messenger v1.0 released!', offset: -7200 },
    { content: 'New features: groups, channels, stories', offset: -3600 },
    { content: 'Update: Liquid Glass UI now available', offset: -1800 },
  ];

  for (const m of channelMessages) {
    insertMessage.run(uuid(), channel, userIds[0], m.content, now + m.offset);
  }
}

export default db;
