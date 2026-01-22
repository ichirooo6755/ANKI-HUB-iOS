import Combine
import SwiftUI
@preconcurrency import UserNotifications

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
        let tasksToSave = items.filter { taskIds.contains($0.id) }
        let template = TodoTemplate(name: name, tasks: tasksToSave)
        templates.append(template)
        saveTemplates()
    }

    func applyTemplate(_ template: TodoTemplate) {
        for task in template.tasks {
            var newTask = task
            newTask.id = UUID()
            newTask.createdAt = Date()
            newTask.isCompleted = false
            newTask.boardColumn = .todo
            items.append(newTask)
        }
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
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
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

    @State private var showAddSheet = false
    @State private var editingItem: TodoItem? = nil
    @State private var viewMode: ViewMode = .list
    @State private var showTemplates = false
    @State private var showCategories = false

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
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(
                            title: "タスク管理",
                            subtitle: nil,
                            trailing: "\(manager.items.count)件"
                        )
                        summaryMetrics
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    // View Mode Picker
                    Picker("", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

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
            Image(systemName: "list.bullet.clipboard")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(theme.onColor(for: theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)))
                    .frame(width: 44, height: 44)
                    .background(theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark), in: Circle())
            }
        }
    }

    private var summaryMetrics: some View {
        let accent = theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
        let primary = theme.currentPalette.color(.primary, isDark: theme.effectiveIsDark)
        let weak = theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)

        return HStack(spacing: 12) {
            HealthMetricCard(
                title: "未完了",
                value: "\(pendingCount)",
                unit: "件",
                icon: "circle",
                color: accent
            )
            HealthMetricCard(
                title: "完了",
                value: "\(completedCount)",
                unit: "件",
                icon: "checkmark.circle.fill",
                color: primary
            )
            HealthMetricCard(
                title: "期限間近",
                value: "\(dueSoonCount)",
                unit: "件",
                icon: "exclamationmark.triangle.fill",
                color: weak
            )
        }
    }

    private var pendingCount: Int {
        manager.pendingItems.count
    }

    private var completedCount: Int {
        manager.completedItems.count
    }

    private var dueSoonCount: Int {
        let now = Date()
        let soon = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now
        return manager.pendingItems.filter { item in
            guard let due = item.dueDate else { return false }
            return due <= soon
        }.count
    }

    private var todoList: some View {
        List {
            // Pending Section
            if !manager.pendingItems.isEmpty {
                Section("未完了 (\(manager.pendingItems.count))") {
                    ForEach(manager.pendingItems) { item in
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
                            manager: manager,
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
        .listStyle(.insetGrouped)
    }

    private var boardView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(TodoItem.BoardColumn.allCases, id: \.self) { column in
                    BoardColumnView(
                        column: column,
                        items: manager.itemsByColumn(column),
                        manager: manager,
                        onItemTap: { item in
                            editingItem = item
                        }
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Board Column View

struct BoardColumnView: View {
    let column: TodoItem.BoardColumn
    let items: [TodoItem]
    @ObservedObject var manager: TodoManager
    let onItemTap: (TodoItem) -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Column Header
            HStack(spacing: 8) {
                Image(systemName: column.icon)
                    .foregroundStyle(column.color)
                Text(column.rawValue)
                    .font(.headline)
                PillBadge(title: "\(items.count)", color: column.color)
            }
            .padding(.horizontal, 8)

            // Tasks
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { item in
                        BoardTaskCard(
                            item: item,
                            manager: manager,
                            onTap: { onItemTap(item) }
                        )
                    }
                }
            }
        }
        .frame(width: 280)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                .opacity(theme.effectiveIsDark ? 0.9 : 0.95)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.currentPalette.color(.border, isDark: theme.effectiveIsDark).opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Board Task Card

struct BoardTaskCard: View {
    let item: TodoItem
    @ObservedObject var manager: TodoManager
    let onTap: () -> Void

    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                Spacer()
                Button {
                    manager.toggleItem(id: item.id)
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.isCompleted ? .green : .gray)
                }
            }

            HStack(spacing: 8) {
                PillBadge(title: item.priority.rawValue, color: item.priority.color)

                if let category = item.category {
                    PillBadge(
                        title: category,
                        color: theme.currentPalette.color(.secondary, isDark: theme.effectiveIsDark)
                    )
                }

                if let dueDate = item.dueDate {
                    PillBadge(
                        title: formatDate(dueDate),
                        color: isOverdue(dueDate)
                            ? theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
                            : theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
                    )
                }
            }

            // Subtasks progress
            let subtasks = manager.subtasks(of: item.id)
            if !subtasks.isEmpty {
                let completed = subtasks.filter { $0.isCompleted }.count
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                    Text("\(completed)/\(subtasks.count)")
                }
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
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
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                .opacity(theme.effectiveIsDark ? 0.92 : 0.97)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.currentPalette.color(.border, isDark: theme.effectiveIsDark).opacity(0.2), lineWidth: 1)
        )
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
                    PillBadge(title: item.priority.rawValue, color: item.priority.color)

                    if let category = item.category {
                        PillBadge(
                            title: category,
                            color: theme.currentPalette.color(.secondary, isDark: theme.effectiveIsDark)
                        )
                    }

                    if let dueDate = item.dueDate {
                        PillBadge(
                            title: formatDate(dueDate),
                            color: isOverdue(dueDate)
                                ? theme.currentPalette.color(.weak, isDark: theme.effectiveIsDark)
                                : theme.currentPalette.color(.accent, isDark: theme.effectiveIsDark)
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
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.currentPalette.color(.surface, isDark: theme.effectiveIsDark))
                .opacity(theme.effectiveIsDark ? 0.92 : 0.97)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.currentPalette.color(.border, isDark: theme.effectiveIsDark).opacity(0.2), lineWidth: 1)
        )
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
                    ForEach(item.comments) { comment in
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
                        var updated = item
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
