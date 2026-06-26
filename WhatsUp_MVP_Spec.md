# VYBIN — Comprehensive MVP Specification
### A Privacy-First, End-to-End Encrypted Mobile Chat Application
**Target Platform:** Android (Flutter)  
**Backend:** Firebase (Firestore + Auth + Storage + Cloud Functions)  
**Encryption:** Client-Side Asymmetric (RSA / ECDH) + Symmetric (AES-GCM)  
**Authentication:** Email + Password (Firebase Auth)  
**Discovery:** Unique Username System  
**Design Language:** WhatsApp-inspired Material Design System  

---

## TABLE OF CONTENTS

1. [Project Vision & Scope](#1-project-vision--scope)
2. [Architecture Overview](#2-architecture-overview)
3. [User Identity & Discovery System](#3-user-identity--discovery-system)
4. [Encryption Architecture](#4-encryption-architecture)
5. [Authentication Flows](#5-authentication-flows)
6. [Core Feature Specifications](#6-core-feature-specifications)
7. [Data Models & Firestore Schema](#7-data-models--firestore-schema)
8. [UI/UX Design System](#8-uiux-design-system)
9. [Screen-by-Screen Specification](#9-screen-by-screen-specification)
10. [Firebase Security Rules](#10-firebase-security-rules)
11. [Cloud Functions](#11-cloud-functions)
12. [Push Notifications](#12-push-notifications)
13. [Offline & Sync Behavior](#13-offline--sync-behavior)
14. [Media Handling](#14-media-handling)
15. [Non-Functional Requirements](#15-non-functional-requirements)
16. [Out of Scope (Post-MVP)](#16-out-of-scope-post-mvp)
17. [Implementation Roadmap](#17-implementation-roadmap)

---

## 1. Project Vision & Scope

### 1.1 What Is VYBIN?

VYBIN is a mobile-first, real-time chat application built with Flutter and Firebase. It mimics the core experience of WhatsApp in terms of design language and feature feel, but differs in two important ways:

1. **Authentication is email + password**, not phone number. No SMS verification, no carrier dependency.
2. **Messages are end-to-end encrypted** using a client-side public/private key model. Firebase Firestore stores only ciphertext. Even if the database is breached, message content is unreadable without the recipient's private key.

The app is designed as an academic project demonstrating modern mobile development, real-time systems, and applied cryptography — but it must be a fully working, installable Android application.

### 1.2 Core Value Proposition

- Users chat privately and in real-time.
- No plaintext message ever leaves the device unencrypted.
- The UI feels native and familiar — indistinguishable in feel from WhatsApp's design system.
- Onboarding is frictionless: pick a username, set a password, done.

### 1.3 MVP Feature Set

| Feature | MVP | Post-MVP |
|---|---|---|
| Email/password sign up & login | ✅ | |
| Unique username registration | ✅ | |
| Username-based user search/discovery | ✅ | |
| One-on-one real-time chat | ✅ | |
| End-to-end encrypted text messages | ✅ | |
| Image sharing (encrypted) | ✅ | |
| Voice notes (encrypted) | ✅ | |
| Document sharing (encrypted) | ✅ | |
| Push notifications (message preview hidden) | ✅ | |
| Online/offline/last seen status | ✅ | |
| Message delivery status (sent/delivered/read) | ✅ | |
| Chat list with last message preview (decrypted locally) | ✅ | |
| Profile photo + display name | ✅ | |
| Delete message (for me / for everyone) | ✅ | |
| Group chats | | ✅ |
| Status/Stories | | ✅ |
| Calls (voice/video) | | ✅ |
| Message reactions | | ✅ |
| Starred messages | | ✅ |

---

## 2. Architecture Overview

### 2.1 System Layers

```
┌──────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Client)                        │
│                                                                │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   UI Layer  │  │  BLoC/State  │  │  Crypto Service       │  │
│  │  (Screens,  │  │  Management  │  │  (KeyGen, Encrypt,    │  │
│  │   Widgets)  │  │  (flutter_   │  │   Decrypt via        │  │
│  └─────────────┘  │  bloc)       │  │   pointycastle)      │  │
│                   └──────────────┘  └──────────────────────┘  │
│                          │                      │              │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                   Repository Layer                        │  │
│  │  (AuthRepo, UserRepo, ChatRepo, MediaRepo)                │  │
│  └─────────────────────────────────────────────────────────┘  │
│                          │                                     │
└──────────────────────────┼─────────────────────────────────────┘
                           │
        ┌──────────────────┼───────────────────────┐
        │                  │                        │
┌───────▼──────┐  ┌────────▼───────┐  ┌────────────▼──────────┐
│  Firebase    │  │  Firebase      │  │  Firebase              │
│  Auth        │  │  Firestore     │  │  Storage               │
│              │  │  (Encrypted    │  │  (Encrypted            │
│  Email/Pass  │  │   messages,    │  │   media blobs)         │
└──────────────┘  │   user meta,   │  └───────────────────────┘
                  │   public keys) │
                  └────────────────┘
                          │
                 ┌────────▼──────────┐
                 │  Firebase Cloud   │
                 │  Functions        │
                 │  (FCM triggers,   │
                 │   username check) │
                 └───────────────────┘
```

### 2.2 Key Architectural Decisions

**Why Flutter BLoC for state management?**  
BLoC cleanly separates business logic from UI. Auth state, chat streams, and encryption state all need to be reactive — BLoC handles this well and is testable.

**Why not store messages in Realtime Database?**  
Firestore's document model maps cleanly to structured messages with metadata fields. It also supports composite queries needed for ordering chats by last-message timestamp.

**Why client-side encryption only?**  
Cloud Functions cannot and should not decrypt messages. All crypto happens on-device. The server is intentionally "dumb" — it stores and routes ciphertext it cannot read.

**Key storage:**  
The user's RSA private key is generated on first login, encrypted with a key derived from their password (PBKDF2), and stored in `flutter_secure_storage` (Android Keystore-backed). The public key is stored in Firestore under the user's profile — publicly readable.

---

## 3. User Identity & Discovery System

### 3.1 The Username Decision (Critical Design Choice)

Since phone numbers are not used, users need another handle to find each other. Two options were considered:

| Option | Pros | Cons |
|---|---|---|
| **Email as identifier** | Simple, unique by nature | Exposes private email to others, hard to type, bad UX |
| **Username (chosen ✅)** | Private, short, memorable, shareable, WhatsApp-like feel | Requires uniqueness enforcement at registration |

**Decision: Username-based discovery.** Every user chooses a unique lowercase alphanumeric username at signup (like a Twitter handle). Users find each other by searching for a username exactly. Email stays private and is only used for authentication.

### 3.2 Username Rules

- 3–20 characters, lowercase letters, numbers, underscores only.
- Pattern: `^[a-z0-9_]{3,20}$`
- Case-insensitive: stored and compared in lowercase.
- Cannot be changed after registration (MVP constraint — keeps database simple).
- Globally unique: enforced at registration via a Firestore `usernames` collection (see schema).
- Reserved words blocked: `admin`, `support`, `VYBIN`, `system`, etc.

### 3.3 User Discovery Flow

1. User opens "New Chat" screen.
2. Types a username into a search field.
3. App queries Firestore's `usernames` collection for an exact match.
4. If found, shows the user's display name, profile photo, and a "Message" button.
5. Tapping "Message" creates or opens a chat conversation with that user.
6. No partial-match / autocomplete search in MVP (privacy-preserving; you must know the exact username).

### 3.4 User Profile Fields

Every registered user has:
- `uid` — Firebase Auth UID (internal, not shown to users)
- `username` — unique handle (shown and searchable)
- `displayName` — full name chosen at signup (editable)
- `email` — private, used only for auth
- `profilePhotoUrl` — Firebase Storage URL (nullable; uses generated avatar if null)
- `publicKey` — RSA/EC public key in PEM format (stored openly in Firestore)
- `fcmToken` — current push notification token (updated on each app open)
- `onlineStatus` — `online` | `offline`
- `lastSeen` — Firestore Timestamp (shown as "last seen X ago" when offline)

---

## 4. Encryption Architecture

### 4.1 Philosophy

The goal is that **no plaintext message content ever exists on the server**. A viewer with full Firestore read access should see only encrypted blobs and metadata (timestamps, sender UID, message type). Message content — text, filenames, captions — must all be encrypted.

This is not Signal Protocol-level forward secrecy in the MVP, but it is a legitimate, correct end-to-end encryption scheme using well-established asymmetric + symmetric cryptography.

### 4.2 Algorithm Choices

| Purpose | Algorithm | Library |
|---|---|---|
| Key pair generation | RSA-2048 or ECDH P-256 | `pointycastle` (Dart) |
| Message encryption | AES-256-GCM | `pointycastle` |
| Key encapsulation | RSA-OAEP or ECDH key exchange | `pointycastle` |
| Private key storage encryption | AES-256-GCM (key from PBKDF2) | `pointycastle` |
| Password-based key derivation | PBKDF2-HMAC-SHA256 | `pointycastle` |

**Recommended starting point for MVP simplicity:** RSA-2048 with OAEP padding for key encapsulation + AES-256-GCM for message body. This is simpler to implement correctly than ECDH and straightforward to audit.

### 4.3 Key Generation & Storage (On Signup)

```
SIGNUP FLOW (crypto steps):
1. User enters email, password, username, display name.
2. Firebase Auth creates account → returns UID.
3. App generates RSA-2048 key pair (on device, never sent to server as plaintext).
4. Derive a 256-bit key from user's password using PBKDF2:
     derivedKey = PBKDF2(password, salt=uid, iterations=100_000, hmac=SHA256, keylen=32)
5. Encrypt private key with AES-256-GCM using derivedKey:
     encryptedPrivKey = AES_GCM_Encrypt(privateKeyPEM, key=derivedKey, iv=random_12bytes)
6. Store encryptedPrivKey in flutter_secure_storage (Android Keystore-backed).
7. Store publicKeyPEM in Firestore: users/{uid}/publicKey
8. Store PBKDF2 salt (=uid) — it's public, that's fine.
```

**Why this works even without remembering the derived key?**  
On every login, step 4 is repeated: derive the same key from password + uid, then decrypt the private key from secure storage. The private key is held in memory only during the app session.

### 4.4 Sending a Message (Encryption Flow)

```
SEND MESSAGE (Alice → Bob):

1. Alice types a message.
2. App fetches Bob's publicKey from Firestore (cached locally after first fetch).
3. Generate a random 256-bit AES session key (per-message).
4. Encrypt the message text:
     ciphertextMsg = AES_GCM_Encrypt(plaintext, key=sessionKey, iv=random_12bytes)
5. Encrypt the session key with Bob's public RSA key (OAEP):
     encryptedKeyForBob = RSA_OAEP_Encrypt(sessionKey, key=Bob.publicKey)
6. Also encrypt the session key with Alice's own public key (so Alice can read her sent messages):
     encryptedKeyForAlice = RSA_OAEP_Encrypt(sessionKey, key=Alice.publicKey)
7. Write to Firestore:
     {
       senderUid: Alice.uid,
       timestamp: serverTimestamp,
       type: "text",
       iv: base64(iv),
       ciphertext: base64(ciphertextMsg),
       encryptedKeys: {
         [Bob.uid]: base64(encryptedKeyForBob),
         [Alice.uid]: base64(encryptedKeyForAlice)
       }
     }
```

### 4.5 Receiving a Message (Decryption Flow)

```
RECEIVE MESSAGE (Bob receives from Alice):

1. New Firestore document arrives via real-time listener.
2. Bob retrieves encryptedKeys[Bob.uid] from the document.
3. Decrypt the session key using Bob's private RSA key:
     sessionKey = RSA_OAEP_Decrypt(encryptedKeys[Bob.uid], key=Bob.privateKey)
4. Decrypt the message:
     plaintext = AES_GCM_Decrypt(ciphertext, key=sessionKey, iv=document.iv)
5. Display plaintext in the chat bubble.
6. Plaintext is never written back to Firestore — it exists only in app memory.
```

### 4.6 Media Encryption

For images, voice notes, and documents:

```
SEND MEDIA:
1. Generate a random 256-bit AES session key.
2. Encrypt the file bytes with AES-256-GCM.
3. Upload encrypted bytes to Firebase Storage (NOT the original file).
4. Store the download URL + encrypted session key in the Firestore message document
   (same encryptedKeys structure as text messages, but ciphertext = encrypted file bytes at URL).
5. The Firestore message doc stores: storageUrl, encryptedKeys, iv, type, and optionally
   an encryptedCaption (same AES key, separate IV).

RECEIVE MEDIA:
1. Decrypt the session key from encryptedKeys[receiver.uid] using private RSA key.
2. Download encrypted bytes from storageUrl.
3. Decrypt bytes in memory with sessionKey + iv.
4. Display the image / play voice note from decrypted in-memory bytes.
5. Optionally cache decrypted file to local device storage (not uploaded back).
```

### 4.7 Encryption Caveats & Honest Scope

The following are known limitations acceptable for MVP/academic scope:

- **No forward secrecy**: A single key pair per user. Compromise of private key compromises all historical messages. (Signal uses Double Ratchet for forward secrecy — out of MVP scope.)
- **No key verification**: There is no fingerprint/safety number screen to verify you're talking to the right person (prevents MITM via server-side public key replacement). Post-MVP feature.
- **Private key backed by password**: If a user forgets their password, their chat history is unrecoverable. This is a feature, not a bug — it means no server-side key escrow.
- **Per-message key encapsulation**: Each message has its own AES key wrapped for both sender and recipient. This is slightly redundant but correct, simple, and auditable.

---

## 5. Authentication Flows

### 5.1 Sign Up Flow

```
Screen: SignUpScreen
Fields:
  - Display Name (text, 2–50 chars)
  - Username (@handle, 3–20 chars, alphanumeric + underscore)
  - Email (validated email format)
  - Password (min 8 chars, at least 1 number)
  - Confirm Password

Validation (before Firebase call):
  1. All fields non-empty.
  2. Username matches regex: ^[a-z0-9_]{3,20}$
  3. Email format valid.
  4. Password strength met.
  5. Passwords match.

On Submit:
  1. Check Firestore usernames/{username} — if exists → "Username taken" error.
  2. Call Firebase Auth createUserWithEmailAndPassword.
  3. On Auth success:
     a. Run crypto key generation (step 4.3).
     b. Write Firestore documents:
        - users/{uid}: { uid, username, displayName, email, publicKey, createdAt, onlineStatus: "offline" }
        - usernames/{username}: { uid }   ← for uniqueness + reverse lookup
  4. Navigate to HomeScreen (chat list).

Error States:
  - "Username already taken" (Firestore check failed)
  - "Email already in use" (Firebase Auth error)
  - "Weak password" (Firebase Auth error)
  - "Network error" (generic retry prompt)
```

### 5.2 Login Flow

```
Screen: LoginScreen
Fields:
  - Email
  - Password

On Submit:
  1. Firebase Auth signInWithEmailAndPassword.
  2. On Auth success:
     a. Re-derive AES key from password + uid (PBKDF2).
     b. Decrypt private key from flutter_secure_storage.
     c. Hold decrypted private key in memory (EncryptionService singleton).
     d. Update Firestore users/{uid}: { onlineStatus: "online", fcmToken: current_token }.
  3. Navigate to HomeScreen.

Error States:
  - "Invalid email or password" (never specify which is wrong — security best practice)
  - "Too many attempts, try again later" (Firebase rate limiting)
  - "Network error"

First-time login on new device:
  - If flutter_secure_storage has no private key for this uid:
    → Show "New Device Detected" screen
    → Explain that the private key is tied to this device and encrypted with their password
    → Prompt re-entry of password to re-derive decryption key
    → If they previously set up on another device, they cannot access old messages (honest UX)
    → Generate new key pair for this device going forward
    → Update publicKey in Firestore (old messages from old device become inaccessible — acceptable for MVP)
```

### 5.3 Password Reset Flow

```
Screen: ForgotPasswordScreen
Field: Email

On Submit:
  1. Firebase Auth sendPasswordResetEmail.
  2. Show: "Check your inbox. A reset link has been sent."

CRITICAL WARNING displayed on this screen:
  "⚠️ Resetting your password will make your existing chat history permanently unreadable,
   because your messages are encrypted with a key derived from your current password.
   Only reset if you are okay with losing access to previous conversations."

After password reset:
  - On next login, re-derivation with new password will fail to decrypt old private key.
  - App detects this, clears old secure storage entry.
  - Generates new key pair.
  - New messages work normally; old messages are inaccessible (expected, communicated to user).
```

### 5.4 Logout Flow

```
On Logout:
  1. Update Firestore users/{uid}: { onlineStatus: "offline", lastSeen: serverTimestamp() }.
  2. Clear in-memory private key from EncryptionService.
  3. Do NOT clear flutter_secure_storage (so re-login on same device works without re-deriving).
  4. Firebase Auth signOut.
  5. Navigate to LoginScreen.
```

---

## 6. Core Feature Specifications

### 6.1 Chat List (Home Screen)

- Shows all conversations the current user is part of, sorted by most recent message timestamp (descending).
- Each list item shows:
  - Contact's profile photo (circular avatar, fallback to initials-based generated avatar)
  - Contact's display name
  - Last message preview (decrypted locally, truncated to ~40 chars)
  - Last message timestamp (today: show time "3:45 PM"; older: show date "Jun 22")
  - Unread message count badge (green pill, like WhatsApp)
  - Delivery status icon (for messages sent by current user): single grey tick (sent), double grey tick (delivered), double blue tick (read)
- Tapping an item opens ChatScreen.
- Long-press on an item shows: "Archive", "Mute", "Delete Chat" options (Archive and Mute are UI-only stubs in MVP if not implemented; Delete Chat should work).

**How last message preview works with encryption:**  
The chat list document in Firestore stores the last message in its fully encrypted form (same structure as a regular message). When the app loads the chat list, it decrypts the last message for each conversation using the local private key to generate the preview. This decryption happens on the device — Firestore never stores plaintext previews.

### 6.2 Chat Screen

**Header:**
- Back arrow
- Contact's circular avatar
- Contact's display name (tappable → opens Contact Profile screen)
- Online status: "online" (green dot) or "last seen X ago" (grey text)
- Icons: More options (⋮)

**Message List:**
- Messages displayed in chronological order (oldest at top, newest at bottom).
- Auto-scrolls to bottom on new message.
- Sent messages: right-aligned, green bubble (WhatsApp green: `#DCF8C6`).
- Received messages: left-aligned, white bubble.
- Each bubble contains:
  - Decrypted message content (text, image thumbnail, voice note player, file name)
  - Timestamp (bottom right of bubble, grey small text)
  - Delivery status icon (bottom right, for sent messages only)
- Messages are grouped by date — a date separator label ("Today", "Yesterday", "June 22") appears between groups.
- Tapping a message: shows "Copy", "Delete for Me", "Delete for Everyone" (Delete for Everyone only within 60 minutes of sending and only if message is yours).
- Images: tappable → opens full-screen image viewer.
- Voice notes: show a waveform-style progress bar with play/pause button + duration.
- Documents: show a file icon + filename + size.

**Message Input Bar:**
- Attachment icon (📎) → opens modal bottom sheet: "Image", "Document", "Voice Note" options.
- Text input field (hint: "Message") — multi-line, expands up to 5 lines before scrolling.
- When text is empty: shows camera icon and microphone icon (hold mic to record voice note).
- When text is present: shows Send button (green circle with white arrow icon).
- Emoji button (opens system emoji keyboard).

**Voice Note Recording:**
- Long-press on microphone icon begins recording.
- Visual feedback: waveform animation + red recording dot + timer.
- Release to send, swipe left to cancel.
- Maximum duration: 5 minutes (MVP).

### 6.3 New Chat / User Search Screen

```
Screen: NewChatScreen

Header: "New Chat" + X (close)

Search field: "Search by username..."

Behavior:
- Input is trimmed and lowercased before querying.
- On submit / search button tap:
  - Query Firestore: usernames/{input} → get uid.
  - If found: fetch users/{uid} → show profile card.
  - If not found: show "No user found with that username."
- Profile card shows: avatar, display name, @username, "Message" button.
- Tapping "Message":
  - Check if a conversation already exists between current user and found user.
  - If yes: open existing ChatScreen.
  - If no: create new conversation document in Firestore (see data model), open ChatScreen.
```

### 6.4 Profile Screen (Own)

- Accessible from the chat list header (avatar icon) or Settings.
- Shows: profile photo (tappable to change), display name, username, "About" bio (editable, default "Hey there! I am using VYBIN"), email (read-only, greyed out).
- Edit icon next to display name and about.
- Profile photo change: opens image picker → uploads to Firebase Storage → updates Firestore.

### 6.5 Contact Profile Screen

- Opens when tapping a contact's name/avatar in ChatScreen or anywhere a contact is shown.
- Shows: profile photo, display name, @username, about bio, "Message" button, "Block" option (MVP stub — adds to blocked list but enforcement is basic).

### 6.6 Message Delivery Status

```
Status flow for a sent message:

1. SENDING: Message written to Firestore with status = "sent"
   Display: Single grey tick (✓)

2. DELIVERED: When recipient's device reads the document from Firestore
   (Firestore real-time listener fires on their device)
   → Recipient's app updates message document: deliveredAt = serverTimestamp()
   Display: Double grey tick (✓✓)

3. READ: When recipient opens the ChatScreen and scrolls to / sees the message
   → Recipient's app updates message document: readAt = serverTimestamp()
   Display: Double blue tick (✓✓ in blue)
```

### 6.7 Online/Last Seen Status

- When app enters foreground: update `users/{uid}.onlineStatus = "online"`.
- When app goes to background: update `users/{uid}.onlineStatus = "offline"`, `lastSeen = serverTimestamp()`.
- Use `WidgetsBindingObserver` lifecycle hooks in Flutter.
- In Chat header: if contact is `online`, show "online" in green. If offline, show "last seen [time]".
- Time formatting:
  - Within last hour: "last seen X minutes ago"
  - Today: "last seen today at 3:45 PM"
  - Yesterday: "last seen yesterday at 9:20 AM"
  - Older: "last seen Jun 22 at 11:00 AM"

---

## 7. Data Models & Firestore Schema

### 7.1 Collections Overview

```
Firestore Root
├── users/                      ← user profiles + public keys
│   └── {uid}/
│       ├── (fields)
│       └── (no subcollections in MVP)
│
├── usernames/                  ← username → uid mapping (for uniqueness + lookup)
│   └── {username}/
│       └── (fields)
│
└── conversations/              ← chat conversations + messages
    └── {conversationId}/
        ├── (fields)
        └── messages/           ← subcollection of encrypted message documents
            └── {messageId}/
                └── (fields)
```

### 7.2 `users/{uid}` Document

```json
{
  "uid": "string — Firebase Auth UID",
  "username": "string — unique handle, e.g. 'john_doe'",
  "displayName": "string — full name, e.g. 'John Doe'",
  "email": "string — private, not shown to other users",
  "profilePhotoUrl": "string | null — Firebase Storage URL",
  "publicKey": "string — RSA public key in PEM format",
  "fcmToken": "string | null — Firebase Cloud Messaging device token",
  "onlineStatus": "string — 'online' | 'offline'",
  "lastSeen": "Timestamp",
  "about": "string — user bio, default 'Hey there! I am using VYBIN'",
  "createdAt": "Timestamp",
  "blockedUids": ["string"] 
}
```

### 7.3 `usernames/{username}` Document

```json
{
  "uid": "string — the uid of the user who owns this username",
  "createdAt": "Timestamp"
}
```

*Purpose: Atomic uniqueness check. When a new user picks a username, the app first checks if this document exists. If not, it creates it as part of a Firestore transaction alongside the user document.*

### 7.4 `conversations/{conversationId}` Document

The `conversationId` is deterministically generated as the two participant UIDs sorted alphabetically and joined with `_`:
```
conversationId = [uid1, uid2].sort().join('_')
```
This ensures that Alice-Bob and Bob-Alice produce the same conversation ID, preventing duplicate conversations.

```json
{
  "conversationId": "string",
  "participantUids": ["string", "string"],
  "createdAt": "Timestamp",
  "lastMessageAt": "Timestamp",
  "lastMessagePreview": {
    "senderUid": "string",
    "type": "string — 'text' | 'image' | 'voice' | 'document'",
    "iv": "string — base64",
    "ciphertext": "string — base64 (encrypted last message text, or '[Photo]', '[Voice Note]' etc.)",
    "encryptedKeys": {
      "{uid1}": "string — base64 encrypted AES key",
      "{uid2}": "string — base64 encrypted AES key"
    }
  },
  "unreadCount": {
    "{uid1}": 0,
    "{uid2}": 3
  },
  "mutedBy": ["string — uids who have muted this conversation"],
  "deletedBy": ["string — uids who have deleted this conversation from their view"]
}
```

### 7.5 `conversations/{conversationId}/messages/{messageId}` Document

```json
{
  "messageId": "string — Firestore auto-ID",
  "senderUid": "string",
  "timestamp": "Timestamp — serverTimestamp()",
  "type": "string — 'text' | 'image' | 'voice' | 'document'",

  "iv": "string — base64(12-byte GCM nonce)",
  "ciphertext": "string — base64(AES-256-GCM encrypted content)",

  "encryptedKeys": {
    "{recipientUid}": "string — base64(RSA-OAEP encrypted AES session key)",
    "{senderUid}": "string — base64(RSA-OAEP encrypted AES session key for sender's own copy)"
  },

  "status": "string — 'sent' | 'delivered' | 'read' | 'failed'",
  "deliveredAt": "Timestamp | null",
  "readAt": "Timestamp | null",

  "mediaUrl": "string | null — Firebase Storage URL for encrypted media blob (for image/voice/document types)",
  "mediaIv": "string | null — separate IV for encrypted media file",
  "mediaEncryptedKeys": {
    "{recipientUid}": "string | null",
    "{senderUid}": "string | null"
  },
  "mediaSize": "number | null — bytes",
  "mediaMimeType": "string | null — e.g. 'image/jpeg', 'audio/aac', 'application/pdf'",
  "mediaOriginalFilename": "string | null — encrypted original filename stored in ciphertext field for document type",

  "deletedFor": ["string — uids who deleted this message for themselves"],
  "deletedForEveryone": "boolean — default false",
  "deletedForEveryoneAt": "Timestamp | null"
}
```

---

## 8. UI/UX Design System

### 8.1 Design Philosophy

The VYBIN UI must feel like WhatsApp. Users should need zero learning curve. This means:

- Color palette matches WhatsApp: teal header (`#075E54`), light teal action bar (`#128C7E`), incoming message white (`#FFFFFF`), outgoing message green (`#DCF8C6`), background subtle grey (`#ECE5DD`).
- Typography: system font (Roboto on Android) — WhatsApp does not use custom fonts.
- Icons: Use Material Icons that match WhatsApp's iconography style.
- Spacing, padding, and component proportions should match WhatsApp's feel.

### 8.2 Color Palette

```
Primary Dark (Header/AppBar):    #075E54
Primary (Action Color):          #128C7E
Accent (FAB, Send Button):       #25D366
Chat Background:                 #ECE5DD
Sent Message Bubble:             #DCF8C6
Received Message Bubble:         #FFFFFF
Timestamp / Status Text:         #667781
Unread Badge:                    #25D366
Blue Tick (Read):                #34B7F1
Dividers / Input BG:             #F0F0F0
Error / Destructive:             #D32F2F
White Text (on Primary):         #FFFFFF
Dark Text (primary):             #111B21
Secondary Text:                  #667781
```

### 8.3 Typography

```dart
// All Roboto — system default on Android
TextStyle headline1 = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF111B21));
TextStyle subtitle1 = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111B21));
TextStyle body1 = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF111B21));
TextStyle body2 = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF667781));
TextStyle caption = TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF667781));
TextStyle messageText = TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Color(0xFF111B21));
```

### 8.4 Component Specifications

**AppBar (Chat List):**
- Background: `#075E54`
- Title: "VYBIN" in white, font weight 600
- Right icons: Search icon (white), More options (⋮) (white)
- Elevation: 0 (flat, like WhatsApp)

**AppBar (Chat Screen):**
- Background: `#075E54`
- Leading: back arrow + avatar (circular, 35px) + contact name + status (stacked vertically)
- Right icons: More options (all white)

**Chat Bubble:**
- Border radius: 8px (with 0 on one corner to indicate direction, like WhatsApp)
- Sent: top-right corner pointed (achieved with CustomPainter or BoxDecoration with specific radii)
- Received: top-left corner pointed
- Padding: 8px horizontal, 6px vertical inside bubble
- Shadow: subtle `BoxShadow(blurRadius: 1, color: rgba(0,0,0,0.13))`

**Message Input Bar:**
- Background: `#FFFFFF`
- Border: none (divider at top: 1px `#E0E0E0`)
- TextField background: `#F0F0F0`, border-radius: 24px
- Send button: circular, background `#25D366`, white icon, 48px diameter

**FAB (New Chat):**
- Background: `#25D366`
- Icon: Chat bubble with plus, white
- Position: bottom-right, 16px margin

**Avatar fallback:**
- When no photo: circular container with contact's initials, background color derived from hashing the display name (consistent color per user).

### 8.5 Navigation Structure

```
App Entry
└── SplashScreen (check auth state)
    ├── [Not logged in] → LoginScreen
    │   ├── → SignUpScreen
    │   └── → ForgotPasswordScreen
    └── [Logged in] → MainScreen (Scaffold with bottom tabs or top tabs)
        ├── Tab 0: ChatListScreen (default)
        ├── Tab 1: ProfileScreen (with personal information)
        
        
From ChatListScreen:
    ├── ChatScreen (on tap a conversation)
    │   └── ContactProfileScreen (on tap contact name)
    ├── NewChatScreen (on FAB tap)
    └── OwnProfileScreen (on avatar tap in AppBar)
    
From any screen:
    └── SettingsScreen (from ⋮ menu > Settings)
        ├── AccountScreen (email, privacy settings)
        └── NotificationsScreen (notification preferences)
```

---

## 9. Screen-by-Screen Specification

### 9.1 SplashScreen

- Shows VYBIN logo (a lock icon inside a chat bubble — reinforcing encryption brand) centered on white background.
- Waits for Firebase Auth state check.
- Checks if `flutter_secure_storage` has a private key for current uid.
- Routes to either `LoginScreen` or `ChatListScreen`.
- Duration: no artificial delay — appears and routes as soon as state is known.

### 9.2 LoginScreen

**Layout:**
- Top 1/3: VYBIN logo + tagline "Private. Simple. Yours."
- Middle: Email field, Password field (with show/hide toggle)
- "Forgot Password?" link (right-aligned, below password field)
- "Log In" button (full width, green `#25D366`, white text, rounded corners 8px)
- Divider with "OR"
- "Create Account" link (centered, teal color)
- Bottom: small "Your messages are end-to-end encrypted 🔒" note in grey caption text

**Behavior:**
- Show loading spinner inside "Log In" button while Firebase call is in progress.
- Disable all inputs while loading.
- Show SnackBar with error message on failure.

### 9.3 SignUpScreen

**Layout:**
- "Create Account" header
- Profile photo picker (circular avatar, camera icon overlay, optional — user can skip)
- Display Name field
- Username field (with @ prefix visual and live validation indicator: green ✓ or red ✗ based on format check; server-side uniqueness check triggered on field blur or submit)
- Email field
- Password field (with strength indicator: Weak/Fair/Strong)
- Confirm Password field
- "Create Account" button (full width, green, loading state while processing)
- "Already have an account? Log In" link at bottom

**Username field UX:**
- Real-time format validation (no server call, just regex).
- After user stops typing for 800ms (debounce): check Firestore `usernames/{value}` for availability.
- Show: "Checking availability..." → "✓ Available" (green) or "✗ Already taken" (red).

### 9.4 ChatListScreen

**Layout:**
- AppBar as described in 8.4.
- Search bar (below AppBar, collapsed by default, expands when search icon tapped — searches by contact display name or username within existing conversations).
- ListView of conversation items (see 6.1 spec).
- FAB (bottom right) for New Chat.
- Empty state (when no conversations): centered illustration + "No conversations yet" + "Tap the button below to start chatting" text.

**Conversation Item Layout (height ~72px):**
```
[Avatar 50px] | [Display Name (bold)]  [Timestamp]
               | [Last message preview (grey)] [Unread badge / Tick]
```

### 9.5 ChatScreen

**Layout:**
- AppBar (see 8.4).
- Background: wallpaper pattern (`#ECE5DD` with subtle repeating leaf/pattern, like WhatsApp — optional: can use solid `#ECE5DD`).
- Message list (ScrollView, reversed for bottom-up display).
- Date separators between message groups.
- Bottom input bar (attached above keyboard, uses `resizeToAvoidBottomInset: true`).

**Performance note:** Use `ListView.builder` with reverse: true. Load messages in paginated chunks of 30 via `limit()` in Firestore query, with a "Load more" trigger at the top of the list.

**Empty state:** "Messages are end-to-end encrypted. No one outside of this chat can read them 🔒" — centered grey text, shown when no messages yet.

### 9.6 NewChatScreen

Already specified in 6.3. Additional note:
- Header "New Chat" with close (X) button.
- No list of contacts shown by default (privacy-preserving — you only see users you explicitly search for).
- After search result shown: tapping "Message" creates conversation if needed and pushes `ChatScreen`.

### 9.7 OwnProfileScreen

**Layout:**
- Large profile photo at top (tappable to change, full width background that blurs into content).
- Display name with edit pencil icon.
- Username shown (read-only, with lock icon to indicate non-editable in MVP, with note "Username cannot be changed").
- About/Bio field (editable, max 139 chars — WhatsApp convention).
- Email (greyed out, read-only).
- Save button (only visible when changes are unsaved).

### 9.8 SettingsScreen

**Sections (ListTile groups):**
- Account: Privacy, Security, Change Password
- Chats: Theme (light/dark — MVP stub), Chat Backup (stub)
- Notifications: Message notifications toggle, Sound/Vibration
- Storage and Data: (stub)
- Help: About VYBIN, Licenses
- Log Out (red text at bottom)

---

## 10. Firebase Security Rules

These rules are critical. They enforce that users can only read/write their own data and only read public keys of other users.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users: own user doc readable by self only (except public fields)
    // Public key must be readable by anyone (needed for encryption)
    match /users/{uid} {
      allow read: if request.auth != null;  
      // Allow read of all users (for contact profile viewing, public key fetching)
      // In post-MVP: restrict to only return publicKey + displayName + profilePhotoUrl + username to others
      
      allow create: if request.auth != null && request.auth.uid == uid;
      allow update: if request.auth != null && request.auth.uid == uid;
      allow delete: if false;  // No user deletion in MVP
    }

    // Usernames: readable by anyone (for search), writable only by owner
    match /usernames/{username} {
      allow read: if request.auth != null;
      allow create: if request.auth != null 
                    && request.resource.data.uid == request.auth.uid
                    && username.matches('^[a-z0-9_]{3,20}$');
      allow update, delete: if false;  // Usernames are permanent in MVP
    }

    // Conversations: only participants can read/write
    match /conversations/{conversationId} {
      allow read, write: if request.auth != null 
                         && request.auth.uid in resource.data.participantUids;
      allow create: if request.auth != null
                    && request.auth.uid in request.resource.data.participantUids
                    && request.resource.data.participantUids.size() == 2;

      // Messages subcollection: only participants of the conversation
      match /messages/{messageId} {
        allow read: if request.auth != null
                    && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantUids;
        
        allow create: if request.auth != null
                      && request.auth.uid == request.resource.data.senderUid
                      && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantUids;
        
        allow update: if request.auth != null
                      && request.auth.uid in get(/databases/$(database)/documents/conversations/$(conversationId)).data.participantUids
                      && (
                        // Sender can delete for everyone within 60 min
                        (request.auth.uid == resource.data.senderUid 
                          && request.resource.data.deletedForEveryone == true
                          && resource.data.timestamp > request.time - duration.value(3600, 's'))
                        ||
                        // Either participant can update delivery/read status
                        request.resource.data.diff(resource.data).affectedKeys()
                          .hasOnly(['status', 'deliveredAt', 'readAt', 'deletedFor'])
                      );
        
        allow delete: if false;  // Soft-delete only via deletedFor/deletedForEveryone fields
      }
    }
  }
}
```

---

## 11. Cloud Functions

Minimal Cloud Functions needed for MVP:

### 11.1 `onMessageCreated` — Push Notification Trigger

```javascript
// Triggered when a new message document is created in any conversation's messages subcollection
exports.onMessageCreated = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const { conversationId } = context.params;

    // Get conversation to find recipient
    const convDoc = await admin.firestore()
      .doc(`conversations/${conversationId}`).get();
    const participants = convDoc.data().participantUids;
    const recipientUid = participants.find(uid => uid !== message.senderUid);

    // Get recipient's FCM token
    const recipientDoc = await admin.firestore()
      .doc(`users/${recipientUid}`).get();
    const fcmToken = recipientDoc.data().fcmToken;
    
    if (!fcmToken) return null;

    // Get sender's display name
    const senderDoc = await admin.firestore()
      .doc(`users/${message.senderUid}`).get();
    const senderName = senderDoc.data().displayName;

    // CRITICAL: Do NOT include message content in push notification
    // Message is encrypted — we can't decrypt it here, and we shouldn't try
    const notificationBody = message.type === 'text' 
      ? '🔒 New encrypted message' 
      : message.type === 'image' ? '📷 Photo'
      : message.type === 'voice' ? '🎤 Voice note'
      : '📎 Document';

    const payload = {
      notification: {
        title: senderName,
        body: notificationBody,
        // No preview of content — privacy by design
      },
      data: {
        conversationId: conversationId,
        senderUid: message.senderUid,
        type: 'new_message',
      },
      token: fcmToken,
    };

    return admin.messaging().send(payload);
  });
```

### 11.2 `updateLastSeen` — Optional Cleanup (Post-MVP)

Not required for MVP; online/last seen is handled directly from the client app using `WidgetsBindingObserver`.

---

## 12. Push Notifications

### 12.1 Setup

- Use `firebase_messaging` Flutter package.
- Request notification permission on first launch (Android 13+ requires explicit permission).
- On permission granted: get FCM token, store in `users/{uid}.fcmToken`.
- Refresh token listener: update Firestore whenever token refreshes.

### 12.2 Notification Handling

**App in foreground:**  
- Suppress system notification (already in the app, show an in-app snackbar or auto-update the chat list via real-time listener — no notification needed).

**App in background:**  
- System notification appears: Sender name as title, "🔒 New encrypted message" as body.
- Tapping notification → opens app → navigates to the relevant ChatScreen.
- Use `conversationId` from notification data payload to route correctly.

**App terminated:**  
- Same as background — FCM background message handler routes on app open.

### 12.3 Privacy Design

Notification body never contains message content. This is intentional and should be communicated to users as a feature: "Notifications only show who messaged you — never what they said."

---

## 13. Offline & Sync Behavior

### 13.1 Firebase Offline Persistence

Enable Firestore offline persistence:
```dart
FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
```

This means:
- Messages already loaded are accessible offline.
- Messages sent while offline are queued and automatically synced when connectivity resumes.
- Chat list loads from cache when offline (may be slightly stale — acceptable).

### 13.2 Message Send States

- On send attempt: message is written to local Firestore cache immediately (appears in UI with single grey tick + clock icon indicating "pending").
- When online: Firestore syncs the queued write to server (tick changes to sent).
- If send fails after retries (e.g. persistent network failure): show "!" icon on the message with a "Retry" tap option.

### 13.3 Connectivity Indicator

Show a thin yellow banner at the top of ChatScreen when offline: "Connecting..." — dismisses automatically when connection restored. Do not block the UI.

---

## 14. Media Handling

### 14.1 Image Sending

1. User taps attachment → "Photo" → opens image picker (`image_picker` package).
2. User selects or captures image.
3. Image is compressed before encryption (using `flutter_image_compress` — reduce quality to 85%, max dimension 1920px to keep file size manageable).
4. Encrypt compressed image bytes with AES-256-GCM (per section 4.6).
5. Upload encrypted bytes to Firebase Storage path: `media/{conversationId}/{messageId}.enc`.
6. Write message document to Firestore with `type: "image"`, `mediaUrl`, `mediaIv`, `mediaEncryptedKeys`.
7. In ChatScreen: show a "loading" thumbnail placeholder while message is sending. After upload complete, show the decrypted thumbnail.

**Thumbnail generation (MVP simplification):**  
Generate a tiny 8x8 pixel blurred thumbnail of the image (like WhatsApp's blur-load technique), encode it as base64 (< 200 bytes), and store it directly in the Firestore message document as `thumbnailBase64`. This thumbnail is NOT encrypted (it's so blurred it reveals nothing). It allows instant display of a placeholder while the full encrypted image downloads.

### 14.2 Voice Note Recording & Sending

1. User long-presses mic button.
2. App records using `record` Flutter package → saves to temp file as AAC format.
3. On release: stop recording, read temp file bytes.
4. Encrypt bytes with AES-256-GCM.
5. Upload to Firebase Storage: `media/{conversationId}/{messageId}_voice.enc`.
6. Write message document with `type: "voice"`, `mediaUrl`, duration (store in non-encrypted metadata field `mediaDuration` as integer seconds — duration itself is not sensitive).

**Playback:**
1. Download encrypted bytes from Storage.
2. Decrypt in memory.
3. Write decrypted bytes to a temp file.
4. Play using `just_audio` Flutter package from temp file.
5. Delete temp file after playback or when leaving the chat.

### 14.3 Document Sending

1. User taps attachment → "Document" → opens file picker (`file_picker` package).
2. File size check: max 100MB (Firebase Storage free tier consideration — reduce to 25MB for MVP to be safe).
3. Encrypt file bytes with AES-256-GCM.
4. Upload encrypted bytes to Firebase Storage.
5. Firestore message document: `type: "document"`, `ciphertext: base64(AES_encrypt(originalFilename))` (encrypt filename too — reveals nothing), `mediaMimeType` (store unencrypted — not sensitive), `mediaSize` (unencrypted — not sensitive).

**Viewing documents:**
1. Download and decrypt in memory.
2. Write to temp file with original filename.
3. Open using `open_file` Flutter package (launches system viewer).

---

## 15. Non-Functional Requirements

### 15.1 Performance Targets

- Chat list load time (from cache): < 300ms.
- Message send latency (network call complete): < 1 second on 4G.
- Encryption/decryption time per message: < 50ms (RSA-2048 OAEP is slow; key decryption once per message acceptable; optimize later by caching decrypted session keys in memory per conversation).
- Image upload (compressed, encrypted, 1MB): < 5 seconds on 4G.
- App cold start to ChatListScreen: < 2 seconds.

### 15.2 Security Requirements

- Private key never leaves the device in plaintext form.
- Private key in-memory only during authenticated session; cleared on logout.
- flutter_secure_storage used for encrypted private key persistence — uses Android Keystore.
- PBKDF2 with 100,000 iterations for password-based key derivation.
- AES-256-GCM with random 12-byte IV per message (never reuse IV/nonce).
- No logging of message content (ciphertext logging is acceptable; plaintext logging is not).
- Certificate pinning: optional for MVP, recommended post-MVP.

### 15.3 Error Handling

Every async operation must have:
- A loading state (UI feedback while waiting).
- A success state (update UI with result).
- An error state (clear user-facing error message, option to retry where appropriate).

Specific error messages (never show raw Firebase errors to users):
- Auth errors: mapped to friendly messages ("Wrong password", "Email not found", etc.)
- Network errors: "No internet connection. Please check your network."
- Upload errors: "Failed to send. Tap to retry."
- Encryption errors: "Something went wrong. Please restart the app." (Should not happen in normal use; log to console.)

### 15.4 Accessibility

- All interactive elements have semantic labels for screen readers.
- Color is never the only indicator (always pair color with icon or text).
- Minimum touch target size: 48x48px (Material spec).
- Text sizes respect system font size settings.

---

## 16. Out of Scope (Post-MVP)

These features are NOT to be built in the MVP. If an AI is implementing from this spec, do not add these unless explicitly instructed:

- Group chats (multi-party encryption is significantly more complex).
- WhatsApp Status / Stories.
- Voice and video calling.
- Message reactions (emoji reactions on messages).
- Starred/bookmarked messages.
- Message forwarding.
- Reply-to (quote a specific message — can add in MVP as bonus if time allows).
- Disappearing messages (auto-delete after timer).
- End-to-end encrypted backup to cloud.
- Key verification screen (safety numbers / QR code comparison).
- Biometric lock (fingerprint to unlock app).
- Two-factor authentication for account.
- Change username feature.
- Account deletion.
- Linked devices / multi-device sync.
- WhatsApp-compatible interoperability.
- Dark mode (can add as a bonus feature in MVP if trivial).

---


## 17. Implementation Roadmap (Phased Development)

To guarantee software quality and structural integrity, VYBIN will be built sequentially over three discrete technical phases.

### Phase 1: UI Development (Frontend Archetype)
Focuses purely on building a pixel-perfect, highly responsive Material Design interface mimicking the native feel of modern chat engines. All data layers during this phase will use mocked static entities.
* **Core Architecture:** Configure the foundational Flutter project file hierarchy (`core/`, `features/`, `shared/`). Register dependencies in `pubspec.yaml` (excluding data-sync libraries).
* **Static Views:** Implement the structural design for the `SplashScreen`, `LoginScreen`, `SignUpScreen`, and `ForgotPasswordScreen`.
* **Navigation & Hubs:** Construct the core `ChatListScreen` and the precision username-lookup `NewChatScreen`.
* **Workspace Canvas:** Finalize the 1-on-1 dynamic `ChatScreen` view canvas, including CustomPainters for message chat bubbles, the expanding custom message input bar, and media attachment sheets.

### Phase 2: Semantic Development (Local Logic & Cryptographic Engine)
Focuses on animating the application layout by programming the business logic, state machines, and localized client-side cryptographic systems.
* **State Management:** Implement `flutter_bloc` structures across all visual modules to decouple state mutations from the presentation layers (e.g., AuthBloc, ChatBloc).
* **Cryptographic Core Engine:** Program the `EncryptionService` powered by `pointycastle`. Write localized unit tests to validate RSA-2048 key pair generation and AES-256-GCM symmetric block cipher encryption.
* **Local Secure Hardware Storage:** Implement the `SecureKeyStorage` module mapping to the Android Keystore using `flutter_secure_storage`.
* **Local Media Processing Services:** Integrate semantic mechanisms for recording localized audio files (`record`), compressing selected images (`flutter_image_compress`), and picking document streams.

### Phase 3: Firebase Integration (Live Synchronization & Database Governance)
The final phase hooks the logical frontend state directly to Google Firebase backend architecture, facilitating global real-time synchronization.
* **Data Channel Operations:** Establish connectivity to Firebase Auth, Firestore, and Firebase Storage. Deploy structural Firestore Security Rules to cloud environments.
* **Dynamic Registries:** Bind backend transaction handlers to user discovery flows via the deterministic `conversations` index and atomicity-guaranteed `usernames` mapping.
* **Asynchronous Message Pipeline:** Establish real-time Firestore reactive streams for continuous chat message document parsing, instant transmission, and immediate message receipt/read tick tracking.
* **Remote Blob Operations:** Wire local media processing to Firebase Storage, sending and pulling encrypted media payloads (images, audio, files).
* **Push Notifications:** Configure Firebase Cloud Functions (`onMessageCreated`) alongside `firebase_messaging` to trigger background notifications without exposing plain-text content payloads.
---

## Appendix A: Flutter Folder Structure

```
lib/
├── main.dart
├── app.dart                   ← MaterialApp + router setup
│
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   ├── app_text_styles.dart
│   │   └── app_constants.dart
│   ├── errors/
│   │   └── failures.dart
│   ├── services/
│   │   ├── encryption_service.dart    ← RSA + AES crypto logic
│   │   ├── secure_key_storage.dart    ← flutter_secure_storage wrapper
│   │   └── media_service.dart         ← compress, encrypt, upload media
│   └── utils/
│       ├── date_formatter.dart
│       └── conversation_id_generator.dart
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── bloc/
│   │   │   ├── auth_bloc.dart
│   │   │   ├── auth_event.dart
│   │   │   └── auth_state.dart
│   │   └── presentation/
│   │       ├── login_screen.dart
│   │       ├── signup_screen.dart
│   │       └── forgot_password_screen.dart
│   │
│   ├── chat/
│   │   ├── data/
│   │   │   ├── chat_repository.dart
│   │   │   └── models/
│   │   │       ├── message_model.dart
│   │   │       └── conversation_model.dart
│   │   ├── bloc/
│   │   │   ├── chat_bloc.dart
│   │   │   ├── chat_list_bloc.dart
│   │   │   └── ...
│   │   └── presentation/
│   │       ├── chat_list_screen.dart
│   │       ├── chat_screen.dart
│   │       ├── new_chat_screen.dart
│   │       └── widgets/
│   │           ├── message_bubble.dart
│   │           ├── message_input_bar.dart
│   │           ├── conversation_list_item.dart
│   │           ├── voice_note_player.dart
│   │           └── image_message_widget.dart
│   │
│   └── profile/
│       ├── data/
│       │   └── user_repository.dart
│       ├── bloc/
│       │   └── profile_bloc.dart
│       └── presentation/
│           ├── own_profile_screen.dart
│           ├── contact_profile_screen.dart
│           └── settings_screen.dart
│
└── shared/
    └── widgets/
        ├── loading_button.dart
        ├── user_avatar.dart
        └── status_indicator.dart
```

---

## Appendix B: Key Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase
  firebase_core: ^3.x.x
  firebase_auth: ^5.x.x
  cloud_firestore: ^5.x.x
  firebase_storage: ^12.x.x
  firebase_messaging: ^15.x.x
  cloud_functions: ^5.x.x

  # State Management
  flutter_bloc: ^9.x.x
  equatable: ^2.x.x

  # Cryptography
  pointycastle: ^3.x.x

  # Secure Storage
  flutter_secure_storage: ^9.x.x

  # Navigation
  go_router: ^14.x.x

  # Media
  image_picker: ^1.x.x
  file_picker: ^8.x.x
  record: ^5.x.x
  just_audio: ^0.9.x
  flutter_image_compress: ^2.x.x
  open_file: ^3.x.x

  # UI Utilities
  cached_network_image: ^3.x.x
  intl: ^0.19.x
  flutter_svg: ^2.x.x

  # Utilities
  uuid: ^4.x.x
  rxdart: ^0.28.x
```

---

## Appendix C: Encryption Service — Pseudocode Reference

```dart
class EncryptionService {
  RSAPrivateKey? _privateKey;  // Held in memory only during session

  // Called on signup — run in isolate (heavy computation)
  Future<KeyPair> generateKeyPair() async { ... } // Returns RSAKeyPair

  // Called on signup and login — derive AES key from password for private key encryption
  Uint8List deriveKeyFromPassword(String password, String uid) {
    // PBKDF2(password, salt=uid, iterations=100_000, hmac=SHA256, keyLen=32)
  }

  // Called on signup — encrypt private key for storage
  String encryptPrivateKey(RSAPrivateKey privKey, Uint8List derivedKey) {
    // Serialize privKey to PEM string
    // AES-256-GCM encrypt PEM bytes with derivedKey, random IV
    // Return base64(iv + ciphertext + authTag)
  }

  // Called on login — decrypt private key from storage
  RSAPrivateKey decryptPrivateKey(String encryptedPrivKeyB64, Uint8List derivedKey) {
    // Decode base64, split iv + ciphertext + authTag
    // AES-256-GCM decrypt
    // Parse PEM → RSAPrivateKey
    // Store in _privateKey
  }

  // Called on every message send
  EncryptedMessage encryptMessage(String plaintext, RSAPublicKey recipientPubKey, RSAPublicKey senderPubKey) {
    // 1. Generate random 32-byte AES session key
    // 2. Generate random 12-byte IV
    // 3. ciphertext = AES_GCM_Encrypt(plaintext.utf8, sessionKey, iv)
    // 4. encKeyForRecipient = RSA_OAEP_Encrypt(sessionKey, recipientPubKey)
    // 5. encKeyForSender = RSA_OAEP_Encrypt(sessionKey, senderPubKey)
    // Return EncryptedMessage { iv, ciphertext, encryptedKeys }
  }

  // Called on every message receive
  String decryptMessage(EncryptedMessage msg, String receiverUid) {
    // 1. RSA_OAEP_Decrypt(msg.encryptedKeys[receiverUid], _privateKey) → sessionKey
    // 2. AES_GCM_Decrypt(msg.ciphertext, sessionKey, msg.iv) → plaintext bytes
    // 3. Return utf8.decode(plaintext bytes)
  }

  void clearPrivateKey() { _privateKey = null; }  // Called on logout
}
```

---

*End of VYBIN MVP Specification*
*Version 1.0 — Prepared for: COMSATS University Islamabad, Mobile Application Development Course*
*Team: Muhammad Abdullah (FA23-BCS-051), Abdulahad (FA23-BCS-005), Abdurehman Jadoon (FA23-BCS-006)*
*Submitted to: DR Jawad Khan*
