//
//  ContentView.swift
//  poker_chips
//
//  Created by lmc4s on 3/26/25.
//

import SwiftUI

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
    @Published var currentSession: Session? = nil
    
    // Predefined players
    let players = ["Alice", "Bob", "Charlie", "Dave", "Eve", "Frank", "Grace", "Heidi", "Ivan", "Judy", "Mallory"]
    
    // New initializer to load saved sessions from persistence
    init() {
        sessions = SessionPersistenceManager.shared.loadSessions()
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
            SessionPersistenceManager.shared.saveSessions(sessions)  // <-- Save sessions persistently
            currentSession = nil
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
        NavigationStack {
            HomeView()
                .environmentObject(sessionStore)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var showInstructions: Bool = false
    
    var activeBinding: Binding<Bool> {
        Binding(
            get: { sessionStore.currentSession != nil },
            set: { newValue in
                if !newValue {
                    sessionStore.endSession()
                }
            }
        )
    }
    
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
            }
        }
    }
    
    var body: some View {
        VStack {
            List {
                pastSessionsSection
            }
            
            // Only show Start New Session button if there's no active session
            if sessionStore.currentSession == nil {
                Button("Start New Session") {
                    sessionStore.startNewSession()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
                .padding([.horizontal, .bottom])
            }
        }
        .navigationTitle("Poker Buy-In Tracker")
        .navigationDestination(isPresented: activeBinding) {
            SessionView()
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsView()
        }
    }
}

// MARK: - Active Session View

struct SessionView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var selectedPlayer: String? = nil
    @State private var showNewPlayerRegistration = false
    @State private var showTotals = false
    @State private var showEndSessionAlert = false
    @State private var showLog = false
    @State private var showInstructions: Bool = false
    
    var body: some View {
        VStack {
            // List of registered players from the current session
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
            
            Spacer()
            
            // New Player button moved to the bottom
            Button("New Player") {
                showNewPlayerRegistration = true
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
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
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Buy-In Options")) {
                    ForEach([10, 20, 30, 40, 50], id: \.self) { amount in
                        Button("$\(amount)") {
                            sessionStore.addBuyIn(for: player, amount: Double(amount))
                            presentationMode.wrappedValue.dismiss()
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
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                Button("Cancel", role: .cancel) { }
            })
            // Alert for cash out entry
            .alert("Enter Chip Stack", isPresented: $showCashOutEntry, actions: {
                TextField("$ Chip Stack Value", text: $cashOutAmount)
                    .keyboardType(.decimalPad)
                Button("Cash Out") {
                    if let chipStack = Double(cashOutAmount) {
                        sessionStore.cashOut(for: player, chipStack: chipStack)
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                Button("Cancel", role: .cancel) { }
            })
        }
    }
}

// MARK: - Totals View

struct TotalsView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                if let session = sessionStore.currentSession {
                    ForEach(session.buyIns.keys.sorted(), id: \.self) { player in
                        if let buyInTotal = session.buyIns[player] {
                            if let cashOut = session.cashOuts[player] {
                                let net = cashOut - buyInTotal
                                Text("\(player): Buy-In: $\(buyInTotal, specifier: "%.2f"), Cashed Out: $\(cashOut, specifier: "%.2f"), Net: $\(net, specifier: "%.2f")")
                            } else {
                                Text("\(player): $\(buyInTotal, specifier: "%.2f")")
                            }
                        }
                    }
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
                    Text("Welcome to Poker Buy-In Tracker!")
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
                            onSelect(manualName)
                        }
                    }
                }
                Section(header: Text("Quick Select")) {
                    ForEach(sessionStore.players, id: \.self) { name in
                        Button(name) {
                            onSelect(name)
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

@main
struct PokerBuyInTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
