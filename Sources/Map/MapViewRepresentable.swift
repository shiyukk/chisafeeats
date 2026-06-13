import MapKit
import SwiftUI

/// Wraps `MKMapView` for performant clustering of thousands of pins.
/// SwiftUI `Map` has no clustering and degrades past a few thousand annotations;
/// MKMapView reuses annotation views and clusters on the GPU.
struct MapViewRepresentable: UIViewRepresentable {
    /// Chicago, centered downtown.
    static let chicagoRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),
        span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
    )

    var pins: [MapPin]
    /// Center the map on this coordinate when `recenterToken` changes.
    var userCoordinate: CLLocationCoordinate2D?
    var recenterToken: Int
    /// Center the map here (e.g. a chosen search result) when `focusToken` changes.
    var focusCoordinate: CLLocationCoordinate2D?
    var focusToken: Int
    /// The chosen search result — drawn highlighted and always on top.
    var highlightedID: String?
    var onRegionChange: (MKCoordinateRegion) -> Void
    var onSelect: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(Self.chicagoRegion, animated: false)
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .excludingAll
        // Individual establishments render as small colored dots (no clustering),
        // so each shows its own result; clusters are kept only as a fallback.
        mapView.register(MKAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: Coordinator.pinID)
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: Coordinator.clusterID)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        // No layoutMargins manipulation: a large left inset (used earlier to
        // center the attribution) shifts the whole map and clips the left edge.
        // Keep the map truly full-screen; the attribution sits bottom-left.
        context.coordinator.sync(pins: pins, on: mapView)
        context.coordinator.applyHighlightIfNeeded(highlightedID, on: mapView)
        context.coordinator.recenterIfNeeded(token: recenterToken, to: userCoordinate, on: mapView)
        context.coordinator.focusIfNeeded(token: focusToken, to: focusCoordinate, on: mapView)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        static let pinID = "estab"
        static let clusterID = "cluster"

        var parent: MapViewRepresentable
        private var shown: [String: EstablishmentAnnotation] = [:]
        private var lastRecenterToken = 0
        private var lastFocusToken = 0
        private var highlightedID: String?
        private var detailLevel: LabelDetail = .dot
        /// Establishments currently chosen to show a (non-overlapping) label;
        /// everyone else renders as a lightweight dot.
        private var labeledIDs: Set<String> = []

        /// How much detail the current zoom reveals.
        enum LabelDetail { case dot, score, full }
        /// What a single annotation draws.
        enum Display { case dot, scorePill, fullPill, hidden }
        static func detail(for latitudeDelta: Double) -> LabelDetail {
            if latitudeDelta <= 0.022 { return .full }   // number + name
            if latitudeDelta <= 0.07 { return .score }   // number only
            return .dot
        }

        init(_ parent: MapViewRepresentable) { self.parent = parent }

        /// Center on the user when the "locate me" button bumps the token.
        func recenterIfNeeded(token: Int, to coordinate: CLLocationCoordinate2D?, on mapView: MKMapView) {
            guard token != lastRecenterToken, let coordinate else { return }
            lastRecenterToken = token
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))
            mapView.setRegion(region, animated: true)
        }

        /// Re-style the previously- and newly-highlighted annotations when the
        /// chosen search result changes, so it stands out and stays on top.
        func applyHighlightIfNeeded(_ id: String?, on mapView: MKMapView) {
            guard id != highlightedID else { return }
            highlightedID = id
            // Restyle visible views so the callout, and the hiding of same-spot
            // sibling licenses, both take effect.
            recomputeLabels(on: mapView)
        }

        /// Center on a chosen search result, zoomed in to show its pill. The
        /// center is nudged south so the pin lands in the visible map band above
        /// the medium-height detail sheet (which covers the lower half).
        func focusIfNeeded(token: Int, to coordinate: CLLocationCoordinate2D?, on mapView: MKMapView) {
            guard token != lastFocusToken, let coordinate else { return }
            lastFocusToken = token
            let span = 0.012
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: coordinate.latitude - span * 0.28,
                                               longitude: coordinate.longitude),
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span))
            mapView.setRegion(region, animated: true)
        }

        /// Diff the incoming pin set against what's on the map.
        func sync(pins: [MapPin], on mapView: MKMapView) {
            let incoming = Dictionary(pins.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

            let removed = shown.filter { incoming[$0.key] == nil }
            if !removed.isEmpty {
                mapView.removeAnnotations(Array(removed.values))
                removed.keys.forEach { shown[$0] = nil }
            }

            let added = incoming.values.filter { shown[$0.id] == nil }
            if !added.isEmpty {
                let annotations = added.map { EstablishmentAnnotation(pin: $0) }
                annotations.forEach { shown[$0.establishmentID] = $0 }
                mapView.addAnnotations(annotations)
            }
            if !removed.isEmpty || !added.isEmpty {
                recomputeLabels(on: mapView)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            recomputeLabels(on: mapView)
            parent.onRegionChange(mapView.region)
        }

        // Keep the blue "you are here" dot above every pin/label.
        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            for view in views where view.annotation is MKUserLocation {
                view.zPriority = .max
                view.displayPriority = .required
            }
        }

        /// Decide which establishments get a label (grid de-confliction so labels
        /// never overlap) and restyle the visible annotations. Runs only on pin
        /// updates and when the map settles — no per-frame work, so it stays smooth.
        func recomputeLabels(on mapView: MKMapView) {
            let band = Self.detail(for: mapView.region.span.latitudeDelta)
            detailLevel = band
            labeledIDs = band == .dot ? [] : Self.computeLabeledIDs(among: shown, on: mapView, band: band)
            // Restyle only the on-screen views; off-screen ones are styled lazily
            // when MapKit realizes them in viewFor — keeps this cheap on settle.
            for case let estab as EstablishmentAnnotation in mapView.annotations(in: mapView.visibleMapRect) {
                guard let view = mapView.view(for: estab) else { continue }
                Self.style(view, for: estab,
                           display: display(for: estab.establishmentID, band: band),
                           highlighted: estab.establishmentID == highlightedID)
            }
        }

        private func display(for id: String, band: LabelDetail) -> Display {
            // Hide sibling licenses sitting at the exact same coordinate as the
            // highlighted place, so its callout doesn't reveal another-colored dot
            // underneath (e.g. a venue with 3 licenses at one address).
            if let hid = highlightedID, id != hid,
               let hc = shown[hid]?.coordinate, let c = shown[id]?.coordinate,
               abs(hc.latitude - c.latitude) < 1e-6, abs(hc.longitude - c.longitude) < 1e-6 {
                return .hidden
            }
            switch band {
            case .dot:
                return .dot
            case .score:
                // Dots underneath + de-conflicted score pills.
                return labeledIDs.contains(id) ? .scorePill : .dot
            case .full:
                // Closest zoom: de-conflicted name labels, with the other places
                // still shown as small dots underneath.
                return labeledIDs.contains(id) ? .fullPill : .dot
            }
        }

        /// Greedy label de-confliction: place labels worst-result-first, accepting
        /// one only if it doesn't collide with any already-placed label. Unlike a
        /// fixed grid (where two labels in adjacent cells could still touch at the
        /// shared edge), this guarantees labels never overlap.
        static func computeLabeledIDs(among shown: [String: EstablishmentAnnotation],
                                      on mapView: MKMapView, band: LabelDetail) -> Set<String> {
            let region = mapView.region
            let size = mapView.bounds.size
            guard size.width > 0, size.height > 0 else { return [] }
            // Label footprint (points, incl. spacing) → min center spacing in degrees.
            let footprint: CGSize = band == .full ? CGSize(width: 168, height: 60)
                                                  : CGSize(width: 50, height: 28)
            let cellW = region.span.longitudeDelta * Double(footprint.width / size.width)
            let cellH = region.span.latitudeDelta * Double(footprint.height / size.height)
            guard cellW > 0, cellH > 0 else { return [] }
            let latM = region.span.latitudeDelta * 0.6, lonM = region.span.longitudeDelta * 0.6
            let minLat = region.center.latitude - latM, maxLat = region.center.latitude + latM
            let minLon = region.center.longitude - lonM, maxLon = region.center.longitude + lonM

            // Candidates within view, worst result first (stable tiebreak by id).
            var candidates: [(id: String, lat: Double, lon: Double, rank: Int)] = []
            for (id, estab) in shown {
                let lat = estab.coordinate.latitude, lon = estab.coordinate.longitude
                guard lat >= minLat, lat <= maxLat, lon >= minLon, lon <= maxLon else { continue }
                candidates.append((id, lat, lon, labelRank(estab.result)))
            }
            candidates.sort { $0.rank != $1.rank ? $0.rank > $1.rank : $0.id < $1.id }

            // Accept greedily; bucket accepted centers so each check only looks at
            // neighbouring cells (a conflict must be within one cell).
            struct Cell: Hashable { let x: Int; let y: Int }
            var accepted: [Cell: [(lat: Double, lon: Double)]] = [:]
            var result = Set<String>()
            for c in candidates {
                let cx = Int((c.lon / cellW).rounded(.down))
                let cy = Int((c.lat / cellH).rounded(.down))
                var conflict = false
                search: for nx in (cx - 1)...(cx + 1) {
                    for ny in (cy - 1)...(cy + 1) {
                        guard let bucket = accepted[Cell(x: nx, y: ny)] else { continue }
                        for p in bucket where abs(c.lon - p.lon) < cellW && abs(c.lat - p.lat) < cellH {
                            conflict = true; break search
                        }
                    }
                }
                if !conflict {
                    accepted[Cell(x: cx, y: cy), default: []].append((c.lat, c.lon))
                    result.insert(c.id)
                }
            }
            return result
        }

        /// Worst result wins a cell's single label slot.
        static func labelRank(_ result: InspectionResult) -> Int {
            switch result {
            case .fail: return 4
            case .passWithConditions: return 3
            case .pass: return 2
            case .other: return 1
            case .outOfBusiness: return 0
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: Coordinator.clusterID, for: annotation) as! MKMarkerAnnotationView
                view.markerTintColor = Self.clusterColor(cluster.memberAnnotations)
                view.glyphText = nil
                return view
            }
            guard let estab = annotation as? EstablishmentAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: Coordinator.pinID, for: annotation)
            view.canShowCallout = false
            view.transform = .identity
            let band = Self.detail(for: mapView.region.span.latitudeDelta)
            detailLevel = band
            Self.style(view, for: estab, display: display(for: estab.establishmentID, band: band),
                       highlighted: estab.establishmentID == highlightedID)
            return view
        }

        /// Renders one annotation as a dot, a compact score pill, or a full
        /// name+score label. Labels are pre-de-conflicted by the grid, so we show
        /// everything (.required); dots sit beneath labels. Color follows the
        /// latest result.
        static func style(_ view: MKAnnotationView, for estab: EstablishmentAnnotation,
                          display: Display, highlighted: Bool) {
            view.centerOffset = .zero
            view.displayPriority = .required
            let (color, key) = marker(for: estab)

            // The chosen result floats above everything as an info callout.
            // `zPriority` (not layer.zPosition) is what MapKit honours for
            // stacking — otherwise it reorders annotations by latitude and a
            // nearby dot would cover a label.
            if highlighted {
                let (img, offset) = calloutImage(for: estab, color: color)
                view.image = img
                view.centerOffset = offset
                view.collisionMode = .rectangle
                view.zPriority = Self.calloutZ   // above pills, below the user dot
                return
            }

            let scored = estab.result.isScored && estab.score != nil
            // Score number when available, otherwise a short status (未检查/已停业…).
            let label = scored ? String(estab.score!) : estab.result.displayLabel(raw: estab.rawResult)

            switch display {
            case .hidden:
                view.image = nil
                view.zPriority = .min
            case .dot:
                view.image = dotImage(color: color, key: key)
                view.collisionMode = .circle
                view.zPriority = .min          // dots sit beneath every label
            case .scorePill:
                view.image = scorePill(label, color: color, cacheKey: key)
                view.collisionMode = .rectangle
                view.zPriority = Self.labelZ    // labels above dots
            case .fullPill:
                let (img, dy) = labeledPill(label, name: shortName(estab.title),
                                            color: color, cacheKey: key)
                view.image = img
                view.centerOffset = CGPoint(x: 0, y: dy)
                view.collisionMode = .rectangle
                view.zPriority = Self.labelZ
            }
        }

        // Stacking order: dots (.min) < labels < callout < user-location dot (.max).
        static let labelZ = MKAnnotationViewZPriority(rawValue: 800)
        static let calloutZ = MKAnnotationViewZPriority(rawValue: 900)

        nonisolated(unsafe) private static var scorePillCache: [String: UIImage] = [:]

        /// A compact colored pill showing just the score number — the mid-zoom
        /// step between a plain dot and the full name+score label.
        static func scorePill(_ text: String, color: UIColor, cacheKey: String) -> UIImage {
            let key = "\(cacheKey)\u{1}\(text)"
            if let cached = scorePillCache[key] { return cached }
            let font = UIFont.systemFont(ofSize: 10, weight: .bold)
            let str = text as NSString
            let textSize = str.size(withAttributes: [.font: font])
            let padH: CGFloat = 5, padV: CGFloat = 2
            let w = ceil(textSize.width) + padH * 2
            let h = ceil(textSize.height) + padV * 2
            let image = UIGraphicsImageRenderer(size: CGSize(width: w, height: h)).image { _ in
                let rect = CGRect(x: 0, y: 0, width: w, height: h)
                color.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: h / 2).fill()
                UIColor.white.setStroke()
                let border = UIBezierPath(roundedRect: rect.insetBy(dx: 0.6, dy: 0.6),
                                          cornerRadius: h / 2)
                border.lineWidth = 1
                border.stroke()
                let shadow = NSShadow()
                shadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
                shadow.shadowBlurRadius = 1.5
                str.draw(at: CGPoint(x: padH, y: padV),
                         withAttributes: [.font: font, .foregroundColor: UIColor.white, .shadow: shadow])
            }
            scorePillCache[key] = image
            return image
        }

        /// SF Symbol summarizing a result, for the callout's leading glyph.
        static func resultSymbol(_ result: InspectionResult) -> String {
            switch result {
            case .pass: return "checkmark.seal.fill"
            case .passWithConditions: return "exclamationmark.triangle.fill"
            case .fail: return "xmark.octagon.fill"
            case .outOfBusiness: return "xmark.circle.fill"
            case .other: return "questionmark.circle.fill"
            }
        }

        /// The chosen result, drawn as a floating info callout: a dark card with
        /// a leading result glyph, the establishment name, and a colored score
        /// badge, plus a downward pointer whose tip sits on the coordinate.
        /// Returns the image and the centerOffset that anchors the tip.
        static func calloutImage(for estab: EstablishmentAnnotation, color: UIColor) -> (UIImage, CGPoint) {
            let nameFont = UIFont.systemFont(ofSize: 14, weight: .bold)
            let labelFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
            let scoreFont = UIFont.systemFont(ofSize: 16, weight: .heavy)
            let nameStr = shortName(estab.title) as NSString
            let labelStr = estab.result.displayLabel(raw: estab.rawResult) as NSString
            let scored = estab.result.isScored && estab.score != nil

            let nameSize = nameStr.size(withAttributes: [.font: nameFont])
            let labelSize = labelStr.size(withAttributes: [.font: labelFont])
            let textW = ceil(max(nameSize.width, labelSize.width))
            let textH = ceil(nameSize.height) + 2 + ceil(labelSize.height)

            // Leading glyph.
            let glyphSize: CGFloat = 22
            let glyphConfig = UIImage.SymbolConfiguration(pointSize: 19, weight: .bold)
            let glyph = UIImage(systemName: resultSymbol(estab.result), withConfiguration: glyphConfig)?
                .withTintColor(color, renderingMode: .alwaysOriginal)

            // Trailing score badge.
            let scoreStr = (scored ? String(estab.score!) : "") as NSString
            let scoreTextSize = scoreStr.size(withAttributes: [.font: scoreFont])
            let badgeW = scored ? ceil(scoreTextSize.width) + 16 : 0
            let badgeH: CGFloat = scored ? 30 : 0

            let pad: CGFloat = 10, gap: CGFloat = 9
            let contentW = glyphSize + gap + textW + (scored ? gap + badgeW : 0)
            let contentH = max(textH, max(glyphSize, badgeH))
            let cardW = pad * 2 + contentW
            let cardH = pad * 2 + contentH

            let margin: CGFloat = 8                 // room for the drop shadow
            let triW: CGFloat = 15, triH: CGFloat = 8
            let W = cardW + margin * 2
            let H = margin + cardH + triH + margin
            let tipY = margin + cardH + triH
            let cx = W / 2

            let cardBG = UIColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 0.97)

            let image = UIGraphicsImageRenderer(size: CGSize(width: W, height: H)).image { ctx in
                let card = CGRect(x: margin, y: margin, width: cardW, height: cardH)
                // Card + pointer as one shape, with a single soft drop shadow.
                let shape = UIBezierPath(roundedRect: card, cornerRadius: 13)
                let tri = UIBezierPath()
                tri.move(to: CGPoint(x: cx - triW / 2, y: card.maxY - 0.5))
                tri.addLine(to: CGPoint(x: cx, y: tipY))
                tri.addLine(to: CGPoint(x: cx + triW / 2, y: card.maxY - 0.5))
                tri.close()
                shape.append(tri)
                ctx.cgContext.saveGState()
                ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 2), blur: 7,
                                        color: UIColor.black.withAlphaComponent(0.45).cgColor)
                cardBG.setFill()
                shape.fill()
                ctx.cgContext.restoreGState()
                UIColor.white.withAlphaComponent(0.12).setStroke()
                let border = UIBezierPath(roundedRect: card, cornerRadius: 13)
                border.lineWidth = 0.5
                border.stroke()

                // Leading glyph (vertically centered).
                let glyphY = card.minY + (cardH - glyphSize) / 2
                glyph?.draw(in: CGRect(x: card.minX + pad, y: glyphY, width: glyphSize, height: glyphSize))

                // Text column.
                let textX = card.minX + pad + glyphSize + gap
                let textColH = textH
                let textY = card.minY + (cardH - textColH) / 2
                nameStr.draw(at: CGPoint(x: textX, y: textY),
                             withAttributes: [.font: nameFont, .foregroundColor: UIColor.white])
                labelStr.draw(at: CGPoint(x: textX, y: textY + ceil(nameSize.height) + 2),
                              withAttributes: [.font: labelFont, .foregroundColor: color])

                // Score badge.
                if scored {
                    let badgeX = card.maxX - pad - badgeW
                    let badgeY = card.minY + (cardH - badgeH) / 2
                    let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeW, height: badgeH)
                    color.setFill()
                    UIBezierPath(roundedRect: badgeRect, cornerRadius: 7).fill()
                    let sx = badgeX + (badgeW - ceil(scoreTextSize.width)) / 2
                    let sy = badgeY + (badgeH - ceil(scoreTextSize.height)) / 2
                    scoreStr.draw(at: CGPoint(x: sx, y: sy),
                                  withAttributes: [.font: scoreFont, .foregroundColor: UIColor.white])
                }
            }
            // Anchor the pointer tip (bottom-center) on the coordinate.
            return (image, CGPoint(x: 0, y: H / 2 - tipY))
        }

        /// Color + cache-key for an establishment, by latest RESULT (so the dot
        /// color always agrees with the result filter): pass → green, conditions
        /// → yellow, fail → red, out of business → gray, else (No Entry…) → slate.
        /// The score is shown as a number on the pill, not via color.
        static func marker(for estab: EstablishmentAnnotation) -> (UIColor, String) {
            switch estab.result {
            case .pass: return (UIColor(InspectionResult.pass.color), "r0")
            case .passWithConditions: return (UIColor(InspectionResult.passWithConditions.color), "r1")
            case .fail: return (UIColor(InspectionResult.fail.color), "r2")
            case .outOfBusiness: return (UIColor(InspectionResult.outOfBusiness.color), "oob")
            case .other: return (UIColor(RatingStyle.noScore), "none")
            }
        }

        /// Truncate a long establishment name for the pill.
        static func shortName(_ name: String?) -> String {
            let name = (name ?? "").trimmingCharacters(in: .whitespaces)
            return name.count > 14 ? String(name.prefix(13)) + "…" : name
        }

        nonisolated(unsafe) private static var dotCache: [String: UIImage] = [:]

        static func dotImage(color: UIColor, key: String) -> UIImage {
            if let cached = dotCache[key] { return cached }
            let size = CGSize(width: 8, height: 8)
            let image = UIGraphicsImageRenderer(size: size).image { ctx in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
                color.setFill()
                ctx.cgContext.fillEllipse(in: rect)
                UIColor.white.withAlphaComponent(0.9).setStroke()
                let ring = UIBezierPath(ovalIn: rect)
                ring.lineWidth = 0.75
                ring.stroke()
            }
            dotCache[key] = image
            return image
        }

        /// A colored pill (score or status) with the establishment name as a
        /// caption *below* it. Returns the image and the centerOffset.y needed to
        /// keep the pill (not the whole image) anchored on the coordinate.
        nonisolated(unsafe) private static var pillCache: [String: (UIImage, CGFloat)] = [:]

        static func labeledPill(_ pillText: String, name: String, color: UIColor,
                                cacheKey: String) -> (UIImage, CGFloat) {
            // Cache by color band + text + name so panning/zooming reuses images
            // instead of re-rendering hundreds of labels each frame.
            let key = "\(cacheKey)\u{1}\(pillText)\u{1}\(name)"
            if let cached = pillCache[key] { return cached }
            let pillFont = UIFont.systemFont(ofSize: 13, weight: .bold)
            let nameFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
            let pillStr = pillText as NSString
            let nameStr = name as NSString
            let pillTextSize = pillStr.size(withAttributes: [.font: pillFont])
            let nameSize = nameStr.size(withAttributes: [.font: nameFont])
            let padH: CGFloat = 11, padV: CGFloat = 5, gap: CGFloat = 3
            let pillW = ceil(pillTextSize.width) + padH * 2
            let pillH = ceil(pillTextSize.height) + padV * 2
            let nameW = ceil(nameSize.width), nameH = ceil(nameSize.height)
            let W = max(pillW, nameW + 6)
            let H = pillH + gap + nameH

            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.55)
            shadow.shadowBlurRadius = 2

            let image = UIGraphicsImageRenderer(size: CGSize(width: W, height: H)).image { _ in
                // Pill (centered horizontally, at the top).
                let pillRect = CGRect(x: (W - pillW) / 2, y: 0, width: pillW, height: pillH)
                color.setFill()
                UIBezierPath(roundedRect: pillRect, cornerRadius: pillH / 2).fill()
                UIColor.white.setStroke()
                let border = UIBezierPath(roundedRect: pillRect.insetBy(dx: 0.75, dy: 0.75),
                                          cornerRadius: pillH / 2)
                border.lineWidth = 1.5
                border.stroke()
                let pillShadow = NSShadow()
                pillShadow.shadowColor = UIColor.black.withAlphaComponent(0.35)
                pillShadow.shadowBlurRadius = 1.5
                pillStr.draw(at: CGPoint(x: pillRect.minX + padH, y: pillRect.minY + padV),
                             withAttributes: [.font: pillFont, .foregroundColor: UIColor.white,
                                              .shadow: pillShadow])
                // Name caption below the pill.
                nameStr.draw(at: CGPoint(x: (W - nameW) / 2, y: pillH + gap),
                             withAttributes: [.font: nameFont, .foregroundColor: UIColor.white,
                                              .shadow: shadow])
            }
            // Shift the image up so the pill sits on the coordinate.
            let result = (image, -(gap + nameH) / 2)
            // Keyed by venue name, this would grow unbounded while panning the
            // whole city — clear it past a generous cap (it just re-renders).
            if pillCache.count > 1500 { pillCache.removeAll(keepingCapacity: true) }
            pillCache[key] = result
            return result
        }

        /// Aggregate a cluster's member results into one tint: green when the
        /// area is almost all passing, amber when conditions/fails are notable,
        /// red when a meaningful share fail. Out-of-business/other are ignored.
        static func clusterColor(_ members: [MKAnnotation]) -> UIColor {
            let codes = members.compactMap { ($0 as? EstablishmentAnnotation)?.resultCode }
            let fail = codes.filter { $0 == InspectionResult.fail.rawValue }.count
            let cond = codes.filter { $0 == InspectionResult.passWithConditions.rawValue }.count
            let pass = codes.filter { $0 == InspectionResult.pass.rawValue }.count
            let rated = fail + cond + pass
            guard rated > 0 else { return .systemGray }
            // Citywide baseline is ~3% fail / ~20% fail-or-conditions, so these
            // thresholds surface relatively worse pockets rather than staying all
            // green. A single establishment shows its own true color.
            let failFrac = Double(fail) / Double(rated)
            let badFrac = Double(fail + cond) / Double(rated)
            if failFrac >= 0.08 { return .systemRed }
            if failFrac >= 0.04 || badFrac >= 0.28 { return .systemOrange }
            return .systemGreen
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                // Zoom into the cluster.
                let region = MKCoordinateRegion(
                    center: cluster.coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: mapView.region.span.latitudeDelta / 3,
                        longitudeDelta: mapView.region.span.longitudeDelta / 3))
                mapView.setRegion(region, animated: true)
                mapView.deselectAnnotation(cluster, animated: false)
            } else if let estab = view.annotation as? EstablishmentAnnotation {
                parent.onSelect(estab.establishmentID)
                mapView.deselectAnnotation(estab, animated: false)
            }
        }
    }
}
