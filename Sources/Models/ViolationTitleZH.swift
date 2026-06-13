import Foundation

/// Chinese translations of the standard Chicago food-code violation titles
/// (post-2018 checklist, items 1–64) and inspection types. Comments in the data
/// are free text and stay in English.
enum FoodCodeZH {
    static func violationTitle(number: Int?) -> String? {
        guard let number else { return nil }
        return violationTitles[number]
    }

    /// Plain-language, one-line explanation of what a checklist item means and
    /// why it matters — so a diner "gets it" without food-code knowledge.
    static func violationMeaning(number: Int?) -> String? {
        // Plain-language meanings exist only in Chinese; other languages fall
        // back to the English food-code title (handled by callers).
        guard currentAppLanguage() == .zh, let number else { return nil }
        return violationMeanings[number]
    }

    /// Translate boilerplate phrases that the cloud translator often leaves in
    /// English (all-caps legal text at the end of comments).
    static func polishComment(_ text: String) -> String {
        var out = text
        let replacements: [(String, String)] = [
            ("PRIORITY FOUNDATION VIOLATION", "重大违规"),
            ("PRIORITY VIOLATION", "严重违规"),
            ("CORE VIOLATION", "一般违规"),
            ("SERIOUS VIOLATION", "严重违规"),
            ("MINOR VIOLATION", "一般违规"),
            ("CITATION RE-ISSUED", "已重新开具传票"),
            ("CITATION ISSUED", "已开具传票"),
            ("CITATION WAS ISSUED", "已开具传票"),
            ("INSTRUCTED TO CORRECT", "已要求整改"),
            ("MUST CORRECT", "须整改"),
        ]
        for (en, zh) in replacements {
            out = out.replacingOccurrences(of: en, with: zh, options: [.caseInsensitive])
        }
        return out
    }

    /// Translate the facility/license type (used to label which license an
    /// inspection belongs to when a venue holds several).
    static func facility(_ raw: String?) -> String {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else {
            return localized("facility.other")
        }
        let key = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if let canonical = facilityKey(key) { return localized(canonical) }
        return raw   // unknown type → show the raw English as-is
    }

    /// Map a raw facility/license type to a localization key (nil if unknown).
    private static func facilityKey(_ key: String) -> String? {
        if key.contains("restaurant") || key == "golden diner" { return "facility.restaurant" }
        if key.contains("bakery") { return "facility.bakery" }
        if key.contains("grocery") { return "facility.grocery" }
        if key.contains("liquor") { return "facility.liquor" }
        if key.contains("tavern") || key.contains("bar") { return "facility.tavern" }
        if key.contains("wholesale") { return "facility.wholesale" }
        if key.contains("mobile") { return "facility.mobile" }
        if key.contains("catering") { return "facility.catering" }
        if key.contains("coffee") || key.contains("cafe") { return "facility.coffee" }
        if key.contains("gas station") { return "facility.gasStation" }
        if key.contains("convenience") { return "facility.convenience" }
        if key.contains("ice cream") { return "facility.iceCream" }
        if key.contains("candy") { return "facility.candy" }
        if key.contains("navy pier kiosk") { return "facility.navyPier" }
        if key.contains("kiosk") { return "facility.kiosk" }
        if key.contains("school") { return "facility.school" }
        if key.contains("daycare") || key.contains("children") { return "facility.daycare" }
        if key.contains("long term care") || key.contains("nursing") { return "facility.longTermCare" }
        if key.contains("hospital") { return "facility.hospital" }
        if key.contains("shared kitchen") { return "facility.sharedKitchen" }
        return nil
    }

    static func inspectionType(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let key = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if let canonical = inspectionKey(key) { return localized(canonical) }
        return raw   // unknown type → show the raw English as-is
    }

    /// Map a raw inspection type to a localization key (nil if unknown).
    private static func inspectionKey(_ key: String) -> String? {
        if key.contains("re-inspection") || key.contains("reinspection") {
            if key.contains("license") { return "insp.licenseReinspection" }
            if key.contains("canvass") { return "insp.canvassReinspection" }
            if key.contains("complaint") { return "insp.complaintReinspection" }
            return "insp.reinspection"
        }
        if key.contains("short form complaint") { return "insp.shortFormComplaint" }
        if key.contains("suspected food poisoning") { return "insp.suspectedFoodPoisoning" }
        if key.contains("license task force") { return "insp.licenseTaskForce" }
        if key.contains("tag removal") { return "insp.tagRemoval" }
        if key.contains("consultation") { return "insp.consultation" }
        if key.contains("out of business") { return "insp.outOfBusiness" }
        if key.contains("recent inspection") { return "insp.recentInspection" }
        if key.contains("non-inspection") || key.contains("no entry") { return "insp.nonInspection" }
        if key.contains("complaint") { return "insp.complaint" }
        if key.contains("canvass") { return "insp.canvass" }
        if key.contains("license") { return "insp.license" }
        return nil
    }

    private static let violationTitles: [Int: String] = [
        1: "负责人在岗、具备知识并履职",
        2: "持有芝加哥食品卫生证书",
        3: "管理者与员工知晓职责及报告义务",
        4: "正确执行病员限制与排除",
        5: "呕吐/腹泻事件应对流程",
        6: "正确的进食/试吃/饮水/禁烟",
        7: "无眼、鼻、口分泌物",
        8: "手部清洁、正确洗手",
        9: "即食食品不徒手接触",
        10: "洗手池充足、供应齐全、可用",
        11: "食材来自合规来源",
        12: "收货温度合规",
        13: "食材状况良好、安全、未掺假",
        14: "必要记录齐全（贝类标签/寄生虫处理）",
        15: "食材分隔与防护",
        16: "食品接触面：清洁并消毒",
        17: "退回/不安全食品的正确处置",
        18: "烹饪时间与温度合规",
        19: "热存食品再加热流程合规",
        20: "冷却时间与温度合规",
        21: "热存温度合规",
        22: "冷存温度合规",
        23: "正确的日期标记与处置",
        24: "以时间作为公共卫生控制（流程/记录）",
        25: "生/半熟食品的消费提示",
        26: "使用巴氏杀菌食品、不售禁售品",
        27: "食品添加剂合规使用",
        28: "有毒物质的标识/存放/使用正确",
        29: "符合变更/专门工艺/HACCP",
        30: "必要时使用巴氏杀菌蛋",
        31: "水与冰来自合规来源",
        32: "专门加工方式已获许可",
        33: "冷却方法得当、控温设备充足",
        34: "植物性食品热存前充分加热",
        35: "解冻方法合规",
        36: "温度计齐备且准确",
        37: "食品正确标签、原包装",
        38: "无虫害、鼠害及动物",
        39: "加工/储存/陈列过程防止污染",
        40: "个人卫生",
        41: "抹布正确使用与存放",
        42: "果蔬清洗",
        43: "在用器具正确存放",
        44: "器具/设备/布草正确存放、干燥、处理",
        45: "一次性用品正确存放与使用",
        46: "手套正确使用",
        47: "食品/非食品接触面易清洁、设计构造使用得当",
        48: "洗消设施安装/维护/使用、配备试纸",
        49: "非食品/食品接触面清洁",
        50: "冷热水供应、水压充足",
        51: "管道安装、配备防回流装置",
        52: "污水与废水正确排放",
        53: "厕所设施构造/供应/清洁",
        54: "垃圾正确处理、设施维护",
        55: "场所设施安装/维护/清洁",
        56: "通风照明充足、按指定区域使用",
        57: "全体员工完成食品操作培训",
        58: "按要求进行过敏原培训",
        59: "上次重大违规已整改",
        60: "上次一般违规已整改",
        61: "检查摘要已公示、公众可见",
        62: "符合室内清洁空气条例",
        63: "已撤除停业标志",
        64: "其他/公共卫生命令",
    ]

    /// Plain-language "what this means" for each checklist item.
    private static let violationMeanings: [Int: String] = [
        1: "店里要有懂食品安全、能管事的负责人在岗。",
        2: "管理者需持有芝加哥食品卫生证书。",
        3: "员工知道生病或有症状要上报、不带病接触食物。",
        4: "生病或带菌的员工被限制接触食物。",
        5: "有应对呕吐/腹泻污染的清理消毒流程。",
        6: "员工不在备餐区随意吃喝吸烟，避免污染食物。",
        7: "员工没有流鼻涕、揉眼等，避免分泌物碰到食物。",
        8: "员工按规范洗手、保持手部清洁。",
        9: "不直接用手碰即食食品（用手套或夹子）。",
        10: "洗手池能正常使用，有肥皂和擦手纸。",
        11: "食材来自正规、合规的供货渠道。",
        12: "进货时冷热食品的温度正常、没在危险温度区。",
        13: "食材新鲜、安全，没有变质或掺假。",
        14: "贝类标签、寄生虫处理等必要记录齐全。",
        15: "不同食材分开存放并有遮盖，防止交叉污染。",
        16: "接触食物的台面和器具有清洗并消毒。",
        17: "退回或不安全的食品被正确丢弃处理。",
        18: "食物烧到足够的中心温度，杀灭细菌。",
        19: "需要再加热的食物达到安全温度。",
        20: "热食按规定快速冷却，不给细菌繁殖机会。",
        21: "需要热存的食物保持够热。",
        22: "需要冷藏的食物保持够冷。",
        23: "食物有制作/保质日期标记，过期就丢。",
        24: "用时间控制安全的食品有规范流程和记录。",
        25: "生的或半熟食品向顾客做了风险提示。",
        26: "面向易感人群的食品经巴氏杀菌、不卖禁售品。",
        27: "食品添加剂按规定使用、不超量。",
        28: "清洁剂等有毒物品标识清楚、单独存放。",
        29: "自制/特殊工艺需经审批，符合 HACCP 安全计划。",
        30: "必要时使用经巴氏杀菌的蛋。",
        31: "用水和冰来自安全水源。",
        32: "特殊加工方式已获得许可。",
        33: "有足够的设备把食物快速降温/保温。",
        34: "植物类食品热存前充分加热。",
        35: "用安全方法解冻（冷藏、流水等）。",
        36: "备有并使用准确的温度计。",
        37: "食品标签正确、原包装完好。",
        38: "店内没有蟑螂、苍蝇、老鼠等有害生物。",
        39: "加工、储存、陈列过程防止食物被污染。",
        40: "员工个人卫生到位（如戴发网、不戴首饰）。",
        41: "擦拭布正确使用并泡在消毒液里。",
        42: "果蔬经过清洗。",
        43: "正在使用的器具放置得当、不被污染。",
        44: "餐具设备洗后晾干、正确存放。",
        45: "一次性餐具正确存放、不重复使用。",
        46: "手套正确使用、按需更换。",
        47: "台面和设备好清洁、结构合理。",
        48: "洗消设施齐全，并用试纸检测消毒浓度。",
        49: "不直接接触食物的表面也保持清洁。",
        50: "有充足的冷热水和水压。",
        51: "管道安装规范、有防回流装置，防污水倒灌。",
        52: "污水和废水正确排放。",
        53: "厕所设施完好、有洗手用品、保持干净。",
        54: "垃圾正确处理、垃圾区维护到位。",
        55: "店内设施安装、维护并保持清洁。",
        56: "通风和照明充足。",
        57: "全体员工完成食品操作培训。",
        58: "按要求完成过敏原培训。",
        59: "上次的重大违规已经整改。",
        60: "上次的一般违规已经整改。",
        61: "检查结果有公示、顾客看得到。",
        62: "符合室内禁烟（清洁空气）条例。",
        63: "停业整改的封条标志已撤除。",
        64: "其他与公共卫生相关的要求。",
    ]
}
