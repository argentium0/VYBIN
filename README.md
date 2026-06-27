# VYBIN

VYBIN is an offline-first, decentralized, and end-to-end encrypted (E2EE) messaging application built with Flutter. It combines the familiar, responsive UI/UX of WhatsApp with a privacy-first cryptographic backend where no plaintext message ever leaves your device.

<img width="320" height="550" alt="image" src="https://github.com/user-attachments/assets/25e21368-4324-4a67-bef9-c735a7fd84b3" />
<img width="320" height="550" alt="image" src="https://github.com/user-attachments/assets/11db5d0e-d893-4f10-8d3c-a8fc06c36959" />
<img width="320" height="550" alt="image" src="https://github.com/user-attachments/assets/990b0ce2-4fbd-415d-8c50-6c9d49d5588b" />



---

## 🚀 Capabilities & Core Features (Phase 1 Baseline)

We have successfully scaffolded and initialized **Phase 1 (UI Development & Local Archetype)** of the application:

*   **GoRouter Navigation Architecture**: Robust shell-based routing structures decoupling routing logic from page trees.
*   **WhatsApp-Inspired High-Fidelity UI Layouts**: 
    *   `SplashScreen` for seamless app entry.
    *   `LoginScreen` and `SignUpScreen` entry gates.
    *   `ChatListScreen` serving as the main communications hub.
    *   `IndividualChatScreen` supporting dynamic message threads.
*   **Dynamic Presentation Components**: Custom chat bubble layouts using Flutter primitives, interactive voice message simulation widgets, and responsive layout scaling.
*   **High-Contrast Dark Theme Presets**: Harmonious and accessibility-minded dark mode design configurations using tailored Material Design tokens.
*   **E2EE-Ready Local Data Models**: Data models (`UserModel`, `MessageModel`, and `ConversationModel`) pre-architected to accommodate RSA public keys, Base64 AES-256-GCM ciphertexts, and GCM IV buffers so that data bindings can transition seamlessly into cryptography without refactoring.

---

## 🛠️ Next Development Stages

Following our technical specification roadmap, we are moving sequentially through the following phases:

### 🟢 Phase 2: Semantic Development (Local Logic & Cryptographic Engine)
*   **State Management Integration**: Establish `flutter_bloc` structures across all feature modules (e.g., `AuthBloc`, `ChatBloc`) to decouple state mutation logic from presentation views.
*   **Cryptographic Core Engine**: Implement the `EncryptionService` using the `pointycastle` library to perform client-side RSA-2048 key generation, AES-256-GCM symmetric block encryption/decryption, and PBKDF2 password-based key derivation.
*   **Local Secure Hardware Storage**: Secure private keys locally using the Android Keystore / iOS Keychain via `flutter_secure_storage`.
*   **Local Media Processing Services**: Wire up localized audio recording, image compression (`flutter_image_compress`), and file picking interfaces.

### 🟡 Phase 3: Firebase Integration (Live Sync & Cloud Governance)
*   **Data Channel Operations**: Bind the local logical states to Firebase Authentication, Cloud Firestore database streams, and Firebase Storage bucket structures.
*   **Real-time Message Pipeline**: Deploy continuous Firestore snapshot listeners for instant message transmission, message state ticks (`sent` / `delivered` / `read`), and automatic remote sync.
*   **Encrypted Remote Blob Storage**: Enable sending, compressing, and downloading E2EE media files.
*   **Decentralized Push Notifications**: Implement Firebase Cloud Functions running metadata-only payloads to trigger background push notifications without exposing raw message contents.

---

## 📦 Key Dependencies

*   **State Management**: `flutter_bloc`, `equatable`
*   **Navigation**: `go_router`
*   **Cryptographic Primitives**: `pointycastle`, `flutter_secure_storage`
*   **Media Support**: `record`, `just_audio`, `flutter_image_compress`, `image_picker`, `file_picker`
*   **Utilities**: `cached_network_image`, `uuid`, `intl`

---

## 🏃 Getting Started

### Prerequisites

*   Flutter SDK (v3.x.x or higher)
*   Android Studio / Xcode (for emulation/testing)

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
