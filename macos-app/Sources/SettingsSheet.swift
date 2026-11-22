import SwiftUI

struct StudioOptionsOverlay: View {
    @ObservedObject var controller: PatchController
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Subtle backdrop scrim (live interactive particles shimmer softly behind)
            StudioTheme.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    closeDrawer()
                }

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    AntigravityArchShape()
                        .fill(
                            LinearGradient(
                                colors: [StudioTheme.prismBlue, StudioTheme.prismGreen, StudioTheme.prismYellow, StudioTheme.prismRed],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 15, height: 15)

                    Text("设置")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(StudioTheme.textPrimary)

                    Spacer()

                    Button {
                        closeDrawer()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .buttonStyle(ChromeIconButtonStyle())
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, 16)
                .padding(.top, 13)
                .padding(.bottom, 10)

                Rectangle()
                    .fill(StudioTheme.hairline)
                    .frame(height: 0.5)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        // 1. Appearance (Auto / Light / Dark)
                        VStack(alignment: .leading, spacing: 6) {
                            sectionHeader("外观")
                            StudioSegmentedControl(
                                options: AppAppearanceMode.allCases,
                                selection: $controller.appearanceMode,
                                title: { $0.title }
                            )
                        }

                        // 2. Localization Mode + Client Location + Startup Check
                        VStack(alignment: .leading, spacing: 6) {
                            sectionHeader("汉化")
                            StudioSegmentedControl(
                                options: PatchTargetMode.allCases,
                                selection: $controller.targetMode,
                                title: { $0.shortLabel },
                                disabled: controller.isRunning
                            )

                            VStack(spacing: 0) {
                                HStack(spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(
                                            controller.snapshot.officialInstalled
                                                ? "Antigravity \(controller.snapshot.officialVersion)"
                                                : "未找到官方应用"
                                        )
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(controller.snapshot.officialInstalled ? StudioTheme.textPrimary : StudioTheme.attention)

                                        Text((controller.snapshot.officialPath as NSString).abbreviatingWithTildeInPath)
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .foregroundStyle(StudioTheme.textTertiary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }

                                    Spacer(minLength: 4)

                                    if !controller.customOfficialAppPath.isEmpty {
                                        Button("自动") {
                                            controller.resetOfficialAppLocation()
                                        }
                                        .buttonStyle(StudioGhostTextButtonStyle(
                                            tint: StudioTheme.textTertiary,
                                            hoverTint: StudioTheme.textPrimary
                                        ))
                                    }

                                    Button("更改") {
                                        MacHaptics.tap()
                                        controller.locateOfficialApp()
                                    }
                                    .buttonStyle(StudioGhostTextButtonStyle(
                                        tint: StudioTheme.textPrimary,
                                        hoverTint: StudioTheme.textPrimary
                                    ))
                                    .disabled(controller.isRunning)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9.5)

                                dividerLine

                                HStack {
                                    Text("启动检查")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundStyle(StudioTheme.textPrimary)
                                    Spacer()
                                    StudioSwitch(
                                        isOn: Binding(
                                            get: { !controller.skipSmokeTest },
                                            set: { controller.skipSmokeTest = !$0 }
                                        ),
                                        disabled: controller.isRunning
                                    )
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                            }
                            .studioPanel(cornerRadius: 11, fill: StudioTheme.surface)
                        }

                        // 3. Management & Uninstall / Rollback
                        VStack(alignment: .leading, spacing: 6) {
                            sectionHeader("管理")
                            VStack(spacing: 0) {
                                if controller.snapshot.officialRunning {
                                    StudioActionRow(
                                        title: controller.isQuittingOfficial ? "正在退出 Antigravity…" : "退出 Antigravity",
                                        symbol: "power",
                                        tint: StudioTheme.attention,
                                        enabled: !controller.isQuittingOfficial && !controller.isRunning
                                    ) {
                                        controller.quitOfficialAppOnly()
                                    }
                                    dividerLine
                                }

                                StudioActionRow(
                                    title: "在访达中显示",
                                    symbol: "folder",
                                    enabled: controller.snapshot.copyExists || controller.snapshot.officialInstalled
                                ) {
                                    let target = controller.snapshot.copyExists
                                        ? controller.snapshot.copyPath
                                        : controller.snapshot.officialPath
                                    controller.revealInFinder(path: target)
                                }

                                dividerLine

                                StudioActionRow(
                                    title: "还原英文版",
                                    symbol: "arrow.uturn.backward",
                                    enabled: controller.canRestore
                                ) {
                                    closeDrawer()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                        controller.requestOperation(.restore)
                                    }
                                }

                                if controller.snapshot.copyExists {
                                    dividerLine
                                    StudioActionRow(
                                        title: "卸载中文版",
                                        symbol: "trash",
                                        tint: StudioTheme.attention,
                                        enabled: !controller.isRunning
                                    ) {
                                        closeDrawer()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                            controller.showRemoveCopyConfirmation = true
                                        }
                                    }
                                }

                                dividerLine

                                StudioActionRow(
                                    title: "清理备份与缓存",
                                    symbol: "xmark.bin",
                                    tint: StudioTheme.error,
                                    enabled: !controller.isRunning
                                ) {
                                    closeDrawer()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                                        controller.showFullResetConfirmation = true
                                    }
                                }
                            }
                            .studioPanel(cornerRadius: 11, fill: StudioTheme.surface)
                        }
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: 364, maxHeight: 382)
            .studioPanel(cornerRadius: 16, fill: StudioTheme.surfaceOverlay)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.62 : 0.16),
                radius: 26,
                x: 0,
                y: 10
            )
            .padding(.top, 26)
            .padding(.bottom, 14)
        }
    }

    private func closeDrawer() {
        MacHaptics.tap()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            isPresented = false
        }
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(StudioTheme.hairline)
            .frame(height: 0.5)
            .padding(.leading, 12)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(StudioTheme.textTertiary)
            .padding(.leading, 4)
    }
}
