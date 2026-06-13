import Foundation

/// Maps a facility type to an SF Symbol for list rows.
enum FacilityIcon {
    static func symbol(for type: String?) -> String {
        switch type ?? "" {
        case "Restaurant": "fork.knife"
        case "Grocery Store": "cart.fill"
        case "School": "graduationcap.fill"
        case "Bakery": "birthday.cake.fill"
        case "Liquor": "wineglass.fill"
        case let t where t.contains("Daycare"), let t where t.contains("Children"):
            "figure.2.and.child.holdinghands"
        case let t where t.contains("Mobile"): "box.truck.fill"
        case let t where t.contains("Coffee") || t.contains("Cafe"): "cup.and.saucer.fill"
        case let t where t.contains("Kitchen"): "frying.pan.fill"
        default: "building.2.fill"
        }
    }
}
