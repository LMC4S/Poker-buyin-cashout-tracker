import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @State private var logRecords: [LogEntry]

    init(session: Session) {
        self.session = session
        _logRecords = State(initialValue: session.logRecords)
    }

    var body: some View {
        VStack {
            Text("\(session.formattedDate)")
                .font(.headline)
                .padding()
            List {
                Section(header: Text("Totals")) {
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
                Section(header: Text("Session Log")) {
                    ForEach(logRecords) { record in
                        Text("\(record.formattedTime) - \(record.player): \(record.type.rawValue) $\(record.amount, specifier: "%.2f")")
                    }
                    .onDelete(perform: deleteRecord)
                }
            }
        }
        .navigationTitle("Session Details")
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
            ]
        )
        return NavigationStack {
            SessionDetailView(session: sampleSession)
        }
    }
}
