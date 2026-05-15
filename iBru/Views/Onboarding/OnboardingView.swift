import SwiftUI
import SwiftData

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var showingBabyForm = false
    @Query(filter: #Predicate<Baby> { $0.isActive == true }, sort: \Baby.name) private var babies: [Baby]

    private struct Page {
        let symbol: String
        let title: LocalizedStringKey
        let body: LocalizedStringKey
        let isInteractive: Bool
    }

    private let pages: [Page] = [
        Page(symbol: "heart.text.square.fill",
             title: "Welcome to iBru",
             body: "The health companion for your whole family.",
             isInteractive: false),
        Page(symbol: "pills.fill",
             title: "Track Medications",
             body: "Set up schedules for every medicine. Log doses with a tap and never miss one.",
             isInteractive: false),
        Page(symbol: "figure.and.child.holdinghands",
             title: "Meet Your Baby",
             body: "Create a profile and all of iBru's features will be personalised to them.",
             isInteractive: true),
        Page(symbol: "pills.circle.fill",
             title: "Quick Dose",
             body: "Need to give medicine right now? Quick Dose lets you log it in seconds — no schedule needed.",
             isInteractive: false),
        Page(symbol: "stethoscope",
             title: "Health Records",
             body: "Track illnesses, vaccines, growth measurements, and temperatures — all in one place.",
             isInteractive: false),
        Page(symbol: "note.text",
             title: "Daily Notes",
             body: "Write observations for any day — milestones, feeding notes, anything worth remembering. Find them in the Notes tab of Records.",
             isInteractive: false),
        Page(symbol: "chart.xyaxis.line",
             title: "Understand the Patterns",
             body: "Insights show trends in medications, illnesses, and growth over time.",
             isInteractive: false),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.08), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $currentPage) {
                    pageContent(pages[0]).tag(0)
                    pageContent(pages[1]).tag(1)
                    pageContent(pages[2]).tag(2)
                    pageContent(pages[3]).tag(3)
                    pageContent(pages[4]).tag(4)
                    pageContent(pages[5]).tag(5)
                    pageContent(pages[6]).tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showingBabyForm) {
            BabyFormView()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            dotsIndicator
            Spacer()
            Button("Skip") { onComplete() }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var dotsIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { index in
                Circle()
                    .fill(index <= currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - Page content

    private func pageContent(_ page: Page) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: page.symbol)
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if page.isInteractive {
                babyProfileButton
                    .padding(.top, 4)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Interactive baby creation (page 2)

    private var babyProfileButton: some View {
        let hasProfile = !babies.isEmpty
        return Button {
            showingBabyForm = true
        } label: {
            Label(
                hasProfile ? "Profile Added" : "Create Profile",
                systemImage: hasProfile ? "checkmark.circle.fill" : "plus.circle.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(hasProfile ? .green : .accentColor)
        .disabled(hasProfile)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        let isLast = currentPage == pages.count - 1
        return Button(isLast ? "Get Started" : "Next") {
            if isLast {
                onComplete()
            } else {
                withAnimation { currentPage += 1 }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OnboardingView { }
        .modelContainer(previewContainer)
}
