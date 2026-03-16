# MyPwd

[中文版](./README.md)

A local password manager for macOS, built with SwiftUI and using CryptoKit for end-to-end encryption.

## Tech Stack

- **UI Framework**: SwiftUI
- **Encryption**: CryptoKit (AES-GCM encryption)
- **Secure Storage**: Keychain Services
- **Biometrics**: LocalAuthentication (Touch ID/Face ID)
- **Project Generation**: XcodeGen

## Project Architecture

```
MyPwd/
├── project.yml                    # XcodeGen configuration
├── Resources/
│   ├── Info.plist                 # App configuration
│   └── MyPwd.entitlements         # Entitlements
├── Sources/
│   ├── App/
│   │   └── MyPwdApp.swift         # App entry point
│   ├── Models/
│   │   └── PasswordItem.swift     # Password data model
│   ├── Services/
│   │   ├── AuthenticationService.swift       # Biometric authentication
│   │   ├── ConfigService.swift                # App configuration service
│   │   ├── CryptoService.swift               # Encryption/decryption service
│   │   ├── GitService.swift                   # Git sync service
│   │   ├── KeychainServiceWithBiometric.swift # Biometric Keychain
│   │   ├── LocalizationService.swift          # Localization service
│   │   ├── LocalizedStrings.swift             # Localized strings
│   │   ├── PasswordGenerator.swift           # Password generator
│   │   └── PasswordStorageService.swift       # Password storage service
│   └── Views/
│       ├── ContentView.swift         # Root view
│       ├── MainView.swift            # Main interface
│       ├── SetupView.swift           # Initial setup view
│       ├── UnlockView.swift          # Unlock view
│       ├── PasswordDetailView.swift  # Password detail
│       ├── PasswordEditorView.swift  # Password editor
│       └── Components/
│           └── PasswordGeneratorView.swift  # Password generator component
```

### Module Description

| Module | Description |
|--------|-------------|
| **App** | App entry point with `@main` |
| **Models** | Data models, `PasswordItem` defines the password entry structure |
| **Services** | Core service layer including authentication, config, encryption, Git sync, storage, etc. |
| **Views** | SwiftUI view layer for UI interactions |

## Build & Run

### Prerequisites

- macOS 13.0+
- Xcode 15.0+
- XcodeGen (`brew install xcodegen`)

### Build Steps

1. Generate Xcode project:
   ```bash
   cd MyPwd
   xcodegen generate
   ```

2. Open project in Xcode:
   ```bash
   open MyPwd.xcodeproj
   ```

3. Select `MyPwd` scheme and run (Cmd+R)

## Core Features

1. **Master Password Setup** - Set master password on first launch
2. **Password Unlock** - Unlock password vault with master password
3. **Biometric Authentication** - Quick unlock with Touch ID/Face ID
4. **Password Management** - Add, edit, delete password entries
5. **Password Generator** - Built-in password generator
6. **Custom Storage Path** - Support for choosing encrypted database storage location
7. **Git Sync** - Sync password vault to remote Git repository
8. **Internationalization** - Support for Simplified Chinese and English interfaces

## Security Features

- Encryption key stored in Keychain, protected by Touch ID
- Password data encrypted with AES-GCM-256
- Biometric authentication support
