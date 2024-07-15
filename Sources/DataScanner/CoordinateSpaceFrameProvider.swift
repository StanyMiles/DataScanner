import SwiftUI

struct CoordinateSpaceFrameProvider: ViewModifier {
  let coordinateSpace: CoordinateSpace
  @Binding var frame: CGRect
  
  @ViewBuilder
  func body(content: Content) -> some View {
    content
      .background(
        GeometryReader { geo in
          Color.clear.onAppear {
            frame = geo.frame(in: coordinateSpace)
          }
        }
      )
  }
}

extension View {
  func get(
    frame: Binding<CGRect>,
    in coordinateSpace: CoordinateSpace
  ) -> some View {
    modifier(CoordinateSpaceFrameProvider(
      coordinateSpace: coordinateSpace,
      frame: frame
    ))
  }
}
