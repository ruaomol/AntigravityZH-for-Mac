import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class AppUIState: ObservableObject {
    @Published var showSettings = false
    @Published var showLogs = false
    @Published var isClosing = false
}

struct RootContainerView: View {
    @ObservedObject var controller: PatchController
    @ObservedObject var uiState: AppUIState

    var body: some View {
        MainView(
            controller: controller,
            showSettings: $uiState.showSettings,
            showLogs: $uiState.showLogs,
            isClosing: uiState.isClosing
        )
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private let controller = PatchController()
    private let uiState = AppUIState()
    private var closeAnimationInFlight = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupMainWindow()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange(_:)),
            name: PatchController.appearanceChangedNotification,
            object: nil
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleAppearanceChange(_ note: Notification) {
        applyWindowAppearance(controller.appearanceMode)
    }

    private func applyWindowAppearance(_ mode: AppAppearanceMode) {
        guard let win = window else { return }
        switch mode {
        case .system:
            win.appearance = nil
        case .light:
            win.appearance = NSAppearance(named: .aqua)
        case .dark:
            win.appearance = NSAppearance(named: .darkAqua)
        }
        win.backgroundColor = StudioTheme.windowNSColor(for: mode)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            uiState.isClosing = false
            closeAnimationInFlight = false
            window?.alphaValue = 1.0
            window?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if closeAnimationInFlight { return true }

        if controller.isRunning {
            let alert = NSAlert()
            alert.messageText = "操作正在进行中"
            alert.informativeText = "当前正在写入或签名客户端文件，强制退出可能导致本次操作中断。确定要终止并退出吗？"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "继续运行")
            alert.addButton(withTitle: "终止并退出")
            let response = alert.runModal()
            if response != .alertSecondButtonReturn {
                return false
            }
            controller.cancelActiveOperation()
        }

        // Smooth zero-gravity particle dispersion + window fade-out close animation
        closeAnimationInFlight = true
        uiState.isClosing = true

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.26
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            sender.animator().alphaValue = 0.0
        }, completionHandler: {
            Task { @MainActor in
                sender.close()
            }
        })
        return false
    }

    private func setupMainWindow() {
        let rootView = RootContainerView(controller: controller, uiState: uiState)
        let hostingController = NSHostingController(rootView: rootView)
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        }

        let win = NSWindow(contentViewController: hostingController)
        win.title = "AntigravityZH"
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        win.isMovableByWindowBackground = true
        win.acceptsMouseMovedEvents = true
        win.isOpaque = true
        win.hasShadow = true
        win.collectionBehavior = [.moveToActiveSpace, .fullScreenNone]
        win.standardWindowButton(.zoomButton)?.isEnabled = false
        win.delegate = self

        self.window = win
        applyWindowAppearance(controller.appearanceMode)

        win.center()
        // Smooth launch fade-in paired with particle coalescence
        win.alphaValue = 0.0
        win.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.34
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            win.animator().alphaValue = 1.0
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "AntigravityZH")
        appMenu.addItem(withTitle: "关于 AntigravityZH for Mac", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)

        let locateItem = NSMenuItem(title: "选择 Antigravity.app…", action: #selector(locateApp), keyEquivalent: "o")
        locateItem.target = self
        appMenu.addItem(locateItem)

        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 AntigravityZH", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "全部显示", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 AntigravityZH", action: #selector(animatedQuit), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Action Menu
        let actionMenuItem = NSMenuItem()
        let actionMenu = NSMenu(title: "操作")

        let primaryItem = NSMenuItem(title: "执行主操作", action: #selector(triggerPrimaryAction), keyEquivalent: "\r")
        primaryItem.target = self
        actionMenu.addItem(primaryItem)

        let refreshItem = NSMenuItem(title: "刷新检测", action: #selector(triggerRefresh), keyEquivalent: "r")
        refreshItem.target = self
        actionMenu.addItem(refreshItem)

        actionMenu.addItem(.separator())

        let logsItem = NSMenuItem(title: "展开 / 收起详情与日志", action: #selector(toggleLogs), keyEquivalent: "l")
        logsItem.target = self
        actionMenu.addItem(logsItem)

        let openLogsDirItem = NSMenuItem(title: "在访达中打开日志目录", action: #selector(openLogsFolder), keyEquivalent: "")
        openLogsDirItem.target = self
        actionMenu.addItem(openLogsDirItem)

        actionMenuItem.submenu = actionMenu
        mainMenu.addItem(actionMenuItem)

        // Edit Menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        let credits = NSAttributedString(
            string: "AntigravityZH for Mac\n保留官方原版 · 一键同步词典与签名校验\nMIT License",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11.5),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "AntigravityZH",
            .applicationVersion: controller.snapshot.toolkitVersion,
            .credits: credits,
        ])
    }

    @objc private func openSettings() {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            uiState.showSettings.toggle()
        }
    }

    @objc private func locateApp() {
        controller.locateOfficialApp()
    }

    @objc private func animatedQuit() {
        if let win = window, win.isVisible {
            win.performClose(nil)
        } else {
            NSApp.terminate(nil)
        }
    }

    @objc private func triggerPrimaryAction() {
        controller.handlePrimaryAction()
    }

    @objc private func triggerRefresh() {
        Task { await controller.refreshEnvironment() }
    }

    @objc private func toggleLogs() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            uiState.showLogs.toggle()
        }
    }

    @objc private func openLogsFolder() {
        controller.openLogsDirectory()
    }
}

// Entry point
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
