# MyPwd

[English Version](./README-en.md)

macOS 平台的本地密码管理器，采用 SwiftUI 构建，使用 CryptoKit 进行端到端加密存储。

## 技术栈

- **UI 框架**: SwiftUI
- **加密库**: CryptoKit (AES-GCM 加密)
- **安全存储**: Keychain Services
- **生物识别**: LocalAuthentication (Touch ID/Face ID)
- **项目生成**: XcodeGen

## 项目架构

```
MyPwd/
├── project.yml                    # XcodeGen 配置文件
├── Resources/
│   ├── Info.plist                 # 应用配置
│   └── MyPwd.entitlements         # 权限配置
├── Sources/
│   ├── App/
│   │   └── MyPwdApp.swift         # 应用入口
│   ├── Models/
│   │   └── PasswordItem.swift     # 密码数据模型
│   ├── Services/
│   │   ├── AuthenticationService.swift       # 生物识别认证
│   │   ├── ConfigService.swift                # 应用配置服务
│   │   ├── CryptoService.swift                # 加密/解密服务
│   │   ├── GitService.swift                   # Git 同步服务
│   │   ├── KeychainServiceWithBiometric.swift # 生物识别 Keychain
│   │   ├── LocalizationService.swift          # 本地化服务
│   │   ├── LocalizedStrings.swift             # 本地化字符串
│   │   ├── PasswordGenerator.swift           # 密码生成器
│   │   └── PasswordStorageService.swift       # 密码存储服务
│   └── Views/
│       ├── ContentView.swift         # 根视图
│       ├── MainView.swift            # 主界面
│       ├── SetupView.swift           # 初始设置视图
│       ├── UnlockView.swift          # 解锁视图
│       ├── PasswordDetailView.swift # 密码详情
│       ├── PasswordEditorView.swift  # 密码编辑
│       └── Components/
│           └── PasswordGeneratorView.swift  # 密码生成组件
```

### 模块说明

| 模块 | 描述 |
|------|------|
| **App** | 应用入口，包含 `@main` 入口点 |
| **Models** | 数据模型，`PasswordItem` 定义密码条目结构 |
| **Services** | 核心服务层，包括认证、配置、加密、Git 同步、存储等 |
| **Views** | SwiftUI 视图层，处理 UI 交互 |

## 构建与运行

### 前置条件

- macOS 13.0+
- Xcode 15.0+
- XcodeGen (`brew install xcodegen`)

### 构建步骤

1. 生成 Xcode 项目:
   ```bash
   cd MyPwd
   xcodegen generate
   ```

2. 使用 Xcode 打开项目:
   ```bash
   open MyPwd.xcodeproj
   ```

3. 在 Xcode 中选择 `MyPwd` scheme 并运行 (Cmd+R)

## 核心功能

1. **主密码设置** - 首次启动时设置主密码
2. **密码解锁** - 使用主密码解锁密码库
3. **生物识别** - 支持 Touch ID/Face ID 快速解锁
4. **密码管理** - 添加、编辑、删除密码条目
5. **密码生成** - 内置密码生成器
6. **自定义存储路径** - 支持选择加密数据库的存储位置
7. **Git 同步** - 支持将密码库同步到远程 Git 仓库
8. **国际化** - 支持简体中文和英文界面

## 安全特性

- 加密密钥存储在 Keychain 中，受 Touch ID 保护
- 密码数据使用 AES-GCM-256 加密存储
- 支持生物识别快速解锁