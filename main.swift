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
    let langItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    let langSystem = NSMenuItem(title: "", action: #selector(setLangSystem), keyEquivalent: "")
    let langEN = NSMenuItem(title: "English", action: #selector(setLangEN), keyEquivalent: "")
    let langRU = NSMenuItem(title: "Русский", action: #selector(setLangRU), keyEquivalent: "")
    let quit = NSMenuItem(title: "", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

    override init() {
        super.init()
        status.isEnabled = false
        for m in [normal, ai, langSystem, langEN, langRU] { m.target = self }

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
    @objc func setLangSystem() { Lang.current = .system; refresh() }
    @objc func setLangEN() { Lang.current = .en; refresh() }
    @objc func setLangRU() { Lang.current = .ru; refresh() }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller()
app.run()
