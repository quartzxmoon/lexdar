import SwiftUI

/// Browsable, searchable grid of the build-out catalog, restricted to
/// `categories` when the caller only wants flooring, or only wall finishes,
/// etc. Tapping an item calls `onSelect` and dismisses.
struct CatalogBrowserView: View {
    let categories: [CatalogCategory]
    let title: String
    let onSelect: (CatalogItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selectedCategory: CatalogCategory?

    private var visibleCategories: [CatalogCategory] {
        selectedCategory.map { [$0] } ?? categories
    }

    private var filteredItems: [CatalogItem] {
        let base = visibleCategories.flatMap { Catalog.items(in: $0) }
        guard !search.isEmpty else { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if categories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            categoryChip(nil, label: "All")
                            ForEach(categories) { cat in
                                categoryChip(cat, label: cat.displayName)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredItems) { item in
                            Button {
                                onSelect(item)
                                dismiss()
                            } label: {
                                CatalogItemCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .searchable(text: $search, prompt: "Search \(title.lowercased())")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func categoryChip(_ category: CatalogCategory?, label: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(selectedCategory == category ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(selectedCategory == category ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

private struct CatalogItemCard: View {
    let item: CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(item.color)
                .frame(height: 70)
                .overlay(
                    Image(systemName: item.category.symbolName)
                        .foregroundStyle(.white.opacity(0.85))
                        .font(.title3)
                )

            Text(item.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            if let note = item.note {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(dimensionLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var dimensionLabel: String {
        let d = item.dimensions
        func feet(_ m: Float) -> String { String(format: "%.1f'", m * 3.28084) }
        return "\(feet(d.x)) × \(feet(d.z))"
    }
}
