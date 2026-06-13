import MapKit
import Observation

/// Holds the pins currently shown on the map and debounces viewport queries.
@Observable
@MainActor
final class MapModel {
    private(set) var pins: [MapPin] = []
    var criteria = FilterCriteria()

    private let repository: EstablishmentRepository
    private var queryTask: Task<Void, Never>?
    private var lastRegion: MKCoordinateRegion?
    /// The box and zoom the current `pins` were loaded for — used to skip
    /// redundant re-queries while panning within already-loaded data.
    private var loadedBox: BoundingBox?
    private var loadedSpan: Double?

    init(repository: EstablishmentRepository) {
        self.repository = repository
    }

    /// Called on every region change. Debounces, then loads the viewport slice.
    func regionChanged(to region: MKCoordinateRegion) {
        lastRegion = region
        load(region: region, debounce: true)
    }

    /// Load immediately for the initial region (no debounce).
    func loadInitial(region: MKCoordinateRegion) {
        lastRegion = region
        load(region: region, debounce: false)
    }

    /// Re-query the current viewport after a filter change.
    func applyFilter(_ criteria: FilterCriteria) {
        self.criteria = criteria
        loadedBox = nil   // force a reload
        if let region = lastRegion { load(region: region, debounce: false) }
    }

    private func load(region: MKCoordinateRegion, debounce: Bool) {
        // Skip the query while panning within already-loaded data at the same
        // zoom — avoids the churn that makes scrolling feel laggy. (Any real zoom
        // change still re-queries so local density stays correct.)
        let viewport = Self.viewportBox(for: region)
        if let loadedBox, let loadedSpan,
           loadedBox.contains(viewport),
           abs(region.span.latitudeDelta - loadedSpan) / loadedSpan < 0.08 {
            return
        }

        queryTask?.cancel()
        let box = Self.boundingBox(for: region)
        let span = region.span.latitudeDelta
        let criteria = criteria
        queryTask = Task { [repository] in
            if debounce {
                try? await Task.sleep(for: .milliseconds(110))
                guard !Task.isCancelled else { return }
            }
            guard let pins = try? await repository.pins(in: box, filter: criteria) else { return }
            guard !Task.isCancelled else { return }
            self.pins = pins
            self.loadedBox = box
            self.loadedSpan = span
        }
    }

    private static func boundingBox(for region: MKCoordinateRegion) -> BoundingBox {
        // Pad ≥ 0.5 span so the box covers the whole visible viewport (0.5 = exactly
        // the viewport; less would leave the edges unloaded), plus a little margin
        // so a moderate pan lands on already-loaded pins (no re-query).
        box(for: region, pad: 0.8)
    }

    /// Just the visible rectangle (no over-scan).
    private static func viewportBox(for region: MKCoordinateRegion) -> BoundingBox {
        box(for: region, pad: 0.5)
    }

    private static func box(for region: MKCoordinateRegion, pad: Double) -> BoundingBox {
        let latPad = region.span.latitudeDelta * pad
        let lonPad = region.span.longitudeDelta * pad
        return BoundingBox(
            minLat: region.center.latitude - latPad,
            maxLat: region.center.latitude + latPad,
            minLon: region.center.longitude - lonPad,
            maxLon: region.center.longitude + lonPad
        )
    }
}
