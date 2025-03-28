//
//  ContentView.swift
//  poker_chips
//
//  Created by lmc4s on 3/26/25.
//

import SwiftUI
import AudioToolbox

// MARK: - Custom Colors and Styles
struct AppColors {
    static let background = Color(red: 0.05, green: 0.25, blue: 0.15)
    static let cardBackground = Color(red: 0.1, green: 0.3, blue: 0.2)
    static let accent = Color(red: 0.8, green: 0.1, blue: 0.2)
    static let secondaryAccent = Color(red: 0.9, green: 0.7, blue: 0.2)
    static let text = Color.white
    static let secondaryText = Color(white: 0.9)
    static let success = Color(red: 0.2, green: 0.8, blue: 0.2)
    static let warning = Color(red: 0.9, green: 0.6, blue: 0.1)
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [AppColors.accent, AppColors.accent.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
            .foregroundColor(.white)
            .shadow(color: AppColors.accent.opacity(0.5), radius: 5, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            .foregroundColor(AppColors.text)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.secondaryAccent, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

enum TransactionType: String, Codable {
    case buyIn = "Buy-In"
    case cashOut = "Cash Out"
    
    var icon: String {
        switch self {
        case .buyIn:
            return "arrow.down.circle.fill"
        case .cashOut:
            return "arrow.up.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .buyIn:
            return AppColors.secondaryAccent
        case .cashOut:
            return AppColors.success
        }
    }
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
            // Custom poker table background with gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.background,
                    AppColors.background.opacity(0.9),
                    AppColors.cardBackground.opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Subtle pattern overlay
            Image(systemName: "suit.club.fill")
                .resizable(resizingMode: .tile)
                .foregroundColor(Color.white.opacity(0.03))
                .ignoresSafeArea()
            
            NavigationStack {
                HomeView()
                    .environmentObject(sessionStore)
            }
        }
        .tint(AppColors.accent)
        .preferredColorScheme(.dark)
    }
}

struct HomeView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @State private var showSettings: Bool = false
    @State private var showInstructions: Bool = false
    @State private var navigateToSessionView: Bool = false
    @State private var showExportView: Bool = false
    @State private var animateCards = false
    
    var pastSessionsSection: some View {
        Section(header: Text("Past Sessions")
            .font(.headline)
            .foregroundColor(AppColors.secondaryAccent)) {
            if sessionStore.sessions.isEmpty {
                Text("No past sessions yet")
                    .foregroundColor(AppColors.secondaryText)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .listRowBackground(Color.clear)
            } else {
                ForEach(sessionStore.sessions.indices, id: \.self) { index in
                    let session = sessionStore.sessions[index]
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(AppColors.secondaryAccent)
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Game \(index + 1)")
                                    .font(.headline)
                                    .foregroundColor(AppColors.text)
                                
                                Text(session.formattedDate)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.secondaryText)
                            }
                            
                            Spacer()
                            
                            Text("\(session.buyIns.count) players")
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                                .padding(6)
                                .background(AppColors.cardBackground)
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(AppColors.cardBackground.opacity(0.8))
                    .swipeActions {
                        Button(role: .destructive) {
                            sessionStore.deleteSession(at: IndexSet(integer: index))
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .opacity(animateCards ? 1 : 0)
                    .offset(x: animateCards ? 0 : -20)
                    .animation(.easeOut.delay(Double(index) * 0.1), value: animateCards)
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient for HomeView
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.background,
                    AppColors.background.opacity(0.9),
                    AppColors.cardBackground.opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Logo/Header area
                VStack {
                    HStack {
                        Image(systemName: "suit.spade.fill")
                        Image(systemName: "suit.heart.fill")
                            .foregroundColor(AppColors.accent)
                        Image(systemName: "suit.club.fill")
                        Image(systemName: "suit.diamond.fill")
                            .foregroundColor(AppColors.accent)
                    }
                    .font(.largeTitle)
                    .padding(.top)
                    
                    Text("POKER at ONE PARK VIEW")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.text)
                        .padding(.bottom, 5)
                    
                    Text("Home Game Tracker")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.bottom)
                }
                .frame(maxWidth: .infinity)
                .background(
                    AppColors.cardBackground
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 5)
                )
            
                List {
                    pastSessionsSection
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)

                VStack(spacing: 16) {
                if let _ = sessionStore.currentSession {
                    NavigationLink(destination: SessionView().environmentObject(sessionStore)) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.headline)
                            Text("Resume Session")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(action: {
                        sessionStore.startNewSession()
                        navigateToSessionView = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline)
                            Text("Start New Session")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                HStack(spacing: 16) {
                    Button(action: {
                        showInstructions = true
                    }) {
                        VStack {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title2)
                            Text("Help")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        showSettings = true
                    }) {
                        VStack {
                            Image(systemName: "gear")
                                .font(.title2)
                            Text("Settings")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        showExportView = true
                    }) {
                        VStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                            Text("Export")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
                }
                .padding()
                .background(
                    AppColors.cardBackground.opacity(0.3)
                )
                
                NavigationLink(
                    destination: SessionView().environmentObject(sessionStore),
                    isActive: $navigateToSessionView,
                    label: { EmptyView() }
                )
                .hidden()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Trigger animations when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    animateCards = true
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
    @State private var animateItems = false
    
    var body: some View {
        ZStack {
            // Background gradient for SessionView
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.background,
                    AppColors.background.opacity(0.9),
                    AppColors.cardBackground.opacity(0.8)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with session info
                VStack {
                    if let session = sessionStore.currentSession {
                        Text("Active Session")
                            .font(.headline)
                            .foregroundColor(AppColors.secondaryAccent)
                        
                        Text(session.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.cardBackground)
            
                // List of registered players
                ScrollView {
                    VStack(spacing: 12) {
                    if let session = sessionStore.currentSession {
                        ForEach(session.buyIns.keys.sorted(), id: \.self) { player in
                            let isCashedOut = session.cashOuts[player] != nil
                            let buyInAmount = session.buyIns[player] ?? 0
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player)
                                        .font(.headline)
                                        .foregroundColor(isCashedOut ? AppColors.secondaryText : AppColors.text)
                                    
                                    Text("Buy-In: $\(buyInAmount, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.secondaryText)
                                    
                                    if let cashOut = session.cashOuts[player] {
                                        let net = cashOut - buyInAmount
                                        let netColor = net >= 0 ? AppColors.success : AppColors.accent
                                        
                                        Text("Cashed Out: $\(cashOut, specifier: "%.2f")")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.secondaryText)
                                        
                                        Text("Net: \(net >= 0 ? "+" : "")\(net, specifier: "$%.2f")")
                                            .font(.subheadline)
                                            .foregroundColor(netColor)
                                    }
                                }
                                
                                Spacer()
                                
                                if isCashedOut {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppColors.success)
                                        .font(.title2)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .foregroundColor(AppColors.secondaryAccent)
                                        .font(.title2)
                                }
                            }
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            .padding(.horizontal)
                            .opacity(isCashedOut ? 0.7 : 1.0)
                            .onTapGesture {
                                if !isCashedOut {
                                    selectedPlayer = player
                                }
                            }
                            .opacity(animateItems ? 1 : 0)
                            .offset(y: animateItems ? 0 : 20)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(session.buyIns.keys.sorted().firstIndex(of: player) ?? 0) * 0.1), value: animateItems)
                        }
                    }
                    }
                    .padding(.vertical)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                Button(action: {
                    showNewPlayerRegistration = true
                }) {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.headline)
                        Text("New Player")
                            .font(.headline)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                
                HStack(spacing: 16) {
                    Button(action: {
                        showTotals = true
                    }) {
                        VStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(.title2)
                            Text("Totals")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        showLog = true
                    }) {
                        VStack {
                            Image(systemName: "list.bullet.clipboard")
                                .font(.title2)
                            Text("Log")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    Button(action: {
                        showEndSessionAlert = true
                    }) {
                        VStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                            Text("End")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
                }
                .padding()
                .background(
                    AppColors.cardBackground.opacity(0.3)
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Home")
                    }
                    .foregroundColor(AppColors.secondaryAccent)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showInstructions = true
                }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(AppColors.secondaryAccent)
                }
            }
        }
        .onAppear {
            // Trigger animations when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    animateItems = true
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
    @State private var showCashOutEntry = false
    @State private var cashOutAmount: String = ""
    @State private var showConfirmationAlert = false
    @State private var confirmationMessage: String = ""
    @State private var animateItems = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with player info
                    VStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.secondaryAccent)
                            .padding(.top)
                        
                        Text(player)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.text)
                            .padding(.bottom, 5)
                        
                        Text("Select an action")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                            .padding(.bottom)
                    }
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Buy-in options section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("BUY-IN OPTIONS")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.secondaryAccent)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 10) {
                                    ForEach([10, 20, 30, 40, 50], id: \.self) { amount in
                                        Button(action: {
                                            sessionStore.addBuyIn(for: player, amount: Double(amount))
                                            confirmationMessage = "Added buy-in of $\(amount) for \(player)"
                                            showConfirmationAlert = true
                                        }) {
                                            HStack {
                                                Image(systemName: "dollarsign.circle.fill")
                                                    .font(.title3)
                                                    .foregroundColor(AppColors.secondaryAccent)
                                                
                                                Text("$\(amount)")
                                                    .font(.headline)
                                                    .foregroundColor(AppColors.text)
                                                
                                                Spacer()
                                                
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(AppColors.secondaryText)
                                            }
                                            .padding()
                                            .background(AppColors.cardBackground)
                                            .cornerRadius(12)
                                        }
                                        .opacity(animateItems ? 1 : 0)
                                        .offset(y: animateItems ? 0 : 20)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double([10, 20, 30, 40, 50].firstIndex(of: amount) ?? 0) * 0.1), value: animateItems)
                                    }
                                    
                                    Button(action: {
                                        showManualEntry = true
                                    }) {
                                        HStack {
                                            Image(systemName: "keyboard")
                                                .font(.title3)
                                                .foregroundColor(AppColors.secondaryAccent)
                                            
                                            Text("Custom Amount")
                                                .font(.headline)
                                                .foregroundColor(AppColors.text)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AppColors.secondaryText)
                                        }
                                        .padding()
                                        .background(AppColors.cardBackground)
                                        .cornerRadius(12)
                                    }
                                    .opacity(animateItems ? 1 : 0)
                                    .offset(y: animateItems ? 0 : 20)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.5), value: animateItems)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.top)
                            
                            // Cash out section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("LEAVING THE GAME")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.success)
                                    .padding(.horizontal)
                                
                                Button(action: {
                                    showCashOutEntry = true
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(AppColors.success)
                                        
                                        Text("Cash Out")
                                            .font(.headline)
                                            .foregroundColor(AppColors.text)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.secondaryText)
                                    }
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                                .opacity(animateItems ? 1 : 0)
                                .offset(y: animateItems ? 0 : 20)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.6), value: animateItems)
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Player Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Trigger animations when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        animateItems = true
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
    @State private var animateItems = false
    
    // Computed property to calculate the table balance
    var tableBalance: Double {
        if let session = sessionStore.currentSession {
            let totalBuyIn = session.buyIns.values.reduce(0, +)
            let totalCashOut = session.cashOuts.values.reduce(0, +)
            return totalBuyIn - totalCashOut
        }
        return 0.0
    }
    
    // Computed property to calculate total profit/loss
    var totalProfitLoss: Double {
        if let session = sessionStore.currentSession {
            var total = 0.0
            for player in session.buyIns.keys {
                let buyIn = session.buyIns[player] ?? 0
                let cashOut = session.cashOuts[player] ?? 0
                total += (cashOut - buyIn)
            }
            return total
        }
        return 0.0
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with summary info
                    VStack(spacing: 8) {
                        Text("Session Summary")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.text)
                        
                        if let session = sessionStore.currentSession {
                            HStack {
                                VStack {
                                    Text("Players")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                    Text("\(session.buyIns.count)")
                                        .font(.headline)
                                        .foregroundColor(AppColors.secondaryAccent)
                                }
                                .frame(maxWidth: .infinity)
                                
                                Divider()
                                    .background(AppColors.secondaryText)
                                    .frame(height: 30)
                                
                                VStack {
                                    Text("Total Buy-In")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                    Text("$\(session.buyIns.values.reduce(0, +), specifier: "%.2f")")
                                        .font(.headline)
                                        .foregroundColor(AppColors.secondaryAccent)
                                }
                                .frame(maxWidth: .infinity)
                                
                                Divider()
                                    .background(AppColors.secondaryText)
                                    .frame(height: 30)
                                
                                VStack {
                                    Text("Balance")
                                        .font(.caption)
                                        .foregroundColor(AppColors.secondaryText)
                                    Text("$\(tableBalance, specifier: "%.2f")")
                                        .font(.headline)
                                        .foregroundColor(tableBalance >= 0 ? AppColors.success : AppColors.accent)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                            .background(AppColors.cardBackground.opacity(0.5))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    
                    // Player results
                    List {
                        Section(header: Text("Player Results")
                            .font(.headline)
                            .foregroundColor(AppColors.secondaryAccent)) {
                            if let session = sessionStore.currentSession {
                                ForEach(session.buyIns.keys.sorted(), id: \.self) { player in
                                    if let buyInTotal = session.buyIns[player] {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(player)
                                                    .font(.headline)
                                                    .foregroundColor(AppColors.text)
                                                
                                                HStack {
                                                    Image(systemName: "arrow.down.circle.fill")
                                                        .foregroundColor(AppColors.secondaryAccent)
                                                        .font(.caption)
                                                    Text("Buy-In: $\(buyInTotal, specifier: "%.2f")")
                                                        .font(.subheadline)
                                                        .foregroundColor(AppColors.secondaryText)
                                                }
                                                
                                                if let cashOut = session.cashOuts[player] {
                                                    let net = cashOut - buyInTotal
                                                    let netColor = net >= 0 ? AppColors.success : AppColors.accent
                                                    
                                                    HStack {
                                                        Image(systemName: "arrow.up.circle.fill")
                                                            .foregroundColor(AppColors.success)
                                                            .font(.caption)
                                                        Text("Cashed Out: $\(cashOut, specifier: "%.2f")")
                                                            .font(.subheadline)
                                                            .foregroundColor(AppColors.secondaryText)
                                                    }
                                                    
                                                    HStack {
                                                        Image(systemName: net >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                                                            .foregroundColor(netColor)
                                                            .font(.caption)
                                                        Text("Net: \(net >= 0 ? "+" : "")\(net, specifier: "$%.2f")")
                                                            .font(.subheadline)
                                                            .foregroundColor(netColor)
                                                    }
                                                } else {
                                                    Text("Not cashed out")
                                                        .font(.subheadline)
                                                        .foregroundColor(AppColors.accent)
                                                        .italic()
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            if let cashOut = session.cashOuts[player] {
                                                let net = cashOut - buyInTotal
                                                if net >= 0 {
                                                    Image(systemName: "arrow.up.circle.fill")
                                                        .foregroundColor(AppColors.success)
                                                        .font(.title2)
                                                } else {
                                                    Image(systemName: "arrow.down.circle.fill")
                                                        .foregroundColor(AppColors.accent)
                                                        .font(.title2)
                                                }
                                            } else {
                                                Image(systemName: "questionmark.circle.fill")
                                                    .foregroundColor(AppColors.secondaryText)
                                                    .font(.title2)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        .listRowBackground(AppColors.cardBackground.opacity(0.8))
                                        .opacity(animateItems ? 1 : 0)
                                        .offset(x: animateItems ? 0 : -20)
                                        .animation(.easeOut.delay(Double(session.buyIns.keys.sorted().firstIndex(of: player) ?? 0) * 0.1), value: animateItems)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Current Totals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Trigger animations when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        animateItems = true
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
    @State private var animateItems = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack {
                        Text("Transaction History")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.text)
                            .padding(.vertical)
                    }
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    
                    // Log entries
                    if let session = sessionStore.currentSession {
                        if session.logRecords.isEmpty {
                            VStack {
                                Spacer()
                                Text("No transactions yet")
                                    .font(.headline)
                                    .foregroundColor(AppColors.secondaryText)
                                    .padding()
                                Spacer()
                            }
                        } else {
                            List {
                                ForEach(Array(session.logRecords.reversed().enumerated()), id: \.element.id) { index, record in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(record.player)
                                                .font(.headline)
                                                .foregroundColor(AppColors.text)
                                            
                                            Text(record.formattedTime)
                                                .font(.caption)
                                                .foregroundColor(AppColors.secondaryText)
                                        }
                                        
                                        Spacer()
                                        
                                        HStack {
                                            Image(systemName: record.type.icon)
                                                .foregroundColor(record.type.color)
                                            
                                            VStack(alignment: .trailing) {
                                                Text(record.type.rawValue)
                                                    .font(.caption)
                                                    .foregroundColor(AppColors.secondaryText)
                                                
                                                Text("$\(record.amount, specifier: "%.2f")")
                                                    .font(.headline)
                                                    .foregroundColor(record.type.color)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                    .listRowBackground(AppColors.cardBackground.opacity(0.8))
                                    .opacity(animateItems ? 1 : 0)
                                    .offset(y: animateItems ? 0 : 20)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(Double(index) * 0.05), value: animateItems)
                                }
                            }
                            .listStyle(PlainListStyle())
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("Game Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Trigger animations when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        animateItems = true
                    }
                }
            }
        }
    }
}

// MARK: - Instructions View

struct InstructionsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var animateItems = false
    
    func instructionSection(icon: String, title: String, instructions: [String], delay: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(AppColors.secondaryAccent)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppColors.text)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(instructions, id: \.self) { instruction in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(AppColors.secondaryAccent)
                        Text(instruction)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
            .padding(.leading)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(12)
        .padding(.horizontal)
        .opacity(animateItems ? 1 : 0)
        .offset(y: animateItems ? 0 : 20)
        .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(delay), value: animateItems)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppColors.secondaryAccent)
                                .padding(.top)
                            
                            Text("Welcome to Poker Chips")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.text)
                                .multilineTextAlignment(.center)
                            
                            Text("Your Home Game Tracker")
                                .font(.headline)
                                .foregroundColor(AppColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.bottom)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.cardBackground)
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 20) {
                            instructionSection(
                                icon: "play.circle.fill",
                                title: "Getting Started",
                                instructions: [
                                    "Tap 'Start New Session' to begin a new game",
                                    "Use 'New Player' to register players as they join"
                                ],
                                delay: 0.1
                            )
                            
                            instructionSection(
                                icon: "dollarsign.circle.fill",
                                title: "Managing Buy-Ins",
                                instructions: [
                                    "Tap on a player's name to add a buy-in amount",
                                    "Choose from preset amounts or enter a custom value"
                                ],
                                delay: 0.2
                            )
                            
                            instructionSection(
                                icon: "arrow.up.circle.fill",
                                title: "Cash Outs",
                                instructions: [
                                    "When a player leaves, tap their name and select 'Cash Out'",
                                    "Enter the chip stack's dollar value"
                                ],
                                delay: 0.3
                            )
                            
                            instructionSection(
                                icon: "chart.bar.fill",
                                title: "Tracking & Analysis",
                                instructions: [
                                    "View current totals with the 'Totals' button",
                                    "See transaction history with the 'Log' button",
                                    "End your session by tapping 'End'"
                                ],
                                delay: 0.4
                            )
                            
                            instructionSection(
                                icon: "square.and.arrow.up",
                                title: "Exporting Data",
                                instructions: [
                                    "Export your session data in JSON or CSV format",
                                    "Select which sessions to include in your export"
                                ],
                                delay: 0.5
                            )
                        }
                        .padding(.bottom)
                    }
                }
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Trigger animations when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        animateItems = true
                    }
                }
            }
        }
    }
}


// MARK: - New Player Registration View

struct NewPlayerRegistrationView: View {
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.presentationMode) var presentationMode
    @State private var manualName: String = ""
    @State private var animateItems = false
    let onSelect: (String) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondaryAccent)
                            .padding(.top)
                        
                        Text("Add New Player")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.text)
                            .padding(.bottom)
                    }
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // New player input
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ENTER PLAYER NAME")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.secondaryAccent)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 16) {
                                    TextField("Player Name", text: $manualName)
                                        .padding()
                                        .background(AppColors.cardBackground)
                                        .cornerRadius(12)
                                        .foregroundColor(AppColors.text)
                                    
                                    Button(action: {
                                        if !manualName.isEmpty {
                                            sessionStore.addPlayerNameToSaved(manualName)
                                            onSelect(manualName)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "person.badge.plus")
                                            Text("Register Player")
                                                .font(.headline)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [AppColors.accent, AppColors.accent.opacity(0.8)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(12)
                                        .foregroundColor(.white)
                                    }
                                    .disabled(manualName.isEmpty)
                                    .opacity(manualName.isEmpty ? 0.6 : 1.0)
                                }
                                .padding(.horizontal)
                            }
                            .opacity(animateItems ? 1 : 0)
                            .offset(y: animateItems ? 0 : 20)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1), value: animateItems)
                            
                            // Saved players section
                            if !sessionStore.savedPlayerNames.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("QUICK SELECT")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.secondaryAccent)
                                        .padding(.horizontal)
                                    
                                    VStack(spacing: 8) {
                                        ForEach(Array(sessionStore.savedPlayerNames.enumerated()), id: \.element) { index, name in
                                            Button(action: {
                                                onSelect(name)
                                            }) {
                                                HStack {
                                                    Image(systemName: "person.circle.fill")
                                                        .foregroundColor(AppColors.secondaryAccent)
                                                    
                                                    Text(name)
                                                        .foregroundColor(AppColors.text)
                                                    
                                                    Spacer()
                                                    
                                                    Image(systemName: "chevron.right")
                                                        .foregroundColor(AppColors.secondaryText)
                                                }
                                                .padding()
                                                .background(AppColors.cardBackground)
                                                .cornerRadius(12)
                                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    sessionStore.removePlayerName(at: index)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                            .opacity(animateItems ? 1 : 0)
                                            .offset(y: animateItems ? 0 : 20)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.2 + Double(index) * 0.05), value: animateItems)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("New Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Trigger animations when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        animateItems = true
                    }
                }
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("vibrationEnabled") var vibrationEnabled: Bool = true
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @State private var animateItems = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack {
                        Image(systemName: "gear")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondaryAccent)
                            .padding(.top)
                        
                        Text("App Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.text)
                            .padding(.bottom)
                    }
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Notification settings
                            VStack(alignment: .leading, spacing: 12) {
                                Text("NOTIFICATIONS")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.secondaryAccent)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 16) {
                                    Toggle(isOn: $vibrationEnabled) {
                                        HStack {
                                            Image(systemName: "iphone.radiowaves.left.and.right")
                                                .foregroundColor(AppColors.secondaryAccent)
                                                .font(.headline)
                                            
                                            Text("Vibration")
                                                .foregroundColor(AppColors.text)
                                        }
                                    }
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
                                    
                                    Toggle(isOn: $soundEnabled) {
                                        HStack {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundColor(AppColors.secondaryAccent)
                                                .font(.headline)
                                            
                                            Text("Sound")
                                                .foregroundColor(AppColors.text)
                                        }
                                    }
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
                                }
                                .padding(.horizontal)
                            }
                            .opacity(animateItems ? 1 : 0)
                            .offset(y: animateItems ? 0 : 20)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1), value: animateItems)
                            
                            // App info
                            VStack(alignment: .leading, spacing: 12) {
                                Text("ABOUT")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.secondaryAccent)
                                    .padding(.horizontal)
                                
                                VStack(spacing: 16) {
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(AppColors.secondaryAccent)
                                            .font(.headline)
                                        
                                        Text("Version 1.0")
                                            .foregroundColor(AppColors.text)
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                    
                                    HStack {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(AppColors.secondaryAccent)
                                            .font(.headline)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Created by Jeff")
                                                .foregroundColor(AppColors.text)
                                            Text("and Cline, of course.")
                                                .font(.caption)
                                                .foregroundColor(AppColors.secondaryText)
                                                .italic()
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                            .opacity(animateItems ? 1 : 0)
                            .offset(y: animateItems ? 0 : 20)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.2), value: animateItems)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Trigger animations when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        animateItems = true
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
    @State private var animateItems = false
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "JSON"
        case csv = "CSV"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .json:
                return "curlybraces"
            case .csv:
                return "tablecells"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    VStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondaryAccent)
                            .padding(.top)
                        
                        Text("Export Session Data")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.text)
                            .padding(.bottom)
                    }
                    .frame(maxWidth: .infinity)
                    .background(AppColors.cardBackground)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Format selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("EXPORT FORMAT")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.secondaryAccent)
                                    .padding(.horizontal)
                                
                                HStack(spacing: 16) {
                                    ForEach(ExportFormat.allCases) { format in
                                        Button(action: {
                                            selectedFormat = format
                                        }) {
                                            VStack(spacing: 8) {
                                                Image(systemName: format.icon)
                                                    .font(.title)
                                                
                                                Text(format.rawValue)
                                                    .font(.headline)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(selectedFormat == format ? AppColors.accent : AppColors.cardBackground)
                                            .cornerRadius(12)
                                            .foregroundColor(selectedFormat == format ? .white : AppColors.text)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedFormat == format ? AppColors.accent : AppColors.secondaryAccent, lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .opacity(animateItems ? 1 : 0)
                            .offset(y: animateItems ? 0 : 20)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1), value: animateItems)
                            
                            // Session selection
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("SELECT SESSIONS")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.secondaryAccent)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        if selectedSessions.count == sessionStore.sessions.count {
                                            selectedSessions.removeAll()
                                        } else {
                                            selectedSessions = Set(sessionStore.sessions.map { $0.id })
                                        }
                                    }) {
                                        Text(selectedSessions.count == sessionStore.sessions.count ? "Deselect All" : "Select All")
                                            .font(.caption)
                                            .foregroundColor(AppColors.secondaryAccent)
                                    }
                                }
                                .padding(.horizontal)
                                
                                if sessionStore.sessions.isEmpty {
                                    Text("No sessions available to export")
                                        .foregroundColor(AppColors.secondaryText)
                                        .italic()
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding()
                                        .background(AppColors.cardBackground)
                                        .cornerRadius(12)
                                        .padding(.horizontal)
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(Array(sessionStore.sessions.enumerated()), id: \.element.id) { index, session in
                                            Button(action: {
                                                if selectedSessions.contains(session.id) {
                                                    selectedSessions.remove(session.id)
                                                } else {
                                                    selectedSessions.insert(session.id)
                                                }
                                            }) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text("Game \(index + 1)")
                                                            .font(.headline)
                                                            .foregroundColor(AppColors.text)
                                                        
                                                        Text(session.formattedDate)
                                                            .font(.subheadline)
                                                            .foregroundColor(AppColors.secondaryText)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    if selectedSessions.contains(session.id) {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(AppColors.secondaryAccent)
                                                            .font(.title2)
                                                    } else {
                                                        Image(systemName: "circle")
                                                            .foregroundColor(AppColors.secondaryText)
                                                            .font(.title2)
                                                    }
                                                }
                                                .padding()
                                                .background(AppColors.cardBackground)
                                                .cornerRadius(12)
                                            }
                                            .opacity(animateItems ? 1 : 0)
                                            .offset(y: animateItems ? 0 : 20)
                                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.2 + Double(index) * 0.05), value: animateItems)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .opacity(animateItems ? 1 : 0)
                            .offset(y: animateItems ? 0 : 20)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.2), value: animateItems)
                            
                            // Export button
                            Button(action: exportSessions) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.headline)
                                    Text("Export Data")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.accent, AppColors.accent.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .opacity(selectedSessions.isEmpty || isExporting ? 0.5 : 1.0)
                                .disabled(selectedSessions.isEmpty || isExporting)
                            }
                            .padding(.top)
                            .opacity(animateItems ? 1 : 0)
                            .offset(y: animateItems ? 0 : 20)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.3), value: animateItems)
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Export Sessions")
            .navigationBarTitleDisplayMode(.inline)
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
            .onAppear {
                // Trigger animations when view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        animateItems = true
                    }
                }
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
