import SwiftUI

struct MainView: View {
    @ObservedObject var controller: PatchController
    @Binding var showSettings: Bool
    @Binding var showLogs: Bool
    var isClosing: Bool

    @State private var refreshRotation: Double = 0
    @State private var ctaHovered: Bool = false
    @State private var appeared: Bool = false
    @State private var copiedFeedback: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            // 1. Pure cosmic obsidian backdrop
            LinearGradient(
                colors: [StudioTheme.canvasUpper, StudioTheme.canvas, StudioTheme.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 2. Full-Window Interactive 60fps Starlight + Inverted V Particle-Lattice Field
            FullWindowCosmicFieldView(
                mode: controller.particleMode,
                progress: controller.progress,
                sheenTrigger: controller.sheenTrigger,
                ctaHovered: ctaHovered,
                isClosing: isClosing
            )
            .ignoresSafeArea()

            // 3. Minimal Floating Editorial Foreground
            VStack(spacing: 0) {
                titlebarChrome

                // Open breathing space for the full-window interactive inverted V particle arch
                Color.clear
                    .frame(height: 234)
                    .allowsHitTesting(false)

                // Editorial title & animated micro-status
                VStack(spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("Antigravity")
                            .font(.system(size: 21, weight: .medium))
                            .tracking(-0.4)
                            .foregroundStyle(StudioTheme.textPrimary)

                        Text("ZH")
                            .font(.system(size: 21, weight: .light))
                            .tracking(-0.2)
                            .foregroundStyle(StudioTheme.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Text(controller.conciseStatusLine)
                            .id(controller.isRunning ? controller.activeStageShortLabel : controller.conciseStatusLine)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(statusLineColor)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))

                        if let outcome = controller.outcome, !outcome.succeeded, !controller.isRunning {
                            Button("日志") {
                                MacHaptics.tap()
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                    showLogs = true
                                }
                            }
                            .buttonStyle(StudioGhostTextButtonStyle(
                                tint: StudioTheme.error,
                                hoverTint: StudioTheme.textPrimary
                            ))
                        }
                    }
                    .frame(height: 20)
                    .clipped()
                }
                .opacity(appeared && !isClosing ? 1.0 : 0.0)
                .offset(y: appeared && !isClosing ? 0 : 8)

                // Fixed-height morphing CTA / Progress slot (smooth in-place transition)
                ZStack {
                    if controller.isRunning {
                        runningProgressSlot
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.94)),
                                removal: .opacity.combined(with: .scale(scale: 0.96))
                            ))
                    } else {
                        idlePrimarySlot
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                removal: .opacity.combined(with: .scale(scale: 0.94))
                            ))
                    }
                }
                .frame(height: 58)
                .padding(.top, 18)
                .opacity(appeared && !isClosing ? 1.0 : 0.0)
                .offset(y: appeared && !isClosing ? 0 : 12)

                // Optional collapsible optical console drawer
                if showLogs {
                    liveConsoleDrawer
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .bottom))
                        ))
                }

                // Whisper-quiet monochrome footer
                footerBar
                    .padding(.horizontal, 20)
                    .padding(.top, showLogs ? 12 : 22)
                    .padding(.bottom, 16)
                    .opacity(appeared && !isClosing ? 1.0 : 0.0)
            }
            .ignoresSafeArea(.container, edges: .top)
            .blur(radius: showSettings ? 3.5 : 0)
            .scaleEffect(showSettings ? 0.985 : 1.0)

            // 4. In-Window Smoked-Obsidian Glass Control Overlay (Replaces Stock Sheet)
            if showSettings {
                StudioOptionsOverlay(controller: controller, isPresented: $showSettings)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .center)),
                        removal: .opacity.combined(with: .scale(scale: 0.97, anchor: .center))
                    ))
                    .zIndex(20)
            }
        }
        .frame(width: 400)
        .fixedSize(horizontal: true, vertical: true)
        .preferredColorScheme(controller.appearanceMode.colorScheme)
        .animation(.spring(response: 0.44, dampingFraction: 0.86), value: controller.isRunning)
        .animation(.spring(response: 0.36, dampingFraction: 0.86), value: showLogs)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showSettings)
        .animation(.easeOut(duration: 0.24), value: isClosing)
        .animation(.easeInOut(duration: 0.24), value: controller.conciseStatusLine)
        .animation(.easeInOut(duration: 0.28), value: controller.appearanceMode)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.88).delay(0.10)) {
                appeared = true
            }
        }
        .alert("关闭官方 Antigravity？", isPresented: $controller.showQuitOfficialConfirmation) {
            Button("关闭并继续") {
                controller.quitOfficialAndContinue()
            }
            Button("取消", role: .cancel) {
                controller.pendingOperationAfterQuit = nil
            }
        } message: {
            Text("创建或同步中文副本前需先退出正在运行的官方客户端。")
        }
        .alert("还原官方原版？", isPresented: $controller.showRestoreConfirmation) {
            Button("还原", role: .destructive) {
                controller.confirmAndRunRestore()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将恢复官方未汉化的 app.asar 并同步签名。")
        }
        .alert("卸载独立中文副本？", isPresented: $controller.showRemoveCopyConfirmation) {
            Button("移至废纸篓", role: .destructive) {
                controller.trashChineseCopy()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将把 ~/Applications/Antigravity 中文.app 移至废纸篓，官方原版与个人数据不受影响。")
        }
        .alert("完全清理数据与缓存？", isPresented: $controller.showFullResetConfirmation) {
            Button("完全清理", role: .destructive) {
                controller.fullResetAndClean()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将移除中文副本及 ~/.antigravity-zh 下的备份、状态与日志。官方 Antigravity 与账号数据不受影响。")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard !controller.isRunning else { return }
            Task { await controller.refreshEnvironment() }
        }
    }

    // MARK: - Titlebar Chrome

    private var titlebarChrome: some View {
        HStack(spacing: 4) {
            Spacer()

            Button {
                MacHaptics.tap()
                withAnimation(.easeInOut(duration: 0.28)) {
                    controller.appearanceMode = controller.appearanceMode.nextMode
                }
            } label: {
                Image(systemName: controller.appearanceMode.symbol)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(ChromeIconButtonStyle())
            .help("外观：\(controller.appearanceMode.title)")

            Button {
                MacHaptics.tap()
                withAnimation(.easeInOut(duration: 0.55)) {
                    refreshRotation += 360
                }
                Task { await controller.refreshEnvironment() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(refreshRotation))
            }
            .buttonStyle(ChromeIconButtonStyle())
            .disabled(controller.isRunning)
            .help("刷新 (⌘R)")

            Button {
                MacHaptics.tap()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .buttonStyle(ChromeIconButtonStyle())
            .help("设置 (⌘,)")
        }
        .padding(.horizontal, 12)
        .padding(.top, 5)
        .frame(height: 32)
    }

    // MARK: - Idle Primary Pill

    private var idlePrimarySlot: some View {
        Button {
            controller.handlePrimaryAction()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: controller.primaryButtonSymbol)
                    .font(.system(size: 11.5, weight: .semibold))
                Text(controller.primaryButtonTitle)
            }
        }
        .buttonStyle(StudioPrimaryButtonStyle(isDisabled: controller.readiness == .scanning))
        .disabled(controller.readiness == .scanning)
        .onHover { hovering in
            ctaHovered = hovering
        }
        .keyboardShortcut(.return, modifiers: .command)
    }

    // MARK: - Running Kinetic Progress Module

    private var runningProgressSlot: some View {
        VStack(spacing: 10) {
            HStack {
                Text(formattedElapsed(controller.elapsedSeconds))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(StudioTheme.textTertiary)
                    .monospacedDigit()

                Spacer()

                Text("\(Int((controller.progress * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(StudioTheme.textPrimary.opacity(0.88))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: 224)

            StudioOpticalProgressBar(progress: controller.progress, isActive: controller.isRunning)
                .frame(width: 224)

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(controller.stages) { stage in
                        Capsule(style: .continuous)
                            .fill(stageTickColor(stage.state))
                            .frame(width: stage.state == .active ? 18 : 6, height: 2)
                            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: stage.state)
                    }
                }

                Button("取消") {
                    MacHaptics.tap()
                    controller.cancelActiveOperation()
                }
                .buttonStyle(StudioGhostTextButtonStyle(
                    tint: StudioTheme.textTertiary,
                    hoverTint: StudioTheme.error
                ))
            }
        }
    }

    // MARK: - Quiet Monochrome Footer

    private var footerBar: some View {
        HStack(spacing: 0) {
            Button {
                MacHaptics.tap()
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    showSettings = true
                }
            } label: {
                Text(footerMetadata)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(StudioTheme.textTertiary)
                    .monospacedDigit()
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 2) {
                if controller.canReinject && controller.readiness == .ready {
                    Button("重注") {
                        MacHaptics.tap()
                        controller.requestOperation(.reinject)
                    }
                    .buttonStyle(StudioGhostTextButtonStyle())
                }

                if controller.canRestore {
                    Button("还原") {
                        MacHaptics.tap()
                        controller.requestOperation(.restore)
                    }
                    .buttonStyle(StudioGhostTextButtonStyle())
                }

                Button(showLogs ? "收起" : "详情") {
                    MacHaptics.tap()
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        showLogs.toggle()
                    }
                }
                .buttonStyle(StudioGhostTextButtonStyle(
                    tint: showLogs ? StudioTheme.textPrimary : StudioTheme.textTertiary,
                    hoverTint: StudioTheme.textPrimary
                ))
            }
        }
    }

    // MARK: - Living Optical Console Drawer (Shows Live Telemetry when Idle, Logs when Active)

    private var liveConsoleDrawer: some View {
        VStack(spacing: 0) {
            HStack {
                Text(controller.logs.isEmpty ? "环境" : "输出")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(StudioTheme.textSecondary)

                Spacer()

                HStack(spacing: 8) {
                    if !controller.logs.isEmpty {
                        Button(copiedFeedback ? "已复制" : "复制") {
                            controller.copyLogsToPasteboard()
                            withAnimation(.easeOut(duration: 0.16)) {
                                copiedFeedback = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    copiedFeedback = false
                                }
                            }
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(copiedFeedback ? StudioTheme.ready : StudioTheme.textSecondary)
                        .buttonStyle(.plain)
                    } else {
                        Button("定位…") {
                            MacHaptics.tap()
                            controller.locateOfficialApp()
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(StudioTheme.textSecondary)
                        .buttonStyle(.plain)
                    }

                    Button("目录") {
                        MacHaptics.tap()
                        controller.openLogsDirectory()
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(StudioTheme.textSecondary)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle()
                .fill(StudioTheme.hairline)
                .frame(height: 0.5)

            if controller.logs.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(controller.telemetryPairs.enumerated()), id: \.offset) { _, pair in
                        HStack(spacing: 8) {
                            Text(pair.0)
                                .font(.system(size: 10.5))
                                .foregroundStyle(StudioTheme.textTertiary)
                                .frame(width: 48, alignment: .leading)
                            Text(pair.1)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(StudioTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 3.5) {
                            ForEach(controller.logs) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(entry.timestamp)
                                        .font(.system(size: 9.5, design: .monospaced))
                                        .foregroundStyle(StudioTheme.textTertiary)
                                        .monospacedDigit()
                                    Text(entry.level.prefixSymbol)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(entry.level.color)
                                        .frame(width: 9)
                                    Text(entry.message)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(entry.level == .error ? StudioTheme.error : StudioTheme.textSecondary)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .frame(height: 128)
                    .onChange(of: controller.logs.count) { _, _ in
                        if let last = controller.logs.last {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .studioPanel(cornerRadius: 12, fill: StudioTheme.surfaceDeep)
    }

    // MARK: - Helpers

    private var statusLineColor: Color {
        if let outcome = controller.outcome, !outcome.succeeded, !controller.isRunning {
            return StudioTheme.error
        }
        if controller.officialBlocksCopy && !controller.isRunning {
            return StudioTheme.attention
        }
        return StudioTheme.textSecondary
    }

    private func stageTickColor(_ state: StepState) -> Color {
        switch state {
        case .completed: return StudioTheme.textPrimary.opacity(0.55)
        case .active: return StudioTheme.prismBlue
        case .failed: return StudioTheme.error
        case .pending: return StudioTheme.controlTrack
        }
    }

    private func formattedElapsed(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var footerMetadata: String {
        var parts: [String] = []
        if controller.snapshot.dictionaryCount > 0 {
            let fmt = NumberFormatter()
            fmt.numberStyle = .decimal
            let s = fmt.string(from: NSNumber(value: controller.snapshot.dictionaryCount)) ?? "\(controller.snapshot.dictionaryCount)"
            parts.append(s)
        }
        parts.append("v\(controller.snapshot.toolkitVersion)")
        if controller.targetMode == .inPlace {
            parts.append("原位")
        }
        return parts.joined(separator: " · ")
    }
}
