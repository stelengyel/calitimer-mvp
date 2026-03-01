import SwiftUI

extension Font {
    static func mono(_ size: CGFloat) -> Font {
        .custom("JetBrainsMono-Regular", size: size)
    }

    static func monoBold(_ size: CGFloat) -> Font {
        .custom("JetBrainsMono-Bold", size: size)
    }
}
