import SwiftUI
import DigitalDeclutterCore

struct SettingsView: View {
    @Binding var config: Configuration
    @State private var activeTab: Tab = .folders
    @State private var editingRule: OrganizationRule?
    @State private var showingRuleEditor = false

    enum Tab {
        case folders
        case rules
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("DigitalDeclutter")
                        .font(.system(size: 20, weight: .bold))
                    Text("Automatic macOS Directory Organizer")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Tab Switcher
                HStack(spacing: 4) {
                    TabButton(title: "Folders", icon: "folder", isActive: activeTab == .folders) {
                        activeTab = .folders
                    }
                    
                    TabButton(title: "Rules", icon: "slider.horizontal.3", isActive: activeTab == .rules) {
                        activeTab = .rules
                    }
                }
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()

            // Main Content Area
            ZStack {
                Color(NSColor.underPageBackgroundColor)
                    .ignoresSafeArea()

                switch activeTab {
                case .folders:
                    foldersTab
                        .transition(.asymmetric(insertion: .push(from: .leading), removal: .push(from: .trailing)))
                case .rules:
                    rulesTab
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
    }

    // MARK: - Folders Tab

    private var foldersTab: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Watched Folders")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(config.sourceSubpaths.count) active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(config.sourceSubpaths, id: \.self) { path in
                        HStack(spacing: 12) {
                            Image(systemName: folderIcon(for: path))
                                .font(.system(size: 18))
                                .foregroundStyle(.blue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(folderName(for: path))
                                    .font(.system(size: 13, weight: .medium))
                                Text(abbreviatePath(path))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()

                            Button(action: {
                                removeFolder(path)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(6)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Add Folder Button
            Button(action: addFolder) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Folder...")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    // MARK: - Rules Tab

    private var rulesTab: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Organization Rules")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(config.rules.count) active")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.top)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(config.rules, id: \.category) { rule in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(rule.category)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(abbreviatePath(rule.destinationSubpath))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(Capsule())
                                    .help(rule.destinationSubpath)

                                HStack(spacing: 4) {
                                    Button(action: {
                                        editingRule = rule
                                        showingRuleEditor = true
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(6)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                                    
                                    Button(action: {
                                        deleteRule(rule)
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(6)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Circle())
                                }
                            }

                            // Extensions list
                            FlowLayout(spacing: 6) {
                                ForEach(Array(rule.extensions).sorted(), id: \.self) { ext in
                                    Text(".\(ext)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Add Rule Button
            Button(action: {
                editingRule = nil
                showingRuleEditor = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Custom Rule...")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding()
        }
    }

    // MARK: - Helpers

    private func folderName(for path: String) -> String {
        if path.hasSuffix("Desktop") { return "Desktop" }
        if path.hasSuffix("Downloads") { return "Downloads" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func folderIcon(for path: String) -> String {
        if path.hasSuffix("Desktop") { return "desktopcomputer" }
        if path.hasSuffix("Downloads") { return "arrow.down.circle" }
        return "folder"
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

        if panel.runModal() == .OK {
            if let url = panel.url {
                let path = url.path
                if !config.sourceSubpaths.contains(path) {
                    config.sourceSubpaths.append(path)
                    Persistence.saveConfiguration(config)
                }
            }
        }
    }

    private func removeFolder(_ path: String) {
        config.sourceSubpaths.removeAll { $0 == path }
        Persistence.saveConfiguration(config)
    }

    private func saveRule(_ savedRule: OrganizationRule) {
        if let index = config.rules.firstIndex(where: { $0.category == savedRule.category }) {
            config.rules[index] = savedRule
        } else {
            config.rules.append(savedRule)
        }
        Persistence.saveConfiguration(config)
    }

    private func deleteRule(_ rule: OrganizationRule) {
        config.rules.removeAll { $0.category == rule.category }
        Persistence.saveConfiguration(config)
    }
}

// MARK: - Tab Button Component

struct TabButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
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

// MARK: - Flow Layout for Tags

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

// MARK: - Rule Editor Sheet Component

struct RuleEditorSheet: View {
    let rule: OrganizationRule? // nil if creating a new rule
    var onSave: (OrganizationRule) -> Void
    var onCancel: () -> Void

    @State private var category = ""
    @State private var extensionsText = ""
    @State private var destinationSubpath = ""

    init(rule: OrganizationRule?, onSave: @escaping (OrganizationRule) -> Void, onCancel: @escaping () -> Void) {
        self.rule = rule
        self.onSave = onSave
        self.onCancel = onCancel

        _category = State(initialValue: rule?.category ?? "")
        _destinationSubpath = State(initialValue: rule?.destinationSubpath ?? "")

        let initialExtensions = rule?.extensions.sorted().joined(separator: ", ") ?? ""
        _extensionsText = State(initialValue: initialExtensions)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text(rule == nil ? "Add Custom Rule" : "Edit Organization Rule")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {
                // Category field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Category Name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("e.g. Archives, Audio, Video", text: $category)
                        .textFieldStyle(.roundedBorder)
                        .disabled(rule != nil) // Category acts as unique name, disable editing for existing rules
                }

                // Extensions field
                VStack(alignment: .leading, spacing: 6) {
                    Text("File Extensions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("e.g. zip, rar, tar, gz", text: $extensionsText)
                        .textFieldStyle(.roundedBorder)

                    Text("Comma-separated list (e.g. zip, tar, rar).")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                // Destination field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Destination Folder")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField("Select destination folder...", text: $destinationSubpath)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)

                        Button(action: selectDestinationFolder) {
                            HStack {
                                Image(systemName: "folder")
                                Text("Choose...")
                            }
                        }
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)

                Spacer()

                Button(action: {
                    let cleanedExts = extensionsText
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: ".", with: "") }
                        .filter { !$0.isEmpty }

                    let newRule = OrganizationRule(
                        category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                        extensions: Set(cleanedExts),
                        destinationSubpath: destinationSubpath
                    )
                    onSave(newRule)
                }) {
                    Text("Save Rule")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            category.isEmpty || extensionsText.isEmpty || destinationSubpath.isEmpty
                                ? Color.gray
                                : Color.blue
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(category.isEmpty || extensionsText.isEmpty || destinationSubpath.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 450, height: 380)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func selectDestinationFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.resolvesAliases = true
        panel.title = "Select Destination Folder"

        if panel.runModal() == .OK {
            if let url = panel.url {
                destinationSubpath = url.path
            }
        }
    }
}
