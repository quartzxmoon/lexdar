import Foundation

/// Holds the ZIP code and state, looks them up, keeps the local price edits,
/// and refreshes the two live indexes the estimate is adjusted by:
/// - construction materials prices (U.S. Bureau of Labor Statistics PPI,
///   FRED series WPUSI012011), and
/// - construction wages (BLS average hourly earnings, FRED series CES2000000003).
/// Both are free public downloads and need no account or key. The state price
/// level comes from the bundled BEA table (`CostData`).
@MainActor
final class CostService: ObservableObject {
    @Published var zip: String { didSet { defaults.set(zip, forKey: Keys.zip) } }
    @Published var stateCode: String { didSet { defaults.set(stateCode, forKey: Keys.state) } }
    @Published var placeName: String { didSet { defaults.set(placeName, forKey: Keys.place) } }
    @Published private(set) var materialsIndex: Double?
    @Published private(set) var wageDollars: Double?
    @Published private(set) var indexMonth: String?
    @Published private(set) var indexFetchedAt: Date?
    @Published private(set) var status: String?
    @Published private(set) var isWorking = false
    /// Local prices typed in by ZIP: zip -> catalog item id -> price per unit.
    @Published private(set) var overrides: [String: [String: Double]]

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let zip = "cost.zip"
        static let state = "cost.state"
        static let place = "cost.place"
        static let materials = "cost.materialsIndex"
        static let wage = "cost.wageDollars"
        static let month = "cost.indexMonth"
        static let fetched = "cost.indexFetchedAt"
        static let overrides = "cost.overrides"
    }

    init() {
        zip = UserDefaults.standard.string(forKey: Keys.zip) ?? ""
        stateCode = UserDefaults.standard.string(forKey: Keys.state) ?? ""
        placeName = UserDefaults.standard.string(forKey: Keys.place) ?? ""
        let m = UserDefaults.standard.double(forKey: Keys.materials)
        let w = UserDefaults.standard.double(forKey: Keys.wage)
        materialsIndex = m > 0 ? m : nil
        wageDollars = w > 0 ? w : nil
        indexMonth = UserDefaults.standard.string(forKey: Keys.month)
        indexFetchedAt = UserDefaults.standard.object(forKey: Keys.fetched) as? Date
        if let data = UserDefaults.standard.data(forKey: Keys.overrides),
           let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) {
            overrides = decoded
        } else {
            overrides = [:]
        }
    }

    // MARK: - Pricing context

    var region: RegionIndex? { CostData.regions[stateCode] }

    var pricing: Pricing {
        var p = Pricing()
        if let region {
            p.goodsIndex = region.goods
            p.servicesIndex = region.services
        }
        if let materialsIndex { p.materialsTrend = materialsIndex / CostData.baseMaterialsIndex }
        if let wageDollars { p.wageTrend = wageDollars / CostData.baseWageDollars }
        p.overrides = overrides[cleanZip] ?? [:]
        return p
    }

    var cleanZip: String { String(zip.filter(\.isNumber).prefix(5)) }

    // MARK: - Local price edits

    func setOverride(_ price: Double?, itemID: String) {
        var forZip = overrides[cleanZip] ?? [:]
        if let price, price > 0 { forZip[itemID] = price } else { forZip.removeValue(forKey: itemID) }
        overrides[cleanZip] = forZip
        if let data = try? JSONEncoder().encode(overrides) { defaults.set(data, forKey: Keys.overrides) }
    }

    // MARK: - ZIP lookup (Zippopotam.us, free, no key)

    private struct ZipResponse: Decodable {
        struct Place: Decodable {
            let name: String
            let state: String
            private enum CodingKeys: String, CodingKey {
                case name = "place name"
                case state = "state abbreviation"
            }
        }
        let places: [Place]
    }

    func lookupZip() async {
        let code = cleanZip
        guard code.count == 5, let url = URL(string: "https://api.zippopotam.us/us/\(code)") else {
            status = "Enter a 5-digit ZIP code."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                status = "ZIP \(code) was not found. Pick your state below instead."
                return
            }
            let decoded = try JSONDecoder().decode(ZipResponse.self, from: data)
            guard let place = decoded.places.first else {
                status = "ZIP \(code) was not found. Pick your state below instead."
                return
            }
            stateCode = place.state
            placeName = place.name
            status = nil
        } catch {
            status = "Could not look up the ZIP (\(error.localizedDescription)). Pick your state below instead."
        }
    }

    // MARK: - Live indexes (FRED public CSV downloads, no key)

    var indexesAreStale: Bool {
        guard let fetched = indexFetchedAt else { return true }
        return Date().timeIntervalSince(fetched) > 7 * 24 * 3600
    }

    func refreshIfStale() async {
        if indexesAreStale { await refreshIndexes() }
    }

    func refreshIndexes() async {
        isWorking = true
        defer { isWorking = false }
        do {
            async let materials = Self.latestReading(series: "WPUSI012011")
            async let wages = Self.latestReading(series: "CES2000000003")
            let (m, w) = try await (materials, wages)
            materialsIndex = m.value
            wageDollars = w.value
            indexMonth = m.date
            indexFetchedAt = Date()
            defaults.set(m.value, forKey: Keys.materials)
            defaults.set(w.value, forKey: Keys.wage)
            defaults.set(m.date, forKey: Keys.month)
            defaults.set(indexFetchedAt, forKey: Keys.fetched)
            status = nil
        } catch {
            status = "Could not refresh current price trends (\(error.localizedDescription)). Using the last saved values."
        }
    }

    /// The newest numeric row of a FRED series' public CSV.
    private nonisolated static func latestReading(series: String) async throws -> (date: String, value: Double) {
        guard let url = URL(string: "https://fred.stlouisfed.org/graph/fredgraph.csv?id=\(series)&cosd=2025-01-01") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, let text = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        for line in text.split(whereSeparator: \.isNewline).reversed() {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count >= 2, let value = Double(parts[1]) {
                return (String(parts[0]), value)
            }
        }
        throw URLError(.cannotParseResponse)
    }
}
