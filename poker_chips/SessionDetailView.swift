import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @State private var logRecords: [LogEntry]
    @State private var animateItems = false
    
    // Computed property to calculate the table balance
    var tableBalance: Double {
        let totalBuyIn = session.buyIns.values.reduce(0, +)
        let totalCashOut = session.cashOuts.values.reduce(0, +)
        return totalBuyIn - totalCashOut
    }
    
    // Computed property to calculate total profit/loss
    var totalProfitLoss: Double {
        var total = 0.0
        for player in session.buyIns.keys {
            let buyIn = session.buyIns[player] ?? 0
            let cashOut = session.cashOuts[player] ?? 0
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
                                        Text("Did not cash out")
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
                    
                    Section(header: Text("Session Log")
                        .font(.headline)
                        .foregroundColor(AppColors.secondaryAccent)) {
                        ForEach(logRecords) { record in
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
                        }
                        .onDelete(perform: deleteRecord)
                        .listRowBackground(AppColors.cardBackground.opacity(0.8))
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Trigger animations when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    animateItems = true
                }
            }
        }
    }
    
    func deleteRecord(at offsets: IndexSet) {
        logRecords.remove(atOffsets: offsets)
    }
}

struct SessionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSession = Session(
            startDate: Date(),
            buyIns: ["Alice": 100, "Bob": 200],
            logRecords: [
                LogEntry(timestamp: Date(), player: "Alice", amount: 10, type: .buyIn),
                LogEntry(timestamp: Date(), player: "Bob", amount: 20, type: .buyIn)
            ],
            cashOuts: ["Alice": 120]
        )
        return NavigationStack {
            SessionDetailView(session: sampleSession)
                .preferredColorScheme(.dark)
        }
    }
}
