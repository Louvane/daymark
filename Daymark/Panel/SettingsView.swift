import SwiftUI

/// 设置:通用(默认提醒时刻/开机启动)+ 关于
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Text("settings.tab.general") }
            AboutSettingsView()
                .tabItem { Text("settings.tab.about") }
        }
        .frame(width: 420, height: 240)
    }
}

/// 通用:默认提醒时刻 + 开机自启动
struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DaymarkStore.self) private var store

    @State private var loginService: any LoginItemServicing = SMAppLoginItemService()

    var body: some View {
        Form {
            // 无具体时刻的日标统一在该时刻提醒;改动后全量重排
            DatePicker(
                "settings.reminder.time",
                selection: reminderTimeBinding,
                displayedComponents: .hourAndMinute
            )
            Toggle("settings.launchAtLogin", isOn: launchAtLoginBinding)
                .toggleStyle(.switch)
            HStack {
                Text("settings.sort")
                Spacer()
                Picker("", selection: sortModeBinding) {
                    Text("list.sort.upcoming").tag(DaymarkSortMode.upcoming)
                    Text("list.sort.manual").tag(DaymarkSortMode.manual)
                }
                .labelsHidden()
                .frame(width: 118)
            }
        }
        .formStyle(.grouped)
        .padding(6)
    }

    /// 列表排序绑定(与面板内切换等效,统一存 AppSettings)
    private var sortModeBinding: Binding<DaymarkSortMode> {
        Binding(get: { settings.sortMode }, set: { settings.sortMode = $0 })
    }

    /// 时刻 <-> Date 双向绑定;改动即全量重排(假调度器测试覆盖链路)
    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: settings.reminderTime.hour,
                                                           minute: settings.reminderTime.minute)) ?? .now
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                var time = settings.reminderTime
                time.hour = comps.hour ?? DaymarkReminderTime.default.hour
                time.minute = comps.minute ?? DaymarkReminderTime.default.minute
                settings.reminderTime = time
                Task { await store.rescheduleReminders() }
            }
        )
    }

    /// 开机启动:写期望值后调系统服务,再以实际注册状态校正
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { desired in
                settings.launchAtLogin = desired
                Task { @MainActor in
                    do {
                        if desired {
                            try await loginService.register()
                        } else {
                            try await loginService.unregister()
                        }
                    } catch {
                        // 注册失败(如系统限制)时回滚 UI 为实际状态
                    }
                    settings.syncLaunchAtLogin(actual: loginService.isRegistered)
                }
            }
        )
    }
}

/// 关于:版本、开源地址、致谢
struct AboutSettingsView: View {
    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("📅")
                .font(.system(size: 40))
            Text("panel.title")
                .font(.title3.bold())
            Text("settings.about.version \(versionText)")
                .font(.callout)
                .foregroundStyle(.secondary)
            Link("settings.about.github", destination: URL(string: "https://github.com/louvane/daymark")!)
                .font(.callout)
            Text("settings.about.license")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("settings.about.credit")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 16)
    }
}
