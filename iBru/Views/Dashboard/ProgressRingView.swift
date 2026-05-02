import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    let isOverdue: Bool
    var size: CGFloat = 56

    private var ringColor: Color {
        if isOverdue { return .orange }
        if progress >= 1.0 { return .green }
        return .blue
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.15), lineWidth: 6)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)

            if progress >= 1.0 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(ringColor)
            } else {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.22, weight: .semibold, design: .rounded))
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        ProgressRingView(progress: 0.0, isOverdue: false)
        ProgressRingView(progress: 0.5, isOverdue: false)
        ProgressRingView(progress: 0.75, isOverdue: true)
        ProgressRingView(progress: 1.0, isOverdue: false)
    }
    .padding()
}
