import Combine
import SwiftUI
@preconcurrency import UserNotifications

#if canImport(UniformTypeIdentifiers)
    import UniformTypeIdentifiers
#endif

#if canImport(Speech)
    import Speech
#endif

// MARK: - Data Models

/// ToDoアイテム
struct TodoItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date?
    var priority: Priority = .medium
    var createdAt: Date = Date()

    // 新規追加機能
    var category: String?
    var parentId: UUID?
    var subtaskIds: [UUID] = []
    var reminderDate: Date?
    var isReminderEnabled: Bool = false
    var recurrence: Recurrence?
    var timeLimit: TimeInterval?
    var comments: [Comment] = []
    var boardColumn: BoardColumn = .todo

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

    enum BoardColumn: String, Codable, CaseIterable {
        case backlog = "バックログ"
        case todo = "ToDo"
        case inProgress = "進行中"
        case done = "完了"

        var icon: String {
            switch self {
            case .backlog: return "tray.fill"
            case .todo: return "circle"
            case .inProgress: return "arrow.right.circle.fill"
            case .done: return "checkmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .backlog: return .gray
            case .todo: return .blue
            case .inProgress: return .orange
            case .done: return .green
            }
        }
    }

    struct Recurrence: Codable, Equatable {
        var type: RecurrenceType
        var interval: Int = 1

        var description: String {
            switch type {
            case .daily: return interval == 1 ? "毎日" : "\(interval)日ごと"
            case .weekly: return interval == 1 ? "毎週" : "\(interval)週ごと"
            case .monthly: return interval == 1 ? "毎月" : "\(interval)ヶ月ごと"
            }
        }
    }

    enum RecurrenceType: String, Codable, CaseIterable {
        case daily = "日"
        case weekly = "週"
        case monthly = "月"
    }

    struct Comment: Identifiable, Codable {
        var id: UUID = UUID()
        var text: String
        var createdAt: Date = Date()
    }
}

/// タスクテンプレート
struct TodoTemplate: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var tasks: [TodoItem]
    var createdAt: Date = Date()
}

// MARK: - TodoManager

@MainActor
class TodoManager: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var templates: [TodoTemplate] = []
    @Published var categories: [String] = []

    private let key = "anki_hub_todo_items_v2"
    private let templateKey = "anki_hub_todo_templates_v1"
    private let categoryKey = "anki_hub_todo_categories_v1"
    private let appGroupId = "group.com.ankihub.ios"
    private let migratedKey = "anki_hub_todo_items_v2_migrated"
    private let notificationPrefix = "todo_reminder_"

    private var cancellables: Set<AnyCancellable> = []

    init() {
        migrateIfNeeded()
        loadItems()
        loadTemplates()
        loadCategories()

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
        let defaults = UserDefaults(suiteName: appGroupId) ?? .standard
        if let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode([TodoItem].self, from: data)
        {
            items = decoded
        }
    }

    func loadTemplates() {
        let defaults = UserDefaults(suiteName: appGroupId) ?? .standard
        if let data = defaults.data(forKey: templateKey),
            let decoded = try? JSONDecoder().decode([TodoTemplate].self, from: data)
        {
            templates = decoded
        }
    }

    func loadCategories() {
        let defaults = UserDefaults(suiteName: appGroupId) ?? .standard
        categories = defaults.stringArray(forKey: categoryKey) ?? []
    }

    func addItem(
        title: String, dueDate: Date?, priority: TodoItem.Priority, category: String? = nil,
        reminderDate: Date? = nil, recurrence: TodoItem.Recurrence? = nil,
        timeLimit: TimeInterval? = nil, parentId: UUID? = nil
    ) {
        var item = TodoItem(title: title, dueDate: dueDate, priority: priority)
        item.category = category
        item.reminderDate = reminderDate
        item.isReminderEnabled = reminderDate != nil
        item.recurrence = recurrence
        item.timeLimit = timeLimit
        item.parentId = parentId

        items.append(item)

        // サブタスクの場合、親に追加
        if let parentId = parentId, let parentIndex = items.firstIndex(where: { $0.id == parentId })
        {
            items[parentIndex].subtaskIds.append(item.id)
        }

        saveItems()

        if let reminder = reminderDate {
            scheduleNotification(for: item, at: reminder)
        }
    }

    func toggleItem(id: UUID) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].isCompleted.toggle()

            if items[index].isCompleted {
                items[index].boardColumn = .done
                cancelNotification(for: items[index])

                // 繰り返しタスクの場合、新しいタスクを作成
                if let recurrence = items[index].recurrence {
                    createRecurringTask(from: items[index], recurrence: recurrence)
                }
            } else {
                items[index].boardColumn = .todo
            }

            saveItems()
        }
    }

    func deleteItem(id: UUID) {
        if let item = items.first(where: { $0.id == id }) {
            cancelNotification(for: item)

            // サブタスクも削除
            for subtaskId in item.subtaskIds {
                items.removeAll { $0.id == subtaskId }
            }

            // 親からサブタスクIDを削除
            if let parentId = item.parentId,
                let idx = items.firstIndex(where: { $0.id == parentId })
            {
                items[idx].subtaskIds.removeAll { $0 == id }
            }
        }
        items.removeAll { $0.id == id }
        saveItems()
    }

    func updateItem(_ item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let oldItem = items[index]
            items[index] = item
            saveItems()

            // 通知更新
            cancelNotification(for: oldItem)
            if item.isReminderEnabled, let reminder = item.reminderDate {
                scheduleNotification(for: item, at: reminder)
            }
        }
    }

    func moveItem(id: UUID, to column: TodoItem.BoardColumn) {
        if let index = items.firstIndex(where: { $0.id == id }) {
            items[index].boardColumn = column
            if column == .done {
                items[index].isCompleted = true
            } else if items[index].isCompleted && column != .done {
                items[index].isCompleted = false
            }
            saveItems()
        }
    }

    func addComment(to itemId: UUID, text: String) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            let comment = TodoItem.Comment(text: text)
            items[index].comments.append(comment)
            saveItems()
        }
    }

    func deleteComment(from itemId: UUID, commentId: UUID) {
        if let index = items.firstIndex(where: { $0.id == itemId }) {
            items[index].comments.removeAll { $0.id == commentId }
            saveItems()
        }
    }

    // MARK: - Categories

    func addCategory(_ name: String) {
        guard !name.isEmpty, !categories.contains(name) else { return }
        categories.append(name)
        saveCategories()
    }

    func deleteCategory(_ name: String) {
        categories.removeAll { $0 == name }
        // タスクのカテゴリもクリア
        for i in items.indices where items[i].category == name {
            items[i].category = nil
        }
        saveCategories()
        saveItems()
    }

    // MARK: - Templates

    func saveAsTemplate(name: String, taskIds: [UUID]) {
        var includeIds = Set(taskIds)
        var queue = taskIds
        while let current = queue.popLast() {
            let children = items.filter { $0.parentId == current }.map { $0.id }
            for child in children where !includeIds.contains(child) {
                includeIds.insert(child)
                queue.append(child)
            }
        }
        let tasksToSave = items.filter { includeIds.contains($0.id) }
        let template = TodoTemplate(name: name, tasks: tasksToSave)
        templates.append(template)
        saveTemplates()
    }

    func applyTemplate(_ template: TodoTemplate) {
        // 旧ID -> 新ID のマップを作り、親子関係やサブタスクを再構築する
        var idMap: [UUID: UUID] = [:]
        var copied: [TodoItem] = []

        // 1. まず全タスクをコピーして新しいIDを割り当てる（サブタスクIDは後で付け替え）
        for task in template.tasks {
            var newTask = task
            let newId = UUID()
            idMap[task.id] = newId
            newTask.id = newId
            newTask.createdAt = Date()
            newTask.isCompleted = false
            newTask.boardColumn = .todo
            newTask.parentId = nil
            newTask.subtaskIds = []
            copied.append(newTask)
        }

        // 2. 親子とサブタスクIDを新IDに貼り替える
        for i in copied.indices {
            if let oldParent = template.tasks.first(where: { $0.id == template.tasks[i].parentId })?.id,
               let newParent = idMap[oldParent] {
                copied[i].parentId = newParent
            }

            let oldSubtasks = template.tasks.first(where: { $0.id == template.tasks[i].id })?.subtaskIds ?? []
            copied[i].subtaskIds = oldSubtasks.compactMap { idMap[$0] }
        }

        // 3. 追加して保存
        items.append(contentsOf: copied)
        saveItems()
    }

    func deleteTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        saveTemplates()
    }

    // MARK: - Notifications

    private func scheduleNotification(for item: TodoItem, at date: Date) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "タスクリマインダー"
            content.body = item.title
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(self.notificationPrefix)\(item.id.uuidString)",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    private func cancelNotification(for item: TodoItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "\(notificationPrefix)\(item.id.uuidString)"
        ])
    }

    // MARK: - Recurring Tasks

    private func createRecurringTask(from item: TodoItem, recurrence: TodoItem.Recurrence) {
        var newItem = item
        newItem.id = UUID()
        newItem.isCompleted = false
        newItem.boardColumn = .todo
        newItem.createdAt = Date()
        newItem.comments = []

        // 次の日付を計算
        if let dueDate = item.dueDate {
            switch recurrence.type {
            case .daily:
                newItem.dueDate = Calendar.current.date(
                    byAdding: .day, value: recurrence.interval, to: dueDate)
            case .weekly:
                newItem.dueDate = Calendar.current.date(
                    byAdding: .weekOfYear, value: recurrence.interval, to: dueDate)
            case .monthly:
                newItem.dueDate = Calendar.current.date(
                    byAdding: .month, value: recurrence.interval, to: dueDate)
            }
        }

        if let reminderDate = item.reminderDate, let dueDate = item.dueDate,
            let newDueDate = newItem.dueDate
        {
            let diff = reminderDate.timeIntervalSince(dueDate)
            newItem.reminderDate = newDueDate.addingTimeInterval(diff)
        }

        items.append(newItem)

        if let reminder = newItem.reminderDate {
            scheduleNotification(for: newItem, at: reminder)
        }
    }

    // MARK: - Persistence

    private func saveItems() {
        if let data = try? JSONEncoder().encode(items) {
            let defaults = UserDefaults(suiteName: appGroupId) ?? .standard
            defaults.set(data, forKey: key)
        }
        SyncManager.shared.requestAutoSync()
        NotificationCenter.default.post(
            name: Notification.Name("anki_hub_todo_items_updated"), object: nil)
    }

    private func saveTemplates() {
        if let data = try? JSONEncoder().encode(templates) {
            let defaults = UserDefaults(suiteName: appGroupId) ?? .standard
            defaults.set(data, forKey: templateKey)
        }
    }

    private func saveCategories() {
        let defaults = UserDefaults(suiteName: appGroupId) ?? .standard
        defaults.set(categories, forKey: categoryKey)
    }

    private func migrateIfNeeded() {
        let defaults = UserDefaults(suiteName: appGroupId)

        if defaults?.bool(forKey: migratedKey) == true { return }

        // v1からv2への移行
        let oldKey = "anki_hub_todo_items_v1"
        if let oldData = defaults?.data(forKey: oldKey),
            let oldItems = try? JSONDecoder().decode([OldTodoItem].self, from: oldData)
        {
            // 古いアイテムを新しい形式に変換
            items = oldItems.map { old in
                var new = TodoItem(title: old.title, dueDate: old.dueDate, priority: old.priority)
                new.id = old.id
                new.isCompleted = old.isCompleted
                new.createdAt = old.createdAt
                new.boardColumn = old.isCompleted ? .done : .todo
                return new
            }
            saveItems()
        }

        defaults?.set(true, forKey: migratedKey)
    }

    // 古いデータ形式
    private struct OldTodoItem: Codable {
        var id: UUID
        var title: String
        var isCompleted: Bool
        var dueDate: Date?
        var priority: TodoItem.Priority
        var createdAt: Date
    }

    // MARK: - Computed Properties

    var pendingItems: [TodoItem] {
        items.filter { !$0.isCompleted && $0.parentId == nil }.sorted {
            ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }
    }

    var completedItems: [TodoItem] {
        items.filter { $0.isCompleted && $0.parentId == nil }.sorted { $0.createdAt > $1.createdAt }
    }

    func itemsByColumn(_ column: TodoItem.BoardColumn) -> [TodoItem] {
        items.filter { $0.boardColumn == column && $0.parentId == nil }
    }

    func itemsInCategory(_ category: String?) -> [TodoItem] {
        items.filter { $0.category == category && $0.parentId == nil }
    }

    func subtasks(of parentId: UUID) -> [TodoItem] {
        items.filter { $0.parentId == parentId }
    }
}

// MARK: - Main TodoView

struct TodoView: View {
    @StateObject private var manager = TodoManager()
    @ObservedObject private var theme = ThemeManager.shared

    @Environment(\.openURL) private var openURL

    @State private var showAddSheet = false
    @State private var editingItem: TodoItem? = nil
    @State private var viewMode: ViewMode = .list
    @State private var showTemplates = false
    @State private var showCategories = false

    @State private var selectedCategoryFilter: String? = nil

    enum ViewMode: String, CaseIterable {
        case list = "リスト"
        case board = "ボード"
    }

    var body: some View {
        ZStack {
            theme.background

            if manager.items.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: 0) {
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            Button {
                                selectedCategoryFilter = nil
                            } label: {
                                Text("すべて")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        (selectedCategoryFilter == nil
                                            ? theme.currentPalette.color(
                                                .accent, isDark: theme.effectiveIsDark)
                                            : theme.currentPalette.color(
                                                .surface, isDark: theme.effectiveIsDark))
                                    )
                                    .foregroundStyle(
                                        selectedCategoryFilter == nil
                                            ? theme.onColor(
                                                for: theme.currentPalette.color(
                                                    .accent, isDark: theme.effectiveIsDark))
                                            : theme.primaryText
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            ForEach(manager.categories, id: \.self) { cat in
                                Button {
                                    selectedCategoryFilter = cat
                                } label: {
                                    Text(cat)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            (selectedCategoryFilter == cat
                                                ? theme.currentPalette.color(
                                                    .accent, isDark: theme.effectiveIsDark)
                                                : theme.currentPalette.color(
                                                    .surface, isDark: theme.effectiveIsDark))
                                        )
                                        .foregroundStyle(
                                            selectedCategoryFilter == cat
                                                ? theme.onColor(
                                                    for: theme.currentPalette.color(
                                                        .accent, isDark: theme.effectiveIsDark))
                                                : theme.primaryText
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                    }

                    // View Mode Picker
                    Picker("", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    switch viewMode {
                    case .list:
                        todoList
                    case .board:
                        boardView
                    }
                }
            }
        }
        .navigationTitle("やることリスト")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("タスクを追加", systemImage: "plus")
                    }

                    Button {
                        showTemplates = true
                    } label: {
                        Label("テンプレート", systemImage: "doc.on.doc")
                    }

                    Button {
                        showCategories = true
                    } label: {
                        Label("カテゴリ管理", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTodoSheet(manager: manager)
        }
        .sheet(item: $editingItem) { item in
            TodoDetailSheet(manager: manager, item: item)
        }
        .sheet(isPresented: $showTemplates) {
            TemplateListSheet(manager: manager)
        }
        .sheet(isPresented: $showCategories) {
            CategoryManagementSheet(manager: manager)
        }
        .applyAppTheme()
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet")
                .font(.system(size: 60))
                .foregroundStyle(theme.secondaryText)

            Text("タスクがありません")
                .font(.headline)
                .foregroundStyle(theme.secondaryText)

            Button {
                showAddSheet = true
            } label: {
                Label("タスクを追加", systemImage: "plus")
                    .padding()
                    .background(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark))
                    .foregroundStyle(
                        theme.onColor(
                            for: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
                        )
                    )
                    .cornerRadius(12)
            }
        }
    }

    private var todoList: some View {
        List {
            // Pending Section
            let pending = filteredListItems(manager.pendingItems)
            if !pending.isEmpty {
                Section("未完了 (\(pending.count))") {
                    ForEach(pending) { item in
                        TodoRow(
                            item: item,
                            manager: manager,
                            onToggle: {
                                withAnimation {
                                    manager.toggleItem(id: item.id)
                                }
                            },
                            onTap: {
                                editingItem = item
                            },
                            onStartTimer: { minutes in
                                startPomodoro(minutes: minutes)
                            })
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let item = pending[index]
                            manager.deleteItem(id: item.id)
                        }
                    }
                }
            }

            // Completed Section
            let completed = filteredListItems(manager.completedItems)
            if !completed.isEmpty {
                Section("完了済み (\(completed.count))") {
                    ForEach(completed) { item in
                        TodoRow(
                            item: item,
                            manager: manager,
                            onToggle: {
                                withAnimation {
                                    manager.toggleItem(id: item.id)
                                }
                            },
                            onTap: {
                                editingItem = item
                            },
                            onStartTimer: { minutes in
                                startPomodoro(minutes: minutes)
                            })
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let item = completed[index]
                            manager.deleteItem(id: item.id)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var boardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(TodoItem.BoardColumn.allCases, id: \.self) { column in
                    BoardColumnView(
                        column: column,
                        items: filteredBoardItems(column: column),
                        manager: manager,
                        onItemTap: { item in
                            editingItem = item
                        },
                        onStartTimer: { minutes in
                            startPomodoro(minutes: minutes)
                        }
                    )
                }
            }
            .padding()
        }
    }

    private func filteredListItems(_ items: [TodoItem]) -> [TodoItem] {
        guard let category = selectedCategoryFilter else { return items }
        return items.filter { $0.category == category }
    }

    private func filteredBoardItems(column: TodoItem.BoardColumn) -> [TodoItem] {
        let items = manager.itemsByColumn(column)
        guard let category = selectedCategoryFilter else { return items }
        return items.filter { $0.category == category }
    }

    private func startPomodoro(minutes: Int) {
        let safeMinutes = max(1, min(180, minutes))
        guard let url = URL(string: "sugwranki://timer/start?minutes=\(safeMinutes)") else { return }
        openURL(url)
    }
}

// MARK: - Board Column View

struct BoardColumnView: View {
    let column: TodoItem.BoardColumn
    let items: [TodoItem]
    @ObservedObject var manager: TodoManager
    let onItemTap: (TodoItem) -> Void
    let onStartTimer: (Int) -> Void

    @ObservedObject private var theme = ThemeManager.shared
    @State private var isTargeted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Column Header
            HStack {
                Image(systemName: column.icon)
                    .foregroundStyle(column.color)
                Text(column.rawValue)
                    .font(.headline)
                Text("(\(items.count))")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(.horizontal, 8)

            // Tasks
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        BoardTaskCard(
                            item: item,
                            manager: manager,
                            onTap: { onItemTap(item) },
                            onStartTimer: onStartTimer
                        )
                        .onDrag {
                            NSItemProvider(object: item.id.uuidString as NSString)
                        }
                    }
                }
            }
        }
        .frame(width: 280)
        .padding()
        .background(
            theme.currentPalette
                .color(.surface, isDark: theme.effectiveIsDark)
                .opacity(isTargeted ? 0.75 : 0.5)
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    column.color.opacity(isTargeted ? 0.6 : 0.0),
                    style: StrokeStyle(lineWidth: 3, dash: [6, 4])
                )
        )

        #if canImport(UniformTypeIdentifiers)
            .onDrop(of: [UTType.text], isTargeted: $isTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: NSString.self) { str, _ in
                    guard let nsText = str as? NSString else { return }
                    let text = nsText as String
                    guard let id = UUID(uuidString: text) else { return }
                    Task { @MainActor in
                        manager.moveItem(id: id, to: column)
                    }
                }
                return true
            }
        #endif
    }
}

// MARK: - Board Task Card

struct BoardTaskCard: View {
    let item: TodoItem
    @ObservedObject var manager: TodoManager
    let onTap: () -> Void
    let onStartTimer: (Int) -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer()
            }

            HStack(spacing: 8) {
                if item.recurrence != nil {
                    Image(systemName: "repeat")
                        .font(.caption2)
                        .foregroundStyle(theme.secondaryText)
                }
                if item.isReminderEnabled {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                if let limit = item.timeLimit {
                    HStack(spacing: 4) {
                        Image(systemName: "stopwatch.fill")
                        Text("\(Int(limit / 60))分")
                    }
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                // Priority
                Text(item.priority.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(item.priority.color.opacity(0.2))
                    .foregroundStyle(item.priority.color)
                    .cornerRadius(4)

                // Category
                if let category = item.category {
                    Text(category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.purple.opacity(0.2))
                        .foregroundStyle(.purple)
                        .cornerRadius(4)
                }

                Spacer()

                // Due Date
                if let dueDate = item.dueDate {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                        Text(formatDate(dueDate))
                    }
                    .font(.caption2)
                    .foregroundStyle(isOverdue(dueDate) ? .red : theme.secondaryText)
                }
            }

            // Subtasks progress
            let subtasks = manager.subtasks(of: item.id)
            if !subtasks.isEmpty {
                let completed = subtasks.filter { $0.isCompleted }.count
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "checklist")
                        Text("\(completed)/\(subtasks.count)")
                    }
                    .font(.caption2)
                    .foregroundStyle(theme.secondaryText)

                    ProgressView(value: Double(completed), total: Double(max(1, subtasks.count)))
                        .progressViewStyle(.linear)
                        .tint(theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark))
                }
            }

            // Move buttons
            HStack {
                ForEach(TodoItem.BoardColumn.allCases, id: \.self) { col in
                    if col != item.boardColumn {
                        Button {
                            withAnimation {
                                manager.moveItem(id: item.id, to: col)
                            }
                        } label: {
                            Image(systemName: col.icon)
                                .font(.caption)
                                .foregroundStyle(col.color)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let limit = item.timeLimit {
                    Button {
                        onStartTimer(Int(limit / 60))
                    } label: {
                        Image(systemName: "stopwatch.fill")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .onTapGesture { onTap() }
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

// MARK: - Todo Row

struct TodoRow: View {
    let item: TodoItem
    @ObservedObject var manager: TodoManager
    let onToggle: () -> Void
    let onTap: () -> Void
    let onStartTimer: (Int) -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(
                        item.isCompleted
                            ? theme.currentPalette.color(.mastered, isDark: theme.effectiveIsDark)
                            : theme.secondaryText
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? theme.secondaryText : theme.primaryText)

                    if item.recurrence != nil {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }

                    if item.isReminderEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 8) {
                    // Priority
                    Text(item.priority.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.priority.color.opacity(0.2))
                        .foregroundStyle(item.priority.color)
                        .cornerRadius(4)

                    // Category
                    if let category = item.category {
                        Text(category)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.purple.opacity(0.2))
                            .foregroundStyle(.purple)
                            .cornerRadius(4)
                    }

                    // Due Date
                    if let dueDate = item.dueDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                            Text(formatDate(dueDate))
                        }
                        .font(.caption)
                        .foregroundStyle(
                            isOverdue(dueDate)
                                ? theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
                                : theme.secondaryText
                        )
                    }

                    // Comments count
                    if !item.comments.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "bubble.left")
                            Text("\(item.comments.count)")
                        }
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    }

                    // Subtasks
                    let subtasks = manager.subtasks(of: item.id)
                    if !subtasks.isEmpty {
                        let completed = subtasks.filter { $0.isCompleted }.count
                        HStack(spacing: 2) {
                            Image(systemName: "checklist")
                            Text("\(completed)/\(subtasks.count)")
                        }
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    }

                    if let limit = item.timeLimit {
                        HStack(spacing: 2) {
                            Image(systemName: "stopwatch.fill")
                            Text("\(Int(limit / 60))分")
                        }
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    }
                }
            }

            Spacer()

            if let limit = item.timeLimit {
                Button {
                    onStartTimer(Int(limit / 60))
                } label: {
                    Image(systemName: "stopwatch.fill")
                        .foregroundStyle(theme.secondaryText)
                }
                .buttonStyle(.plain)
            }
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

// MARK: - Add Todo Sheet

struct AddTodoSheet: View {
    @ObservedObject var manager: TodoManager
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var priority: TodoItem.Priority = .medium
    @State private var selectedCategory: String? = nil
    @State private var hasReminder: Bool = false
    @State private var reminderDate: Date = Date()
    @State private var hasRecurrence: Bool = false
    @State private var recurrenceType: TodoItem.RecurrenceType = .daily
    @State private var recurrenceInterval: Int = 1
    @State private var hasTimeLimit: Bool = false
    @State private var timeLimit: TimeInterval = 25 * 60  // 25 minutes

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク") {
                    TextField("タイトル", text: $title)

                    Picker("カテゴリ", selection: $selectedCategory) {
                        Text("なし").tag(nil as String?)
                        ForEach(manager.categories, id: \.self) { cat in
                            Text(cat).tag(cat as String?)
                        }
                    }
                }

                Section("期限") {
                    Toggle("期限を設定", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker(
                            "期限日", selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("リマインダー") {
                    Toggle("リマインダー", isOn: $hasReminder)

                    if hasReminder {
                        DatePicker(
                            "通知日時", selection: $reminderDate,
                            displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("繰り返し") {
                    Toggle("繰り返し", isOn: $hasRecurrence)

                    if hasRecurrence {
                        Picker("頻度", selection: $recurrenceType) {
                            ForEach(TodoItem.RecurrenceType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        Stepper("間隔: \(recurrenceInterval)", value: $recurrenceInterval, in: 1...30)
                    }
                }

                Section("タイムリミット") {
                    Toggle("集中タイマー", isOn: $hasTimeLimit)

                    if hasTimeLimit {
                        Stepper(
                            "\(Int(timeLimit / 60))分",
                            value: Binding(
                                get: { timeLimit / 60 },
                                set: { timeLimit = $0 * 60 }
                            ), in: 5...120, step: 5)
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
                            priority: priority,
                            category: selectedCategory,
                            reminderDate: hasReminder ? reminderDate : nil,
                            recurrence: hasRecurrence
                                ? TodoItem.Recurrence(
                                    type: recurrenceType, interval: recurrenceInterval) : nil,
                            timeLimit: hasTimeLimit ? timeLimit : nil
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Todo Detail Sheet

struct TodoDetailSheet: View {
    @ObservedObject var manager: TodoManager
    let item: TodoItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var priority: TodoItem.Priority = .medium
    @State private var selectedCategory: String? = nil
    @State private var hasReminder: Bool = false
    @State private var reminderDate: Date = Date()
    @State private var hasRecurrence: Bool = false
    @State private var recurrenceType: TodoItem.RecurrenceType = .daily
    @State private var recurrenceInterval: Int = 1
    @State private var hasTimeLimit: Bool = false
    @State private var timeLimit: TimeInterval = 25 * 60
    @State private var newComment: String = ""
    @State private var showAddSubtask = false
    @State private var newSubtaskTitle: String = ""

    private var currentItem: TodoItem {
        manager.items.first(where: { $0.id == item.id }) ?? item
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("タスク") {
                    TextField("タイトル", text: $title)

                    Picker("カテゴリ", selection: $selectedCategory) {
                        Text("なし").tag(nil as String?)
                        ForEach(manager.categories, id: \.self) { cat in
                            Text(cat).tag(cat as String?)
                        }
                    }
                }

                Section("期限") {
                    Toggle("期限を設定", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "期限日", selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("リマインダー") {
                    Toggle("リマインダー", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker(
                            "通知日時", selection: $reminderDate,
                            displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("繰り返し") {
                    Toggle("繰り返し", isOn: $hasRecurrence)
                    if hasRecurrence {
                        Picker("頻度", selection: $recurrenceType) {
                            ForEach(TodoItem.RecurrenceType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        Stepper("間隔: \(recurrenceInterval)", value: $recurrenceInterval, in: 1...30)
                    }
                }

                Section("タイムリミット") {
                    Toggle("集中タイマー", isOn: $hasTimeLimit)
                    if hasTimeLimit {
                        Stepper(
                            "\(Int(timeLimit / 60))分",
                            value: Binding(
                                get: { timeLimit / 60 },
                                set: { timeLimit = $0 * 60 }
                            ), in: 5...120, step: 5)
                    }
                }

                Section("ポモドーロ") {
                    Button {
                        guard hasTimeLimit else { return }
                        let minutes = max(1, min(180, Int(timeLimit / 60)))
                        guard let url = URL(string: "sugwranki://timer/start?minutes=\(minutes)") else {
                            return
                        }
                        dismiss()
                        openURL(url)
                    } label: {
                        Label("このタイムリミットでタイマー開始", systemImage: "stopwatch.fill")
                    }
                    .disabled(!hasTimeLimit)
                }

                Section("優先度") {
                    Picker("優先度", selection: $priority) {
                        ForEach(TodoItem.Priority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Subtasks
                Section("サブタスク") {
                    ForEach(manager.subtasks(of: item.id)) { subtask in
                        HStack {
                            Button {
                                manager.toggleItem(id: subtask.id)
                            } label: {
                                Image(
                                    systemName: subtask.isCompleted
                                        ? "checkmark.circle.fill" : "circle"
                                )
                                .foregroundStyle(subtask.isCompleted ? .green : .gray)
                            }
                            .buttonStyle(.plain)

                            Text(subtask.title)
                                .strikethrough(subtask.isCompleted)

                            Spacer()

                            Button {
                                manager.deleteItem(id: subtask.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if showAddSubtask {
                        HStack {
                            TextField("サブタスク", text: $newSubtaskTitle)
                            Button("追加") {
                                if !newSubtaskTitle.isEmpty {
                                    manager.addItem(
                                        title: newSubtaskTitle,
                                        dueDate: nil,
                                        priority: .medium,
                                        parentId: item.id
                                    )
                                    newSubtaskTitle = ""
                                    showAddSubtask = false
                                }
                            }
                        }
                    } else {
                        Button {
                            showAddSubtask = true
                        } label: {
                            Label("サブタスクを追加", systemImage: "plus")
                        }
                    }
                }

                // Comments
                Section("コメント") {
                    ForEach(currentItem.comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.text)
                            Text(formatCommentDate(comment.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                manager.deleteComment(from: item.id, commentId: comment.id)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }

                    HStack {
                        TextField("コメントを追加...", text: $newComment)
                        Button {
                            if !newComment.isEmpty {
                                manager.addComment(to: item.id, text: newComment)
                                newComment = ""
                            }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                        }
                        .disabled(newComment.isEmpty)
                    }
                }
            }
            .navigationTitle("タスク詳細")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var updated = currentItem
                        updated.title = title
                        updated.dueDate = hasDueDate ? dueDate : nil
                        updated.priority = priority
                        updated.category = selectedCategory
                        updated.isReminderEnabled = hasReminder
                        updated.reminderDate = hasReminder ? reminderDate : nil
                        updated.recurrence =
                            hasRecurrence
                            ? TodoItem.Recurrence(
                                type: recurrenceType, interval: recurrenceInterval) : nil
                        updated.timeLimit = hasTimeLimit ? timeLimit : nil
                        manager.updateItem(updated)
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
                selectedCategory = item.category
                hasReminder = item.isReminderEnabled
                reminderDate = item.reminderDate ?? Date()
                hasRecurrence = item.recurrence != nil
                recurrenceType = item.recurrence?.type ?? .daily
                recurrenceInterval = item.recurrence?.interval ?? 1
                hasTimeLimit = item.timeLimit != nil
                timeLimit = item.timeLimit ?? 25 * 60
            }
        }
    }

    private func formatCommentDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Template List Sheet

struct TemplateListSheet: View {
    @ObservedObject var manager: TodoManager
    @Environment(\.dismiss) private var dismiss

    @State private var showCreateTemplate = false
    @State private var templateName = ""
    @State private var selectedTasks: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                if manager.templates.isEmpty && !showCreateTemplate {
                    Text("テンプレートがありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(manager.templates) { template in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                            Text("\(template.tasks.count)個のタスク")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            manager.applyTemplate(template)
                            dismiss()
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                manager.deleteTemplate(id: template.id)
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }

                if showCreateTemplate {
                    Section("新規テンプレート") {
                        TextField("テンプレート名", text: $templateName)

                        ForEach(manager.items.filter { $0.parentId == nil }) { item in
                            HStack {
                                Image(
                                    systemName: selectedTasks.contains(item.id)
                                        ? "checkmark.circle.fill" : "circle"
                                )
                                .foregroundStyle(selectedTasks.contains(item.id) ? .blue : .gray)
                                Text(item.title)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedTasks.contains(item.id) {
                                    selectedTasks.remove(item.id)
                                } else {
                                    selectedTasks.insert(item.id)
                                }
                            }
                        }

                        Button("保存") {
                            if !templateName.isEmpty && !selectedTasks.isEmpty {
                                manager.saveAsTemplate(
                                    name: templateName, taskIds: Array(selectedTasks))
                                templateName = ""
                                selectedTasks = []
                                showCreateTemplate = false
                            }
                        }
                        .disabled(templateName.isEmpty || selectedTasks.isEmpty)
                    }
                }
            }
            .navigationTitle("テンプレート")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTemplate.toggle()
                    } label: {
                        Image(systemName: showCreateTemplate ? "xmark" : "plus")
                    }
                }
            }
        }
    }
}

// MARK: - Category Management Sheet

struct CategoryManagementSheet: View {
    @ObservedObject var manager: TodoManager
    @Environment(\.dismiss) private var dismiss

    @State private var newCategory = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("新しいカテゴリ", text: $newCategory)
                        Button {
                            if !newCategory.isEmpty {
                                manager.addCategory(newCategory)
                                newCategory = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newCategory.isEmpty)
                    }
                }

                Section("カテゴリ一覧") {
                    ForEach(manager.categories, id: \.self) { category in
                        HStack {
                            Text(category)
                            Spacer()
                            Text("\(manager.itemsInCategory(category).count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            manager.deleteCategory(manager.categories[index])
                        }
                    }
                }
            }
            .navigationTitle("カテゴリ管理")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
