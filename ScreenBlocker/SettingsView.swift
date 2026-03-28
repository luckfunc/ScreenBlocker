import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: ScreenBlockerCoordinator

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    blockRatioSection
                    Divider()
                    togglesSection
                    Divider()
                    statusSection
                }
                .padding(24)
            }
        }
        .frame(width: 420, height: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Block Ratio

    private var blockRatioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("遮挡高度", systemImage: "arrow.up.and.down.text.horizontal")
                .font(.headline)

            HStack {
                Text("10%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { coordinator.displayedBlockRatio },
                        set: { coordinator.previewBlockRatio($0) }
                    ),
                    in: SettingsManager.blockRatioRange,
                    step: 0.01,
                    onEditingChanged: coordinator.setBlockRatioEditing
                )
                Text("80%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Text("当前：占屏幕上方 \(Int(coordinator.displayedBlockRatio * 100))%")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.85, green: 0.47, blue: 0.34))
                Spacer()
            }

            if let screen = coordinator.portraitScreen {
                HStack {
                    Spacer()
                    let blockedPx = Int(screen.frame.height * coordinator.displayedBlockRatio)
                    let usablePx = Int(screen.frame.height) - blockedPx
                    Text("遮挡 \(blockedPx)px · 可用 \(usablePx)px（共 \(Int(screen.frame.width))×\(Int(screen.frame.height))）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Toggles

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("通用设置", systemImage: "gearshape")
                .font(.headline)

            Toggle(
                "登录时自动启动",
                isOn: Binding(
                    get: { coordinator.settings.launchAtLogin },
                    set: { coordinator.settings.launchAtLogin = $0 }
                )
            )
            Toggle(
                "显示菜单栏图标",
                isOn: Binding(
                    get: { coordinator.settings.showMenuBarIcon },
                    set: { coordinator.settings.showMenuBarIcon = $0 }
                )
            )

            if !coordinator.settings.showMenuBarIcon {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text("隐藏后可通过重新打开应用恢复菜单栏图标")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("状态", systemImage: "info.circle")
                .font(.headline)

            HStack {
                Circle()
                    .fill(coordinator.hasAccessibilityPermission ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(coordinator.hasAccessibilityPermission ? "辅助功能权限已授权" : "辅助功能权限未授权")
                    .font(.callout)
                if !coordinator.hasAccessibilityPermission {
                    Button("去授权") { coordinator.requestAccessibility() }
                        .font(.callout)
                }
            }

            HStack {
                Circle()
                    .fill(coordinator.portraitScreen != nil ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(coordinator.portraitScreen != nil ? "已检测到竖屏显示器" : "未检测到竖屏显示器")
                    .font(.callout)
            }
        }
    }
}
