enum Theme: CaseIterable, Equatable {
    case trueBgRegularFront
    case regularBgRegularFront
    case transparentBgRegularFront

    func next() -> Theme {
        let all = Self.allCases
        let currentIndex = all.firstIndex(of: self)!
        let nextIndex = (currentIndex + 1) % all.count
        return all[nextIndex]
    }
}
