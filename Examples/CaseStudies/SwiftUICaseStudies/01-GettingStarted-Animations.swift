import ComposableArchitecture
import ReactiveSwift
import SwiftUI

private let readMe = """
  This screen demonstrates how changes to application state can drive animations. Because the \
  `Store` processes actions sent to it synchronously you can typically perform animations \
  in the Composable Architecture just as you would in regular SwiftUI.

  To animate the changes made to state when an action is sent to the store you can pass along an \
  explicit animation, as well, or you can call `viewStore.send` in a `withAnimation` block.

  To animate changes made to state through a binding, use the `.animation` method on `Binding`.

  To animate asynchronous changes made to state via effects, use the `.animation` method provided \
  by the CombineSchedulers library to receive asynchronous actions in an animated fashion.

  Try it out by tapping or dragging anywhere on the screen to move the dot, and by flipping the \
  toggle at the bottom of the screen.
  """

extension Effect where Error == Never {
  public static func keyFrames(
    values: [(output: Value, duration: TimeInterval)],
    scheduler: DateScheduler
  ) -> Effect {
    .concatenate(
      values
        .enumerated()
        .map { index, animationState in
          index == 0
            ? Effect(value: animationState.output)
            : Effect(value: animationState.output)
              .delay(values[index - 1].duration, on: scheduler)
        }
    )
  }
}

struct AnimationsState: Equatable {
  var circleCenter = CGPoint.zero
  var circleColor = Color.white
  var isCircleScaled = false
}

enum AnimationsAction: Equatable {
  case circleScaleToggleChanged(Bool)
  case rainbowButtonTapped
  case setColor(Color)
  case tapped(CGPoint)
}

struct AnimationsEnvironment {
  var mainQueue: DateScheduler
}

let animationsReducer = Reducer<AnimationsState, AnimationsAction, AnimationsEnvironment> {
  state, action, environment in

  switch action {
  case let .circleScaleToggleChanged(isScaled):
    state.isCircleScaled = isScaled
    return .none

  case .rainbowButtonTapped:
    return .keyFrames(
      values: [Color.red, .blue, .green, .orange, .pink, .purple, .yellow, .white]
        .map { (output: .setColor($0), duration: 1) },
      scheduler: environment.mainQueue.animation(.linear)
    )

  case let .setColor(color):
    state.circleColor = color
    return .none

  case let .tapped(point):
    state.circleCenter = point
    return .none
  }
}

struct AnimationsView: View {
  @Environment(\.colorScheme) var colorScheme
  let store: Store<AnimationsState, AnimationsAction>

  var body: some View {
    GeometryReader { proxy in
      WithViewStore(self.store) { viewStore in
        VStack(alignment: .leading) {
          ZStack(alignment: .center) {
            Text(template: readMe, .body)
              .padding()

            Circle()
              .fill(viewStore.circleColor)
              .blendMode(.difference)
              .frame(width: 50, height: 50)
              .scaleEffect(viewStore.isCircleScaled ? 2 : 1)
              .offset(
                x: viewStore.circleCenter.x - proxy.size.width / 2,
                y: viewStore.circleCenter.y - proxy.size.height / 2
              )
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(self.colorScheme == .dark ? Color.black : .white)
          .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { gesture in
              viewStore.send(
                .tapped(gesture.location),
                animation: .interactiveSpring(response: 0.25, dampingFraction: 0.1)
              )
            }
          )
          Toggle(
            "Big mode",
            isOn:
              viewStore
              .binding(get: \.isCircleScaled, send: AnimationsAction.circleScaleToggleChanged)
              .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.1))
          )
          .padding()
          Button("Rainbow") { viewStore.send(.rainbowButtonTapped, animation: .linear) }
            .padding([.leading, .trailing, .bottom])
        }
      }
    }
  }
}

struct AnimationsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        AnimationsView(
          store: Store(
            initialState: AnimationsState(circleCenter: CGPoint(x: 50, y: 50)),
            reducer: animationsReducer,
            environment: AnimationsEnvironment(
              mainQueue: QueueScheduler.main
            )
          )
        )
      }

      NavigationView {
        AnimationsView(
          store: Store(
            initialState: AnimationsState(circleCenter: CGPoint(x: 50, y: 50)),
            reducer: animationsReducer,
            environment: AnimationsEnvironment(
              mainQueue: QueueScheduler.main
            )
          )
        )
      }
      .environment(\.colorScheme, .dark)
    }
  }
}
