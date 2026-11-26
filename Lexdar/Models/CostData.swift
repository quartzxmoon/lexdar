import Foundation

/// State price levels from the U.S. Bureau of Economic Analysis, Regional Price
/// Parities (table SARPP), 2024 edition, where 100 is the national level. BEA
/// publishes these for states and metro areas; this table holds the state
/// values. "Goods" scales material prices and "Services: Other" is used as the
/// closest published stand-in for local labor rates. BEA's next release is
/// expected December 2026, so refresh this table then.
/// Source: https://www.bea.gov/data/prices-inflation/regional-price-parities-state-and-metro-area
struct RegionIndex: Hashable {
    let allItems: Double
    let goods: Double
    let services: Double
}

enum CostData {
    static let regionsDataYear = 2024

    static let regions: [String: RegionIndex] = [
        "AK": RegionIndex(allItems: 102.359, goods: 106.319, services: 102.208),
        "AL": RegionIndex(allItems: 88.823, goods: 96.399, services: 96.711),
        "AR": RegionIndex(allItems: 86.937, goods: 93.597, services: 95.312),
        "AZ": RegionIndex(allItems: 100.677, goods: 95.361, services: 102.808),
        "CA": RegionIndex(allItems: 110.72, goods: 106.098, services: 102.591),
        "CO": RegionIndex(allItems: 103.052, goods: 98.727, services: 99.613),
        "CT": RegionIndex(allItems: 103.61, goods: 97.33, services: 102.658),
        "DC": RegionIndex(allItems: 109.901, goods: 106.502, services: 102.964),
        "DE": RegionIndex(allItems: 99.808, goods: 96.155, services: 101.235),
        "FL": RegionIndex(allItems: 103.414, goods: 98.059, services: 101.324),
        "GA": RegionIndex(allItems: 96.293, goods: 98.929, services: 97.343),
        "HI": RegionIndex(allItems: 109.951, goods: 111.562, services: 102.898),
        "IA": RegionIndex(allItems: 87.762, goods: 93.73, services: 92.927),
        "ID": RegionIndex(allItems: 95.494, goods: 96.311, services: 99.015),
        "IL": RegionIndex(allItems: 99.958, goods: 103.832, services: 100.156),
        "IN": RegionIndex(allItems: 93.329, goods: 95.509, services: 99.145),
        "KS": RegionIndex(allItems: 90.068, goods: 94.027, services: 93.816),
        "KY": RegionIndex(allItems: 90.159, goods: 95.967, services: 97.25),
        "LA": RegionIndex(allItems: 88.207, goods: 93.7, services: 95.706),
        "MA": RegionIndex(allItems: 105.757, goods: 98.82, services: 102.852),
        "MD": RegionIndex(allItems: 104.959, goods: 102.524, services: 101.596),
        "ME": RegionIndex(allItems: 97.05, goods: 97.171, services: 103.191),
        "MI": RegionIndex(allItems: 96.217, goods: 95.993, services: 100.933),
        "MN": RegionIndex(allItems: 98.621, goods: 100.519, services: 100.213),
        "MO": RegionIndex(allItems: 90.817, goods: 96.299, services: 95.169),
        "MS": RegionIndex(allItems: 86.953, goods: 96.219, services: 96.09),
        "MT": RegionIndex(allItems: 94.645, goods: 96.006, services: 98.715),
        "NC": RegionIndex(allItems: 94.326, goods: 96.621, services: 98.186),
        "ND": RegionIndex(allItems: 88.959, goods: 95.701, services: 91.158),
        "NE": RegionIndex(allItems: 90.103, goods: 94.101, services: 92.98),
        "NH": RegionIndex(allItems: 104.165, goods: 98.578, services: 103.879),
        "NJ": RegionIndex(allItems: 108.805, goods: 107.066, services: 103.529),
        "NM": RegionIndex(allItems: 92.212, goods: 96.144, services: 98.54),
        "NV": RegionIndex(allItems: 99.979, goods: 96.271, services: 98.744),
        "NY": RegionIndex(allItems: 107.921, goods: 107.254, services: 104.067),
        "OH": RegionIndex(allItems: 92.774, goods: 93.67, services: 98.947),
        "OK": RegionIndex(allItems: 87.843, goods: 93.778, services: 95.458),
        "OR": RegionIndex(allItems: 103.361, goods: 105.261, services: 100.298),
        "PA": RegionIndex(allItems: 97.572, goods: 99.357, services: 99.762),
        "RI": RegionIndex(allItems: 102.28, goods: 97.165, services: 102.84),
        "SC": RegionIndex(allItems: 93.749, goods: 96.339, services: 98.284),
        "SD": RegionIndex(allItems: 88.586, goods: 95.473, services: 91.899),
        "TN": RegionIndex(allItems: 91.87, goods: 96.247, services: 95.142),
        "TX": RegionIndex(allItems: 97.057, goods: 98.083, services: 97.081),
        "UT": RegionIndex(allItems: 98.864, goods: 96.446, services: 98.959),
        "VA": RegionIndex(allItems: 101.104, goods: 100.368, services: 100.233),
        "VT": RegionIndex(allItems: 97.958, goods: 97.274, services: 101.586),
        "WA": RegionIndex(allItems: 107.013, goods: 104.359, services: 103.873),
        "WI": RegionIndex(allItems: 94.095, goods: 94.31, services: 99.501),
        "WV": RegionIndex(allItems: 89.497, goods: 96.539, services: 99.94),
        "WY": RegionIndex(allItems: 92.691, goods: 95.368, services: 100.428),
    ]

    static let stateNames: [String: String] = [
        "AK": "Alaska",
        "AL": "Alabama",
        "AR": "Arkansas",
        "AZ": "Arizona",
        "CA": "California",
        "CO": "Colorado",
        "CT": "Connecticut",
        "DC": "District of Columbia",
        "DE": "Delaware",
        "FL": "Florida",
        "GA": "Georgia",
        "HI": "Hawaii",
        "IA": "Iowa",
        "ID": "Idaho",
        "IL": "Illinois",
        "IN": "Indiana",
        "KS": "Kansas",
        "KY": "Kentucky",
        "LA": "Louisiana",
        "MA": "Massachusetts",
        "MD": "Maryland",
        "ME": "Maine",
        "MI": "Michigan",
        "MN": "Minnesota",
        "MO": "Missouri",
        "MS": "Mississippi",
        "MT": "Montana",
        "NC": "North Carolina",
        "ND": "North Dakota",
        "NE": "Nebraska",
        "NH": "New Hampshire",
        "NJ": "New Jersey",
        "NM": "New Mexico",
        "NV": "Nevada",
        "NY": "New York",
        "OH": "Ohio",
        "OK": "Oklahoma",
        "OR": "Oregon",
        "PA": "Pennsylvania",
        "RI": "Rhode Island",
        "SC": "South Carolina",
        "SD": "South Dakota",
        "TN": "Tennessee",
        "TX": "Texas",
        "UT": "Utah",
        "VA": "Virginia",
        "VT": "Vermont",
        "WA": "Washington",
        "WI": "Wisconsin",
        "WV": "West Virginia",
        "WY": "Wyoming",
    ]

    // Baseline readings the starter prices were set against (October 2026).
    // FRED series WPUSI012011: PPI, Construction Materials (index 1982=100).
    // FRED series CES2000000003: average hourly earnings, construction ($).
    static let baseMaterialsIndex = 381.552
    static let baseWageDollars = 42.03
}
