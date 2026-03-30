import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var settings: SettingsManager
    @ObservedObject private var windowController: BlockerWindowController
    @ObservedObject private var windowWatcher: WindowWatcher

    @StateObject private var interactions: SettingsInteractionController

    init(
        windowController: BlockerWindowController,
        windowWatcher: WindowWatcher,
        settings: SettingsManager = .shared
    ) {
        self._settings = ObservedObject(wrappedValue: settings)
        self._windowController = ObservedObject(wrappedValue: windowController)
        self._windowWatcher = ObservedObject(wrappedValue: windowWatcher)
        self._interactions = StateObject(
            wrappedValue: SettingsInteractionController(
                settings: settings,
                windowWatcher: windowWatcher
            )
        )
    }

    var body: some View {
        ZStack {
            WindowMaterialView()
                .ignoresSafeArea()

            backgroundAtmosphere
                .ignoresSafeArea()

            VStack(spacing: 14) {
                primaryPanel
                secondaryPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 10)
            .padding(.horizontal, 18)
            .padding(.bottom, 10)
        }
        .frame(width: 420, height: 458)
        .onAppear {
            interactions.syncCommittedBlockRatio(settings.blockRatio)
        }
        .onReceive(settings.$blockRatio) { value in
            interactions.syncCommittedBlockRatio(value)
        }
    }

    private var backgroundAtmosphere: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: topGlowColor).opacity(colorScheme == .dark ? 0.24 : 0.18),
                    Color(nsColor: bottomGlowColor).opacity(colorScheme == .dark ? 0.10 : 0.06),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(nsColor: accentMistColor).opacity(colorScheme == .dark ? 0.16 : 0.12),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 24,
                endRadius: 240
            )
        }
    }

    private var primaryPanel: some View {
        SettingsPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("竖屏显示器")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text(displayDescription)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 12)

                    Text("\(percentageValue)%")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Slider(value: sliderBinding, in: SettingsManager.blockRatioRange, step: 0.01) { editing in
                            if editing {
                                interactions.beginBlockRatioInteraction()
                            } else {
                                interactions.finishBlockRatioInteraction()
                            }
                        }
                        .controlSize(.small)

                        InlinePercentStepper(
                            value: percentageValue,
                            range: 10...80
                        ) { newValue in
                            interactions.commitBlockRatio(Double(newValue) / 100, adjustmentDelay: 0.12)
                        }
                    }

                    BlockedAreaPreview(ratio: interactions.blockRatio)
                        .frame(height: 9)

                    Text(pixelDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var secondaryPanel: some View {
        SettingsPanel {
            VStack(spacing: 0) {
                ToggleRow(
                    title: "登录时自动启动",
                    subtitle: "启动时自动恢复遮挡状态",
                    isOn: launchAtLoginBinding
                )

                SettingsSeparator()

                StatusRow(
                    title: "辅助功能权限",
                    value: windowWatcher.hasAccessibilityPermission ? "已授权" : "需要授权",
                    tone: windowWatcher.hasAccessibilityPermission ? .secondary : .orange,
                    actionTitle: windowWatcher.hasAccessibilityPermission ? nil : "去授权"
                ) {
                    windowWatcher.requestAccessibility()
                }

                SettingsSeparator()

                StatusRow(
                    title: "竖屏状态",
                    value: windowController.portraitScreen != nil ? "正常" : "未检测到",
                    tone: .secondary
                )
            }
        }
    }

    private var displayDescription: String {
        guard let screen = windowController.portraitScreen else {
            return "未检测到"
        }

        return "\(Int(screen.frame.width)) × \(Int(screen.frame.height))"
    }

    private var percentageValue: Int {
        Int((interactions.blockRatio * 100).rounded())
    }

    private var pixelDescription: String {
        guard let screen = windowController.portraitScreen else {
            return "未检测到竖屏显示器"
        }

        let blockedPx = Int(screen.frame.height * interactions.blockRatio)
        let usablePx = Int(screen.frame.height) - blockedPx
        return "遮挡 \(blockedPx) px，可用 \(usablePx) px"
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { interactions.blockRatio },
            set: interactions.updateBlockRatioDraft(_:)
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: settings.setLaunchAtLogin(_:)
        )
    }

    private var topGlowColor: NSColor {
        if colorScheme == .dark {
            return NSColor(calibratedRed: 0.29, green: 0.17, blue: 0.18, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.93, green: 0.87, blue: 0.84, alpha: 1.0)
    }

    private var bottomGlowColor: NSColor {
        if colorScheme == .dark {
            return NSColor(calibratedRed: 0.18, green: 0.15, blue: 0.19, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.91, green: 0.92, blue: 0.95, alpha: 1.0)
    }

    private var accentMistColor: NSColor {
        if colorScheme == .dark {
            return NSColor(calibratedRed: 0.54, green: 0.28, blue: 0.28, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.84, green: 0.77, blue: 0.74, alpha: 1.0)
    }
}

final class SettingsInteractionController: ObservableObject {
    @Published private(set) var blockRatio: Double

    private let settings: SettingsManager
    private weak var windowWatcher: WindowWatcher?
    private var isInteracting = false

    init(
        settings: SettingsManager,
        windowWatcher: WindowWatcher
    ) {
        self.settings = settings
        self.windowWatcher = windowWatcher
        self.blockRatio = settings.blockRatio
    }

    func syncCommittedBlockRatio(_ value: Double) {
        guard !isInteracting else { return }
        blockRatio = SettingsManager.clampedBlockRatio(value)
    }

    func beginBlockRatioInteraction() {
        isInteracting = true
        windowWatcher?.pause()
    }

    func updateBlockRatioDraft(_ value: Double) {
        blockRatio = SettingsManager.clampedBlockRatio(value)
    }

    func finishBlockRatioInteraction() {
        isInteracting = false
        commitBlockRatio(blockRatio, adjustmentDelay: 0.35)
    }

    func commitBlockRatio(_ value: Double, adjustmentDelay: TimeInterval) {
        blockRatio = SettingsManager.clampedBlockRatio(value)
        settings.setBlockRatio(blockRatio)
        windowWatcher?.resume(applyPendingAdjustment: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + adjustmentDelay) { [weak self] in
            self?.windowWatcher?.adjustAllWindows()
        }
    }
}

private struct SettingsPanel<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.05), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.04), radius: 10, y: 4)
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
    }
}

private struct StatusRow: View {
    let title: String
    let value: String
    let tone: Color
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))

                Text(value)
                    .font(.caption)
                    .foregroundStyle(tone)
            }

            Spacer(minLength: 12)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SettingsSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, 10)
    }
}

private struct InlinePercentStepper: View {
    @Environment(\.colorScheme) private var colorScheme

    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            button(symbol: "minus", disabled: value <= range.lowerBound) {
                onChange(max(range.lowerBound, value - 1))
            }

            divider

            Text("\(value)%")
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .frame(minWidth: 44)

            divider

            button(symbol: "plus", disabled: value >= range.upperBound) {
                onChange(min(range.upperBound, value + 1))
            }
        }
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.07 : 0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06), lineWidth: 0.7)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.08))
            .frame(width: 1, height: 14)
    }

    private func button(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(disabled ? .tertiary : .primary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

private struct BlockedAreaPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let ratio: Double

    var body: some View {
        GeometryReader { geometry in
            let blockedWidth = geometry.size.width * ratio

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.05), lineWidth: 0.6)
                    )

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(colorScheme == .dark ? 0.30 : 0.24),
                                Color.accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: blockedWidth)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.24))
                            .frame(height: 1)
                            .padding(.horizontal, 1)
                            .opacity(blockedWidth > 10 ? 1 : 0)
                    }
            }
        }
    }
}

private struct WindowMaterialView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .withinWindow
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .sidebar
        nsView.blendingMode = .withinWindow
        nsView.state = .active
        nsView.isEmphasized = false
    }
}
