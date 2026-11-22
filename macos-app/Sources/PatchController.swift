import AppKit
import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

private final class LockedLineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func appendAndExtractLines(_ chunk: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        data.append(chunk)
        var lines: [String] = []
        while let newlineRange = data.firstRange(of: Data([0x0A])) {
            let lineData = data.subdata(in: 0..<newlineRange.lowerBound)
            data.removeSubrange(0..<newlineRange.upperBound)
            if let str = String(data: lineData, encoding: .utf8) {
                let cleaned = str.trimmingCharacters(in: CharacterSet.newlines)
                if !cleaned.isEmpty { lines.append(cleaned) }
            }
        }
        return lines
    }

    func flushRemaining(_ trailing: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        data.append(trailing)
        var lines: [String] = []
        if let str = String(data: data, encoding: .utf8) {
            for raw in str.components(separatedBy: .newlines) {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { lines.append(trimmed) }
            }
        }
        data.removeAll()
        return lines
    }
}

@MainActor
final class PatchController: ObservableObject {
    // MARK: - Published State

    @Published var snapshot = AppSnapshot()
    @Published var isScanning = true
    @Published var isRunning = false
    @Published var activeOperation: OperationKind? = nil
    @Published var stages: [PipelineStage] = []
    @Published var progress: Double = 0.0
    @Published var liveCaption: String = ""
    @Published var elapsedSeconds: Int = 0
    @Published var logs: [LogEntry] = []
    @Published var outcome: OperationOutcome? = nil
    @Published var sheenTrigger: Int = 0

    static let appearanceChangedNotification = Notification.Name("AGZH.appearanceChanged")

    // Preferences
    @Published var appearanceMode: AppAppearanceMode = .dark {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "AGZH.appearanceMode")
            NotificationCenter.default.post(name: Self.appearanceChangedNotification, object: appearanceMode)
        }
    }
    @Published var targetMode: PatchTargetMode = .copyApp {
        didSet {
            UserDefaults.standard.set(targetMode.rawValue, forKey: "AGZH.targetMode")
        }
    }
    @Published var skipSmokeTest: Bool = false {
        didSet {
            UserDefaults.standard.set(skipSmokeTest, forKey: "AGZH.skipSmokeTest")
        }
    }
    @Published var customOfficialAppPath: String = "" {
        didSet {
            UserDefaults.standard.set(customOfficialAppPath, forKey: "AGZH.customOfficialAppPath")
        }
    }

    // UI Prompts
    @Published var pendingOperationAfterQuit: OperationKind? = nil
    @Published var showQuitOfficialConfirmation = false
    @Published var showRestoreConfirmation = false
    @Published var showRemoveCopyConfirmation = false
    @Published var showFullResetConfirmation = false
    @Published var isQuittingOfficial = false

    // MARK: - Private Internals

    private var activeProcess: Process? = nil
    private var progressCreepTimer: Timer? = nil
    private var elapsedTimer: Timer? = nil
    private var progressCeiling: Double = 0.0
    private var cancelledByUser = false
    private var dictCacheKey: String = ""
    private var cachedDictCount: Int = 0
    private var cachedDictSHA: String = ""
    private var latestLogFileFromRun: String? = nil

    private static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }()

    // MARK: - Init

    init() {
        if let savedTheme = UserDefaults.standard.string(forKey: "AGZH.appearanceMode"),
           let mode = AppAppearanceMode(rawValue: savedTheme) {
            self.appearanceMode = mode
        }
        if let saved = UserDefaults.standard.string(forKey: "AGZH.targetMode"),
           let mode = PatchTargetMode(rawValue: saved) {
            self.targetMode = mode
        }
        self.skipSmokeTest = UserDefaults.standard.bool(forKey: "AGZH.skipSmokeTest")
        self.customOfficialAppPath = UserDefaults.standard.string(forKey: "AGZH.customOfficialAppPath") ?? ""

        Task {
            await refreshEnvironment()
        }
    }

    // MARK: - Computed Readiness & Primary Action

    var readiness: ReadinessState {
        if isScanning && snapshot.coreDirectory.isEmpty {
            return .scanning
        }
        if !snapshot.hasPython {
            return .missingPython
        }
        if !snapshot.officialInstalled {
            return .officialMissing
        }

        if targetMode == .copyApp {
            if !snapshot.copyExists {
                return .needsInstall
            }
            if !snapshot.copyPatched {
                return .copyUnpatched
            }
            if !snapshot.copyMatchesOfficial {
                let targetVer = snapshot.officialVersion.isEmpty ? "新版" : "v\(snapshot.officialVersion)"
                return .needsSync(reason: "官方已更新至 \(targetVer)，可一键同步")
            }
            if !snapshot.dictionarySHA256.isEmpty && !snapshot.dictionarySynced {
                return .needsSync(reason: "词典已更新，可一键同步")
            }
            return .ready
        } else {
            if !snapshot.officialAsarPatched {
                return .needsInstall
            }
            if !snapshot.dictionarySHA256.isEmpty && !snapshot.dictionarySynced {
                return .needsSync(reason: "词典已更新，可重新注入")
            }
            return .ready
        }
    }

    var particleMode: ParticleVisualMode {
        if isRunning { return .working }
        if isScanning && snapshot.coreDirectory.isEmpty { return .scanning }
        if let outcome, !outcome.succeeded { return .error }
        if officialBlocksCopy { return .attention }
        switch readiness {
        case .scanning: return .scanning
        case .ready: return .ready
        case .needsSync: return .needsSync
        case .missingPython, .officialMissing: return .attention
        case .needsInstall, .copyUnpatched: return .idle
        }
    }

    var activeStageShortLabel: String {
        if let active = stages.first(where: { $0.state == .active }) {
            return active.shortTitle
        }
        return activeOperation?.title ?? "处理中"
    }

    /// Ultra-concise human-readable micro-status
    var conciseStatusLine: String {
        if isRunning {
            let pct = Int((progress * 100).rounded())
            return "\(activeStageShortLabel) · \(pct)%"
        }
        if let outcome {
            return outcome.headline
        }
        let ver = snapshot.officialVersion.isEmpty ? "" : snapshot.officialVersion
        switch readiness {
        case .scanning:
            return "检测中"
        case .missingPython:
            return "缺少 Python 3"
        case .officialMissing:
            return "未找到 Antigravity"
        case .needsInstall:
            return officialBlocksCopy ? "\(ver) · 官方运行中" : "\(ver)"
        case .copyUnpatched:
            return "\(ver) · 英文原版"
        case .needsSync:
            return officialBlocksCopy ? "\(ver) · 官方运行中" : "\(ver) · 可更新"
        case .ready:
            if targetMode == .copyApp {
                return snapshot.copyRunning ? "\(ver) · 运行中" : "\(ver) · 已就绪"
            } else {
                return snapshot.officialRunning ? "\(ver) · 运行中" : "\(ver) · 已就绪"
            }
        }
    }

    var primaryButtonTitle: String {
        switch readiness {
        case .scanning:
            return "检测中"
        case .missingPython:
            return "重新检测"
        case .officialMissing:
            return "选择应用"
        case .needsInstall:
            return officialBlocksCopy ? "关闭并汉化" : "一键汉化"
        case .copyUnpatched:
            return "一键汉化"
        case .needsSync:
            return officialBlocksCopy ? "关闭并更新" : "更新汉化"
        case .ready:
            if targetMode == .copyApp {
                return snapshot.copyRunning ? "打开中文版" : "启动中文版"
            } else {
                return snapshot.officialRunning ? "打开应用" : "启动应用"
            }
        }
    }

    var primaryButtonSymbol: String {
        switch readiness {
        case .scanning: return "ellipsis"
        case .missingPython: return "arrow.clockwise"
        case .officialMissing: return "folder"
        case .needsInstall, .copyUnpatched: return "arrow.up.right"
        case .needsSync: return "arrow.triangle.2.circlepath"
        case .ready: return "play.fill"
        }
    }

    var canRestore: Bool {
        guard !isRunning && snapshot.hasPython else { return false }
        if targetMode == .copyApp {
            return snapshot.copyExists && snapshot.copyPatched && snapshot.backupExists
        } else {
            return snapshot.officialInstalled && snapshot.officialAsarPatched && snapshot.backupExists
        }
    }

    var canReinject: Bool {
        guard !isRunning && snapshot.hasPython && snapshot.officialInstalled else { return false }
        return readiness == .ready || readiness == .copyUnpatched || (targetMode == .copyApp && snapshot.copyExists)
    }

    var officialBlocksCopy: Bool {
        guard targetMode == .copyApp && snapshot.officialRunning else { return false }
        switch readiness {
        case .needsInstall:
            return true
        case .needsSync:
            return !snapshot.copyMatchesOfficial
        default:
            return false
        }
    }

    // MARK: - Environment Refresh

    func refreshEnvironment() async {
        guard !isRunning else { return }
        isScanning = true

        let coreDir = Self.resolveCoreDirectory()
        let pythonBin = Self.resolvePythonBinary()
        let customOfficial = customOfficialAppPath
        let prevCacheKey = dictCacheKey
        let prevCount = cachedDictCount
        let prevSHA = cachedDictSHA

        // Snapshot running app URLs on main thread via NSWorkspace
        let runningPaths = Set(
            NSWorkspace.shared.runningApplications
                .compactMap { $0.bundleURL?.standardizedFileURL.path }
        )

        let result = await Task.detached(priority: .userInitiated) {
            Self.inspectSystem(
                coreDir: coreDir,
                pythonPath: pythonBin,
                customOfficialPath: customOfficial,
                runningBundlePaths: runningPaths,
                cachedDictKey: prevCacheKey,
                cachedCount: prevCount,
                cachedSHA: prevSHA
            )
        }.value

        self.snapshot = result.snapshot
        self.dictCacheKey = result.dictKey
        self.cachedDictCount = result.snapshot.dictionaryCount
        self.cachedDictSHA = result.snapshot.dictionarySHA256
        self.isScanning = false
    }

    /// Opens native macOS file panel to locate Antigravity.app manually
    func locateOfficialApp() {
        let panel = NSOpenPanel()
        panel.title = "定位官方 Antigravity.app"
        panel.prompt = "选择"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let url = panel.url {
            let asarPath = url.appendingPathComponent("Contents/Resources/app.asar").path
            if FileManager.default.fileExists(atPath: asarPath) {
                MacHaptics.confirm()
                customOfficialAppPath = url.path
                outcome = nil
                Task { await refreshEnvironment() }
            } else {
                outcome = OperationOutcome(
                    kind: .smartInstallAndLaunch,
                    succeeded: false,
                    headline: "无效的客户端应用",
                    detail: "所选应用内缺少 Contents/Resources/app.asar。",
                    logFilePath: nil
                )
            }
        }
    }

    func resetOfficialAppLocation() {
        MacHaptics.tap()
        customOfficialAppPath = ""
        Task { await refreshEnvironment() }
    }

    /// Cleanly removes Chinese copy + ~/.antigravity-zh cache, backup & state
    func fullResetAndClean() {
        showFullResetConfirmation = false
        Task {
            let copyURL = URL(fileURLWithPath: snapshot.copyPath)
            if FileManager.default.fileExists(atPath: snapshot.copyPath) {
                let copyStd = copyURL.standardizedFileURL
                for app in NSWorkspace.shared.runningApplications where app.bundleURL?.standardizedFileURL == copyStd {
                    app.terminate()
                }
                try? await Task.sleep(nanoseconds: 450_000_000)
                try? FileManager.default.trashItem(at: copyURL, resultingItemURL: nil)
            }

            let userDir = (NSHomeDirectory() as NSString).appendingPathComponent(".antigravity-zh")
            if FileManager.default.fileExists(atPath: userDir) {
                try? FileManager.default.removeItem(atPath: userDir)
            }
            customOfficialAppPath = ""
            logs = []
            MacHaptics.confirm()
            sheenTrigger += 1
            outcome = OperationOutcome(
                kind: .restore,
                succeeded: true,
                headline: "已完全清理",
                detail: "中文副本、备份与状态缓存已移除。",
                logFilePath: nil
            )
            await refreshEnvironment()
        }
    }

    var telemetryPairs: [(String, String)] {
        let shortOfficial = (snapshot.officialPath as NSString).abbreviatingWithTildeInPath
        let shortCopy = (snapshot.copyPath as NSString).abbreviatingWithTildeInPath
        return [
            ("官方应用", snapshot.officialInstalled ? "\(snapshot.officialVersion) · \(shortOfficial)" : "未找到"),
            ("中文应用", snapshot.copyExists ? (snapshot.copyPatched ? "\(snapshot.copyVersion) · \(shortCopy)" : "英文原版 · \(shortCopy)") : "未创建"),
            ("词条数量", snapshot.dictionaryCount > 0 ? "\(snapshot.dictionaryCount) 条" : "—"),
            ("原版备份", snapshot.backupExists ? "v\(snapshot.backupVersion)" : "尚未生成"),
        ]
    }

    // MARK: - Primary User Actions

    func handlePrimaryAction() {
        guard !isRunning else { return }
        MacHaptics.tap()

        switch readiness {
        case .scanning:
            return
        case .missingPython:
            Task { await refreshEnvironment() }
        case .officialMissing:
            locateOfficialApp()
        case .ready:
            launchTargetApp()
        case .needsInstall, .copyUnpatched, .needsSync:
            requestOperation(.smartInstallAndLaunch)
        }
    }

    func requestOperation(_ kind: OperationKind) {
        guard !isRunning else { return }
        outcome = nil

        if kind == .restore {
            showRestoreConfirmation = true
            return
        }

        // Check if official app is currently running and would block copy creation/refresh
        let needsOfficialClosed: Bool = {
            if targetMode == .inPlace {
                return snapshot.officialRunning
            }
            if !snapshot.officialRunning { return false }
            if kind == .reinject {
                return !snapshot.copyExists || !snapshot.copyMatchesOfficial
            }
            return !snapshot.copyExists || !snapshot.copyMatchesOfficial
        }()

        if needsOfficialClosed {
            pendingOperationAfterQuit = kind
            showQuitOfficialConfirmation = true
            return
        }

        executeOperation(kind)
    }

    func quitOfficialAndContinue() {
        let nextOp = pendingOperationAfterQuit
        showQuitOfficialConfirmation = false
        pendingOperationAfterQuit = nil

        Task {
            let closed = await quitOfficialAppGracefully()
            await refreshEnvironment()
            if closed, let op = nextOp {
                executeOperation(op)
            } else if !closed {
                outcome = OperationOutcome(
                    kind: nextOp ?? .smartInstallAndLaunch,
                    succeeded: false,
                    headline: "未能自动退出官方 Antigravity",
                    detail: "请先在官方 Antigravity 中按 ⌘Q 保存并退出，然后重试。",
                    logFilePath: nil
                )
            }
        }
    }

    func quitOfficialAppOnly() {
        Task {
            _ = await quitOfficialAppGracefully()
            await refreshEnvironment()
        }
    }

    func quitOfficialAppGracefully() async -> Bool {
        isQuittingOfficial = true
        defer { isQuittingOfficial = false }

        let officialURL = URL(fileURLWithPath: snapshot.officialPath).standardizedFileURL
        let matches = NSWorkspace.shared.runningApplications.filter {
            $0.bundleURL?.standardizedFileURL == officialURL
        }
        if matches.isEmpty { return true }

        for app in matches {
            app.terminate()
        }

        for _ in 0..<24 {
            try? await Task.sleep(nanoseconds: 250_000_000)
            let stillRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleURL?.standardizedFileURL == officialURL && !$0.isTerminated
            }
            if !stillRunning {
                try? await Task.sleep(nanoseconds: 400_000_000)
                return true
            }
        }
        return false
    }

    func confirmAndRunRestore() {
        showRestoreConfirmation = false
        executeOperation(.restore)
    }

    // MARK: - Native App Launching & Finder Helpers

    func launchTargetApp() {
        let path = targetMode == .copyApp ? snapshot.copyPath : snapshot.officialPath
        launchApp(at: path)
    }

    func launchApp(at path: String) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { return }
        MacHaptics.confirm()
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
    }

    func revealInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let parent = url.deletingLastPathComponent()
            NSWorkspace.shared.open(parent)
        }
    }

    func openLogsDirectory() {
        let dir = (NSHomeDirectory() as NSString).appendingPathComponent(".antigravity-zh/logs")
        let url = URL(fileURLWithPath: dir)
        if FileManager.default.fileExists(atPath: dir) {
            NSWorkspace.shared.open(url)
        } else {
            let parent = (NSHomeDirectory() as NSString).appendingPathComponent(".antigravity-zh")
            NSWorkspace.shared.open(URL(fileURLWithPath: parent))
        }
    }

    func openFile(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func trashChineseCopy() {
        showRemoveCopyConfirmation = false
        let url = URL(fileURLWithPath: snapshot.copyPath)
        guard FileManager.default.fileExists(atPath: snapshot.copyPath) else { return }

        Task {
            // Close copy if running
            let copyStd = url.standardizedFileURL
            for app in NSWorkspace.shared.runningApplications where app.bundleURL?.standardizedFileURL == copyStd {
                app.terminate()
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                let metaPath = (NSHomeDirectory() as NSString).appendingPathComponent(".antigravity-zh/macos-copy.json")
                try? FileManager.default.removeItem(atPath: metaPath)
                MacHaptics.confirm()
                outcome = OperationOutcome(
                    kind: .restore,
                    succeeded: true,
                    headline: "已将独立中文副本移至废纸篓",
                    detail: "官方 Antigravity 未受任何影响，随时可再次一键创建中文副本。",
                    logFilePath: nil
                )
            } catch {
                outcome = OperationOutcome(
                    kind: .restore,
                    succeeded: false,
                    headline: "移除副本失败",
                    detail: error.localizedDescription,
                    logFilePath: nil
                )
            }
            await refreshEnvironment()
        }
    }

    func copyLogsToPasteboard() {
        let text = logs.map { "[\($0.timestamp)] \($0.message)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        MacHaptics.tap()
    }

    func cancelActiveOperation() {
        guard isRunning else { return }
        cancelledByUser = true
        activeProcess?.terminate()
        appendLog("已请求取消当前操作…", level: .warning)
    }

    // MARK: - Subprocess Execution & Live Progress Engine

    private func executeOperation(_ kind: OperationKind) {
        guard let python = snapshot.pythonPath else { return }
        let scriptPath = (snapshot.coreDirectory as NSString).appendingPathComponent("install.py")
        guard FileManager.default.fileExists(atPath: scriptPath) else {
            outcome = OperationOutcome(
                kind: kind,
                succeeded: false,
                headline: "找不到核心安装脚本",
                detail: "路径缺失：\(scriptPath)",
                logFilePath: nil
            )
            return
        }

        // Prepare pipeline UI state
        cancelledByUser = false
        latestLogFileFromRun = nil
        activeOperation = kind
        isRunning = true
        outcome = nil
        logs = []
        elapsedSeconds = 0
        progress = 0.04

        if kind == .restore {
            stages = PipelineStage.restoreStages()
            activateStage(0, targetProgress: 0.14, ceiling: 0.34)
        } else {
            stages = PipelineStage.installStages(isCopyMode: targetMode == .copyApp)
            activateStage(0, targetProgress: 0.08, ceiling: 0.27)
        }

        var args: [String] = ["-u", scriptPath]
        if targetMode == .copyApp {
            args.append("--copy-app")
            if !snapshot.officialPath.isEmpty {
                args.append(contentsOf: ["--source-app", snapshot.officialPath])
            }
        } else {
            args.append("--in-place")
            if !snapshot.officialPath.isEmpty {
                let customAsar = (snapshot.officialPath as NSString).appendingPathComponent("Contents/Resources/app.asar")
                args.append(contentsOf: ["--asar", customAsar])
            }
        }

        switch kind {
        case .smartInstallAndLaunch:
            args.append("--auto")
            if skipSmokeTest { args.append("--no-smoke") }
        case .reinject:
            args.append("--launch")
            if skipSmokeTest { args.append("--no-smoke") }
        case .restore:
            args.append("--restore")
        }

        appendLog("执行：\(URL(fileURLWithPath: python).lastPathComponent) \(args.dropFirst().joined(separator: " "))", level: .info)

        startTimers()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: python)
        proc.arguments = args
        proc.currentDirectoryURL = URL(fileURLWithPath: snapshot.coreDirectory)

        var env = ProcessInfo.processInfo.environment
        let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = extraPaths + (env["PATH"].map { ":\($0)" } ?? "")
        env["PYTHONIOENCODING"] = "utf-8"
        env["PYTHONUNBUFFERED"] = "1"
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        self.activeProcess = proc

        let lineBuffer = LockedLineBuffer()

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }

            let extractedLines = lineBuffer.appendAndExtractLines(chunk)
            if !extractedLines.isEmpty {
                Task { @MainActor [weak self] in
                    for line in extractedLines {
                        self?.handleProcessLine(line, kind: kind)
                    }
                }
            }
        }

        proc.terminationHandler = { [weak self] finishedProc in
            pipe.fileHandleForReading.readabilityHandler = nil
            let trailing = pipe.fileHandleForReading.readDataToEndOfFile()
            let finalLines = lineBuffer.flushRemaining(trailing)

            let exitCode = finishedProc.terminationStatus
            Task { @MainActor [weak self] in
                guard let self else { return }
                for line in finalLines {
                    self.handleProcessLine(line, kind: kind)
                }
                await self.finishOperation(kind: kind, exitCode: exitCode)
            }
        }

        do {
            try proc.run()
        } catch {
            stopTimers()
            isRunning = false
            activeProcess = nil
            outcome = OperationOutcome(
                kind: kind,
                succeeded: false,
                headline: "无法启动安装核心",
                detail: error.localizedDescription,
                logFilePath: nil
            )
        }
    }

    private func handleProcessLine(_ raw: String, kind: OperationKind) {
        let level: LogLevel
        if raw.hasPrefix("[OK]") || raw.hasPrefix("[DONE]") {
            level = .success
        } else if raw.hasPrefix("[!]") {
            level = .warning
        } else if raw.hasPrefix("[ERR]") || raw.hasPrefix("[X]") {
            level = .error
        } else {
            level = .info
        }

        appendLog(raw, level: level)

        // Extract log file path if printed
        if let range = raw.range(of: "日志: ") ?? raw.range(of: "详细日志: ") {
            let candidate = String(raw[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.hasPrefix("/") {
                latestLogFileFromRun = candidate
            }
        }

        // Friendly live caption (strip technical prefix tags)
        let cleanCaption = raw
            .replacingOccurrences(of: "[OK] ", with: "")
            .replacingOccurrences(of: "[*] ", with: "")
            .replacingOccurrences(of: "[i] ", with: "")
            .replacingOccurrences(of: "[!] ", with: "")
            .replacingOccurrences(of: "[DONE] ", with: "")
            .replacingOccurrences(of: "[ERR] ", with: "")
            .replacingOccurrences(of: "[X] ", with: "")
        if !cleanCaption.hasPrefix("SHA256:") && !cleanCaption.hasPrefix("日志:") {
            liveCaption = cleanCaption
        }

        if kind == .restore {
            mapRestoreProgress(raw)
        } else {
            mapInstallProgress(raw)
        }
    }

    private func mapInstallProgress(_ line: String) {
        if line.contains("已创建独立") && line.contains("副本") {
            activateStage(1, targetProgress: 0.30, ceiling: 0.44)
        } else if line.contains("使用 app.asar:") || line.contains("词典词条:") || line.contains("原包 unpacked") {
            activateStage(1, targetProgress: max(progress, 0.34), ceiling: 0.48)
        } else if line.contains("官方原版已另存") || line.contains("macOS 备份") || line.contains("客户端版本:") {
            activateStage(2, targetProgress: max(progress, 0.48), ceiling: 0.78)
        } else if line.contains("dist/preload.js 注入翻译引擎") {
            activateStage(2, targetProgress: max(progress, 0.56), ceiling: 0.78)
        } else if line.contains("dist/menu.js") || line.contains("dist/main.js") || line.contains("加载画面翻译完成") {
            activateStage(2, targetProgress: max(progress, 0.64), ceiling: 0.78)
        } else if line.contains("重新打包") {
            activateStage(2, targetProgress: max(progress, 0.70), ceiling: 0.81)
        } else if line.contains("结构校验通过") || line.contains("已替换 app.asar") {
            activateStage(3, targetProgress: max(progress, 0.82), ceiling: 0.91)
        } else if line.contains("ElectronAsarIntegrity 已同步") {
            activateStage(3, targetProgress: max(progress, 0.86), ceiling: 0.91)
        } else if line.contains("做本机临时签名") {
            activateStage(3, targetProgress: max(progress, 0.88), ceiling: 0.92)
        } else if line.contains("macOS 本机签名校验通过") {
            activateStage(4, targetProgress: max(progress, 0.92), ceiling: 0.98)
        } else if line.contains("冒烟测试") {
            activateStage(4, targetProgress: max(progress, 0.94), ceiling: 0.98)
        } else if line.contains("[DONE]") || line.contains("当前已是最新") {
            completeAllStages()
        }
    }

    private func mapRestoreProgress(_ line: String) {
        if line.contains("正在用") || line.contains("正在关闭") {
            activateStage(1, targetProgress: 0.42, ceiling: 0.68)
        } else if line.contains("ElectronAsarIntegrity") || line.contains("做本机临时签名") {
            activateStage(2, targetProgress: 0.74, ceiling: 0.94)
        } else if line.contains("已还原官方原版") || line.contains("就是官方原版") {
            completeAllStages()
        }
    }

    private func activateStage(_ index: Int, targetProgress: Double, ceiling: Double) {
        guard index < stages.count else { return }
        var changedStage = false
        for i in stages.indices {
            if i < index {
                if stages[i].state != .completed {
                    stages[i].state = .completed
                    changedStage = true
                }
            } else if i == index {
                if stages[i].state != .active {
                    stages[i].state = .active
                    changedStage = true
                }
            } else {
                stages[i].state = .pending
            }
        }
        if changedStage && index > 0 {
            MacHaptics.step()
        }
        if targetProgress > progress {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                progress = targetProgress
            }
        }
        progressCeiling = max(progressCeiling, ceiling)
    }

    private func completeAllStages() {
        for i in stages.indices {
            stages[i].state = .completed
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            progress = 1.0
        }
        progressCeiling = 1.0
    }

    private func finishOperation(kind: OperationKind, exitCode: Int32) async {
        stopTimers()
        activeProcess = nil
        isRunning = false

        if cancelledByUser {
            for i in stages.indices where stages[i].state == .active {
                stages[i].state = .failed
            }
            outcome = OperationOutcome(
                kind: kind,
                succeeded: false,
                headline: "已取消操作",
                detail: "你可以随时重新发起操作，已完成的官方原版不会受损。",
                logFilePath: latestLogFileFromRun
            )
            await refreshEnvironment()
            return
        }

        if exitCode == 0 {
            completeAllStages()
            MacHaptics.confirm()
            sheenTrigger += 1

            let detail: String
            switch kind {
            case .smartInstallAndLaunch:
                detail = targetMode == .copyApp
                    ? "已在 ~/Applications/AntigravityZH.app 部署完成并启动。"
                    : "已完成中文注入并启动 Antigravity。"
            case .reinject:
                detail = "最新词典（\(snapshot.dictionaryCount) 条）与运行时补丁已重新写入。"
            case .restore:
                detail = "官方原版 app.asar 与完整性摘要已安全恢复。"
            }

            outcome = OperationOutcome(
                kind: kind,
                succeeded: true,
                headline: kind.successTitle,
                detail: detail,
                logFilePath: latestLogFileFromRun
            )
        } else {
            for i in stages.indices where stages[i].state == .active {
                stages[i].state = .failed
            }
            let errLine = logs.last(where: { $0.level == .error })?.message
                .replacingOccurrences(of: "[ERR] ", with: "")
                .replacingOccurrences(of: "[X] ", with: "")
                ?? "操作未完成（退出码 \(exitCode)），请展开运行日志查看详情。"

            outcome = OperationOutcome(
                kind: kind,
                succeeded: false,
                headline: "执行未成功（代码 \(exitCode)）",
                detail: errLine,
                logFilePath: latestLogFileFromRun
            )
        }

        await refreshEnvironment()
    }

    private func appendLog(_ message: String, level: LogLevel) {
        let ts = Self.timeFormatter.string(from: Date())
        logs.append(LogEntry(timestamp: ts, level: level, message: message))
        if logs.count > 400 {
            logs.removeFirst(logs.count - 400)
        }
    }

    private func startTimers() {
        stopTimers()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.elapsedSeconds += 1
            }
        }
        progressCreepTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                let remaining = self.progressCeiling - self.progress
                if remaining > 0.004 {
                    self.progress += remaining * 0.038
                }
            }
        }
    }

    private func stopTimers() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        progressCreepTimer?.invalidate()
        progressCreepTimer = nil
    }

    // MARK: - Non-Isolated Pure System Inspection

    nonisolated private static func resolveCoreDirectory() -> String {
        let fm = FileManager.default
        let bundleDir = Bundle.main.bundleURL.deletingLastPathComponent()
        let siblingInstall = bundleDir.appendingPathComponent("install.py").path
        let siblingDict = bundleDir.appendingPathComponent("dicts/zh_cn.json").path
        if fm.fileExists(atPath: siblingInstall) && fm.fileExists(atPath: siblingDict) {
            return bundleDir.path
        }

        if let resURL = Bundle.main.resourceURL {
            let coreURL = resURL.appendingPathComponent("Core")
            if fm.fileExists(atPath: coreURL.appendingPathComponent("install.py").path) {
                return coreURL.path
            }
        }

        // Development fallback
        let cwd = fm.currentDirectoryPath
        if fm.fileExists(atPath: (cwd as NSString).appendingPathComponent("install.py")) {
            return cwd
        }
        return bundleDir.path
    }

    nonisolated private static func resolvePythonBinary() -> String? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/usr/bin/python3",
        ]
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    nonisolated private static func resolveOfficialAppPath(customPath: String) -> String {
        let fm = FileManager.default
        let copyStd = URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent("Applications/AntigravityZH.app")).standardizedFileURL.path

        func isValidAntigravityBundle(_ path: String) -> Bool {
            guard !path.isEmpty else { return false }
            let std = URL(fileURLWithPath: path).standardizedFileURL.path
            guard std != copyStd else { return false }
            let asar = (std as NSString).appendingPathComponent("Contents/Resources/app.asar")
            return fm.fileExists(atPath: asar)
        }

        if isValidAntigravityBundle(customPath) {
            return customPath
        }

        let defaults = [
            "/Applications/Antigravity.app",
            (NSHomeDirectory() as NSString).appendingPathComponent("Applications/Antigravity.app"),
        ]
        for candidate in defaults where isValidAntigravityBundle(candidate) {
            return candidate
        }

        // Spotlight fallback: auto-locate Antigravity.app anywhere on disk
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        proc.arguments = ["kMDItemCFBundleIdentifier == 'com.google.antigravity'"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        if (try? proc.run()) != nil {
            proc.waitUntilExit()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            if let text = String(data: data, encoding: .utf8) {
                for raw in text.components(separatedBy: .newlines) {
                    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasSuffix(".app"), isValidAntigravityBundle(trimmed) {
                        return trimmed
                    }
                }
            }
        }

        return "/Applications/Antigravity.app"
    }

    nonisolated private static func inspectSystem(
        coreDir: String,
        pythonPath: String?,
        customOfficialPath: String,
        runningBundlePaths: Set<String>,
        cachedDictKey: String,
        cachedCount: Int,
        cachedSHA: String
    ) -> (snapshot: AppSnapshot, dictKey: String) {
        let fm = FileManager.default
        var snap = AppSnapshot()
        snap.coreDirectory = coreDir
        snap.pythonPath = pythonPath
        snap.scannedAt = Date()

        // 1. Toolkit VERSION
        let versionPath = (coreDir as NSString).appendingPathComponent("VERSION")
        if let v = try? String(contentsOfFile: versionPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
            snap.toolkitVersion = v
        }

        // 2. Official App (Auto-discovered or user-located)
        let officialPath = resolveOfficialAppPath(customPath: customOfficialPath)
        snap.officialPath = officialPath
        if fm.fileExists(atPath: (officialPath as NSString).appendingPathComponent("Contents/Resources/app.asar")) {
            snap.officialInstalled = true
            let plist = readInfoPlist(appPath: officialPath)
            snap.officialVersion = plist.shortVersion
            snap.officialBuildVersion = plist.bundleVersion
            snap.officialRunning = runningBundlePaths.contains(URL(fileURLWithPath: officialPath).standardizedFileURL.path)

            let officialAsar = (officialPath as NSString).appendingPathComponent("Contents/Resources/app.asar")
            if fm.fileExists(atPath: officialAsar) {
                snap.officialAsarPatched = quickIsPatched(asarPath: officialAsar)
                snap.officialAsarSHA256 = sha256File(path: officialAsar) ?? ""
            }
        }

        // 3. Localized Copy (~/Applications/AntigravityZH.app)
        let copyPath = (NSHomeDirectory() as NSString).appendingPathComponent("Applications/AntigravityZH.app")
        snap.copyPath = copyPath
        if fm.fileExists(atPath: copyPath) {
            snap.copyExists = true
            let plist = readInfoPlist(appPath: copyPath)
            snap.copyVersion = plist.shortVersion
            snap.copyRunning = runningBundlePaths.contains(URL(fileURLWithPath: copyPath).standardizedFileURL.path)

            let copyAsar = (copyPath as NSString).appendingPathComponent("Contents/Resources/app.asar")
            if fm.fileExists(atPath: copyAsar) {
                snap.copyPatched = quickIsPatched(asarPath: copyAsar)
            }
        }

        // 4. Copy identity check against official app (matches install.py macos-copy.json)
        let userDir = (NSHomeDirectory() as NSString).appendingPathComponent(".antigravity-zh")
        let copyMetaPath = (userDir as NSString).appendingPathComponent("macos-copy.json")
        if snap.copyExists && snap.officialInstalled,
           let data = fm.contents(atPath: copyMetaPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let identity = json["identity"] as? [String],
           identity.count == 2 {
            snap.copyMatchesOfficial = (identity[0] == snap.officialBuildVersion && identity[1] == snap.officialAsarSHA256)
        } else {
            snap.copyMatchesOfficial = false
        }

        // 5. State file (~/.antigravity-zh/state.json)
        let statePath = (userDir as NSString).appendingPathComponent("state.json")
        var stateDictSHA = ""
        if let data = fm.contents(atPath: statePath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            stateDictSHA = (json["dict_sha256"] as? String) ?? ""
            snap.lastInjectedAt = (json["injected_at"] as? String) ?? ""
        }

        // 6. Backup metadata (~/.antigravity-zh/backup/)
        let backupAsar = (userDir as NSString).appendingPathComponent("backup/app.asar.orig")
        let backupMeta = (userDir as NSString).appendingPathComponent("backup/meta.json")
        snap.backupExists = fm.fileExists(atPath: backupAsar)
        if let data = fm.contents(atPath: backupMeta),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            snap.backupVersion = (json["app_version"] as? String) ?? ""
            snap.backupSavedAt = (json["saved_at"] as? String) ?? ""
        }

        // 7. Dictionary count & canonical SHA-256 (cached by file mtime+size)
        let dictPath = (coreDir as NSString).appendingPathComponent("dicts/zh_cn.json")
        var nextDictKey = cachedDictKey
        if let attrs = try? fm.attributesOfItem(atPath: dictPath) {
            let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
            let key = "\(dictPath)|\(mtime)|\(size)"
            if key == cachedDictKey && cachedCount > 0 {
                snap.dictionaryCount = cachedCount
                snap.dictionarySHA256 = cachedSHA
            } else {
                let computed = computeDictionaryInfo(dictPath: dictPath, pythonPath: pythonPath)
                snap.dictionaryCount = computed.count
                snap.dictionarySHA256 = computed.sha256
                nextDictKey = key
            }
        }

        if !stateDictSHA.isEmpty && !snap.dictionarySHA256.isEmpty {
            snap.dictionarySynced = (stateDictSHA == snap.dictionarySHA256)
        } else {
            snap.dictionarySynced = false
        }

        return (snap, nextDictKey)
    }

    nonisolated private static func readInfoPlist(appPath: String) -> (shortVersion: String, bundleVersion: String) {
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        guard let data = FileManager.default.contents(atPath: plistPath),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return ("", "")
        }
        let shortV = (dict["CFBundleShortVersionString"] as? String) ?? ""
        let buildV = (dict["CFBundleVersion"] as? String) ?? shortV
        return (shortV.isEmpty ? buildV : shortV, buildV)
    }

    nonisolated private static func quickIsPatched(asarPath: String) -> Bool {
        let needles: [Data] = [
            Data("AG_ZH_BEGIN:engine".utf8),
            Data("Antigravity Chinese Translation Injection".utf8),
            Data("Antigravity-ZH".utf8),
        ]
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: asarPath)) else {
            return false
        }
        defer { try? handle.close() }

        var tail = Data()
        let chunkSize = 1 << 20 // 1 MB
        while true {
            guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                return false
            }
            var buffer = tail
            buffer.append(chunk)
            for needle in needles {
                if buffer.range(of: needle) != nil {
                    return true
                }
            }
            if buffer.count > 64 {
                tail = Data(buffer.suffix(64))
            } else {
                tail = buffer
            }
        }
    }

    nonisolated private static func sha256File(path: String) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) else {
            return nil
        }
        defer { try? handle.close() }

        var hasher = SHA256()
        let chunkSize = 1 << 20
        while true {
            guard let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty else {
                break
            }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func computeDictionaryInfo(dictPath: String, pythonPath: String?) -> (count: Int, sha256: String) {
        // Compute exact canonical hash matching install.py's dictionary_sha()
        if let python = pythonPath {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: python)
            proc.arguments = [
                "-c",
                """
                import hashlib, json, sys
                with open(sys.argv[1], 'r', encoding='utf-8') as f:
                    data = json.load(f)
                d = {}
                if isinstance(data, dict):
                    d.update(data)
                elif isinstance(data, list):
                    for item in data:
                        if isinstance(item, dict) and 'key' in item and 'value' in item:
                            d[item['key']] = item['value']
                payload = json.dumps(d, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')
                print(len(d), hashlib.sha256(payload).hexdigest())
                """,
                dictPath,
            ]
            let out = Pipe()
            proc.standardOutput = out
            proc.standardError = Pipe()
            if (try? proc.run()) != nil {
                proc.waitUntilExit()
                let data = out.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    let parts = str.split(separator: " ")
                    if parts.count == 2, let cnt = Int(parts[0]) {
                        return (cnt, String(parts[1]))
                    }
                }
            }
        }

        // Pure Swift fallback if Python isn't available yet
        guard let data = FileManager.default.contents(atPath: dictPath),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return (0, "")
        }
        if let dict = obj as? [String: Any] {
            return (dict.count, "")
        }
        if let arr = obj as? [Any] {
            return (arr.count, "")
        }
        return (0, "")
    }
}
