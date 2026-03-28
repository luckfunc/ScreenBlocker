import SwiftUI

struct ContentView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("ClaudeIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(rotation))
                    .onAppear {
                        withAnimation(
                            .linear(duration: 8)
                            .repeatForever(autoreverses: false)
                        ) {
                            rotation = 360
                        }
                    }

                Text("Claude")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.47, blue: 0.34),
                                Color(red: 0.95, green: 0.65, blue: 0.45)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 400, height: 300)
}
