import Foundation
import SwiftUI

// MARK: - Appearance Mode

enum AppAppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "自动"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nextMode: AppAppearanceMode {
        switch self {
        case .dark: return .light
        case .light: return .system
        case .system: return .dark
        }
    }
}

// MARK: - Patch Mode & Preferences

enum PatchTargetMode: String, CaseIterable, Identifiable, Sendable {
    case copyApp = "copy"
    case inPlace = "inplace"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .copyApp: return "独立应用"
        case .inPlace: return "直接替换"
        }
    }
}

// MARK: - Environment Snapshot

struct AppSnapshot: Equatable, Sendable {
    var officialInstalled: Bool = false
    var officialVersion: String = ""
    var officialBuildVersion: String = ""
    var officialPath: String = "/Applications/Antigravity.app"
    var officialRunning: Bool = false
    var officialAsarPatched: Bool = false
    var officialAsarSHA256: String = ""

    var copyExists: Bool = false
    var copyVersion: String = ""
    var copyPath: String = (NSHomeDirectory() as NSString).appendingPathComponent("Applications/AntigravityZH.app")
    var copyRunning: Bool = false
    var copyPatched: Bool = false
    var copyMatchesOfficial: Bool = false

    var toolkitVersion: String = "1.6.1"
    var dictionaryCount: Int = 0
    var dictionarySHA256: String = ""
    var dictionarySynced: Bool = false

    var backupExists: Bool = false
    var backupVersion: String = ""
    var backupSavedAt: String = ""
    var lastInjectedAt: String = ""

    var pythonPath: String? = nil
    var coreDirectory: String = ""
    var scannedAt: Date = Date()

    var hasPython: Bool { pythonPath != nil }
}

// MARK: - High-Level Readiness Assessment

enum ReadinessState: Equatable, Sendable {
    case scanning
    case missingPython
    case officialMissing
    case needsInstall
    case copyUnpatched
    case needsSync(reason: String)
    case ready
}

// MARK: - Operations & Pipeline Stages

enum OperationKind: Equatable, Sendable {
    case smartInstallAndLaunch
    case reinject
    case restore

    var title: String {
        switch self {
        case .smartInstallAndLaunch: return "正在汉化"
        case .reinject: return "正在更新"
        case .restore: return "正在还原"
        }
    }

    var successTitle: String {
        switch self {
        case .smartInstallAndLaunch: return "已完成"
        case .reinject: return "已更新"
        case .restore: return "已还原"
        }
    }
}

enum StepState: Equatable, Sendable {
    case pending
    case active
    case completed
    case failed
}

struct PipelineStage: Identifiable, Equatable, Sendable {
    let id: Int
    let shortTitle: String
    let activeDescription: String
    let symbol: String
    var state: StepState = .pending

    static func installStages(isCopyMode: Bool) -> [PipelineStage] {
        if isCopyMode {
            return [
                PipelineStage(id: 0, shortTitle: "复制应用", activeDescription: "正在复制独立中文应用", symbol: "square.on.square"),
                PipelineStage(id: 1, shortTitle: "备份原版", activeDescription: "正在备份官方原版文件", symbol: "shippingbox"),
                PipelineStage(id: 2, shortTitle: "写入中文", activeDescription: "正在写入中文语言包", symbol: "sparkles"),
                PipelineStage(id: 3, shortTitle: "修复签名", activeDescription: "正在同步校验并签名", symbol: "checkmark.seal"),
                PipelineStage(id: 4, shortTitle: "启动检查", activeDescription: "正在启动并检查可用性", symbol: "play.circle"),
            ]
        } else {
            return [
                PipelineStage(id: 0, shortTitle: "检查环境", activeDescription: "正在检查应用状态", symbol: "magnifyingglass"),
                PipelineStage(id: 1, shortTitle: "备份原版", activeDescription: "正在备份官方原版文件", symbol: "shippingbox"),
                PipelineStage(id: 2, shortTitle: "写入中文", activeDescription: "正在写入中文语言包", symbol: "sparkles"),
                PipelineStage(id: 3, shortTitle: "修复签名", activeDescription: "正在同步校验并签名", symbol: "checkmark.seal"),
                PipelineStage(id: 4, shortTitle: "启动检查", activeDescription: "正在启动并检查可用性", symbol: "play.circle"),
            ]
        }
    }

    static func restoreStages() -> [PipelineStage] {
        [
            PipelineStage(id: 0, shortTitle: "核对备份", activeDescription: "正在核对原版备份", symbol: "doc.badge.gearshape"),
            PipelineStage(id: 1, shortTitle: "恢复原版", activeDescription: "正在恢复英文原版", symbol: "arrow.uturn.backward.circle"),
            PipelineStage(id: 2, shortTitle: "修复签名", activeDescription: "正在重新签名校验", symbol: "checkmark.seal"),
        ]
    }
}

// MARK: - Live Log Entry

enum LogLevel: Sendable {
    case info
    case success
    case warning
    case error

    var color: Color {
        switch self {
        case .info: return StudioTheme.textSecondary
        case .success: return StudioTheme.ready
        case .warning: return StudioTheme.attention
        case .error: return StudioTheme.error
        }
    }

    var prefixSymbol: String {
        switch self {
        case .info: return "·"
        case .success: return "✓"
        case .warning: return "!"
        case .error: return "✕"
        }
    }
}

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: String
    let level: LogLevel
    let message: String
}

// MARK: - Completion Banner

struct OperationOutcome: Equatable, Sendable {
    let kind: OperationKind
    let succeeded: Bool
    let headline: String
    let detail: String
    let logFilePath: String?
}
