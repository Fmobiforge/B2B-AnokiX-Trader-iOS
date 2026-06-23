import SwiftUI

private struct ViewportFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

extension View {
    /// Updates `isVisible` when this view intersects the on-screen viewport.
    /// Use on inline video layers inside `ScrollView` so they detach when scrolled away.
    func trackViewportVisibility(_ isVisible: Binding<Bool>) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: ViewportFrameKey.self,
                                       value: geo.frame(in: .global))
            }
        )
        .onPreferenceChange(ViewportFrameKey.self) { frame in
            let screen = UIScreen.main.bounds
            let visible = frame.maxY > screen.minY + 48 && frame.minY < screen.maxY - 16
            if isVisible.wrappedValue != visible {
                isVisible.wrappedValue = visible
            }
        }
    }
}
