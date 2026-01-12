import SwiftUI
import Combine

/// ToDoアイテム
struct TodoItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date?
    var priority: Priority = .medium
    var createdAt: Date = Date()

    enum Priority: String, Codable, CaseIterable {
        case low = "低"
        case medium = "中"
        case high = "高"

        var color: Color {
            switch self {
            case .low: return .blue
            case .medium: return .orange
            case .high: return .red
            }
        }
    }
}

/// ToDoマネージャー
@MainActor
class TodoManager: ObservableObject {
    @Published var items: [TodoItem] = []

    private let key = "anki_hub_todo_items_v1"

    private var cancellables: Set<AnyCancellable> = []

    init() {
        loadItems()

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadItems()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Notification.Name("anki_hub_todo_items_updated"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadItems()
            }
            .store(in: &cancellables)
    }

    func loadItems() {
        if let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([TodoItem].self, from: data)
        {
            items = decoded
        }
    }

    func addItem(title: String, dueDate: Date?, priority: TodoItem.Priority) {
        let item = TodoItem(title: title, dueDate: dueDate, priority: priority)
        items.append(item)
        saveItems()
    }

    func toggleItem(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isCompleted.toggle()
            saveItems()
        }
    }

    func deleteItem(id: UUID) {
        items.removeAll { $0.id == id }
        saveItems()
    }

    func updateItem(id: UUID, title: String, dueDate: Date?, priority: TodoItem.Priority) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].title = title
            items[index].dueDate = dueDate
            items[index].priority = priority
            saveItems()
        }
    }

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
        SyncManager.shared.requestAutoSync()
    }

    var pendingItems: [TodoItem] {
        items.filter { !$0.isCompleted }.sorted {
            ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }
    }

    var completedItems: [TodoItem] {
        items.filter { $0.isCompleted }.sorted { $0.createdAt > $1.createdAt }
    }
}

/// ToDoビュー
struct TodoView: View {
    @StateObject private var manager = TodoManager()
    @ObservedObject private var theme = ThemeManager.shared

    @State private var showAddSheet = false
    @State private var editingItem: TodoItem? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background

                if manager.items.isEmpty {
                    emptyStateView
                } else {
                    todoList
                }
            }
            .navigationTitle("やることリスト")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddTodoSheet(manager: manager)
            }
            .sheet(item: $editingItem) { item in
                EditTodoSheet(manager: manager, item: item)
            }
        }
        .applyAppTheme()
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("タスクがありません")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                showAddSheet = true
            } label: {
                Label("タスクを追加", systemImage: "plus")
                    .padding()
                    .background(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                    .foregroundStyle(
                        theme.onColor(for: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                    )
                    .cornerRadius(12)
            }
        }
    }

    private var todoList: some View {
        List {
            // Pending Section
            if !manager.pendingItems.isEmpty {
                Section("未完了 (\(manager.pendingItems.count))") {
                    ForEach(manager.pendingItems) { item in
                        TodoRow(
                            item: item,
                            onToggle: {
                                withAnimation {
                                    manager.toggleItem(id: item.id)
                                }
                            },
                            onTap: {
                                editingItem = item
                            })
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let item = manager.pendingItems[index]
                            manager.deleteItem(id: item.id)
                        }
                    }
                }
            }

            // Completed Section
            if !manager.completedItems.isEmpty {
                Section("完了済み (\(manager.completedItems.count))") {
                    ForEach(manager.completedItems) { item in
                        TodoRow(
                            item: item,
                            onToggle: {
                                withAnimation {
                                    manager.toggleItem(id: item.id)
                                }
                            },
                            onTap: {
                                editingItem = item
                            })
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let item = manager.completedItems[index]
                            manager.deleteItem(id: item.id)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

struct TodoRow: View {
    let item: TodoItem
    let onToggle: () -> Void
    let onTap: () -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)

                HStack(spacing: 8) {
                    // Priority
                    Text(item.priority.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.priority.color.opacity(0.2))
                        .foregroundStyle(item.priority.color)
                        .cornerRadius(4)

                    // Due Date
                    if let dueDate = item.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                            Text(formatDate(dueDate))
                        }
                        .font(.caption)
                        .foregroundStyle(isOverdue(dueDate) ? .red : .secondary)
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func isOverdue(_ date: Date) -> Bool {
        !Calendar.current.isDateInToday(date) && date < Date()
    }
}

struct AddTodoSheet: View {
    @ObservedObject var manager: TodoManager
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var priority: TodoItem.Priority = .medium

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク") {
                    TextField("タイトル", text: $title)
                }

                Section("期限") {
                    Toggle("期限を設定", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("期限日", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("優先度") {
                    Picker("優先度", selection: $priority) {
                        ForEach(TodoItem.Priority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("タスクを追加")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        manager.addItem(
                            title: title,
                            dueDate: hasDueDate ? dueDate : nil,
                            priority: priority
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct EditTodoSheet: View {
    @ObservedObject var manager: TodoManager
    let item: TodoItem
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var priority: TodoItem.Priority = .medium

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク") {
                    TextField("タイトル", text: $title)
                }

                Section("期限") {
                    Toggle("期限を設定", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker("期限日", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("優先度") {
                    Picker("優先度", selection: $priority) {
                        ForEach(TodoItem.Priority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("タスクを編集")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        manager.updateItem(
                            id: item.id,
                            title: title,
                            dueDate: hasDueDate ? dueDate : nil,
                            priority: priority
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                title = item.title
                hasDueDate = item.dueDate != nil
                dueDate = item.dueDate ?? Date()
                priority = item.priority
            }
        }
    }
}

// Preview removed for macOS compatibility
