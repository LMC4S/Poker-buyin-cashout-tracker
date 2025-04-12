import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @State private var logRecords: [LogEntry]
    @State private var animateItems = false
    @State private var showInfoSheet = false
    
    // Computed property to find the player with the highest profit
    var biggestWinner: (name: String, amount: Double)? {
        var playerProfits: [(name: String, amount: Double)] = []
        
        for playerId in session.buyIns.keys {
            let buyIn = session.buyIns[playerId] ?? 0
            let cashOut = session.cashOuts[playerId] ?? 0
            let profit = cashOut - buyIn
            
            // Only include players who have cashed out and made a profit
            if session.cashOuts[playerId] != nil && profit > 0 {
                playerProfits.append((name: session.playerName(for: playerId), amount: profit))
            }
        }
        
        return playerProfits.max(by: { $0.amount < $1.amount })
    }
    
    // Computed property to find the player with the biggest loss
    var biggestDeficit: (name: String, amount: Double)? {
        var playerLosses: [(name: String, amount: Double)] = []
        
        for playerId in session.buyIns.keys {
            let buyIn = session.buyIns[playerId] ?? 0
            let cashOut = session.cashOuts[playerId] ?? 0
            let loss = buyIn - cashOut
            
            // Only include players who have cashed out and had a loss
            if session.cashOuts[playerId] != nil && loss > 0 {
                playerLosses.append((name: session.playerName(for: playerId), amount: loss))
            }
        }
        
        return playerLosses.max(by: { $0.amount < $1.amount })
    }
    
    // Computed property to get the first buy-in time (game start time)
    var gameStartTime: String {
        let buyInEntries = logRecords.filter { $0.type == .buyIn }
        if let firstBuyIn = buyInEntries.min(by: { $0.timestamp < $1.timestamp }) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .medium
            return formatter.string(from: firstBuyIn.timestamp)
        }
        return "No buy-ins recorded"
    }
    
    // Computed property to get the last cash-out time (game end time)
    var gameEndTime: String {
        let cashOutEntries = logRecords.filter { $0.type == .cashOut }
        if let lastCashOut = cashOutEntries.max(by: { $0.timestamp < $1.timestamp }) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .medium
            return formatter.string(from: lastCashOut.timestamp)
        }
        return "No cash-outs recorded"
    }
    
    // Computed property to calculate the total game duration
    var gameDuration: String {
        let buyInEntries = logRecords.filter { $0.type == .buyIn }
        let cashOutEntries = logRecords.filter { $0.type == .cashOut }
        
        if let firstBuyIn = buyInEntries.min(by: { $0.timestamp < $1.timestamp }),
           let lastCashOut = cashOutEntries.max(by: { $0.timestamp < $1.timestamp }) {
            
            let duration = lastCashOut.timestamp.timeIntervalSince(firstBuyIn.timestamp)
            
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes) minutes"
            }
        }
        return "Duration unavailable"
    }
    
    // Computed property to calculate the table balance
    var tableBalance: Double {
        let totalBuyIn = session.buyIns.values.reduce(0, +)
        let totalCashOut = session.cashOuts.values.reduce(0, +)
        return totalBuyIn - totalCashOut
    }
    
    // Computed property to calculate total profit/loss
    var totalProfitLoss: Double {
        var total = 0.0
        for playerId in session.buyIns.keys {
            let buyIn = session.buyIns[playerId] ?? 0
            let cashOut = session.cashOuts[playerId] ?? 0
            total += (cashOut - buyIn)
        }
        return total
    }

    init(session: Session) {
        self.session = session
        _logRecords = State(initialValue: session.logRecords)
    }

    var body: some View {
        ZStack {
            // Background gradient for SessionDetailView
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
                VStack(spacing: 8) {
                    Text(session.formattedDate)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.text)
                    
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
                .padding()
                .background(AppColors.cardBackground)
            
                // Player results
                List {
                    Section(header: Text("Player Results")
                        .font(.headline)
                        .foregroundColor(AppColors.secondaryAccent)) {
                        ForEach(session.buyIns.keys.sorted(), id: \.self) { playerId in
                        if let buyInTotal = session.buyIns[playerId] {
                            let playerName = session.playerName(for: playerId)
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playerName)
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
                                    
                                    if let cashOut = session.cashOuts[playerId] {
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
                                        Text("Did not cash out")
                                            .font(.subheadline)
                                            .foregroundColor(AppColors.accent)
                                            .italic()
                                    }
                                }
                                
                                Spacer()
                                
                                if let cashOut = session.cashOuts[playerId] {
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
                            .animation(.easeOut.delay(Double(session.buyIns.keys.sorted().firstIndex(of: playerId) ?? 0) * 0.1), value: animateItems)
                        }
                    }
                    }
                    
                    Section(header: Text("Session Log")
                        .font(.headline)
                        .foregroundColor(AppColors.secondaryAccent)) {
                        ForEach(logRecords) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.playerName(for: record.playerId))
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
                        }
                        .listRowBackground(AppColors.cardBackground.opacity(0.8))
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showInfoSheet = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppColors.secondaryAccent)
                }
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            NavigationView {
                ZStack {
                    AppColors.background.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondaryAccent)
                            .padding(.top, 30)
                        
                        Text("Game Stats")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.text)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            // Game Stats Section
                            Text("TIME STATS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.secondaryAccent)
                                .padding(.horizontal, 8)
                                .padding(.top, 8)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                HStack(alignment: .top) {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(AppColors.secondaryAccent)
                                        .font(.title3)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Game Time")
                                            .font(.headline)
                                            .foregroundColor(AppColors.secondaryAccent)
                                        
                                        Text("\(gameStartTime) → \(gameEndTime)")
                                            .font(.body)
                                            .foregroundColor(AppColors.text)
                                    }
                                }
                                
                                HStack(alignment: .top) {
                                    Image(systemName: "hourglass")
                                        .foregroundColor(AppColors.secondaryText)
                                        .font(.title3)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Total Duration")
                                            .font(.headline)
                                            .foregroundColor(AppColors.secondaryText)
                                        
                                        Text(gameDuration)
                                            .font(.body)
                                            .foregroundColor(AppColors.text)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            
                            // Player Performance Section
                            Text("PLAYER HIGHLIGHTS")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.secondaryAccent)
                                .padding(.horizontal, 8)
                                .padding(.top, 16)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                if let winner = biggestWinner {
                                    HStack(alignment: .top) {
                                        Image(systemName: "crown.fill")
                                            .foregroundColor(AppColors.secondaryAccent)
                                            .font(.title3)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Hot Streak Hero")
                                                .font(.headline)
                                                .foregroundColor(AppColors.secondaryAccent)
                                            
                                            Text(winner.name)
                                                .font(.body)
                                                .foregroundColor(AppColors.text)
                                            
                                            Text("+$\(winner.amount, specifier: "%.2f")")
                                                .font(.body)
                                                .foregroundColor(AppColors.success)
                                        }
                                    }
                                }
                                
                                if let loser = biggestDeficit {
                                    HStack(alignment: .top) {
                                        Image(systemName: "chart.line.downtrend.xyaxis")
                                            .foregroundColor(AppColors.accent)
                                            .font(.title3)
                                            .frame(width: 30)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Unlucky Challenger")
                                                .font(.headline)
                                                .foregroundColor(AppColors.accent)
                                            
                                            Text(loser.name)
                                                .font(.body)
                                                .foregroundColor(AppColors.text)
                                            
                                            Text("-$\(loser.amount, specifier: "%.2f")")
                                                .font(.body)
                                                .foregroundColor(AppColors.accent)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                }
                .navigationTitle("Session Info")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showInfoSheet = false
                        }
                    }
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

struct SessionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let aliceId = UUID()
        let bobId = UUID()
        
        let sampleSession = Session(
            startDate: Date(),
            players: [
                aliceId: Player(id: aliceId, name: "Alice"),
                bobId: Player(id: bobId, name: "Bob")
            ],
            buyIns: [aliceId: 100, bobId: 200],
            logRecords: [
                LogEntry(timestamp: Date(), playerId: aliceId, amount: 10, type: .buyIn),
                LogEntry(timestamp: Date(), playerId: bobId, amount: 20, type: .buyIn)
            ],
            cashOuts: [aliceId: 120]
        )
        return NavigationStack {
            SessionDetailView(session: sampleSession)
                .preferredColorScheme(.dark)
        }
    }
}
