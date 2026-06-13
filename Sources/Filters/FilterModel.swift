import Observation

/// Shared filter state. One instance drives both the map and the nearby/search
/// list so a filter set in one place applies everywhere.
@Observable
@MainActor
final class FilterModel {
    var criteria = FilterCriteria()
}
