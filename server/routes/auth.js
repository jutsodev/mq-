import { Router } from 'express';
import { v4 as uuid } from 'uuid';
import db from '../db.js';
import { generateToken } from '../middleware/auth.js';

const router = Router();

router.post('/login', (req, res) => {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ error: 'phone_required' });

  const cleaned = phone.replace(/\s/g, '');
  let user = db.prepare('SELECT * FROM users WHERE phone = ?').get(cleaned);

  if (!user) {
    const id = uuid();
    const username = 'user_' + Date.now().toString(36);
    db.prepare(`
      INSERT INTO users (id, phone, username, display_name, status, last_seen)
      VALUES (?, ?, ?, ?, 'online', ?)
    `).run(id, cleaned, username, cleaned, Math.floor(Date.now() / 1000));
    user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  }

  db.prepare('UPDATE users SET status = ?, last_seen = ? WHERE id = ?')
    .run('online', Math.floor(Date.now() / 1000), user.id);

  const token = generateToken(user.id);
  res.json({ token, user: sanitizeUser(user) });
});

router.post('/verify', (req, res) => {
  const { phone, code } = req.body;
  if (code === '0000' || code === '1234') {
    const user = db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);
    if (user) {
      const token = generateToken(user.id);
      return res.json({ token, user: sanitizeUser(user) });
    }
  }
  res.status(400).json({ error: 'invalid_code' });
});

router.get('/me', (req, res) => {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: 'unauthorized' });
  try {
    const { verifyToken } = require('../middleware/auth.js');
    const decoded = verifyToken(header.split(' ')[1]);
    const user = db.prepare('SELECT * FROM users WHERE id = ?').get(decoded.userId);
    if (!user) return res.status(404).json({ error: 'not_found' });
    res.json({ user: sanitizeUser(user) });
  } catch {
    res.status(401).json({ error: 'invalid_token' });
  }
});

function sanitizeUser(u) {
  return {
    id: u.id,
    phone: u.phone,
    username: u.username,
    display_name: u.display_name,
    avatar: u.avatar,
    bio: u.bio,
    status: u.status,
    last_seen: u.last_seen,
    language: u.language,
    theme: u.theme,
    wallpaper: u.wallpaper,
    font_size: u.font_size,
    show_online: !!u.show_online,
    show_last_seen: !!u.show_last_seen,
    show_read_receipts: !!u.show_read_receipts,
    show_typing: !!u.show_typing,
    two_step_enabled: !!u.two_step_enabled,
    notification_sound: u.notification_sound,
    notification_vibrate: !!u.notification_vibrate,
    notification_preview: !!u.notification_preview,
    created_at: u.created_at,
  };
}

export { sanitizeUser };
export default router;
