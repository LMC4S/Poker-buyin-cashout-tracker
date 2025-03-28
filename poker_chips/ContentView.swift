//
//  ContentView.swift
//  poker_chips
//
//  Created by lmc4s on 3/26/25.
//

import SwiftUI
import AudioToolbox

enum TransactionType: String, Codable {
    case buyIn = "Buy-In"
    case cashOut = "Cash Out"
}

struct PlayerName: Identifiable {
    let name: String
    var id: String { name }
}

struct LogEntry: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let player: String
    let amount: Double
    let type: TransactionType
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }
    
    private enum CodingKeys: String, CodingKey {
        case timestamp, player, amount, type
    }
}

// MARK: - Data Models

struct Session: Identifiable, Codable {  // <-- Added Codable conformance
    var id = UUID()
    let startDate: Date
    var buyIns: [String: Double]
    var logRecords: [LogEntry] = []
    var cashOuts: [String: Double] = [:]  // <-- Added cashOuts property
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: startDate)
    }
}

// MARK: - Session Store

class SessionStore: ObservableObject {
    // A simple in-memory storage of sessions
    @Published var sessions: [Session] = []
    @Published var currentSession: Session? = nil {
        didSet {
            SessionPersistenceManager.shared.saveActiveSession(currentSession)
        }
    }
    
    // Saved player names for quick selection
    @Published var savedPlayerNames: [String] = [] {
        didSet {
            saveSavedPlayerNames()
        }
    }
    
    private let savedPlayerNamesKey = "saved_player_names"
    
    // New initializer to load saved sessions and player names from persistence
    init() {
        sessions = SessionPersistenceManager.shared.loadSessions()
        currentSession = SessionPersistenceManager.shared.loadActiveSession()
        loadSavedPlayerNames()
    }
    
    // Load saved player names from UserDefaults
    private func loadSavedPlayerNames() {
        if let data = UserDefaults.standard.stringArray(forKey: savedPlayerNamesKey) {
            savedPlayerNames = data
        }
    }
    
    // Save player names to UserDefaults
    private func saveSavedPlayerNames() {
        UserDefaults.standard.set(savedPlayerNames, forKey: savedPlayerNamesKey)
    }
    
    // Add a new player name to saved names if it doesn't already exist
    func addPlayerNameToSaved(_ name: String) {
        if !savedPlayerNames.contains(name) {
            savedPlayerNames.append(name)
        }
    }
    
    // Remove a player name from saved names
    func removePlayerName(at index: Int) {
        if index >= 0 && index < savedPlayerNames.count {
            savedPlayerNames.remove(at: index)
        }
    }
    
    func startNewSession() {
        // Start a new session with an empty dictionary; players will be added when registered
        currentSession = Session(startDate: Date(), buyIns: [:])
    }
    
    func addBuyIn(for player: String, amount: Double) {
        guard var session = currentSession else { return }
        session.buyIns[player, default: 0.0] += amount
        let record = LogEntry(timestamp: Date(), player: player, amount: amount, type: .buyIn)
        session.logRecords.append(record)
        currentSession = session
    }
    
    func cashOut(for player: String, chipStack: Double) {
        guard var session = currentSession else { return }
        session.cashOuts[player] = chipStack
        let record = LogEntry(timestamp: Date(), player: player, amount: chipStack, type: .cashOut)
        session.logRecords.append(record)
        currentSession = session
    }
    
    func endSession() {
        if let session = currentSession {
            sessions.append(session)
            SessionPersistenceManager.shared.saveSessions(sessions)  // Save sessions persistently
            currentSession = nil  // This will automatically clear the active session in persistence
        }
    }
    
    func deleteSession(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        SessionPersistenceManager.shared.saveSessions(sessions)
    }
}

// MARK: - ContentView & Home Screen

struct ContentView: View {
    @StateObject var sessionStore = SessionStore()
    
    var body: some View {
        ZStack {
            // Casino table green background
            Color(red: 0.0, green: 0.4, blue: 0.0)
                .ignoresSafeArea()
            NavigationStack {
                HomeView()
                    .environmentObject(sessionStore)
            }
        }
        .tint(.red) // Casino red accent color
    }
}

struct HomeView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var showSettings: Bool = false
    @State private var showInstructions: Bool = false
    @State private var navigateToSessionView: Bool = false
    @State private var showExportView: Bool = false
    
    
    var pastSessionsSection: some View {
        Section(header: Text("Past Sessions")) {
            ForEach(sessionStore.sessions.indices, id: \.self) { index in
                let session = sessionStore.sessions[index]
                NavigationLink(destination: SessionDetailView(session: session)) {
                    Text("Game \(index + 1) – \(session.formattedDate)")
                }
                .swipeActions {
                    Button(role: .destructive) {
                        sessionStore.deleteSession(at: IndexSet(integer: index))
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(Color(UIColor.systemBackground).opacity(0.8))
            }
        }
    }
    
    var body: some View {
        VStack {
            List {
                pastSessionsSection
            }
            .listStyle(InsetGroupedListStyle())

            if let _ = sessionStore.currentSession {
                NavigationLink("Resume Session", destination: SessionView().environmentObject(sessionStore))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [Color.red, Color.yellow]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .shadow(color: Color.gray.opacity(0.5), radius: 5, x: 0, y: 2)
                    .padding([.horizontal, .bottom])
            } else {
                Button("Start New Session") {
                    sessionStore.startNewSession()
                    navigateToSessionView = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(gradient: Gradient(colors: [Color.red, Color.yellow]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(8)
                .foregroundColor(.white)
                .shadow(color: Color.gray.opacity(0.5), radius: 5, x: 0, y: 2)
                .padding([.horizontal, .bottom])
            }
            NavigationLink(
                destination: SessionView().environmentObject(sessionStore),
                isActive: $navigateToSessionView,
                label: { EmptyView() }
            )
            .hidden()
        }
        .navigationTitle("Home Game Tracker")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showExportView = true
                    }) {
                        Label("Export Sessions", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        Label("Settings", systemImage: "gear")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showExportView) {
            ExportView()
                .environmentObject(sessionStore)
        }
    }
}

// MARK: - Active Session View

struct SessionView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlayer: String? = nil
    @State private var showNewPlayerRegistration = false
    @State private var showTotals = false
    @State private var showEndSessionAlert = false
    @State private var showLog = false
    @State private var showInstructions: Bool = false
    
    var body: some View {
        VStack {
            // List of registered players from the current session with scroll capability
            ScrollView {
                if let session = sessionStore.currentSession {
                    ForEach(session.buyIns.keys.sorted(), id: \.self) { player in
                        if session.cashOuts[player] != nil {
                            Text(player)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            Button(action: {
                                selectedPlayer = player
                            }) {
                                Text(player)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            Spacer()
            
            // New Player button moved to the bottom
            Button("New Player") {
                showNewPlayerRegistration = true
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(LinearGradient(gradient: Gradient(colors: [Color.red, Color.yellow]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(8)
            .foregroundColor(.white)
            .shadow(color: Color.gray.opacity(0.5), radius: 5, x: 0, y: 2)
            .padding(.horizontal)

            // Totals and End Session buttons
            HStack {
                Button("View Totals") {
                    showTotals = true
                }
                .padding()
                
                Spacer()
                
                Button("View Log") {
                    showLog = true
                }
                .padding()
                
                Spacer()
                
                Button("End Session") {
                    showEndSessionAlert = true
                }
                .padding()
            }
            .padding()
        }
        .navigationBarTitle("Active Session", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showInstructions = true
                }) {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
        // Modal sheet for new player registration
        .sheet(isPresented: $showNewPlayerRegistration) {
            NewPlayerRegistrationView { name in
                selectedPlayer = name
                showNewPlayerRegistration = false
            }
            .environmentObject(sessionStore)
        }
        // Modal sheet for buy-in selection
        .sheet(isPresented: Binding(
            get: { selectedPlayer != nil },
            set: { if !$0 { selectedPlayer = nil } }
        )) {
            BuyInSelectionView(player: selectedPlayer ?? "")
                .environmentObject(sessionStore)
        }
        // Modal sheet for viewing totals
        .sheet(isPresented: $showTotals) {
            TotalsView()
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showLog) {
            LogView()
                .environmentObject(sessionStore)
        }
        .alert("Confirm End Session", isPresented: $showEndSessionAlert) {
            Button("Yes", role: .destructive) {
                sessionStore.endSession()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to end this session?")
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsView()
        }
    }
}

// MARK: - Buy-In Selection View

struct BuyInSelectionView: View {
    @EnvironmentObject var sessionStore: SessionStore
    let player: String
    @Environment(\.presentationMode) var presentationMode
    @State private var manualAmount: String = ""
    @State private var showManualEntry = false
    @State private var showCashOutEntry = false  // <-- Added cashOutEntry state
    @State private var cashOutAmount: String = "" // <-- Added cashOutAmount state
    @State private var showConfirmationAlert = false
    @State private var confirmationMessage: String = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Buy-In Options")) {
                    ForEach([10, 20, 30, 40, 50], id: \.self) { amount in
                        Button("$\(amount)") {
                            sessionStore.addBuyIn(for: player, amount: Double(amount))
                            confirmationMessage = "Added buy-in of $\(amount) for \(player)"
                            showConfirmationAlert = true
                        }
                    }
                    Button("Manual") {
                        showManualEntry = true
                    }
                }
                Section(header: Text("Leaving")) {
                    Button("Cash Out") {
                        showCashOutEntry = true
                    }
                }
            }
            .navigationTitle("Buy-In for \(player)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            // Alert for manual amount entry
            .alert("Enter Custom Amount", isPresented: $showManualEntry, actions: {
                TextField("Amount", text: $manualAmount)
                    .keyboardType(.decimalPad)
                Button("Add") {
                    if let amount = Double(manualAmount) {
                        sessionStore.addBuyIn(for: player, amount: amount)
                        confirmationMessage = "Added buy-in of $\(amount) for \(player)"
                        showConfirmationAlert = true
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            })
            // Alert for cash out entry
            .alert("Enter Cash Out Value (in dollars)", isPresented: $showCashOutEntry, actions: {
                TextField("$ Value (e.g., 20 for $20)", text: $cashOutAmount)
                    .keyboardType(.decimalPad)
                Button("Cash Out") {
                    if let cashOutValue = Double(cashOutAmount) {
                        sessionStore.cashOut(for: player, chipStack: cashOutValue)
                        confirmationMessage = "Cashed out \(player) with $\(cashOutValue)"
                        showConfirmationAlert = true
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                Button("Cancel", role: .cancel) { }
            })
        }
        .alert("Confirmation", isPresented: $showConfirmationAlert, actions: {
            Button("OK") {
                presentationMode.wrappedValue.dismiss()
            }
        }, message: {
            Text(confirmationMessage)
                .onAppear {
                    if UserDefaults.standard.bool(forKey: "vibrationEnabled") {
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                    }
                    if UserDefaults.standard.bool(forKey: "soundEnabled") {
                        AudioServicesPlaySystemSound(1013)
                    }
                }
        })
    }
}

// MARK: - Totals View

struct TotalsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.presentationMode) var presentationMode
    
    // Computed property to calculate the table balance
    var tableBalance: Double {
        if let session = sessionStore.currentSession {
            let totalBuyIn = session.buyIns.values.reduce(0, +)
            let totalCashOut = session.cashOuts.values.reduce(0, +)
            return totalBuyIn - totalCashOut
        }
        return 0.0
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Players")) {
                    if let session = sessionStore.currentSession {
                        ForEach(session.buyIns.keys.sorted(), id: \.self) { player in
                            if let buyInTotal = session.buyIns[player] {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player)
                                        .font(.headline)
                                    Text("Buy-In: $\(buyInTotal, specifier: "%.2f")")
                                    if let cashOut = session.cashOuts[player] {
                                        let net = cashOut - buyInTotal
                                        Text("Cashed Out: $\(cashOut, specifier: "%.2f")")
                                        Text("Net: $\(net, specifier: "%.2f")")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                
                // New section displaying the table-wide balance
                Section(header: Text("Table Balance")) {
                    Text("$\(tableBalance, specifier: "%.2f")")
                }
            }
            .navigationTitle("Current Totals")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Log View

struct LogView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                if let session = sessionStore.currentSession {
                    ForEach(session.logRecords.reversed(), id: \.id) { record in
                    Text("\(record.formattedTime) - \(record.player): \(record.type.rawValue) $\(record.amount, specifier: "%.2f")")
                    }
                }
            }
            .navigationTitle("Game Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Instructions View

struct InstructionsView: View {
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Welcome to Poker Home Game Tracker!")
                        .font(.title)
                        .padding(.bottom, 8)
                    Text("Instructions:")
                        .font(.headline)
                    Text("• Tap 'Start New Session' to begin a new game.")
                    Text("• During a session, tap on a player's name to add a buy-in amount.")
                    Text("• For cash outs, tap the 'Cash Out' option and enter the chip stack's dollar value (displayed with a $ sign).")
                    Text("• Use the 'New Player' button to register additional players.")
                    Text("• View current totals with the 'View Totals' button and see individual transactions with the 'View Log' button.")
                    Text("• End your session by tapping 'End Session' and confirming the action.")
                    Text("• Export your session data by tapping the menu button (⋯) in the top-right corner and selecting 'Export Sessions'. You can choose between JSON and CSV formats and select which sessions to export.")
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - App Entry Point

struct NewPlayerRegistrationView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.presentationMode) var presentationMode
    @State private var manualName: String = ""
    let onSelect: (String) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Enter New Player Name")) {
                    TextField("Player Name", text: $manualName)
                    Button("Register") {
                        if !manualName.isEmpty {
                            // Save the new name for future quick selection
                            sessionStore.addPlayerNameToSaved(manualName)
                            onSelect(manualName)
                        }
                    }
                }
                
                if !sessionStore.savedPlayerNames.isEmpty {
                    Section(header: Text("Quick Select")) {
                        ForEach(sessionStore.savedPlayerNames.indices, id: \.self) { index in
                            let name = sessionStore.savedPlayerNames[index]
                            Button(name) {
                                onSelect(name)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    sessionStore.removePlayerName(at: index)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Player")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("vibrationEnabled") var vibrationEnabled: Bool = true
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    
    var body: some View {
        NavigationView {
            Form {
                Toggle("Vibration", isOn: $vibrationEnabled)
                Toggle("Sound", isOn: $soundEnabled)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Export View

struct ExportView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedFormat: ExportFormat = .json
    @State private var selectedSessions: Set<UUID> = []
    @State private var isExporting = false
    @State private var exportURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"
        case csv = "CSV"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Select Sessions")) {
                    Button("Select All") {
                        if selectedSessions.count == sessionStore.sessions.count {
                            selectedSessions.removeAll()
                        } else {
                            selectedSessions = Set(sessionStore.sessions.map { $0.id })
                        }
                    }
                    
                    ForEach(sessionStore.sessions) { session in
                        HStack {
                            Text("Game – \(session.formattedDate)")
                            Spacer()
                            if selectedSessions.contains(session.id) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedSessions.contains(session.id) {
                                selectedSessions.remove(session.id)
                            } else {
                                selectedSessions.insert(session.id)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: exportSessions) {
                        HStack {
                            Spacer()
                            Text("Export")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(selectedSessions.isEmpty || isExporting)
                }
            }
            .navigationTitle("Export Sessions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Export Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func exportSessions() {
        guard !selectedSessions.isEmpty else { return }
        
        isExporting = true
        
        // Filter selected sessions
        let sessionsToExport = sessionStore.sessions.filter { selectedSessions.contains($0.id) }
        
        // Export based on selected format
        switch selectedFormat {
        case .json:
            if let url = SessionPersistenceManager.shared.exportSessionsToJSON(sessions: sessionsToExport) {
                exportURL = url
                showShareSheet = true
            } else {
                alertMessage = "Failed to export sessions to JSON."
                showAlert = true
            }
        case .csv:
            if let url = SessionPersistenceManager.shared.exportSessionsToCSV(sessions: sessionsToExport) {
                exportURL = url
                showShareSheet = true
            } else {
                alertMessage = "Failed to export sessions to CSV."
                showAlert = true
            }
        }
        
        isExporting = false
    }
}

// ShareSheet for exporting files
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

@main
struct PokerBuyInTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
