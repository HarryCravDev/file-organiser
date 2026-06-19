import SwiftUI
import DigitalDeclutterCore

// MARK: - Category Style Mapping

/// Maps a category name to an SF Symbol icon and accent colour.
struct CategoryStyle {
    let icon: String
    let color: Color
}

func categoryStyle(for name: String) -> CategoryStyle {
    switch name.lowercased() {
    case "images", "image", "photos", "photo", "screenshots":
        return CategoryStyle(icon: "photo.fill", color: .purple)
    case "documents", "document", "docs":
        return CategoryStyle(icon: "doc.text.fill", color: .blue)
    case "installers", "installer":
        return CategoryStyle(icon: "shippingbox.fill", color: .orange)
    case "audio", "music":
        return CategoryStyle(icon: "music.note", color: .pink)
    case "video", "videos":
        return CategoryStyle(icon: "video.fill", color: .red)
    case "archives", "archive", "compressed":
        return CategoryStyle(icon: "archivebox.fill", color: Color(red: 0.6, green: 0.4, blue: 0.2))
    case "code", "development", "dev":
        return CategoryStyle(icon: "curlybraces", color: .green)
    case "spreadsheets", "spreadsheet":
        return CategoryStyle(icon: "tablecells.fill", color: .teal)
    default:
        return CategoryStyle(icon: "folder.fill", color: .indigo)
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @Binding var config: Configuration
    /// Optional callback invoked when the user taps "Run Now" in the Settings header.
    var onRunNow: (() -> Void)? = nil

    @State private var activeTab: Tab = .folders
    @State private var editingRule: OrganizationRule?
    @State private var showingRuleEditor = false

    // Hover tracking
    @State private var hoveredFolder: String? = nil
    @State private var hoveredRule: String? = nil

    // Deletion confirmation
    @State private var pendingDeleteFolder: String? = nil
    @State private var pendingDeleteRule: OrganizationRule? = nil

    // Saved indicator
    @State private var showSaved = false

    enum Tab { case folders, rules, automation }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ZStack {
                Color(NSColor.underPageBackgroundColor)
                    .ignoresSafeArea()

                switch activeTab {
                case .folders:
                    foldersTab
                        .transition(.asymmetric(insertion: .push(from: .leading), removal: .push(from: .trailing)))
                case .rules:
                    rulesTab
                        .transition(.opacity)
                case .automation:
                    automationTab
                        .transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .leading)))
                }
            }
            .animation(.spring(duration: 0.25), value: activeTab)
        }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows {
                if window.title.contains("Declutter") || window.title.contains("Preferences") {
                    window.orderFrontRegardless()
                    window.makeKey()
                }
            }
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
        .sheet(isPresented: $showingRuleEditor) {
            RuleEditorSheet(rule: editingRule) { savedRule in
                saveRule(savedRule)
                showingRuleEditor = false
            } onCancel: {
                showingRuleEditor = false
            }
            .id(editingRule?.category ?? "new-rule")
        }
        // Delete folder confirmation
        .confirmationDialog(
            "Remove Watched Folder",
            isPresented: Binding(
                get: { pendingDeleteFolder != nil },
                set: { if !$0 { pendingDeleteFolder = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Folder", role: .destructive) {
                if let path = pendingDeleteFolder { removeFolder(path) }
                pendingDeleteFolder = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteFolder = nil }
        } message: {
            Text("This folder will no longer be scanned by DigitalDeclutter.")
        }
        // Delete rule confirmation
        .confirmationDialog(
            "Delete Rule",
            isPresented: Binding(
                get: { pendingDeleteRule != nil },
                set: { if !$0 { pendingDeleteRule = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Rule", role: .destructive) {
                if let rule = pendingDeleteRule { deleteRule(rule) }
                pendingDeleteRule = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteRule = nil }
        } message: {
            if let rule = pendingDeleteRule {
                Text("The \"\(rule.category)\" rule will be permanently deleted.")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            // App icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.18), .blue.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("DigitalDeclutter")
                    .font(.system(size: 16, weight: .bold))
                Text("Automatic macOS Directory Organizer")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // "Saved" flash indicator
            if showSaved {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Saved")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // Run Now button (only shown when callback is provided)
            if let runNow = onRunNow {
                Button(action: runNow) {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text("Run Now")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(colors: [.green, .teal], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            // Tab switcher
            HStack(spacing: 4) {
                TabButton(title: "Folders", icon: "folder", isActive: activeTab == .folders) {
                    activeTab = .folders
                }
                TabButton(title: "Rules", icon: "slider.horizontal.3", isActive: activeTab == .rules) {
                    activeTab = .rules
                }
                TabButton(title: "Automation", icon: "cpu", isActive: activeTab == .automation) {
                    activeTab = .automation
                }
            }
            .padding(4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Folders Tab

    private var foldersTab: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Watched Folders")
                    .font(.headline)
                Spacer()
                CountBadge(count: config.sourceSubpaths.count)
            }
            .padding(.horizontal)
            .padding(.top)

            if config.sourceSubpaths.isEmpty {
                EmptyStateView(
                    icon: "folder.badge.questionmark",
                    title: "No Folders Watched",
                    subtitle: "Add a folder to start organizing your files automatically.",
                    accentColor: .blue
                )
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(config.sourceSubpaths, id: \.self) { path in
                            folderRow(for: path)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            Spacer()

            // Add Folder button — Cmd+N activates it while this tab is visible
            Button(action: addFolder) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Folder…")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding([.horizontal, .bottom])
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    private func folderRow(for path: String) -> some View {
        let isHovered = hoveredFolder == path
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: folderIcon(for: path))
                    .font(.system(size: 17))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(folderName(for: path))
                    .font(.system(size: 13, weight: .semibold))
                Text(abbreviatePath(path))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { pendingDeleteFolder = path }) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(7)
            .background(Color.red.opacity(0.1))
            .clipShape(Circle())
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHovered ? Color.blue.opacity(0.35) : Color.primary.opacity(0.05),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .shadow(color: isHovered ? Color.blue.opacity(0.12) : .clear, radius: 8, y: 3)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { hoveredFolder = $0 ? path : nil }
    }

    // MARK: - Rules Tab

    private var rulesTab: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Organization Rules")
                    .font(.headline)
                Spacer()
                CountBadge(count: config.rules.count)
            }
            .padding(.horizontal)
            .padding(.top)

            if config.rules.isEmpty {
                EmptyStateView(
                    icon: "slider.horizontal.3",
                    title: "No Rules Configured",
                    subtitle: "Add a rule to tell DigitalDeclutter where to move your files.",
                    accentColor: .indigo
                )
            } else {
                List {
                    ForEach(config.rules, id: \.category) { rule in
                        ruleRow(for: rule)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                    .onMove { indices, newOffset in
                        config.rules.move(fromOffsets: indices, toOffset: newOffset)
                        persistAndFlash()
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Spacer()

            // Add Rule button — Cmd+N activates it while this tab is visible
            Button(action: {
                editingRule = nil
                showingRuleEditor = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Rule…")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding([.horizontal, .bottom])
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    private func ruleRow(for rule: OrganizationRule) -> some View {
        let style = categoryStyle(for: rule.category)
        let isHovered = hoveredRule == rule.category

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Category icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(style.color.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: style.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(style.color)
                }

                Text(rule.category)
                    .font(.system(size: 14, weight: .bold))

                Spacer()

                // Destination path chip
                Text(abbreviatePath(rule.destinationSubpath))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                    .help(rule.destinationSubpath)

                // Action buttons
                HStack(spacing: 6) {
                    Button(action: {
                        editingRule = rule
                        showingRuleEditor = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())

                    Button(action: { pendingDeleteRule = rule }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Circle())
                }
            }

            // Extension chips tinted with the category colour
            FlowLayout(spacing: 6) {
                ForEach(Array(rule.extensions).sorted(), id: \.self) { ext in
                    Text(".\(ext)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(style.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(style.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isHovered ? style.color.opacity(0.4) : Color.primary.opacity(0.05),
                    lineWidth: isHovered ? 1.5 : 1
                )
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .shadow(color: isHovered ? style.color.opacity(0.12) : .clear, radius: 8, y: 3)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { hoveredRule = $0 ? rule.category : nil }
    }

    // MARK: - Helpers

    private func folderName(for path: String) -> String {
        if path.hasSuffix("Desktop") { return "Desktop" }
        if path.hasSuffix("Downloads") { return "Downloads" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func folderIcon(for path: String) -> String {
        if path.hasSuffix("Desktop") { return "desktopcomputer" }
        if path.hasSuffix("Downloads") { return "arrow.down.circle.fill" }
        return "folder.fill"
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.resolvesAliases = true
        panel.title = "Select Folder to Declutter"

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            if !config.sourceSubpaths.contains(path) {
                config.sourceSubpaths.append(path)
                persistAndFlash()
            }
        }
    }

    private func removeFolder(_ path: String) {
        config.sourceSubpaths.removeAll { $0 == path }
        persistAndFlash()
    }

    private func saveRule(_ savedRule: OrganizationRule) {
        if let index = config.rules.firstIndex(where: { $0.category == savedRule.category }) {
            config.rules[index] = savedRule
        } else {
            config.rules.append(savedRule)
        }
        persistAndFlash()
    }

    private func deleteRule(_ rule: OrganizationRule) {
        config.rules.removeAll { $0.category == rule.category }
        persistAndFlash()
    }

    /// Persist current config and briefly flash the "Saved" indicator.
    private func persistAndFlash() {
        Persistence.saveConfiguration(config)
        withAnimation(.spring(duration: 0.3)) { showSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.4)) { showSaved = false }
        }
    }

    // MARK: - Automation Tab

    private var automationTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Automation Settings")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Main Toggle Row
                    HStack {
                        Image(systemName: "cpu")
                            .font(.system(size: 24))
                            .foregroundStyle(config.isAutomationEnabled ? .green : .secondary)
                            .symbolEffect(.bounce, value: config.isAutomationEnabled)
                            .frame(width: 32, height: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Automatic Decluttering")
                                .font(.headline)
                            Text("Let DigitalDeclutter organize your folders silently in the background.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { config.isAutomationEnabled },
                            set: { config.isAutomationEnabled = $0; persistAndFlash() }
                        ))
                        .toggleStyle(.switch)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    if config.isAutomationEnabled {
                        // Trigger Method Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trigger Method")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Picker("", selection: Binding(
                                get: { config.automationType },
                                set: { config.automationType = $0; persistAndFlash() }
                            )) {
                                Text("Real-Time (When a file is added)").tag(AutomationType.realTime)
                                Text("Scheduled Interval (Periodically)").tag(AutomationType.scheduled)
                            }
                            .pickerStyle(.radioGroup)
                            .padding(.leading, 8)
                            
                            if config.automationType == .scheduled {
                                Divider()
                                    .padding(.vertical, 4)
                                
                                HStack {
                                    Text("Run Every:")
                                        .font(.subheadline)
                                    Spacer()
                                    Picker("", selection: Binding(
                                        get: { config.scheduleIntervalMinutes },
                                        set: { config.scheduleIntervalMinutes = $0; persistAndFlash() }
                                    )) {
                                        Text("1 Minute (Testing)").tag(1)
                                        Text("5 Minutes").tag(5)
                                        Text("15 Minutes").tag(15)
                                        Text("30 Minutes").tag(30)
                                        Text("1 Hour").tag(60)
                                        Text("3 Hours").tag(180)
                                        Text("6 Hours").tag(360)
                                        Text("12 Hours").tag(720)
                                        Text("24 Hours").tag(1440)
                                    }
                                    .frame(width: 180)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)
            .font(.system(size: 12, weight: isActive ? .semibold : .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? Color(NSColor.selectedContentBackgroundColor) : Color.clear)
            .foregroundColor(isActive ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Count Badge

struct CountBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.55))
            .clipShape(Capsule())
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 74, height: 74)
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(accentColor.opacity(0.7))
            }
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Flow Layout for Extension Tags

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var maxRowHeight: CGFloat = 0

        for size in sizes {
            if currentX + size.width > width {
                currentX = 0
                currentY += maxRowHeight + spacing
                maxRowHeight = 0
            }
            maxRowHeight = max(maxRowHeight, size.height)
            currentX += size.width + spacing
        }
        height = currentY + maxRowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = bounds.width
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var maxRowHeight: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = sizes[index]
            if currentX + size.width > width + bounds.minX {
                currentX = bounds.minX
                currentY += maxRowHeight + spacing
                maxRowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            maxRowHeight = max(maxRowHeight, size.height)
            currentX += size.width + spacing
        }
    }
}

// MARK: - Rule Editor Sheet

struct RuleEditorSheet: View {
    let rule: OrganizationRule?
    var onSave: (OrganizationRule) -> Void
    var onCancel: () -> Void

    @State private var category = ""
    @State private var extensionsText = ""
    @State private var destinationSubpath = ""
    @State private var validationAttempted = false

    init(rule: OrganizationRule?, onSave: @escaping (OrganizationRule) -> Void, onCancel: @escaping () -> Void) {
        self.rule = rule
        self.onSave = onSave
        self.onCancel = onCancel

        _category = State(initialValue: rule?.category ?? "")
        _destinationSubpath = State(initialValue: rule?.destinationSubpath ?? "")
        let initialExtensions = rule?.extensions.sorted().joined(separator: ", ") ?? ""
        _extensionsText = State(initialValue: initialExtensions)
    }

    private var parsedExtensions: [String] {
        extensionsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: ".", with: "") }
            .filter { !$0.isEmpty }
    }

    private var canSave: Bool {
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !parsedExtensions.isEmpty
            && !destinationSubpath.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sheet header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: rule == nil ? "plus.square.fill" : "pencil.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.blue)
                }
                Text(rule == nil ? "Add Custom Rule" : "Edit Organization Rule")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
            }
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 18) {

                // Category Name
                formField(label: "Category Name", required: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("e.g. Archives, Audio, Video", text: $category)
                            .textFieldStyle(.roundedBorder)
                            .disabled(rule != nil)
                            .help(rule != nil ? "Category name cannot be changed for existing rules." : "")

                        if validationAttempted && category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            validationLabel("Category name is required.")
                        }
                    }
                }

                // File Extensions
                formField(label: "File Extensions", required: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("e.g. zip, rar, tar, gz", text: $extensionsText)
                            .textFieldStyle(.roundedBorder)

                        if validationAttempted && parsedExtensions.isEmpty {
                            validationLabel("Add at least one file extension.")
                        } else {
                            Text("Comma-separated list, without leading dots.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        // Live preview of parsed extension chips
                        if !parsedExtensions.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(parsedExtensions, id: \.self) { ext in
                                    Text(".\(ext)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 5))
                                }
                            }
                            .animation(.spring(duration: 0.2), value: parsedExtensions.count)
                        }
                    }
                }

                // Destination Folder
                formField(label: "Destination Folder", required: true) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            // Styled read-only path display
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(destinationSubpath.isEmpty ? .secondary : .blue)
                                Text(destinationSubpath.isEmpty ? "No folder selected" : abbreviatePath(destinationSubpath))
                                    .font(.system(size: 12))
                                    .foregroundStyle(destinationSubpath.isEmpty ? .secondary : .primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                if !destinationSubpath.isEmpty {
                                    Button(action: { destinationSubpath = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(
                                        validationAttempted && destinationSubpath.isEmpty
                                            ? Color.red.opacity(0.5)
                                            : Color.primary.opacity(0.15),
                                        lineWidth: 1
                                    )
                            )

                            Button(action: selectDestinationFolder) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.badge.plus")
                                    Text("Choose…")
                                }
                                .font(.system(size: 12))
                            }
                        }

                        if validationAttempted && destinationSubpath.isEmpty {
                            validationLabel("Please select a destination folder.")
                        }
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Spacer()

                Button(action: attemptSave) {
                    Text(rule == nil ? "Add Rule" : "Save Rule")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: canSave ? [.blue, .cyan] : [Color.gray, Color.gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(24)
        .frame(width: 460, height: 410)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }

    // MARK: - Form Helpers

    @ViewBuilder
    private func formField<Content: View>(
        label: String,
        required: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                if required {
                    Text("*")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
            content()
        }
    }

    private func validationLabel(_ message: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10))
            Text(message)
                .font(.system(size: 10))
        }
        .foregroundStyle(.red)
    }

    private func attemptSave() {
        validationAttempted = true
        guard canSave else { return }
        let newRule = OrganizationRule(
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            extensions: Set(parsedExtensions),
            destinationSubpath: destinationSubpath
        )
        onSave(newRule)
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func selectDestinationFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.resolvesAliases = true
        panel.title = "Select Destination Folder"

        if panel.runModal() == .OK, let url = panel.url {
            destinationSubpath = url.path
        }
    }
}
