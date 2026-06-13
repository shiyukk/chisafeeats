import Foundation
import CryptoKit
import GRDB

/// Pure ingest logic: turns API DTOs into `inspection` + `establishment` rows,
/// maintaining the denormalized "latest inspection" snapshot. Idempotent — safe
/// to re-run on overlapping data. Shared by the runtime sync and the seed builder.
enum InspectionImporter {

    /// Ingest a batch of DTOs inside a single write transaction.
    /// Returns the max `inspection_date` seen (for sync bookkeeping).
    @discardableResult
    static func ingest(_ dtos: [InspectionDTO], into db: Database) throws -> String? {
        var maxDate: String?
        for dto in dtos {
            guard let date = try ingestOne(dto, into: db) else { continue }
            if maxDate == nil || date > maxDate! { maxDate = date }
        }
        return maxDate
    }

    /// Returns the inspection date if the row was usable, else nil.
    private static func ingestOne(_ dto: InspectionDTO, into db: Database) throws -> String? {
        let inspectionId = dto.inspectionId.trimmingCharacters(in: .whitespaces)
        guard !inspectionId.isEmpty, let date = dto.inspectionDate, !date.isEmpty else {
            return nil
        }

        let estabId = establishmentID(for: dto)
        let result = InspectionResult(raw: dto.results)
        let risk = RiskLevel(raw: dto.risk)?.rawValue

        let idNum = Int(inspectionId) ?? 0
        let lat = dto.latitude.flatMap(Double.init)
        let lon = dto.longitude.flatMap(Double.init)
        let score = HygieneScore.score(resultCode: result.rawValue,
                                       violations: Violation.parse(dto.violations, date: date))

        // Write the parent establishment first so the inspection's foreign key holds.
        if var existing = try EstablishmentRecord.fetchOne(db, key: estabId) {
            // Refresh the denormalized snapshot only for a strictly-later event:
            // a newer date, or the SAME date with a higher inspection_id (so a
            // same-day re-inspection wins over the morning's failed visit).
            // Order-independent, so re-syncing boundary rows stays stable.
            let existingId = existing.latestInspectionId.flatMap { Int($0) } ?? -1
            let existingDate = existing.latestInspectionDate ?? ""
            if date > existingDate || (date == existingDate && idNum > existingId) {
                existing.latestResult = dto.results
                existing.latestResultCode = result.rawValue
                existing.latestInspectionDate = date
                existing.latestInspectionId = inspectionId
                existing.isOutOfBusiness = (result == .outOfBusiness)
                // Score tracks the latest inspection (nil for No Entry etc.), so
                // the dot color always agrees with the displayed result.
                existing.score = score
                existing.dbaName = dto.dbaName ?? existing.dbaName
                existing.akaName = dto.akaName ?? existing.akaName
                // facility_type / risk are venue-stable: a venue with several
                // licenses must NOT flip category/risk to whichever license was
                // inspected last (#6). They're set once on insert (seed picks the
                // dominant type) and left alone here.
                existing.address = dto.address ?? existing.address
                existing.city = dto.city ?? existing.city
                existing.state = dto.state ?? existing.state
                existing.zip = dto.zip ?? existing.zip
                existing.license = validLicense(dto) ?? existing.license
                // Never clobber a known-good coordinate with a null one.
                if let lat, let lon { existing.latitude = lat; existing.longitude = lon }
                try existing.update(db)
            }
        } else {
            let establishment = EstablishmentRecord(
                id: estabId,
                license: validLicense(dto),
                dbaName: dto.dbaName ?? "",
                akaName: dto.akaName,
                facilityType: dto.facilityType,
                risk: risk,
                address: dto.address,
                city: dto.city,
                state: dto.state,
                zip: dto.zip,
                latitude: lat,
                longitude: lon,
                latestResult: dto.results,
                latestResultCode: result.rawValue,
                latestInspectionDate: date,
                latestInspectionId: inspectionId,
                isOutOfBusiness: result == .outOfBusiness,
                score: score
            )
            try establishment.insert(db)
        }

        let inspection = InspectionRecord(
            inspectionId: inspectionId,
            establishmentId: estabId,
            inspectionDate: date,
            inspectionType: dto.inspectionType,
            results: dto.results,
            resultsCode: result.rawValue,
            risk: risk,
            violationsRaw: dto.violations
        )
        try inspection.upsert(db)
        return date
    }

    // MARK: - Dedup key

    /// Stable establishment id keyed by the *venue* (normalized name + address +
    /// zip), so several licenses at the same name+address collapse into one
    /// establishment. Falls back to the license number only when name+address
    /// are missing. NOTE: must stay in sync with Tools/rekey_seed.py, which
    /// re-keys the bundled seed with the identical rule.
    static func establishmentID(for dto: InspectionDTO) -> String {
        let name = norm(dto.dbaName)
        let address = norm(dto.address)
        let identity = [name, address, norm(dto.zip)].joined(separator: "|")
        if !name.isEmpty, !address.isEmpty { return "A:" + sha1(identity) }
        if let license = validLicense(dto) { return "L:" + license }
        return "A:" + sha1(identity)
    }

    private static func norm(_ s: String?) -> String {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func validLicense(_ dto: InspectionDTO) -> String? {
        guard let license = dto.license?.trimmingCharacters(in: .whitespaces),
              !license.isEmpty, license != "0" else { return nil }
        return license
    }

    /// First 16 hex chars (64 bits) of SHA-1 — keeps ids (and the seed) small.
    /// Collision odds across ~40k venues are ~4e-11, i.e. effectively zero.
    private static func sha1(_ string: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(string.utf8))
        return String(digest.map { String(format: "%02x", $0) }.joined().prefix(16))
    }
}
