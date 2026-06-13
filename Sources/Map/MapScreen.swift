import CoreLocation
import MapKit
import SwiftUI

/// The map tab: viewport-clustered dots, an inline search box, filter, legend,
/// and a tap-through to establishment detail.
struct MapScreen: View {
    let establishments: EstablishmentRepository
    let inspections: InspectionRepository
    let location: LocationManager
    @Bindable var filter: FilterModel

    @State private var model: MapModel
    @State private var sheet: MapSheet?
    @State private var recenterToken = 0
    @State private var focusToken = 0
    @State private var focusCoordinate: CLLocationCoordinate2D?

    @State private var query = ""
    @State private var results: [EstablishmentRecord] = []
    @State private var highlightedID: String?
    @State private var showLocationDenied = false
    @State private var showAbout = false
    @State private var controlsExpanded = false
    @Environment(LanguageManager.self) private var languageManager
    @Environment(\.openURL) private var openURL
    @FocusState private var searchFocused: Bool

    init(establishments: EstablishmentRepository, inspections: InspectionRepository,
         location: LocationManager, filter: FilterModel) {
        self.establishments = establishments
        self.inspections = inspections
        self.location = location
        self.filter = filter
        _model = State(initialValue: MapModel(repository: establishments))
    }

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        ZStack {
            // Only the map ignores the safe area; controls stay inside it.
            MapViewRepresentable(
                pins: model.pins,
                userCoordinate: location.coordinate,
                recenterToken: recenterToken,
                focusCoordinate: focusCoordinate,
                focusToken: focusToken,
                highlightedID: highlightedID,
                onRegionChange: { model.regionChanged(to: $0) },
                onSelect: { sheet = .detail($0) }
            )
            .ignoresSafeArea()

            topControls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if !isSearching {
                MapLegend()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    // Extra bottom inset so the legend clears MapKit's bottom-left
                    // "Maps · Legal" attribution (which must stay visible).
                    .padding(.bottom, 26)
                // Right controls: collapsed to a single "⋯" circle by default;
                // expands into one grouped glass capsule (about / settings /
                // locate) — mirrors the legend's collapse behavior.
                Group {
                    if controlsExpanded {
                        VStack(spacing: 0) {
                            Button { withAnimation(.snappy) { controlsExpanded = false } } label: {
                                Image(systemName: "chevron.down")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: Self.controlHeight, height: 32)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            controlDivider
                            aboutButton
                            controlDivider
                            SettingsMenu {
                                Image(systemName: "gearshape")
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                                    .frame(width: Self.controlHeight, height: Self.controlHeight)
                                    .contentShape(Rectangle())
                            }
                            controlDivider
                            locateButton
                        }
                        .glassEffect(.regular.interactive(), in: Capsule())
                    } else {
                        Button { withAnimation(.snappy) { controlsExpanded = true } } label: {
                            Image(systemName: "ellipsis")
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .frame(width: Self.controlHeight, height: Self.controlHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: Circle())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.horizontal, 16)
                // Same bottom inset as the legend so both bottoms align (the
                // Maps attribution sits bottom-left, clear of this capsule).
                .padding(.bottom, 26)
            }
        }
        .task {
            model.applyFilter(filter.criteria)
            model.loadInitial(region: MapViewRepresentable.chicagoRegion)
            // Only prompt for location once the user is past the language picker
            // (it renders as an overlay above this map), so the system alert
            // never pops over the picker.
            if languageManager.languageChosen { location.requestIfNeeded() }
        }
        .onChange(of: languageManager.languageChosen) { _, chosen in
            if chosen { location.requestIfNeeded() }
        }
        .onChange(of: filter.criteria) { _, new in model.applyFilter(new) }
        .task(id: query) { await runSearch() }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .filter:
                FilterSheet(model: filter)
            case .detail(let id):
                NavigationStack {
                    EstablishmentDetailScreen(establishmentID: id,
                                              establishments: establishments,
                                              inspections: inspections)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                // Frosted-map backdrop so the glass cards read as real glass
                // (not flat white panels) in light mode.
                .presentationBackground(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showAbout) { AboutView() }
    }

    // MARK: - Top controls (search + filter) and results

    private var topControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                searchField
                Button { sheet = .filter } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle\(filter.criteria.isActive ? ".fill" : "")")
                        .font(.title3)
                        .foregroundStyle(filter.criteria.isActive ? Color.accentColor : .primary)
                        .frame(width: Self.controlHeight, height: Self.controlHeight)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
            }
            // Show the results dropdown while searching. When a sheet is open,
            // only show it once the field is focused again (actively searching
            // another place) — so tapping a result doesn't leave it covering the
            // map, but searching for a new place from the detail still works.
            if isSearching && (sheet == nil || searchFocused) { searchResults }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
    }

    private static let controlHeight: CGFloat = 44

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(localized("search.placeholder"), text: $query)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = ""; searchFocused = false; highlightedID = nil } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: Self.controlHeight)
        .glassEffect(.regular, in: Capsule())
    }

    private var searchResults: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results, id: \.id) { e in
                    Button { select(e) } label: {
                        SearchRow(establishment: e, distance: distance(to: e))
                            .padding(.horizontal, 12).padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
                if results.isEmpty {
                    Text(localized("search.noResults")).font(.subheadline).foregroundStyle(.secondary)
                        .padding(.vertical, 16)
                }
            }
        }
        // Shorter when a detail card is open so the results sit above it
        // without overlapping; taller otherwise.
        .frame(maxHeight: sheet == nil ? 320 : 260)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Thin separator between the grouped capsule's buttons.
    private var controlDivider: some View {
        Divider().frame(width: 26)
    }

    private var aboutButton: some View {
        Button {
            showAbout = true
            withAnimation(.snappy) { controlsExpanded = false }
        } label: {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: Self.controlHeight, height: Self.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var locateButton: some View {
        Button {
            switch location.authorization {
            case .denied, .restricted:
                showLocationDenied = true       // can't re-prompt — point to Settings
            default:
                location.requestIfNeeded()
                recenterToken += 1
                withAnimation(.snappy) { controlsExpanded = false }
            }
        } label: {
            Image(systemName: location.coordinate == nil ? "location" : "location.fill")
                .font(.title3)
                .foregroundStyle(location.coordinate == nil ? Color.primary : Color.accentColor)
                .frame(width: Self.controlHeight, height: Self.controlHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .alert(localized("location.denied.message"), isPresented: $showLocationDenied) {
            Button(localized("common.openSettings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button(localized("common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Search logic

    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { results = []; return }
        let rows = (try? await establishments.search(matching: trimmed, filter: filter.criteria)) ?? []
        let deduped = dedupeByPlace(rows)
        results = location.coordinate == nil ? deduped : sortByDistance(deduped)
    }

    /// Collapse multiple license records at the same name+address (e.g. a
    /// restaurant with several licenses) into one — the most recent inspection.
    private func dedupeByPlace(_ rows: [EstablishmentRecord]) -> [EstablishmentRecord] {
        var best: [String: EstablishmentRecord] = [:]
        for row in rows {
            let key = [row.dbaName, row.address, row.zip]
                .map { ($0 ?? "").lowercased().trimmingCharacters(in: .whitespaces) }
                .joined(separator: "|")
            if let existing = best[key],
               (existing.latestInspectionDate ?? "") >= (row.latestInspectionDate ?? "") { continue }
            best[key] = row
        }
        return best.values.sorted { ($0.latestInspectionDate ?? "") > ($1.latestInspectionDate ?? "") }
    }

    private func select(_ e: EstablishmentRecord) {
        searchFocused = false
        // Clear the query so the results dropdown collapses (and the bottom
        // controls return) instead of re-covering the map after the detail sheet
        // is dismissed. The chosen pin stays highlighted via highlightedID.
        query = ""
        highlightedID = e.id
        if let lat = e.latitude, let lon = e.longitude {
            focusCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            focusToken += 1
        }
        sheet = .detail(e.id)
    }

    private func sortByDistance(_ rows: [EstablishmentRecord]) -> [EstablishmentRecord] {
        guard let c = location.coordinate else { return rows }
        let origin = CLLocation(latitude: c.latitude, longitude: c.longitude)
        return rows.sorted {
            (dist($0, origin) ?? .greatestFiniteMagnitude) < (dist($1, origin) ?? .greatestFiniteMagnitude)
        }
    }

    private func distance(to e: EstablishmentRecord) -> Double? {
        guard let c = location.coordinate else { return nil }
        return dist(e, CLLocation(latitude: c.latitude, longitude: c.longitude))
    }

    private func dist(_ e: EstablishmentRecord, _ origin: CLLocation) -> Double? {
        guard let lat = e.latitude, let lon = e.longitude else { return nil }
        return origin.distance(from: CLLocation(latitude: lat, longitude: lon))
    }
}

/// Single sheet for the map (filter or an establishment's detail).
enum MapSheet: Identifiable {
    case filter
    case detail(String)
    var id: String { if case .detail(let id) = self { return id } else { return "filter" } }
}
