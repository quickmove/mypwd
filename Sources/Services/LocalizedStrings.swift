import Foundation

/// Manages all localized strings for the app
enum LocalizedStrings {
    private static var isChinese: Bool {
        LocalizationService.shared.isSimplifiedChinese
    }
    
    // MARK: - Setup View
    static var setMasterPassword: String {
        isChinese ? "设置主密码" : "Set Master Password"
    }
    
    static var chooseStorageLocation: String {
        isChinese ? "选择存储位置" : "Choose Storage Location"
    }
    
    static var gitRepositoryConfiguration: String {
        isChinese ? "Git 仓库配置" : "Git Repository Configuration"
    }
    
    static var masterPassword: String {
        isChinese ? "主密码" : "Master Password"
    }
    
    static var enterMasterPassword: String {
        isChinese ? "输入主密码" : "Enter master password"
    }
    
    static var confirmPassword: String {
        isChinese ? "确认密码" : "Confirm Password"
    }
    
    static var enterMasterPasswordAgain: String {
        isChinese ? "再次输入主密码" : "Enter master password again"
    }
    
    static var passwordMustBeAtLeast6Characters: String {
        isChinese ? "密码至少6位且两次输入一致" : "Password must be at least 6 characters and match"
    }
    
    static var next: String {
        isChinese ? "下一步" : "Next"
    }
    
    static var previous: String {
        isChinese ? "上一步" : "Previous"
    }
    
    static var finishAndSync: String {
        isChinese ? "完成并同步" : "Finish & Sync"
    }
    
    static var pleaseKeepYourMasterPasswordSafe: String {
        isChinese ? "请妥善保管主密码，遗忘后无法恢复。" : "Please keep your master password safe. It cannot be recovered if forgotten."
    }
    
    static var storageLocation: String {
        isChinese ? "存储位置" : "Storage Location"
    }
    
    static var select: String {
        isChinese ? "选择..." : "Select..."
    }
    
    static var repositoryURL: String {
        isChinese ? "仓库地址" : "Repository URL"
    }
    
    static var username: String {
        isChinese ? "用户名" : "Username"
    }
    
    static var githubUsernameOrToken: String {
        isChinese ? "GitHub 用户名或 Token" : "GitHub username or Token"
    }
    
    static var passwordOrPersonalAccessToken: String {
        isChinese ? "密码 / Personal Access Token" : "Password / Personal Access Token"
    }
    
    static var passwordOrToken: String {
        isChinese ? "密码或 Token" : "Password or Token"
    }
    
    static var privateRepositoriesRequireUsernameAndPassword: String {
        isChinese ? "私有仓库需要用户名和密码或 Personal Access Token" : "Private repositories require username and password or Personal Access Token"
    }
    
    static var existingPasswordVaultFound: String {
        isChinese ? "发现现有密码库" : "Existing Password Vault Found"
    }
    
    static var passwordVaultFileAlreadyExists: String {
        isChinese ? "密码库文件已存在，是否使用现有文件或创建新文件？" : "A password vault file already exists at this location. Use existing file or create new?"
    }
    
    static var useExistingFile: String {
        isChinese ? "使用现有文件" : "Use Existing File"
    }
    
    static var createNewFile: String {
        isChinese ? "创建新文件" : "Create New File"
    }
    
    static var setupFailed: String {
        isChinese ? "设置失败" : "Setup failed"
    }
    
    static var gitCloneFailed: String {
        isChinese ? "Git 克隆失败" : "Git clone failed"
    }
    
    // MARK: - Unlock View
    static var unlockPasswordVault: String {
        isChinese ? "解锁密码库" : "Unlock Password Vault"
    }
    
    static var unlockWithTouchID: String {
        isChinese ? "使用 Touch ID 解锁" : "Unlock with Touch ID"
    }
    
    static var unlockWithFaceID: String {
        isChinese ? "使用 Face ID 解锁" : "Unlock with Face ID"
    }
    
    static var unlockWithBiometrics: String {
        isChinese ? "使用生物识别解锁" : "Unlock with Biometrics"
    }
    
    static var touchIDNotAvailable: String {
        isChinese ? "Touch ID 不可用" : "TouchID not available"
    }
    
    // MARK: - Main View
    static var secondsUntilAutoLock: String {
        isChinese ? "秒后自动锁定" : "seconds until auto-lock"
    }
    
    static var lock: String {
        isChinese ? "锁定" : "Lock"
    }
    
    static var selectAPasswordItem: String {
        isChinese ? "选择一个密码项目" : "Select a password item"
    }
    
    // MARK: - Password Editor View
    static var editPassword: String {
        isChinese ? "编辑密码" : "Edit Password"
    }
    
    static var addPassword: String {
        isChinese ? "添加密码" : "Add Password"
    }
    
    static var title: String {
        isChinese ? "标题" : "Title"
    }
    
    static var url: String {
        isChinese ? "网址" : "URL"
    }
    
    static var usernameField: String {
        isChinese ? "用户名" : "Username"
    }
    
    static var password: String {
        isChinese ? "密码" : "Password"
    }
    
    static var notes: String {
        isChinese ? "备注" : "Notes"
    }
    
    static var cancel: String {
        isChinese ? "取消" : "Cancel"
    }
    
    static var save: String {
        isChinese ? "保存" : "Save"
    }
    
    static var passwordStrength: String {
        isChinese ? "密码强度" : "Password Strength"
    }
    
    static var pleaseEnterAPassword: String {
        isChinese ? "请输入密码" : "Please enter a password"
    }
    
    // MARK: - Password Detail View
    static var edit: String {
        isChinese ? "编辑" : "Edit"
    }
    
    static var delete: String {
        isChinese ? "删除" : "Delete"
    }
    
    static var confirmDelete: String {
        isChinese ? "确认删除" : "Confirm Delete"
    }
    
    static var areYouSureYouWantToDelete: String {
        isChinese ? "确定要删除" : "Are you sure you want to delete"
    }
    
    static var thisActionCannotBeUndone: String {
        isChinese ? "此操作无法撤销。" : "This action cannot be undone."
    }
    
    static var created: String {
        isChinese ? "创建时间" : "Created"
    }
    
    static var updated: String {
        isChinese ? "更新时间" : "Updated"
    }
    
    // MARK: - Password Generator View
    static var passwordGenerator: String {
        isChinese ? "密码生成器" : "Password Generator"
    }
    
    static var length: String {
        isChinese ? "长度" : "Length"
    }
    
    static var uppercase: String {
        isChinese ? "大写字母 (A-Z)" : "Uppercase (A-Z)"
    }
    
    static var lowercase: String {
        isChinese ? "小写字母 (a-z)" : "Lowercase (a-z)"
    }
    
    static var numbers: String {
        isChinese ? "数字 (0-9)" : "Numbers (0-9)"
    }
    
    static var symbols: String {
        isChinese ? "符号 (!@#$%)" : "Symbols (!@#$%)"
    }
    
    static var regenerate: String {
        isChinese ? "重新生成" : "Regenerate"
    }
    
    static var useThisPassword: String {
        isChinese ? "使用此密码" : "Use This Password"
    }
    
    // MARK: - Password Strength
    static var veryWeak: String {
        isChinese ? "非常弱" : "Very Weak"
    }
    
    static var weak: String {
        isChinese ? "弱" : "Weak"
    }
    
    static var medium: String {
        isChinese ? "中等" : "Medium"
    }
    
    static var strong: String {
        isChinese ? "强" : "Strong"
    }
    
    static var veryStrong: String {
        isChinese ? "非常强" : "Very Strong"
    }
}
