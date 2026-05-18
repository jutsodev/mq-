# MQ Messenger

Full-featured messenger application (iOS + Backend) — WhatsApp/Telegram alternative.

## Architecture

- **iOS App**: Swift / SwiftUI / MVVM
- **Backend**: Node.js / Express / Socket.IO / SQLite

## Features

- Real-time messaging via WebSocket
- Private chats, groups, channels
- Message reactions, replies, forwarding, editing, deleting
- User search and contact management
- Profile with avatar, bio, username
- Push notifications (APNs)
- Liquid Glass UI effects
- Light/Dark theme support
- Chat appearance customization (wallpapers, bubble colors, font size, corner radius)
- Privacy settings (online status, last seen, read receipts, typing indicator)
- Confidentiality (two-step verification, encryption info)
- Russian / English localization
- Demo phone login (enter any phone number)
- File/image upload and sharing
- Typing indicators
- Online/offline status
- Pin/mute/archive chats
- Star/pin messages
- Invite links for groups

## Project Structure

```
mq-/
├── server/                  # Node.js backend
│   ├── index.js            # Express + Socket.IO server
│   ├── db.js               # SQLite database + schema + seed
│   ├── middleware/auth.js   # JWT auth
│   ├── routes/
│   │   ├── auth.js         # Login/verify
│   │   ├── users.js        # Profile, contacts, search
│   │   ├── chats.js        # Chats, messages, members
│   │   └── notifications.js # Notifications
│   ├── socket/handler.js   # WebSocket events
│   └── utils/push.js       # Push notifications
│
├── MQMessenger/             # iOS SwiftUI app
│   ├── App/                # App entry point
│   ├── Models/             # Data models
│   ├── Services/           # API, WebSocket, Auth, Theme, Localization
│   ├── ViewModels/         # MVVM view models
│   ├── Views/
│   │   ├── Auth/           # Login screen
│   │   ├── Main/           # Tab view
│   │   ├── Home/           # Home screen
│   │   ├── Chats/          # Chat list, room, bubbles, input
│   │   ├── Profile/        # Profile, edit profile
│   │   ├── Settings/       # Privacy, appearance, notifications
│   │   ├── Contacts/       # Contacts, user search
│   │   ├── Groups/         # Create group/channel, group info
│   │   ├── Notifications/  # Notifications list
│   │   └── Components/     # Reusable UI (LiquidGlass, Avatar, etc.)
│   ├── Resources/          # Assets (app icon)
│   ├── Info.plist
│   ├── project.yml         # XcodeGen config
│   └── Package.swift       # SPM dependencies
│
└── .github/workflows/      # CI/CD
    └── build-ios.yml       # Xcode build + server check
```

## Setup

### Backend

```bash
cd server
npm install
node index.js
# Server runs on http://localhost:4000
# Demo login: enter any phone number, code: 0000 or 1234
```

### iOS App

Requirements: macOS with Xcode 15+, XcodeGen

```bash
brew install xcodegen
cd MQMessenger
xcodegen generate
open MQMessenger.xcodeproj
# Build & run on simulator (Cmd+R)
```

Update `APIService.swift` `baseURL` to point to your server address.

### Demo Login

1. Start the backend server
2. Run the iOS app
3. Enter any phone number
4. Server auto-creates user and returns auth token

Demo users are seeded on first server start.

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /auth/login | Phone login |
| POST | /auth/verify | Verify code |
| GET | /auth/me | Current user |
| GET | /users/search | Search users |
| GET/PUT | /users/profile | Profile |
| GET/POST/DELETE | /users/contacts | Contacts |
| GET/POST | /chats | List/create chats |
| GET/POST | /chats/:id/messages | Messages |
| PUT/DELETE | /chats/:id/messages/:id | Edit/delete |
| POST | /chats/:id/messages/:id/reaction | React |
| GET | /notifications | List notifications |
| POST | /upload | File upload |

## WebSocket Events

| Event | Direction | Description |
|-------|-----------|-------------|
| message:send | Client→Server | Send message |
| message:new | Server→Client | New message |
| message:edit | Client→Server | Edit message |
| message:delete | Client→Server | Delete message |
| typing:start/stop | Bidirectional | Typing indicators |
| message:read | Client→Server | Read receipt |
| user:status | Server→Client | Online/offline |

## Tech Stack

- **iOS**: Swift 5.9, SwiftUI, Combine, Socket.IO Client, Kingfisher
- **Backend**: Node.js, Express, Socket.IO, better-sqlite3, JWT, bcryptjs, multer, web-push
- **CI**: GitHub Actions (Xcode build + Node.js server check)

## License

MIT
