import webpush from 'web-push';
import db from '../db.js';

const VAPID_PUBLIC = process.env.VAPID_PUBLIC_KEY || 'BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkOs-qHe2VcSOcGgiJimRRFDAJRmiEkhMlJkXdVHSs';
const VAPID_PRIVATE = process.env.VAPID_PRIVATE_KEY || 'UUxI4o8-FbRouAevSmBQ6o18hgE4nSG3qwvJTfKc-ls';

webpush.setVapidDetails('mailto:mq@messenger.app', VAPID_PUBLIC, VAPID_PRIVATE);

export function getVapidPublicKey() {
  return VAPID_PUBLIC;
}

export async function sendPushNotification(userId, payload) {
  const user = db.prepare('SELECT push_subscription FROM users WHERE id = ?').get(userId);
  if (!user?.push_subscription) return false;

  try {
    const subscription = JSON.parse(user.push_subscription);
    await webpush.sendNotification(subscription, JSON.stringify(payload));
    return true;
  } catch (err) {
    if (err.statusCode === 410) {
      db.prepare('UPDATE users SET push_subscription = NULL WHERE id = ?').run(userId);
    }
    return false;
  }
}

export async function sendPushToChat(chatId, senderId, payload) {
  const members = db.prepare(`
    SELECT cm.user_id, u.notification_preview, u.push_subscription
    FROM chat_members cm
    JOIN users u ON u.id = cm.user_id
    WHERE cm.chat_id = ? AND cm.user_id != ? AND cm.is_muted = 0
  `).all(chatId, senderId);

  const results = [];
  for (const member of members) {
    if (!member.push_subscription) continue;
    const p = member.notification_preview
      ? payload
      : { ...payload, body: 'New message' };
    const ok = await sendPushNotification(member.user_id, p);
    results.push({ user_id: member.user_id, sent: ok });
  }
  return results;
}

export async function sendBatchPush(userIds, payload) {
  const results = [];
  for (const uid of userIds) {
    const ok = await sendPushNotification(uid, payload);
    results.push({ user_id: uid, sent: ok });
  }
  return results;
}
