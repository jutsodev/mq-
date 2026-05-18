import { Router } from 'express';
import { v4 as uuid } from 'uuid';
import db from '../db.js';
import { authMiddleware } from '../middleware/auth.js';
import { sanitizeUser } from './auth.js';

const router = Router();
router.use(authMiddleware);

router.get('/search', (req, res) => {
  const { q, page = 1, limit = 20 } = req.query;
  if (!q) return res.json({ users: [] });

  const offset = (page - 1) * limit;
  const users = db.prepare(`
    SELECT * FROM users
    WHERE (username LIKE ? OR display_name LIKE ? OR phone LIKE ?)
    AND id != ?
    ORDER BY display_name ASC
    LIMIT ? OFFSET ?
  `).all(`%${q}%`, `%${q}%`, `%${q}%`, req.userId, Number(limit), offset);

  res.json({ users: users.map(sanitizeUser) });
});

router.get('/contacts', (req, res) => {
  const contacts = db.prepare(`
    SELECT u.*, c.nickname, c.is_favorite, c.is_blocked
    FROM contacts c
    JOIN users u ON u.id = c.contact_id
    WHERE c.user_id = ?
    ORDER BY c.is_favorite DESC, u.display_name ASC
  `).all(req.userId);

  res.json({
    contacts: contacts.map(c => ({
      ...sanitizeUser(c),
      nickname: c.nickname,
      is_favorite: !!c.is_favorite,
      is_blocked: !!c.is_blocked,
    })),
  });
});

router.post('/contacts', (req, res) => {
  const { contact_id, nickname } = req.body;
  if (!contact_id) return res.status(400).json({ error: 'contact_id_required' });
  if (contact_id === req.userId) return res.status(400).json({ error: 'cannot_add_self' });

  const target = db.prepare('SELECT id FROM users WHERE id = ?').get(contact_id);
  if (!target) return res.status(404).json({ error: 'user_not_found' });

  const existing = db.prepare('SELECT id FROM contacts WHERE user_id = ? AND contact_id = ?')
    .get(req.userId, contact_id);
  if (existing) return res.status(409).json({ error: 'already_added' });

  const id = uuid();
  db.prepare('INSERT INTO contacts (id, user_id, contact_id, nickname) VALUES (?, ?, ?, ?)')
    .run(id, req.userId, contact_id, nickname || null);

  res.json({ id, contact_id, nickname });
});

router.delete('/contacts/:contactId', (req, res) => {
  db.prepare('DELETE FROM contacts WHERE user_id = ? AND contact_id = ?')
    .run(req.userId, req.params.contactId);
  res.json({ ok: true });
});

router.put('/contacts/:contactId/favorite', (req, res) => {
  const { is_favorite } = req.body;
  db.prepare('UPDATE contacts SET is_favorite = ? WHERE user_id = ? AND contact_id = ?')
    .run(is_favorite ? 1 : 0, req.userId, req.params.contactId);
  res.json({ ok: true });
});

router.put('/contacts/:contactId/block', (req, res) => {
  const { is_blocked } = req.body;
  db.prepare('UPDATE contacts SET is_blocked = ? WHERE user_id = ? AND contact_id = ?')
    .run(is_blocked ? 1 : 0, req.userId, req.params.contactId);
  res.json({ ok: true });
});

router.get('/profile', (req, res) => {
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.userId);
  if (!user) return res.status(404).json({ error: 'not_found' });
  res.json({ user: sanitizeUser(user) });
});

router.put('/profile', (req, res) => {
  const fields = ['username', 'display_name', 'bio', 'avatar', 'language', 'theme',
    'wallpaper', 'font_size', 'show_online', 'show_last_seen', 'show_read_receipts',
    'show_typing', 'notification_sound', 'notification_vibrate', 'notification_preview'];

  const updates = [];
  const values = [];

  for (const f of fields) {
    if (req.body[f] !== undefined) {
      updates.push(`${f} = ?`);
      const val = typeof req.body[f] === 'boolean' ? (req.body[f] ? 1 : 0) : req.body[f];
      values.push(val);
    }
  }

  if (updates.length === 0) return res.status(400).json({ error: 'no_fields' });

  updates.push('updated_at = ?');
  values.push(Math.floor(Date.now() / 1000));
  values.push(req.userId);

  if (req.body.username) {
    const existing = db.prepare('SELECT id FROM users WHERE username = ? AND id != ?')
      .get(req.body.username, req.userId);
    if (existing) return res.status(409).json({ error: 'username_taken' });
  }

  db.prepare(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`).run(...values);
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.userId);
  res.json({ user: sanitizeUser(user) });
});

router.put('/profile/two-step', (req, res) => {
  const { enabled, pin } = req.body;
  if (enabled && (!pin || pin.length < 4)) {
    return res.status(400).json({ error: 'pin_too_short' });
  }
  db.prepare('UPDATE users SET two_step_enabled = ?, two_step_pin = ? WHERE id = ?')
    .run(enabled ? 1 : 0, enabled ? pin : null, req.userId);
  res.json({ ok: true });
});

router.post('/profile/push-subscription', (req, res) => {
  const { subscription } = req.body;
  db.prepare('UPDATE users SET push_subscription = ? WHERE id = ?')
    .run(JSON.stringify(subscription), req.userId);
  res.json({ ok: true });
});

router.get('/:userId', (req, res) => {
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.userId);
  if (!user) return res.status(404).json({ error: 'not_found' });

  const isBlocked = db.prepare(
    'SELECT is_blocked FROM contacts WHERE user_id = ? AND contact_id = ?'
  ).get(req.params.userId, req.userId);

  const publicUser = sanitizeUser(user);
  if (!user.show_online) publicUser.status = 'hidden';
  if (!user.show_last_seen) publicUser.last_seen = null;

  res.json({ user: publicUser, is_blocked: isBlocked?.is_blocked || false });
});

router.get('/', (req, res) => {
  const { ids } = req.query;
  if (!ids) return res.json({ users: [] });

  const idList = ids.split(',');
  const placeholders = idList.map(() => '?').join(',');
  const users = db.prepare(`SELECT * FROM users WHERE id IN (${placeholders})`).all(...idList);
  res.json({ users: users.map(sanitizeUser) });
});

export default router;
