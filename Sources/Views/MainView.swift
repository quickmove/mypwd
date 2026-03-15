import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedItem: PasswordItem?
    @State private var showingEditor = false
    @State private var refreshId = UUID()

    private var store: PasswordStore {
        PasswordStorageService.shared.getStore()
    }

    private var filteredItems: [PasswordItem] {
        store.items
    }

    var body: some View {
        VStack(spacing: 0) {
            // 锁定倒计时栏
            HStack {
                Image(systemName: "lock.fill")
                    .foregroundStyle(appState.remainingSeconds <= 10 ? .orange : .secondary)
                Text("\(appState.remainingSeconds) 秒后自动锁定")
                    .font(.caption)
                    .foregroundStyle(appState.remainingSeconds <= 10 ? .orange : .secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(appState.remainingSeconds <= 10 ? Color.orange.opacity(0.1) : Color.clear)

            NavigationView {
                List(selection: $selectedItem) {
                    HStack {
                        Spacer()
                        Button(action: {
                            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
                            NotificationCenter.default.post(name: .pauseAutoLock, object: nil)
                            showingEditor = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)

                    ForEach(filteredItems) { item in
                        PasswordRowView(item: item)
                            .tag(item)
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.inset)
                .onChange(of: selectedItem) { _ in
                    NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
                }
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: lock) {
                            Label("锁定", systemImage: "lock.fill")
                        }
                    }
                }

                if let item = selectedItem {
                    PasswordDetailView(item: item, onEdit: { selectedItem = nil }, onDelete: { selectedItem = nil })
                } else {
                    Text("选择一个密码项")
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showingEditor) {
                PasswordEditorView(item: nil) { didSave in
                    showingEditor = false
                    if didSave {
                        refreshId = UUID()
                    }
                }
                .onAppear {
                    NotificationCenter.default.post(name: .pauseAutoLock, object: nil)
                }
                .onDisappear {
                    NotificationCenter.default.post(name: .resumeAutoLock, object: nil)
                }
            }
            .onChange(of: appState.refreshTrigger) { _ in
                refreshId = UUID()
            }
            .onTapGesture {
                NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidBeginEditingNotification)) { _ in
            // 输入框获得焦点时记录活动并暂停锁定
            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
            NotificationCenter.default.post(name: .pauseAutoLock, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidEndEditingNotification)) { _ in
            // 输入框失去焦点时恢复锁定
            NotificationCenter.default.post(name: .resumeAutoLock, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSControl.textDidChangeNotification)) { _ in
            // 输入框内容变化时记录活动
            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // 应用获得焦点时记录活动
            NotificationCenter.default.post(name: .userActivityRecorded, object: nil)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = filteredItems[index]
            try? PasswordStorageService.shared.deleteItem(id: item.id)
        }
    }

    private func lock() {
        appState.lock()
    }
}

struct PasswordRowView: View {
    let item: PasswordItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)

                Text(item.displayTitle.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.username)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
