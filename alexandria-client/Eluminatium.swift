//
//  Eluminatium.swift
//  Alexandria
//
//  App browser – pretragu obavlja isključivo Eluminatium (svoj katalog). Nema web pretrage.
//

import SwiftUI
import AppKit

// MARK: - Rezultat pretrage (što vizualizirati)
enum EluminatiumContent: Equatable {
    case connecting       // uspostavlja vezu s backendom
    case idle(serverUI: AlexandriaViewNode?)  // spojeno, renderira se pretraživač (UI s backenda)
    case loading
    case code(String)
    case app(AlexandriaViewNode)
    case pageList([EluminatiumPageItem])  // popis stranica prije otvaranja (makar jedna)
    case error(String)
    case httpError(statusCode: Int, message: String?)  // interna stranica za 4xx/5xx
}

/// Ikona aplikacije – URL s backenda ili SF Symbol
struct AppIconView: View {
    let iconUrl: String?
    let systemName: String
    let size: CGFloat
    let accentColor: Color
    
    init(iconUrl: String?, systemName: String = "app.badge.fill", size: CGFloat = 24, accentColor: Color = Color(hex: "ff5c00")) {
        self.iconUrl = iconUrl
        self.systemName = systemName
        self.size = size
        self.accentColor = accentColor
    }
    
    var body: some View {
        Group {
            if let urlString = iconUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: .fit)
                    case .failure, .empty: Image(systemName: systemName).foregroundColor(accentColor)
                    @unknown default: Image(systemName: systemName).foregroundColor(accentColor)
                    }
                }
            } else {
                Image(systemName: systemName).foregroundColor(accentColor)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Jedna stranica u popisu – može biti iz pretrage (catalog) ili iz file
enum EluminatiumPageItem: Equatable {
    case catalog(EluminatiumAppCatalogItem)
    case file(name: String, node: AlexandriaViewNode)
}

// MARK: - Search TextField – Enter = submit (internal za Island)
struct SearchTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)?
    var textColor: NSColor = .white

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField(string: text)
        tf.placeholderString = placeholder
        tf.isBordered = false
        tf.drawsBackground = false
        tf.isEditable = true
        tf.isSelectable = true
        tf.focusRingType = .none
        tf.textColor = textColor
        tf.font = .systemFont(ofSize: 14)
        if let cell = tf.cell as? NSTextFieldCell {
            cell.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [.foregroundColor: NSColor.gray]
            )
        }
        tf.delegate = context.coordinator
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.textColor = textColor
        context.coordinator.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            _text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onSubmit?()
                return true
            }
            return false
        }
    }
}

private let eluminatiumGreen = Color(hex: "1a5f2a")

// MARK: - Dinamička zelena pozadina – polarna svjetlost (aurora)
struct AuroraGreenBackgroundView: View {
    private let darkGreen = Color(hex: "0a1810")
    private let auroraGreen1 = Color(hex: "1a4d2e")
    private let auroraGreen2 = Color(hex: "2d6a3e")
    private let auroraGreen3 = Color(hex: "3d8b52")
    private let auroraGlow = Color(hex: "5bb87a")

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let p1 = CGFloat(sin(t * 0.15) * 0.5 + 0.5)
            let p2 = CGFloat(sin(t * 0.12 + 1) * 0.5 + 0.5)
            let p3 = CGFloat(sin(t * 0.18 + 2) * 0.5 + 0.5)

            ZStack {
                darkGreen

                // Prva traka – lijevo, pomiče se gore-dolje
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [auroraGreen2.opacity(0.5), auroraGreen1.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 280
                        )
                    )
                    .frame(width: 600, height: 400)
                    .offset(x: -200, y: 80 + p1 * 120)
                    .blur(radius: 80)

                // Druga traka – desno, sporija
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [auroraGlow.opacity(0.35), auroraGreen3.opacity(0.2), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 320
                        )
                    )
                    .frame(width: 700, height: 450)
                    .offset(x: 220, y: -60 + p2 * 100)
                    .blur(radius: 90)

                // Treća traka – sredina, najblaža
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [auroraGreen3.opacity(0.25), auroraGreen2.opacity(0.1), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 250
                        )
                    )
                    .frame(width: 500, height: 350)
                    .offset(x: 0, y: 100 + p3 * 80)
                    .blur(radius: 70)
            }
        }
        .drawingGroup(opaque: false)
        .ignoresSafeArea()
    }
}

struct EluminatiumView: View {
    @Binding var initialSearchQuery: String?
    @Binding var currentAddress: String
    @State private var showSettings = false
    @State private var content: EluminatiumContent = .connecting
    @State private var serverUINode: AlexandriaViewNode?
    var onOpenAppFromSearch: ((InstalledApp) -> Void)?
    var onSwitchToDevMode: (() -> Void)?

    var body: some View {
        ZStack {
            AuroraGreenBackgroundView()

            VStack(spacing: 0) {
                switch content {
                case .connecting:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Uspostavljam vezu s Eluminatiumom...")
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { connectAndLoadUI() }
                case .idle(let serverUI):
                    EluminatiumShellView(
                        content: $content,
                        serverUINode: serverUI,
                        initialSearchQuery: $initialSearchQuery,
                        currentAddress: $currentAddress,
                        onOpenSettings: { showSettings = true },
                        onOpenAppFromSearch: onOpenAppFromSearch
                    )
                case .loading:
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Učitavam...")
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .code(let source):
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            content = .idle(serverUI: serverUINode)
                        } label: {
                            Image(systemName: "arrow.left")
                                .foregroundColor(Color(hex: "ff5c00"))
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                        Spacer()
                    }
                    .background(Color.black.opacity(0.5))
                    CodeView(source: source)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .app(let node):
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            content = .idle(serverUI: serverUINode)
                        } label: {
                            Image(systemName: "arrow.left")
                                .foregroundColor(Color(hex: "ff5c00"))
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                        Spacer()
                    }
                    .background(Color.black.opacity(0.5))
                    AlexandriaRenderer(node: node)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .pageList(let items):
                    EluminatiumShellView(
                        content: $content,
                        serverUINode: serverUINode,
                        initialSearchQuery: $initialSearchQuery,
                        currentAddress: $currentAddress,
                        onOpenSettings: { showSettings = true },
                        onOpenAppFromSearch: onOpenAppFromSearch,
                        pageListItems: items
                    )
                case .error(let message):
                    VStack(spacing: 24) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.9))
                        ScrollView {
                            Text(message)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxHeight: 200)
                        HStack(spacing: 16) {
                            Button("Pokušaj ponovo") {
                                content = .connecting
                            }
                            .foregroundColor(.white)
                            Button("Lokalni mod") {
                                content = .idle(serverUI: nil)
                            }
                            .foregroundColor(.white.opacity(0.8))
                            Button("Dev Mode") {
                                onSwitchToDevMode?()
                            }
                            .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .httpError(let statusCode, let message):
                ErrorPageView(
                    statusCode: statusCode,
                    message: message,
                    onRetry: { content = .connecting },
                    onLocalMode: { content = .idle(serverUI: nil) },
                    onDevMode: onSwitchToDevMode
                )
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSettings) {
            SettingsView(onClose: { showSettings = false })
        }
    }

    private func connectAndLoadUI() {
        let baseURL = SearchEngineManager.shared.selectedEngineURL
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/$", with: "", options: .regularExpression)
        currentAddress = baseURL.isEmpty ? "" : "\(baseURL)/api/ui"
        Task {
            do {
                let dsl = try await EluminatiumService.shared.fetchSearchUI()
                do {
                    let node = try AlexandriaParser(source: dsl).parse()
                    await MainActor.run {
                        ConsoleStore.shared.log("[Spajanje] Swift kod parsiran uspješno", type: .info)
                        serverUINode = node
                        content = .idle(serverUI: node)
                        currentAddress = baseURL.isEmpty ? "" : baseURL
                    }
                } catch let parseError as AlexandriaParseError {
                    await MainActor.run {
                        ConsoleStore.shared.log("Swift greška: \(parseError.localizedDescription)", type: .error)
                        content = .error("Swift greška: \(parseError.localizedDescription)\n\nKoristi „Lokalni mod“ ili „Dev Mode“ za detalje.")
                    }
                } catch {
                    await MainActor.run {
                        ConsoleStore.shared.log("Swift greška: \(error.localizedDescription)", type: .error)
                        content = .error("Swift greška: \(error.localizedDescription)\n\nKoristi „Lokalni mod“ ili „Dev Mode“ za detalje.")
                    }
                }
            } catch let httpErr as HTTPStatusError {
                await MainActor.run {
                    ConsoleStore.shared.log("HTTP greška: \(httpErr.statusCode) – \(httpErr.message ?? "")", type: .error)
                    content = .httpError(statusCode: httpErr.statusCode, message: httpErr.message)
                }
            } catch {
                await MainActor.run {
                    ConsoleStore.shared.log("Veza neuspjela: \(error.localizedDescription)", type: .error)
                    content = .error("Nema veze s Eluminatiumom: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Shell: zelena pozadina, naslov, tražilica, popis stranica
struct EluminatiumShellView: View {
    @Binding var content: EluminatiumContent
    let serverUINode: AlexandriaViewNode?
    @Binding var initialSearchQuery: String?
    @Binding var currentAddress: String
    var onOpenSettings: (() -> Void)?
    var onOpenAppFromSearch: ((InstalledApp) -> Void)?
    var pageListItems: [EluminatiumPageItem]? = nil
    
    @State private var installingId: String?
    private let accentColor = Color(hex: "ff5c00")
    
    var body: some View {
        VStack(spacing: 0) {
            if let items = pageListItems, !items.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Spacer(minLength: 0)
                        SearchEngineSection(
                            content: $content,
                            initialSearchQuery: $initialSearchQuery,
                            currentAddress: $currentAddress,
                            onOpenSettings: onOpenSettings,
                            onOpenAppFromSearch: onOpenAppFromSearch,
                            shellStyle: true
                        )
                        .padding(.bottom, 16)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    HStack {
                        Button {
                            content = .idle(serverUI: serverUINode)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.left")
                                Text("Nazad")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 12)
                        Spacer()
                    }
                    EluminatiumPageListView(
                        items: items,
                        accentColor: accentColor,
                        installingId: installingId,
                        onSelect: { item in
                            handlePageSelect(item)
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let node = serverUINode {
                // ZStack: sadržaj s backenda u pozadini, unos (bijela kartica) točno u sredini ekrana
                ZStack {
                    AlexandriaRenderer(node: node)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    SearchEngineSection(
                        content: $content,
                        initialSearchQuery: $initialSearchQuery,
                        currentAddress: $currentAddress,
                        onOpenSettings: onOpenSettings,
                        onOpenAppFromSearch: onOpenAppFromSearch,
                        shellStyle: true
                    )
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Nema sadržaja s backenda – naslov + unos centrirani u sredini
                ZStack {
                    VStack(spacing: 20) {
                        Text("Eluminatium")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        SearchEngineSection(
                            content: $content,
                            initialSearchQuery: $initialSearchQuery,
                            currentAddress: $currentAddress,
                            onOpenSettings: onOpenSettings,
                            onOpenAppFromSearch: onOpenAppFromSearch,
                            shellStyle: true
                        )
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func handlePageSelect(_ item: EluminatiumPageItem) {
        switch item {
        case .catalog(let catalogItem):
            installingId = catalogItem.id
            Task {
                do {
                    let zipData = try await EluminatiumService.shared.downloadZip(appId: catalogItem.id)
                    let installed = try AppInstallService.shared.install(from: zipData)
                    await MainActor.run {
                        installingId = nil
                        content = .idle(serverUI: serverUINode)
                        onOpenAppFromSearch?(installed)
                    }
                } catch {
                    await MainActor.run {
                        installingId = nil
                        ConsoleStore.shared.log("Instalacija: \(error.localizedDescription)", type: .error)
                    }
                }
            }
        case .file(_, let node):
            content = .app(node)
        }
    }
}

// MARK: - Popis stranica (prije otvaranja)
struct EluminatiumPageListView: View {
    let items: [EluminatiumPageItem]
    let accentColor: Color
    let installingId: String?
    let onSelect: (EluminatiumPageItem) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    pageRow(item)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    @ViewBuilder
    private func pageRow(_ item: EluminatiumPageItem) -> some View {
        let (name, desc, isCatalog, iconUrl) = itemDisplay(item)
        Button {
            onSelect(item)
        } label: {
            HStack(spacing: 16) {
                AppIconView(iconUrl: isCatalog ? iconUrl : nil, systemName: isCatalog ? "app.badge.fill" : "doc.text.fill", size: 28, accentColor: accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    if let d = desc {
                        Text(d)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
                if case .catalog(let app) = item, installingId == app.id {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                        .frame(width: 80, height: 32)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .disabled(isCatalog && installingId != nil)
    }
    
    private func itemDisplay(_ item: EluminatiumPageItem) -> (String, String?, Bool, String?) {
        switch item {
        case .catalog(let app):
            return (app.name, app.description, true, app.iconUrl)
        case .file(let name, _):
            return (name, nil, false, nil)
        }
    }
}

// MARK: - Search Engine (tražilica – uvijek prikazana kad je idle)
struct SearchEngineSection: View {
    @Binding var content: EluminatiumContent
    @Binding var initialSearchQuery: String?
    @Binding var currentAddress: String
    @State private var isHovering = false
    @State private var searchText = ""
    @State private var suggestions: [EluminatiumAppCatalogItem] = []
    @State private var suggestionsTask: Task<Void, Never>?
    @State private var installingSuggestionId: String?
    var onOpenSettings: (() -> Void)?
    var onOpenAppFromSearch: ((InstalledApp) -> Void)?
    var shellStyle: Bool = false  // zelena pozadina – svjetlija kartica

    private let accentColor = Color(hex: "ff5c00")

    var body: some View {
        VStack(spacing: 12) {
            SearchBar(
                searchText: $searchText,
                accentColor: shellStyle ? Color.black : accentColor,
                onSubmit: { performSearch() },
                shellStyle: shellStyle
            )

            if !suggestions.isEmpty && !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                SearchSuggestionsDropdown(
                    suggestions: suggestions,
                    accentColor: shellStyle ? Color.black : accentColor,
                    installingId: installingSuggestionId,
                    onSelect: { selectSuggestion($0) },
                    shellStyle: shellStyle
                )
            }
        }
        .padding(24)
        .frame(maxWidth: 440)
        .foregroundColor(shellStyle ? .black : .white)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
        )
        .onChange(of: searchText) { _, newValue in
            fetchSuggestionsDebounced(for: newValue)
        }
        .onChange(of: initialSearchQuery) { _, newValue in
            guard let query = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else { return }
            searchText = query
            performSearch(with: query, source: .island)
            initialSearchQuery = nil
        }
        .task(id: initialSearchQuery) {
            guard let query = initialSearchQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty else { return }
            searchText = query
            performSearch(with: query, source: .island)
            initialSearchQuery = nil
        }
    }

    private func fetchSuggestionsDebounced(for text: String) {
        suggestionsTask?.cancel()
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            suggestions = []
            return
        }
        suggestionsTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            do {
                let apps = try await EluminatiumService.shared.search(query: q, source: .suggestions)
                await MainActor.run { suggestions = apps }
            } catch {
                await MainActor.run { suggestions = [] }
            }
        }
    }

    private func selectSuggestion(_ catalogItem: EluminatiumAppCatalogItem) {
        suggestions = []
        installingSuggestionId = catalogItem.id
        Task {
            do {
                let zipData = try await EluminatiumService.shared.downloadZip(appId: catalogItem.id)
                let installed = try AppInstallService.shared.install(from: zipData)
                await MainActor.run {
                    installingSuggestionId = nil
                    onOpenAppFromSearch?(installed)
                }
            } catch {
                await MainActor.run {
                    installingSuggestionId = nil
                    ConsoleStore.shared.log("Instalacija: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }

    private func performSearch() {
        suggestions = []
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        performSearch(with: query, source: .searchBar)
    }

    private func performSearch(with query: String, source: EluminatiumRequestSource = .searchBar) {
        guard !query.isEmpty else { return }

        // Samo Eluminatium katalog – što god korisnik upisao = pretraga kataloga
        var searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: query), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty {
            currentAddress = url.absoluteString
            searchQuery = host
        }

        content = .loading
        let baseURL = SearchEngineManager.shared.selectedEngineURL
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "/$", with: "", options: .regularExpression)
        let searchURL = baseURL.isEmpty ? "" : "\(baseURL)/api/search?q=\(searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery)"
        Task {
            do {
                let apps = try await EluminatiumService.shared.search(query: searchQuery, source: source)
                await MainActor.run {
                    if apps.isEmpty {
                        content = .error("Nema aplikacije „\(searchQuery)“ u katalogu.")
                    } else {
                        content = .pageList(apps.map { .catalog($0) })
                        currentAddress = searchURL
                    }
                }
            } catch {
                await MainActor.run {
                    ConsoleStore.shared.log("Pretraga greška: \(error.localizedDescription)", type: .error)
                    content = .error("Pretraga: \(error.localizedDescription)")
                }
            }
        }
    }

    private func tryParseAndRender(_ source: String) -> EluminatiumContent {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let swiftViewKeywords = ["vstack", "hstack", "zstack", "scrollview", "list", "form", "grid", "tabview", "group", "groupbox", "section", "disclosuregroup", "text", "button", "image", "label", "link", "textfield", "securefield", "texteditor", "toggle", "slider", "stepper", "picker", "progressview", "gauge", "menu", "spacer", "divider", "color", "rectangle", "circle", "roundedrectangle", "ellipse", "capsule", "lazyvstack", "lazyhstack", "padding", "frame", "position", "positioned", "background", "foreground"]
        let firstWord = trimmed.prefix(100).lowercased()
        let looksLikeSwift = swiftViewKeywords.contains { firstWord.contains($0) }
        
        if looksLikeSwift {
            do {
                let parser = AlexandriaParser(source: trimmed)
                let node = try parser.parse()
                ConsoleStore.shared.log("Swift (Alexandria) parsiran uspješno")
                return .app(node)
            } catch {
                ConsoleStore.shared.log("Parse error: \(error)")
                return .code(source)
            }
        }
        return .code(source)
    }
}

// MARK: - Rezultati pretrage (lista appova s Eluminatium servera)
struct EluminatiumSearchResultsView: View {
    let apps: [EluminatiumAppCatalogItem]
    let onBack: () -> Void
    let onOpenApp: (InstalledApp) -> Void
    
    @State private var installingId: String?
    @State private var errorMessage: String?
    private let accentColor = Color(hex: "ff5c00")
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { onBack() } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(accentColor)
                }
                .buttonStyle(.plain)
                .padding(12)
                Text("Rezultati pretrage")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }
            .background(Color.black.opacity(0.5))
            
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .padding(12)
            }
            
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(apps) { app in
                        HStack(spacing: 16) {
                            Image(systemName: "app.badge.fill")
                                .font(.system(size: 28))
                                .foregroundColor(accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                if let desc = app.description {
                                    Text(desc)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                            }
                            Spacer()
                            Button {
                                installAndOpen(app)
                            } label: {
                                if installingId == app.id {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                        .frame(width: 80, height: 32)
                                } else {
                                    Text("Instaliraj i otvori")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(accentColor))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(installingId != nil)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func installAndOpen(_ catalogItem: EluminatiumAppCatalogItem) {
        installingId = catalogItem.id
        errorMessage = nil
        Task {
            do {
                let zipData = try await EluminatiumService.shared.downloadZip(appId: catalogItem.id)
                let installed = try AppInstallService.shared.install(from: zipData)
                await MainActor.run {
                    installingId = nil
                    onOpenApp(installed)
                }
            } catch {
                await MainActor.run {
                    installingId = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Suggestions dropdown (autocomplete – npr. "g" → Google, Gmail)
struct SearchSuggestionsDropdown: View {
    let suggestions: [EluminatiumAppCatalogItem]
    let accentColor: Color
    let installingId: String?
    let onSelect: (EluminatiumAppCatalogItem) -> Void
    var shellStyle: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ForEach(suggestions.prefix(6)) { app in
                Button {
                    onSelect(app)
                } label: {
                    HStack(spacing: 12) {
                        AppIconView(iconUrl: app.iconUrl, systemName: "app.badge.fill", size: 20, accentColor: accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(shellStyle ? .black : .white)
                            if let desc = app.description {
                                Text(desc)
                                    .font(.system(size: 11))
                                    .foregroundColor(shellStyle ? .black.opacity(0.7) : .white.opacity(0.6))
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if installingId == app.id {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(shellStyle ? .black : .white)
                        } else {
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 12))
                                .foregroundColor(accentColor.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(shellStyle ? Color.black.opacity(0.06) : Color.white.opacity(0.06))
                }
                .buttonStyle(.plain)
                .disabled(installingId != nil)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(shellStyle ? Color.white.opacity(0.2) : Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.top, 4)
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var searchText: String
    let accentColor: Color
    var onSubmit: (() -> Void)?
    var shellStyle: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            SearchTextField(
                placeholder: "",
                text: $searchText,
                onSubmit: onSubmit,
                textColor: .black
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            
            HStack(spacing: 20) {
                Button { } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
                Button { } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }
                .buttonStyle(.plain)
                Button {
                    onSubmit?()
                } label: {
                    Text("Go")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Search Settings Row
struct SearchSettingsRow: View {
    let accentColor: Color
    var onOpenSettings: (() -> Void)?

    var body: some View {
        HStack(spacing: 16) {
            SearchSettingChip(icon: "globe", label: "Default engine", accentColor: accentColor)
            SearchSettingChip(icon: "lock.shield", label: "Private", accentColor: accentColor)
            SearchSettingChip(icon: "arrow.up.arrow.down", label: "Sort", accentColor: accentColor)
            SearchSettingChip(icon: "gearshape", label: "Više", accentColor: accentColor, action: onOpenSettings)
        }
    }
}

struct SearchSettingChip: View {
    let icon: String
    let label: String
    let accentColor: Color
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hover Proximity Zone
struct HoverProximityZone<Content: View>: View {
    @Binding var isHovering: Bool
    let proximityPadding: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(proximityPadding)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
    }
}
