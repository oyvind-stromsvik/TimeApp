import SwiftUI
import AppKit

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { hovering in
            if hovering { cursor.push() } else { NSCursor.pop() }
        }
    }
}
