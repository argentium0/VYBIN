# VYBIN

VYBIN is an offline-first, decentralized, and end-to-end encrypted (E2EE) messaging application built with Flutter. It combines the familiar, responsive UI/UX of WhatsApp with a privacy-first cryptographic backend where no plaintext message ever leaves your device.

<img width="320" height="550" alt="image" src="https://github.com/user-attachments/assets/25e21368-4324-4a67-bef9-c735a7fd84b3" />
<img width="320" height="550" alt="image" src="https://github.com/user-attachments/assets/11db5d0e-d893-4f10-8d3c-a8fc06c36959" />
<img width="320" height="550" alt="image" src="https://github.com/user-attachments/assets/990b0ce2-4fbd-415d-8c50-6c9d49d5588b" />
<img width="320" height="550" alt="image" src="https://github.com/user-attachments/assets/389a1955-6c27-40d2-8cc7-6e75cbb31f80" />

---

## Capabilities & Core Features

VYBIN provides a fully functional, privacy-first messaging architecture featuring:

### Cryptographic Core & Identity Security
* **Client-Side Key Generation**: Generates RSA-2048 keypairs locally. The public key is published for user discovery, while the private key is stored securely on-device.
* **Hybrid Encryption Pipeline**: Combines local AES-256-GCM symmetric block encryption for message contents with RSA key encapsulation for secure distribution of the AES key.
* **PBKDF2 Password Derivation**: Derives an encryption key from the user's account password to encrypt the RSA private key prior to storage.
* **Hardware-Backed Secure Storage**: Saves encrypted private keys using Android Keystore / iOS Keychain via `flutter_secure_storage`.
* **Identity Verification**: Enables safety numbers/fingerprints verification to ensure communication security.
* **Identity Recovery & Migration**: Identity Import Screen allows users to manually import/restore their cryptographic identity using recovery parameters.

### Real-Time Messaging & Statuses
* **Real-time 1-on-1 Chat**: Low-latency message synchronization powered by Firestore snapshot streams.
* **Message Status Receipts**: Visual status ticks for sent, delivered, and read status updates.
* **On-the-Fly Decryption**: Locally decrypts the latest message in the Chat List preview, keeping Firestore unaware of the message content.
* **State Management**: Clean architectural boundaries separation via `flutter_bloc` (`AuthBloc`, `ChatBloc`, `ChatListBloc`).

### Encrypted Media Transmission
* **Photos**: In-app photo picking, image compression, local AES encryption, Firebase Storage transfer, and local decryption.
* **Voice Notes**: Encrypted audio recording, transmission, and playback using device audio frameworks.
* **Videos**: Localized encryption and upload, status-aware downloader (with download progress and error states), and a retry-mechanism for download failures.
* **Documents**: Support for picking, local encryption, downloading, and local opening of PDF documents.

### Push Notifications & Background Sync
* **Metadata-Only Cloud Payloads**: Decentralized notifications via Firebase Cloud Functions where push payloads exclude raw ciphertext.
* **Local Notifications**: Direct-to-system notifications via `flutter_local_notifications` for both foreground and background states.
* **Active Chat Silencing**: Automatically tracks active chats to suppress notifications for the chat currently being viewed.

### Voice Calling & Custom Signaling
* **1-on-1 Voice Calling**: Integrated voice calling capabilities directly from individual chat screens via Zego Cloud.
* **Real-time Custom Signaling**: Utilizes Zego's signaling plugin to send instant peer-to-peer command messages (e.g., new message alerts) directly between devices.
* **Security Notice**: Voice calls are secured in transit but are not End-to-End Encrypted (E2EE) at this time.

### UI/UX Design System
* **Material 3 Design**: High-fidelity interface layouts styled similarly to WhatsApp.
* **Premium Dark Mode**: Custom-tailored Material Design dark theme configurations.
* **User Settings & Profiles**: Dynamic profile screen, account credentials management, and notification settings.

---

## Key Dependencies

* **State Management**: `flutter_bloc`, `equatable`
* **Navigation**: `go_router`
* **Cryptographic Primitives**: `pointycastle`, `flutter_secure_storage`, `crypto`
* **Media & Hardware Support**: `record`, `just_audio`, `flutter_image_compress`, `image_picker`, `file_picker`, `open_file`, `permission_handler`, `path_provider`
* **Real-time & Sync**: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`
* **Voice Calling & Signaling**: `zego_uikit_prebuilt_call`, `zego_uikit_signaling_plugin`
* **Utilities & UI**: `cached_network_image`, `uuid`, `intl`, `share_plus`

---

## Getting Started

### Prerequisites

* Flutter SDK (v3.x.x or higher)
* Android Studio / Xcode (for emulation/testing)

### Installation & Run

1. Clone the repository:
   ```bash
   git clone https://github.com/argentium0/VYBIN.git
   cd VYBIN
   ```

2. Retrieve dependencies:
   ```bash
   flutter pub get
   ```

3. Run the development build on your connected device/emulator:
   ```bash
   flutter run
   ```
