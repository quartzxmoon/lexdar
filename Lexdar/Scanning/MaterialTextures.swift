import UIKit

/// Procedurally drawn surface textures (wood planks, tile, brick, siding,
/// shingle, carpet, and so on) so floors, walls, and exteriors read as real
/// materials in the 3D views instead of flat color. Nothing is downloaded:
/// each texture is drawn once from the catalog item's own color and cached.
/// The pattern is chosen from keywords in the catalog item's id.
enum MaterialTextures {
    enum Pattern {
        case planks, tile, subway, herringbone, shiplap, carpet, concrete
        case stone, brick, siding, shingle, seam, grass, parquet
    }

    /// Which pattern, if any, a catalog item should be drawn with. Plain
    /// paints return nil and stay a flat color.
    static func pattern(for item: CatalogItem) -> Pattern? {
        let id = item.id
        func has(_ tokens: String...) -> Bool { tokens.contains { id.contains($0) } }
        if has("wallpaper") || id.hasPrefix("wall.paint") { return nil }
        if has("herringbone") { return .herringbone }
        if has("parquet") { return .parquet }
        if has("subway", "zellige", "mosaic") { return .subway }
        if has("tile.") { return .tile }
        if has("shiplap", "board.batten", "batten", "wall.board") { return .shiplap }
        if has("shake", "shingle", "roof.gable.asphalt", "roof.hip.asphalt", "roof.gable.slate",
               "roof.gable.cedar", "roof.gable.clay", "roof.hip.clay") { return .shingle }
        if has("standingseam", "roof.gable.metal", "roof.hip.metal", "roof.shed.metal", "corrugated") { return .seam }
        if has("brick") { return .brick }
        if has("stone", "slate", "flagstone", "limestone", "land.path", "travertine") { return .stone }
        if has("siding", "log.round", "cedar.natural", "wood.cedar", "wood.charred", "wood.slat") { return .siding }
        if has("carpet", "berber", "rubber") { return .carpet }
        if has("concrete", "stucco", "plaster", "terrazzo", "epoxy", "driveway", "sidewalk", "gravel", "mulch") { return .concrete }
        if has("grass") { return .grass }
        if has("floor.", "wood", "oak", "hickory", "maple", "cherry", "ebony", "barnwood", "bamboo", "laminate",
               "lvp", "cork", "deck") { return .planks }
        return nil
    }

    /// How many meters one repeat of the texture covers.
    static func coverage(of pattern: Pattern) -> Float {
        switch pattern {
        case .planks: return 1.1
        case .tile: return 0.6
        case .subway: return 0.6
        case .herringbone, .parquet: return 0.8
        case .shiplap: return 0.8
        case .carpet: return 0.5
        case .concrete: return 1.5
        case .stone: return 1.2
        case .brick: return 0.7
        case .siding: return 0.8
        case .shingle: return 0.8
        case .seam: return 1.0
        case .grass: return 1.5
        }
    }

    private final class Store: @unchecked Sendable {
        private let lock = NSLock()
        private var images: [String: UIImage] = [:]
        func image(for key: String) -> UIImage? {
            lock.lock(); defer { lock.unlock() }
            return images[key]
        }
        func set(_ image: UIImage, for key: String) {
            lock.lock(); defer { lock.unlock() }
            images[key] = image
        }
    }
    private static let store = Store()

    static func image(for item: CatalogItem) -> UIImage? {
        guard let pattern = pattern(for: item) else { return nil }
        if let hit = store.image(for: item.id) { return hit }
        let image = render(pattern, base: UIColor(item.color))
        store.set(image, for: item.id)
        return image
    }

    // MARK: - Drawing

    private struct Noise {
        var state: UInt64
        mutating func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((state >> 33) & 0xFFFF) / 65535
        }
    }

    private static func shade(_ color: UIColor, _ factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(max(r * factor, 0), 1),
                       green: min(max(g * factor, 0), 1),
                       blue: min(max(b * factor, 0), 1), alpha: 1)
    }

    private static func render(_ pattern: Pattern, base: UIColor) -> UIImage {
        let size = CGSize(width: 256, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        var noise = Noise(state: 987_654_321)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let g = context.cgContext
            func fill(_ rect: CGRect, _ color: UIColor) {
                g.setFillColor(color.cgColor)
                g.fill(rect)
            }
            fill(CGRect(origin: .zero, size: size), base)

            switch pattern {
            case .planks:
                let rows = 7
                let h = size.height / CGFloat(rows)
                for r in 0..<rows {
                    let y = CGFloat(r) * h
                    fill(CGRect(x: 0, y: y, width: size.width, height: h), shade(base, 0.88 + noise.next() * 0.22))
                    let joint = noise.next() * size.width
                    fill(CGRect(x: joint, y: y, width: 2, height: h), shade(base, 0.6))
                    fill(CGRect(x: (joint + 128).truncatingRemainder(dividingBy: size.width), y: y, width: 2, height: h), shade(base, 0.6))
                    fill(CGRect(x: 0, y: y, width: size.width, height: 2), shade(base, 0.62))
                }

            case .tile:
                fill(CGRect(origin: .zero, size: size), shade(base, 0.72))
                let n = 2
                let cell = size.width / CGFloat(n)
                for i in 0..<n {
                    for j in 0..<n {
                        fill(CGRect(x: CGFloat(i) * cell + 3, y: CGFloat(j) * cell + 3, width: cell - 6, height: cell - 6),
                             shade(base, 0.95 + noise.next() * 0.1))
                    }
                }

            case .subway:
                fill(CGRect(origin: .zero, size: size), shade(base, 0.78))
                let rows = 8
                let h = size.height / CGFloat(rows)
                let w: CGFloat = 64
                for r in 0..<rows {
                    let offset: CGFloat = r % 2 == 1 ? -w / 2 : 0
                    for c in 0..<6 {
                        fill(CGRect(x: CGFloat(c) * w + offset + 1.5, y: CGFloat(r) * h + 1.5, width: w - 3, height: h - 3),
                             shade(base, 0.96 + noise.next() * 0.08))
                    }
                }

            case .herringbone, .parquet:
                fill(CGRect(origin: .zero, size: size), shade(base, 0.7))
                let cell: CGFloat = 32
                for i in 0..<8 {
                    for j in 0..<8 {
                        g.saveGState()
                        g.translateBy(x: CGFloat(i) * cell + cell / 2, y: CGFloat(j) * cell + cell / 2)
                        g.rotate(by: (i + j) % 2 == 0 ? .pi / 4 : -.pi / 4)
                        let rect = CGRect(x: -22, y: -7, width: 44, height: 14)
                        g.setFillColor(shade(base, 0.9 + noise.next() * 0.2).cgColor)
                        g.fill(rect)
                        g.restoreGState()
                    }
                }

            case .shiplap:
                let rows = 7
                let h = size.height / CGFloat(rows)
                for r in 0..<rows {
                    let y = CGFloat(r) * h
                    fill(CGRect(x: 0, y: y, width: size.width, height: h), shade(base, 0.97 + noise.next() * 0.05))
                    fill(CGRect(x: 0, y: y, width: size.width, height: 3), shade(base, 0.6))
                    fill(CGRect(x: 0, y: y + 3, width: size.width, height: 1.5), shade(base, 1.1))
                }

            case .carpet:
                for _ in 0..<3500 {
                    let x = noise.next() * size.width
                    let y = noise.next() * size.height
                    fill(CGRect(x: x, y: y, width: 2, height: 2), shade(base, 0.85 + noise.next() * 0.3))
                }

            case .concrete:
                for _ in 0..<7 {
                    let x = noise.next() * size.width
                    let y = noise.next() * size.height
                    g.setFillColor(shade(base, 0.94 + noise.next() * 0.1).cgColor)
                    g.fillEllipse(in: CGRect(x: x - 50, y: y - 50, width: 100, height: 100))
                }
                for _ in 0..<1800 {
                    let x = noise.next() * size.width
                    let y = noise.next() * size.height
                    fill(CGRect(x: x, y: y, width: 1.5, height: 1.5), shade(base, 0.8 + noise.next() * 0.35))
                }

            case .stone:
                fill(CGRect(origin: .zero, size: size), shade(base, 0.6))
                var y: CGFloat = 0
                while y < size.height {
                    let h = 38 + noise.next() * 30
                    var x: CGFloat = -noise.next() * 40
                    while x < size.width {
                        let w = 48 + noise.next() * 52
                        fill(CGRect(x: x + 2, y: y + 2, width: w - 4, height: h - 4), shade(base, 0.85 + noise.next() * 0.3))
                        x += w
                    }
                    y += h
                }

            case .brick:
                fill(CGRect(origin: .zero, size: size), UIColor(red: 0.8, green: 0.78, blue: 0.74, alpha: 1))
                let rows = 12
                let h = size.height / CGFloat(rows)
                let w: CGFloat = 64
                for r in 0..<rows {
                    let offset: CGFloat = r % 2 == 1 ? -w / 2 : 0
                    for c in 0..<6 {
                        fill(CGRect(x: CGFloat(c) * w + offset + 1.5, y: CGFloat(r) * h + 1.5, width: w - 3, height: h - 3),
                             shade(base, 0.82 + noise.next() * 0.32))
                    }
                }

            case .siding:
                let rows = 8
                let h = size.height / CGFloat(rows)
                for r in 0..<rows {
                    let y = CGFloat(r) * h
                    fill(CGRect(x: 0, y: y, width: size.width, height: 2), shade(base, 1.12))
                    fill(CGRect(x: 0, y: y + h - 4, width: size.width, height: 4), shade(base, 0.68))
                }

            case .shingle:
                fill(CGRect(origin: .zero, size: size), shade(base, 0.5))
                let rows = 8
                let h = size.height / CGFloat(rows)
                let w: CGFloat = 32
                for r in 0..<rows {
                    let offset: CGFloat = r % 2 == 1 ? -w / 2 : 0
                    for c in 0..<9 {
                        let rect = CGRect(x: CGFloat(c) * w + offset + 1, y: CGFloat(r) * h, width: w - 2, height: h + 4)
                        g.setFillColor(shade(base, 0.85 + noise.next() * 0.3).cgColor)
                        g.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 5).cgPath)
                        g.fillPath()
                    }
                }

            case .seam:
                let w: CGFloat = 32
                for c in 0..<8 {
                    let x = CGFloat(c) * w
                    fill(CGRect(x: x, y: 0, width: 3, height: size.height), shade(base, 1.2))
                    fill(CGRect(x: x + 3, y: 0, width: 3, height: size.height), shade(base, 0.6))
                }

            case .grass:
                for _ in 0..<4500 {
                    let x = noise.next() * size.width
                    let y = noise.next() * size.height
                    fill(CGRect(x: x, y: y, width: 1.5, height: 4), shade(base, 0.7 + noise.next() * 0.55))
                }
            }
        }
    }
}
