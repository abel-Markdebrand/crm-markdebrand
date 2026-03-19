# Mardebran MVP Odoo

Mardebran is a premium Flutter application designed to integrate seamlessly with Odoo ERP. It provides a modern, robust interface for managing CRM, HR, Recruitment, and VoIP Business communications.

## Key Features

- **Odoo Integration**: Full synchronization with Odoo via RPC, supporting both standard Odoo and custom Prisma servers.
- **VoIP Service**: Integrated SIP/WebRTC softphone for business calls, featuring call history, dialpad, and background reconnection.
- **CRM Module**: Manage leads, opportunities, and sales orders on the go.
- **HR & Recruitment**: Handle employee profiles, attendance, and recruitment pipelines with ease.
- **Modern UI/UX**: Premium design system using Slate color palettes, Nexa typography, and responsive layouts.
- **Biometric Security**: Secure login using device biometrics (Fingerprint/FaceID).

## Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: Provider / ChangeNotifier
- **Networking**: `odoo_rpc`, `http`
- **VoIP**: `sip_ua`, `flutter_webrtc`
- **Persistence**: `shared_preferences`
- **Utilities**: `path_provider`, `url_launcher`, `local_auth`

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code with Flutter extensions
- An active Odoo instance

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   ```
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the application**:
   ```bash
   flutter run
   ```

## Project Structure

- `lib/main.dart`: App entry point and theme configuration.
- `lib/services/`: Core business logic and external integrations (Odoo, VoIP, etc.).
- `lib/models/`: Data models for CRM, HR, and Sales.
- `lib/screens/`: UI implementation for different modules.
- `lib/widgets/`: Reusable UI components.

## Documentation

- **Inline Documentation**: All core services and app logic are documented in English within the source code.
- **Odoo Service**: See `lib/services/odoo_service.dart` for deep communication logic.
- **VoIP Module**: See `lib/services/voip_service.dart` and `lib/services/call_manager.dart`.

---
Developed by **Markdebrand**.
