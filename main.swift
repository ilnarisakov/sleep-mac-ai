import AppKit

// MARK: - Язык / Language

enum Lang: String {
    case system, en, ru

    static var current: Lang {
        get { Lang(rawValue: UserDefaults.standard.string(forKey: "lang") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "lang") }
    }
}

func isRU() -> Bool {
    switch Lang.current {
    case .ru: return true
    case .en: return false
    case .system: return Locale.preferredLanguages.first?.hasPrefix("ru") ?? false
    }
}

func t(_ en: String, _ ru: String) -> String { isRU() ? ru : en }

// MARK: - pmset

// Читает/пишет pmset SleepDisabled — единственный флаг, который держит мак
// живым с закрытой крышкой (caffeinate это не умеет).
func sleepDisabled() -> Bool {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    p.arguments = ["-g"]
    let pipe = Pipe()
    p.standardOutput = pipe
    try? p.run()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    p.waitUntilExit()
    guard let line = out.split(separator: "\n").first(where: { $0.contains("SleepDisabled") }) else { return false }
    // pmset разделяет табами, не пробелами
    return line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last == "1"
}

func setSleepDisabled(_ on: Bool) {
    let value = on ? "1" : "0"
    // Сначала без пароля (если установлен sudoers-хелпер), иначе системный запрос пароля.
    let sudo = Process()
    sudo.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
    sudo.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", value]
    try? sudo.run()
    sudo.waitUntilExit()
    if sudo.terminationStatus == 0 { return }

    let osa = Process()
    osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    osa.arguments = ["-e", "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"]
    try? osa.run()
    osa.waitUntilExit()
}

// MARK: - sudoers-хелпер

let sudoersPath = "/etc/sudoers.d/aimode"

// Файл 440 root:wheel, но /etc/sudoers.d доступна на чтение — наличие видно без root.
func helperInstalled() -> Bool { FileManager.default.fileExists(atPath: sudoersPath) }

// Разрешает без пароля ровно два вызова pmset и ничего больше.
@discardableResult
func runAsAdmin(_ command: String) -> Bool {
    let osa = Process()
    osa.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    osa.arguments = ["-e", "do shell script \"\(command)\" with administrator privileges"]
    try? osa.run()
    osa.waitUntilExit()
    return osa.terminationStatus == 0
}

func installHelper() -> Bool {
    let user = NSUserName()
    let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
    let tmp = NSTemporaryDirectory() + "aimode.sudoers"
    guard (try? rule.write(toFile: tmp, atomically: true, encoding: .utf8)) != nil else { return false }
    defer { try? FileManager.default.removeItem(atPath: tmp) }
    // visudo -c отклоняет битое правило, чтобы не сломать sudo на машине
    let ok = runAsAdmin("install -m 440 -o root -g wheel '\(tmp)' \(sudoersPath) && /usr/sbin/visudo -c -f \(sudoersPath) || rm -f \(sudoersPath)")
    return ok && helperInstalled()
}

func removeHelper() -> Bool {
    runAsAdmin("rm -f \(sudoersPath)")
    return !helperInstalled()
}

func alert(_ text: String) {
    let a = NSAlert()
    a.messageText = text
    a.addButton(withTitle: "OK")
    NSApp.activate(ignoringOtherApps: true)
    a.runModal()
}

if CommandLine.arguments.contains("--status") {
    print(sleepDisabled() ? "1" : "0")
    exit(0)
}

// MARK: - Меню

final class Controller: NSObject, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let normal = NSMenuItem(title: "", action: #selector(pickNormal), keyEquivalent: "")
    let ai = NSMenuItem(title: "", action: #selector(pickAI), keyEquivalent: "")
    let helper = NSMenuItem(title: "", action: #selector(toggleHelper), keyEquivalent: "")
    let langItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let langSystem = NSMenuItem(title: "", action: #selector(setLangSystem), keyEquivalent: "")
    let langEN = NSMenuItem(title: "English", action: #selector(setLangEN), keyEquivalent: "")
    let langRU = NSMenuItem(title: "Русский", action: #selector(setLangRU), keyEquivalent: "")
    let quit = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    override init() {
        super.init()
        status.isEnabled = false
        for m in [normal, ai, helper, langSystem, langEN, langRU] { m.target = self }

        let langMenu = NSMenu()
        for m in [langSystem, langEN, langRU] { langMenu.addItem(m) }
        langItem.submenu = langMenu

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(status)
        menu.addItem(.separator())
        menu.addItem(normal)
        menu.addItem(ai)
        menu.addItem(.separator())
        menu.addItem(helper)
        menu.addItem(langItem)
        menu.addItem(quit)
        item.menu = menu
        refresh()
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    func refresh() {
        let on = sleepDisabled()
        let image = NSImage(systemSymbolName: on ? "bolt.fill" : "moon.zzz.fill", accessibilityDescription: nil)
        image?.isTemplate = true
        item.button?.image = image

        status.title = on ? t("Sleep disabled (AI mode)", "Сон отключён (ИИ режим)")
                          : t("Sleep enabled (normal)", "Сон включён (обычный)")
        normal.title = t("Normal mode", "Обычный режим")
        ai.title = t("AI mode — never sleep", "ИИ режим — без сна")
        helper.title = t("Toggle without password", "Переключать без пароля")
        helper.state = helperInstalled() ? .on : .off
        langItem.title = t("Language", "Язык")
        langSystem.title = t("System", "Системный")
        quit.title = t("Quit", "Выход")

        normal.state = on ? .off : .on
        ai.state = on ? .on : .off
        langSystem.state = Lang.current == .system ? .on : .off
        langEN.state = Lang.current == .en ? .on : .off
        langRU.state = Lang.current == .ru ? .on : .off
    }

    @objc func pickNormal() { setSleepDisabled(false); refresh() }
    @objc func pickAI() { setSleepDisabled(true); refresh() }
    @objc func toggleHelper() {
        if helperInstalled() {
            let ok = removeHelper()
            alert(ok ? t("Password will be asked on every switch.", "Пароль будет спрашиваться при каждом переключении.")
                     : t("Could not remove the helper.", "Не удалось удалить правило."))
        } else {
            let ok = installHelper()
            alert(ok ? t("Done — switching no longer asks for a password.", "Готово — переключение больше не спрашивает пароль.")
                     : t("Setup failed. Switching will keep asking for a password.", "Не удалось настроить. Переключение будет спрашивать пароль."))
        }
        refresh()
    }

    @objc func setLangSystem() { Lang.current = .system; refresh() }
    @objc func setLangEN() { Lang.current = .en; refresh() }
    @objc func setLangRU() { Lang.current = .ru; refresh() }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller()
app.run()
