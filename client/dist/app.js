/* MQ Messenger Web Client */

const API_BASE = window.location.origin + '/api';
let socket = null;
let currentUser = null;
let token = null;
let chats = [];
let currentChatId = null;
let currentChatDetail = null;
let messages = [];
let typingTimer = null;
let replyToMessage = null;
let onlineUsers = new Set();
let searchDebounce = null;

// ── Auth ──

function sendCode() {
  const phone = document.getElementById('phone-input').value.trim();
  if (!phone) return;

  fetch(API_BASE + '/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone }),
  })
    .then(r => r.json())
    .then(data => {
      if (data.token) {
        token = data.token;
        currentUser = data.user;
        localStorage.setItem('mq_token', token);
        localStorage.setItem('mq_user', JSON.stringify(currentUser));
        initApp();
      } else {
        document.getElementById('phone-step').style.display = 'none';
        document.getElementById('code-step').style.display = 'block';
        document.getElementById('code-step').dataset.phone = phone;
      }
    })
    .catch(err => console.error('Login error:', err));
}

function verifyCode() {
  const code = document.getElementById('code-input').value.trim();
  const phone = document.getElementById('code-step').dataset.phone;

  fetch(API_BASE + '/auth/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ phone, code }),
  })
    .then(r => r.json())
    .then(data => {
      if (data.token) {
        token = data.token;
        currentUser = data.user;
        localStorage.setItem('mq_token', token);
        localStorage.setItem('mq_user', JSON.stringify(currentUser));
        initApp();
      } else {
        alert('Неверный код');
      }
    })
    .catch(err => console.error('Verify error:', err));
}

function logout() {
  localStorage.removeItem('mq_token');
  localStorage.removeItem('mq_user');
  if (socket) socket.disconnect();
  token = null;
  currentUser = null;
  document.getElementById('main-screen').classList.remove('active');
  document.getElementById('login-screen').classList.add('active');
}

// ── Init ──

function initApp() {
  document.getElementById('login-screen').classList.remove('active');
  document.getElementById('main-screen').classList.add('active');
  connectSocket();
  loadChats();
  loadContacts();
  loadProfile();
  fetchOnlineUsers();
}

function connectSocket() {
  socket = io(window.location.origin, {
    auth: { token },
    transports: ['websocket', 'polling'],
  });

  socket.on('connect', () => {
    console.log('Socket connected');
  });

  socket.on('message:new', (msg) => {
    handleNewMessage(msg);
  });

  socket.on('message:updated', (msg) => {
    handleMessageUpdate(msg);
  });

  socket.on('message:edited', (msg) => {
    handleMessageUpdate(msg);
  });

  socket.on('message:deleted', (data) => {
    handleMessageDelete(data);
  });

  socket.on('message:reaction', (data) => {
    handleReactionUpdate(data);
  });

  socket.on('message:read', (data) => {
    handleReadReceipt(data);
  });

  socket.on('typing:start', (data) => {
    showTyping(data);
  });

  socket.on('typing:stop', (data) => {
    hideTyping(data);
  });

  socket.on('user:status', (data) => {
    if (data.status === 'online') onlineUsers.add(data.user_id);
    else onlineUsers.delete(data.user_id);
    updateStatusIndicators();
  });

  socket.on('disconnect', () => {
    console.log('Socket disconnected');
  });

  setInterval(() => {
    if (socket && socket.connected) socket.emit('presence:ping');
  }, 30000);
}

// ── API Helpers ──

function apiFetch(url, opts = {}) {
  opts.headers = opts.headers || {};
  opts.headers['Authorization'] = 'Bearer ' + token;
  if (opts.body && typeof opts.body === 'string') {
    opts.headers['Content-Type'] = 'application/json';
  }
  return fetch(API_BASE + url, opts).then(r => r.json());
}

function fetchOnlineUsers() {
  apiFetch('/online').then(data => {
    onlineUsers = new Set(data.online || []);
    updateStatusIndicators();
  });
}

// ── Chats ──

function loadChats() {
  apiFetch('/chats').then(data => {
    chats = data.chats || [];
    renderChatList();
  });
}

function renderChatList() {
  const list = document.getElementById('chat-list');
  list.innerHTML = chats.map(chat => {
    const isActive = chat.id === currentChatId;
    const lastMsg = chat.last_message;
    const time = lastMsg ? formatTime(lastMsg.created_at) : '';
    const preview = lastMsg
      ? (lastMsg.type === 'image' ? '📷 Фото' : lastMsg.type === 'file' ? '📎 Файл' : lastMsg.content || '')
      : '';
    const avatarHtml = renderAvatar(chat.avatar, chat.name, 'avatar-small');
    const badge = chat.unread_count > 0
      ? `<span class="chat-item-badge">${chat.unread_count}</span>` : '';
    const pin = chat.is_pinned
      ? '<span class="chat-item-pinned">📌</span>' : '';

    return `
      <div class="chat-item ${isActive ? 'active' : ''}"
           onclick="openChat('${chat.id}')"
           oncontextmenu="showChatContextMenu(event, '${chat.id}')">
        ${avatarHtml}
        <div class="chat-item-info">
          <div class="chat-item-top">
            <span class="chat-item-name">${escapeHtml(chat.name || 'Чат')}</span>
            <span class="chat-item-time">${time}${pin}</span>
          </div>
          <div class="chat-item-bottom">
            <span class="chat-item-preview">${escapeHtml(preview)}</span>
            ${badge}
          </div>
        </div>
      </div>
    `;
  }).join('');
}

function filterChats(query) {
  const items = document.querySelectorAll('.chat-item');
  const q = query.toLowerCase();
  items.forEach(item => {
    const name = item.querySelector('.chat-item-name').textContent.toLowerCase();
    item.style.display = name.includes(q) ? '' : 'none';
  });
}

function openChat(chatId) {
  currentChatId = chatId;
  renderChatList();
  document.getElementById('no-chat-selected').style.display = 'none';
  document.getElementById('chat-view').style.display = 'flex';
  document.getElementById('chat-view').style.flexDirection = 'column';
  document.getElementById('chat-view').style.height = '100%';

  const chatArea = document.getElementById('chat-area');
  chatArea.classList.add('open');

  socket.emit('chat:join', { chat_id: chatId });

  apiFetch('/chats/' + chatId).then(data => {
    currentChatDetail = data;
    const chat = chats.find(c => c.id === chatId);
    const name = chat ? chat.name : data.chat.name || 'Чат';

    document.getElementById('chat-header-name').textContent = name;
    const headerAvatar = document.getElementById('chat-header-avatar');
    headerAvatar.innerHTML = renderAvatarInner(chat?.avatar || data.chat.avatar, name);

    updateChatStatus(data);
  });

  loadMessages(chatId);

  apiFetch('/chats/' + chatId, { method: 'PUT', body: JSON.stringify({}) }).catch(() => {});
  markAsRead(chatId);
}

function updateChatStatus(detail) {
  const statusEl = document.getElementById('chat-header-status');
  const chat = chats.find(c => c.id === currentChatId);
  if (!chat) return;

  if (chat.type === 'private') {
    const other = detail.members.find(m => m.id !== currentUser.id);
    if (other && onlineUsers.has(other.id)) {
      statusEl.textContent = 'в сети';
      statusEl.className = 'status-text online';
    } else if (other && other.last_seen) {
      statusEl.textContent = 'был(а) ' + formatLastSeen(other.last_seen);
      statusEl.className = 'status-text';
    } else {
      statusEl.textContent = '';
    }
  } else {
    statusEl.textContent = detail.members.length + ' участников';
    statusEl.className = 'status-text';
  }
}

function closeChat() {
  currentChatId = null;
  document.getElementById('chat-area').classList.remove('open');
  document.getElementById('chat-view').style.display = 'none';
  document.getElementById('no-chat-selected').style.display = 'flex';
  renderChatList();
}

// ── Messages ──

function loadMessages(chatId) {
  apiFetch('/chats/' + chatId + '/messages?limit=100').then(data => {
    messages = (data.messages || []).reverse();
    renderMessages();
    scrollToBottom();
  });
}

function renderMessages() {
  const container = document.getElementById('messages-container');
  let html = '';
  let lastDate = '';
  let lastSender = '';

  for (const msg of messages) {
    const date = formatDate(msg.created_at);
    if (date !== lastDate) {
      html += `<div class="date-separator"><span>${date}</span></div>`;
      lastDate = date;
      lastSender = '';
    }

    const isMe = msg.sender_id === currentUser.id;
    const dir = isMe ? 'outgoing' : 'incoming';
    const showSender = !isMe && msg.sender_id !== lastSender;
    lastSender = msg.sender_id;

    let replyHtml = '';
    if (msg.reply_to_id) {
      const orig = messages.find(m => m.id === msg.reply_to_id);
      if (orig) {
        replyHtml = `
          <div class="message-reply">
            <div class="message-reply-name">${escapeHtml(orig.sender_name || '')}</div>
            <div>${escapeHtml((orig.content || '').substring(0, 60))}</div>
          </div>`;
      }
    }

    let contentHtml = '';
    if (msg.type === 'image' && msg.media_url) {
      contentHtml = `<div class="message-media"><img src="${msg.media_url}" onclick="window.open('${msg.media_url}','_blank')" loading="lazy"></div>`;
    }
    if (msg.content) {
      contentHtml += `<div class="message-text">${formatMessageText(msg.content, msg.format)}</div>`;
    }

    const reactions = msg.reactions ? renderReactions(msg) : '';

    html += `
      <div class="message-group ${dir}" data-msg-id="${msg.id}"
           oncontextmenu="showMsgContextMenu(event, '${msg.id}')">
        ${showSender ? `<div class="message-sender">${escapeHtml(msg.sender_name || msg.sender_username || '')}</div>` : ''}
        <div class="message-bubble">
          ${replyHtml}
          ${contentHtml}
          <div class="message-meta">
            ${msg.is_edited ? '<span style="font-size:11px;color:var(--text-tertiary)">ред.</span>' : ''}
            <span class="message-time">${formatTime(msg.created_at)}</span>
            ${isMe ? `<span class="message-status ${(msg.read_by && msg.read_by.length > 1) ? 'read' : ''}">${(msg.read_by && msg.read_by.length > 1) ? '✓✓' : '✓'}</span>` : ''}
          </div>
          ${reactions}
        </div>
      </div>`;
  }

  container.innerHTML = html;
}

function renderReactions(msg) {
  const reactions = msg.reactions;
  if (!reactions || typeof reactions !== 'object' || Object.keys(reactions).length === 0) return '';
  const badges = Object.entries(reactions).map(([emoji, users]) => {
    if (!Array.isArray(users) || users.length === 0) return '';
    const mine = users.includes(currentUser.id) ? 'mine' : '';
    return `<span class="reaction-badge ${mine}" onclick="toggleReaction('${msg.id}','${emoji}')">${emoji}<span class="reaction-count">${users.length}</span></span>`;
  }).filter(Boolean).join('');
  if (!badges) return '';
  return `<div class="message-reactions">${badges}</div>`;
}

function sendMessage() {
  const input = document.getElementById('message-input');
  const content = input.value.trim();
  if (!content || !currentChatId) return;

  const data = {
    chat_id: currentChatId,
    content,
    type: 'text',
  };

  if (replyToMessage) {
    data.reply_to_id = replyToMessage.id;
    clearReply();
  }

  socket.emit('message:send', data, (response) => {
    if (response && response.error) {
      console.error('Send error:', response.error);
    }
  });

  input.value = '';
  autoResize(input);
  stopTyping();
}

function handleNewMessage(msg) {
  if (msg.chat_id === currentChatId) {
    messages.push(msg);
    renderMessages();
    scrollToBottom();
    markAsRead(msg.chat_id);
  }

  const chatIdx = chats.findIndex(c => c.id === msg.chat_id);
  if (chatIdx >= 0) {
    chats[chatIdx].last_message = msg;
    if (msg.chat_id !== currentChatId) {
      chats[chatIdx].unread_count = (chats[chatIdx].unread_count || 0) + 1;
    }
    chats.sort((a, b) => {
      if (a.is_pinned !== b.is_pinned) return b.is_pinned - a.is_pinned;
      const aTime = a.last_message?.created_at || a.updated_at || 0;
      const bTime = b.last_message?.created_at || b.updated_at || 0;
      return bTime - aTime;
    });
    renderChatList();
  } else {
    loadChats();
  }
}

function handleMessageUpdate(msg) {
  if (msg.chat_id !== currentChatId) return;
  const idx = messages.findIndex(m => m.id === msg.id);
  if (idx >= 0) {
    messages[idx] = { ...messages[idx], ...msg };
    renderMessages();
  }
}

function handleMessageDelete(data) {
  if (data.chat_id !== currentChatId) return;
  const idx = messages.findIndex(m => m.id === data.message_id);
  if (idx >= 0) {
    messages.splice(idx, 1);
    renderMessages();
  }
}

function handleReactionUpdate(data) {
  if (data.chat_id !== currentChatId) return;
  loadMessages(currentChatId);
}

function handleReadReceipt(data) {
  if (data.chat_id !== currentChatId) return;
  loadMessages(currentChatId);
}

function markAsRead(chatId) {
  if (messages.length > 0) {
    socket.emit('message:read', { chat_id: chatId, message_id: messages[messages.length - 1].id });
    const chat = chats.find(c => c.id === chatId);
    if (chat) {
      chat.unread_count = 0;
      renderChatList();
    }
  }
}

// ── Typing ──

function handleTyping() {
  if (!currentChatId) return;
  socket.emit('typing:start', { chat_id: currentChatId });
  clearTimeout(typingTimer);
  typingTimer = setTimeout(stopTyping, 3000);
}

function stopTyping() {
  if (!currentChatId) return;
  socket.emit('typing:stop', { chat_id: currentChatId });
  clearTimeout(typingTimer);
}

function showTyping(data) {
  if (data.chat_id !== currentChatId) return;
  const indicator = document.getElementById('typing-indicator');
  const member = currentChatDetail?.members?.find(m => m.id === data.user_id);
  const name = member?.display_name || member?.username || '';
  document.getElementById('typing-text').textContent = name + ' печатает';
  indicator.style.display = 'flex';
}

function hideTyping(data) {
  if (data.chat_id !== currentChatId) return;
  document.getElementById('typing-indicator').style.display = 'none';
}

// ── Reactions ──

function toggleReaction(msgId, emoji) {
  socket.emit('message:reaction', { message_id: msgId, emoji, chat_id: currentChatId });
}

// ── Reply ──

function setReply(msgId) {
  const msg = messages.find(m => m.id === msgId);
  if (!msg) return;
  replyToMessage = msg;

  let preview = document.querySelector('.reply-preview');
  if (!preview) {
    preview = document.createElement('div');
    preview.className = 'reply-preview';
    const inputArea = document.querySelector('.message-input-area');
    inputArea.parentNode.insertBefore(preview, inputArea);
  }
  preview.innerHTML = `
    <div class="reply-preview-content">
      <div class="reply-preview-name">${escapeHtml(msg.sender_name || '')}</div>
      <div class="reply-preview-text">${escapeHtml((msg.content || '').substring(0, 80))}</div>
    </div>
    <button class="icon-btn" onclick="clearReply()">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
    </button>`;
  document.getElementById('message-input').focus();
}

function clearReply() {
  replyToMessage = null;
  const preview = document.querySelector('.reply-preview');
  if (preview) preview.remove();
}

// ── File Upload ──

function handleFileUpload(file) {
  if (!file || !currentChatId) return;
  const formData = new FormData();
  formData.append('file', file);

  fetch(API_BASE + '/upload', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + token },
    body: formData,
  })
    .then(r => r.json())
    .then(data => {
      const type = data.mimetype?.startsWith('image/') ? 'image' : 'file';
      socket.emit('message:send', {
        chat_id: currentChatId,
        content: type === 'file' ? data.filename : '',
        type,
        media_url: data.url,
        media_type: data.mimetype,
      });
    })
    .catch(err => console.error('Upload error:', err));
}

// ── Context Menus ──

function showMsgContextMenu(e, msgId) {
  e.preventDefault();
  const msg = messages.find(m => m.id === msgId);
  if (!msg) return;

  const isMe = msg.sender_id === currentUser.id;
  const menu = document.getElementById('context-menu');
  menu.innerHTML = `
    <div class="context-menu-item" onclick="setReply('${msgId}'); hideContextMenu()">💬 Ответить</div>
    <div class="context-menu-item" onclick="copyMessage('${msgId}'); hideContextMenu()">📋 Копировать</div>
    <div class="context-menu-item" onclick="showEmojiPicker('${msgId}'); hideContextMenu()">😊 Реакция</div>
    ${isMe ? `
      <div class="context-menu-divider"></div>
      <div class="context-menu-item" onclick="editMessage('${msgId}'); hideContextMenu()">✏️ Редактировать</div>
      <div class="context-menu-item danger" onclick="deleteMessage('${msgId}'); hideContextMenu()">🗑 Удалить</div>
    ` : ''}
  `;
  positionContextMenu(menu, e);
}

function showChatContextMenu(e, chatId) {
  e.preventDefault();
  const chat = chats.find(c => c.id === chatId);
  if (!chat) return;

  const menu = document.getElementById('context-menu');
  menu.innerHTML = `
    <div class="context-menu-item" onclick="togglePin('${chatId}'); hideContextMenu()">${chat.is_pinned ? '📌 Открепить' : '📌 Закрепить'}</div>
    <div class="context-menu-item" onclick="toggleMute('${chatId}'); hideContextMenu()">${chat.is_muted ? '🔔 Включить уведомления' : '🔕 Выключить уведомления'}</div>
    <div class="context-menu-divider"></div>
    <div class="context-menu-item danger" onclick="leaveChat('${chatId}'); hideContextMenu()">🚪 Покинуть чат</div>
  `;
  positionContextMenu(menu, e);
}

function positionContextMenu(menu, e) {
  menu.style.display = 'block';
  const x = Math.min(e.clientX, window.innerWidth - 200);
  const y = Math.min(e.clientY, window.innerHeight - menu.offsetHeight);
  menu.style.left = x + 'px';
  menu.style.top = y + 'px';
}

function hideContextMenu() {
  document.getElementById('context-menu').style.display = 'none';
}

document.addEventListener('click', hideContextMenu);

function copyMessage(msgId) {
  const msg = messages.find(m => m.id === msgId);
  if (msg && msg.content) navigator.clipboard.writeText(msg.content);
}

function editMessage(msgId) {
  const msg = messages.find(m => m.id === msgId);
  if (!msg) return;
  const newContent = prompt('Редактировать сообщение:', msg.content);
  if (newContent && newContent !== msg.content) {
    socket.emit('message:edit', { message_id: msgId, content: newContent, chat_id: currentChatId });
  }
}

function deleteMessage(msgId) {
  if (confirm('Удалить сообщение?')) {
    socket.emit('message:delete', { message_id: msgId, chat_id: currentChatId });
  }
}

function showEmojiPicker(msgId) {
  const emojis = ['👍', '❤️', '😂', '😮', '😢', '🔥', '🎉', '👎'];
  const menu = document.getElementById('context-menu');
  menu.innerHTML = emojis.map(e =>
    `<span style="cursor:pointer;font-size:24px;padding:6px;display:inline-block" onclick="toggleReaction('${msgId}','${e}'); hideContextMenu()">${e}</span>`
  ).join('');
  menu.style.display = 'block';
}

function togglePin(chatId) {
  const chat = chats.find(c => c.id === chatId);
  if (!chat) return;
  apiFetch('/chats/' + chatId + '/pin', {
    method: 'PUT',
    body: JSON.stringify({ is_pinned: !chat.is_pinned }),
  }).then(() => loadChats());
}

function toggleMute(chatId) {
  const chat = chats.find(c => c.id === chatId);
  if (!chat) return;
  apiFetch('/chats/' + chatId + '/mute', {
    method: 'PUT',
    body: JSON.stringify({ is_muted: !chat.is_muted }),
  }).then(() => loadChats());
}

function leaveChat(chatId) {
  if (!confirm('Покинуть чат?')) return;
  apiFetch('/chats/' + chatId + '/members/' + currentUser.id, { method: 'DELETE' })
    .then(() => {
      if (currentChatId === chatId) closeChat();
      loadChats();
    });
}

// ── Contacts ──

let contacts = [];

function loadContacts() {
  apiFetch('/users/contacts').then(data => {
    contacts = data.contacts || [];
    renderContacts();
  });
}

function renderContacts() {
  const list = document.getElementById('contacts-list');
  list.innerHTML = contacts.map(c => {
    const isOnline = onlineUsers.has(c.id);
    return `
      <div class="contact-item" onclick="startPrivateChat('${c.id}')">
        ${renderAvatar(c.avatar, c.display_name || c.username, 'avatar-small')}
        <div class="contact-item-info">
          <div class="contact-item-name">${escapeHtml(c.display_name || c.username || c.phone)}</div>
          <div class="contact-item-status ${isOnline ? 'online' : ''}">${isOnline ? 'в сети' : c.last_seen ? 'был(а) ' + formatLastSeen(c.last_seen) : 'не в сети'}</div>
        </div>
      </div>`;
  }).join('');
}

function searchUsers(query) {
  clearTimeout(searchDebounce);
  if (!query.trim()) {
    document.getElementById('search-results').style.display = 'none';
    document.getElementById('contacts-list').style.display = '';
    return;
  }
  searchDebounce = setTimeout(() => {
    apiFetch('/users/search?q=' + encodeURIComponent(query)).then(data => {
      const results = document.getElementById('search-results');
      results.style.display = 'block';
      document.getElementById('contacts-list').style.display = 'none';
      results.innerHTML = (data.users || []).map(u => `
        <div class="contact-item" onclick="startPrivateChat('${u.id}')">
          ${renderAvatar(u.avatar, u.display_name || u.username, 'avatar-small')}
          <div class="contact-item-info">
            <div class="contact-item-name">${escapeHtml(u.display_name || u.username || u.phone)}</div>
            <div class="contact-item-status">@${escapeHtml(u.username || '')}</div>
          </div>
        </div>`).join('') || '<div style="padding:20px;text-align:center;color:var(--text-tertiary)">Не найдено</div>';
    });
  }, 300);
}

function startPrivateChat(userId) {
  apiFetch('/chats', {
    method: 'POST',
    body: JSON.stringify({ type: 'private', members: [userId] }),
  }).then(data => {
    if (data.chat_id) {
      loadChats();
      setTimeout(() => openChat(data.chat_id), 500);
      switchTab('chats');
      hideNewChatModal();
    }
  });
}

// ── New Chat ──

function showNewChatModal() {
  document.getElementById('new-chat-modal').style.display = 'flex';
  document.getElementById('new-chat-search').value = '';
  document.getElementById('new-chat-results').innerHTML = '';
  document.getElementById('new-chat-search').focus();
}

function hideNewChatModal() {
  document.getElementById('new-chat-modal').style.display = 'none';
}

function searchForNewChat(query) {
  clearTimeout(searchDebounce);
  if (!query.trim()) {
    document.getElementById('new-chat-results').innerHTML = '';
    return;
  }
  searchDebounce = setTimeout(() => {
    apiFetch('/users/search?q=' + encodeURIComponent(query)).then(data => {
      document.getElementById('new-chat-results').innerHTML = (data.users || []).map(u => `
        <div class="contact-item" onclick="startPrivateChat('${u.id}')">
          ${renderAvatar(u.avatar, u.display_name || u.username, 'avatar-small')}
          <div class="contact-item-info">
            <div class="contact-item-name">${escapeHtml(u.display_name || u.username || u.phone)}</div>
            <div class="contact-item-status">@${escapeHtml(u.username || '')}</div>
          </div>
        </div>`).join('') || '<div style="padding:20px;text-align:center;color:var(--text-tertiary)">Не найдено</div>';
    });
  }, 300);
}

// ── Profile ──

function loadProfile() {
  if (!currentUser) return;
  document.getElementById('profile-name').value = currentUser.display_name || '';
  document.getElementById('profile-username').value = currentUser.username || '';
  document.getElementById('profile-bio').value = currentUser.bio || '';
  const avatarEl = document.getElementById('profile-avatar');
  avatarEl.innerHTML = renderAvatarInner(currentUser.avatar, currentUser.display_name || currentUser.username, true);
}

function saveProfile() {
  const data = {
    display_name: document.getElementById('profile-name').value,
    username: document.getElementById('profile-username').value,
    bio: document.getElementById('profile-bio').value,
  };
  apiFetch('/users/profile', {
    method: 'PUT',
    body: JSON.stringify(data),
  }).then(response => {
    if (response.user) {
      currentUser = response.user;
      localStorage.setItem('mq_user', JSON.stringify(currentUser));
      loadProfile();
    } else if (response.error) {
      alert(response.error === 'username_taken' ? 'Имя пользователя занято' : response.error);
    }
  });
}

function uploadAvatar(file) {
  if (!file) return;
  const formData = new FormData();
  formData.append('avatar', file);
  fetch(API_BASE + '/upload/avatar', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + token },
    body: formData,
  })
    .then(r => r.json())
    .then(data => {
      if (data.url) {
        apiFetch('/users/profile', {
          method: 'PUT',
          body: JSON.stringify({ avatar: data.url }),
        }).then(response => {
          if (response.user) {
            currentUser = response.user;
            localStorage.setItem('mq_user', JSON.stringify(currentUser));
            loadProfile();
            loadChats();
          }
        });
      }
    });
}

// ── Tabs ──

function switchTab(tab) {
  document.querySelectorAll('.nav-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.tab === tab);
  });

  const sidebar = document.getElementById('sidebar');
  const contactsPanel = document.getElementById('contacts-panel');
  const profilePanel = document.getElementById('profile-panel');

  sidebar.style.display = tab === 'chats' ? '' : 'none';
  contactsPanel.style.display = tab === 'contacts' ? '' : 'none';
  profilePanel.style.display = tab === 'profile' ? '' : 'none';

  if (tab === 'contacts') loadContacts();
  if (tab === 'profile') loadProfile();
}

function toggleChatInfo() {
  // TODO: chat info panel
}

// ── Helpers ──

function renderAvatar(url, name, className) {
  return `<div class="${className}">${renderAvatarInner(url, name)}</div>`;
}

function renderAvatarInner(url, name, large) {
  if (url) {
    const src = url.startsWith('/') ? url : url;
    return `<img src="${src}" alt="" loading="lazy">`;
  }
  const initials = getInitials(name || '?');
  const colors = ['#7c5cfc', '#e84393', '#00b894', '#fdcb6e', '#6c5ce7', '#ff6b6b', '#48dbfb', '#ff9ff3'];
  const color = colors[Math.abs(hashCode(name || '')) % colors.length];
  const size = large ? 36 : 16;
  return `<span style="background:${color};width:100%;height:100%;display:flex;align-items:center;justify-content:center;font-size:${size}px;font-weight:700;color:white;border-radius:50%">${initials}</span>`;
}

function getInitials(name) {
  return name.split(' ').map(w => w[0]).filter(Boolean).slice(0, 2).join('').toUpperCase() || '?';
}

function hashCode(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash) + str.charCodeAt(i);
    hash |= 0;
  }
  return hash;
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function formatTime(ts) {
  const d = new Date(ts * 1000);
  return d.toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit' });
}

function formatDate(ts) {
  const d = new Date(ts * 1000);
  const today = new Date();
  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);

  if (d.toDateString() === today.toDateString()) return 'Сегодня';
  if (d.toDateString() === yesterday.toDateString()) return 'Вчера';
  return d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' });
}

function formatLastSeen(ts) {
  const d = new Date(ts * 1000);
  const now = new Date();
  const diff = Math.floor((now - d) / 1000);

  if (diff < 60) return 'только что';
  if (diff < 3600) return Math.floor(diff / 60) + ' мин. назад';
  if (diff < 86400) return Math.floor(diff / 3600) + ' ч. назад';
  return d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short' });
}

function formatMessageText(text, format) {
  let html = escapeHtml(text);
  if (format === 'markdown') {
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    html = html.replace(/\*(.+?)\*/g, '<em>$1</em>');
    html = html.replace(/~~(.+?)~~/g, '<del>$1</del>');
    html = html.replace(/`(.+?)`/g, '<code style="background:rgba(255,255,255,0.1);padding:1px 4px;border-radius:3px">$1</code>');
  }
  html = html.replace(/(https?:\/\/[^\s<]+)/g, '<a href="$1" target="_blank" style="color:var(--accent)">$1</a>');
  return html;
}

function autoResize(el) {
  el.style.height = 'auto';
  el.style.height = Math.min(el.scrollHeight, 150) + 'px';
}

function handleInputKeydown(e) {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
}

function scrollToBottom() {
  const container = document.getElementById('messages-container');
  requestAnimationFrame(() => {
    container.scrollTop = container.scrollHeight;
  });
}

function updateStatusIndicators() {
  renderChatList();
  if (currentChatDetail) updateChatStatus(currentChatDetail);
  renderContacts();
}

// ── Startup ──

(function boot() {
  token = localStorage.getItem('mq_token');
  const savedUser = localStorage.getItem('mq_user');
  if (token && savedUser) {
    currentUser = JSON.parse(savedUser);
    initApp();
  } else {
    document.getElementById('login-screen').classList.add('active');
  }

  // Enter key for login
  document.getElementById('phone-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') sendCode();
  });
  document.getElementById('code-input').addEventListener('keydown', e => {
    if (e.key === 'Enter') verifyCode();
  });
})();
