enum FrontMatterTypography {
    static func titleSize(for baseSize: Double) -> Double {
        baseSize * 0.72
    }

    static func delimiterSize(for baseSize: Double) -> Double {
        baseSize * 0.76
    }

    static func valueSize(for baseSize: Double) -> Double {
        baseSize * 0.86
    }

    static func codeSize(for baseSize: Double) -> Double {
        baseSize * 0.9
    }
}
