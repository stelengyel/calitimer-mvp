# Phase 1: App Layout & Navigation - Research

**Researched:** 2026-03-01
**Domain:** SwiftUI app structure, NavigationStack, custom slide-out drawer, brand theming, SwiftData scaffold
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Top-level navigation:** Home screen is the root/anchor — not a tab bar, not the session screen directly
- **Slide-out drawer (hamburger menu)** for secondary screens: History, Upload, Settings (3 items)
- **"Start Session" button on Home** launches the session view as a full-screen push with no tab bar or navigation chrome visible — maximizes screen real estate for Phase 2 camera feed
- **Session screen has a back/end button** to return to Home
- **Session screen shell:** Dark placeholder rectangle where the camera preview will live in Phase 2; placeholder Start/End session controls in the appropriate position
- **Upload screen layout:** Three-zone layout: (1) import action, (2) video player area, (3) results area; empty state shows prominent "Import Video" button; results area shows "Results will appear here" placeholder
- **History screen shell:** Empty state with icon and "No sessions yet" message
- **Settings screen shell:** Empty shell with screen title and an empty list (or "Settings coming soon" placeholder); no non-functional stub toggles
- **Drawer navigation model:** History and Upload open via NavigationStack push from the Home context (idiomatic iOS, allows nested navigation in each section later)
- **Brand from day one:** Background #0C0906, ember accent #FF6B2B, text-primary #FAF3EC, text-secondary #B8A090
- **JetBrains Mono as the primary font everywhere** (uniform mono aesthetic throughout the app)
- **Home screen:** Large ember gradient hero behind the Start Session button — full background treatment; app name "CaliTimer" over the hero; brand gradient: `linear-gradient(135deg, #FF6B2B 0%, #FFAA3B 50%, #FFD166 100%)`
- **SwiftData ModelContainer configured at app root** — storage layer scaffold can be set up in Phase 1 even if empty

### Claude's Discretion

- Exact drawer animation style and overlay treatment
- Whether the session screen's back/end button is "End Session" text or a chevron
- Precise empty-state icon choices for History and Upload

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

## Summary

Phase 1 is a pure structural phase: create an Xcode project from scratch, wire the root navigation, build the five screen shells (Home, Session, History, Upload, Settings), implement a custom slide-out drawer, and apply full brand theming. No logic, no data, no permissions. Every decision is locked in CONTEXT.md and every API used is first-party SwiftUI on iOS 17+.

The navigation topology is non-standard: a single `NavigationStack` rooted at Home, with a custom overlay drawer that pushes History/Upload/Settings onto the stack. Session is also a NavigationStack push but presented differently (no chrome). This means there is exactly one `NavigationStack` in the hierarchy — the AppCoordinator owns the `NavigationPath` and all screens are `navigationDestination` targets on that single stack. The drawer is a `ZStack` overlay positioned outside the stack content, animated with `offset` + `withAnimation(.spring)`.

Brand application requires embedding JetBrains Mono font files in the bundle, declaring them in `Info.plist` under `UIAppFonts`, and using `Font.custom("JetBrainsMono-Regular", size:)`. SwiftUI's `Color` does not have a built-in hex initializer — a simple `Color(hex:)` extension is needed (one-time, ~10 lines). The ember gradient hero on Home is a `LinearGradient` in a `ZStack` behind the content.

**Primary recommendation:** One `NavigationStack` + `NavigationPath` at the app root, custom `ZStack` drawer overlay with spring animation, JetBrains Mono loaded via `UIAppFonts`, brand colors as `Color` static extensions, SwiftData `ModelContainer` scaffolded empty at launch.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ | All UI, navigation, layout | Project commitment — @Observable, NavigationStack, all modern APIs available |
| Swift / Swift 6 | Xcode 16+ | Language | Required for strict concurrency used in later phases |
| SwiftData | iOS 17+ | Model persistence scaffold | Committed at app root now so later phases just add @Model classes |
| Foundation | iOS 17+ | Color hex math, file paths | Built-in |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| JetBrains Mono (font files) | 2.x (any recent) | Primary app font | Embedded in bundle; referenced via UIAppFonts in Info.plist |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom ZStack drawer | `NavigationSplitView` | NavigationSplitView is iPad-optimized; on iPhone it collapses to a stack — fighting the framework for a custom drawer look; ZStack gives full control |
| Custom ZStack drawer | TabView | User decided against tab bar — tabs are always visible, wrong for this app's hierarchy |
| Single NavigationStack + NavigationPath | Per-screen NavigationStack | Nested stacks cause unpredictable back-button behavior and make programmatic navigation impossible |

**Installation:** No external packages. All dependencies are first-party Apple frameworks. JetBrains Mono font files are added directly to the Xcode target (drag into project navigator, check "Add to target").

---

## Architecture Patterns

### Recommended Project Structure

The ARCHITECTURE.md already specifies this layout. Phase 1 creates the skeleton:

```
CaliTimer/
├── App/
│   ├── CaliTimerApp.swift        # App entry, ModelContainer, font setup
│   └── AppCoordinator.swift      # @Observable root navigation state + drawer state
├── UI/
│   ├── Home/
│   │   └── HomeView.swift        # Ember gradient hero + Start Session button
│   ├── LiveSession/
│   │   └── LiveSessionView.swift # Dark rect placeholder + back/end button
│   ├── History/
│   │   └── HistoryView.swift     # Empty state: icon + "No sessions yet"
│   ├── Upload/
│   │   └── UploadModeView.swift  # Three-zone shell: import / player / results
│   ├── Settings/
│   │   └── SettingsView.swift    # Title + "Settings coming soon" placeholder
│   └── Shared/
│       ├── DrawerView.swift      # Slide-out drawer overlay component
│       ├── BrandColors.swift     # Color static extensions (#0C0906, etc.)
│       └── BrandFonts.swift      # Font.custom("JetBrainsMono-*") helpers
└── Storage/
    └── Models/
        ├── Session.swift         # Empty @Model scaffold (no properties yet)
        ├── Hold.swift            # Empty @Model scaffold
        └── SkillPersonalBest.swift  # Empty @Model scaffold
```

Phase 1 does NOT create Camera/, Pose/, or Session/ (logic) folders — those belong to Phase 2 and later.

### Pattern 1: AppCoordinator — Single Navigation Source of Truth

**What:** An `@Observable @MainActor` class owns the entire app's navigation state: the `NavigationPath` for the stack and a `Bool` for drawer open/closed. All screens read and write through this coordinator. No screen manages its own navigation.

**When to use:** Always — this is the established pattern from ARCHITECTURE.md. The coordinator is also the Phase 2 hook point for `SessionCoordinator`.

**Example:**
```swift
// Source: ARCHITECTURE.md pattern + Apple NavigationStack docs
@Observable
@MainActor
final class AppCoordinator {
    var path = NavigationPath()
    var isDrawerOpen = false

    enum Destination: Hashable {
        case history
        case upload
        case settings
        case liveSession
    }

    func navigate(to destination: Destination) {
        isDrawerOpen = false
        path.append(destination)
    }

    func popToRoot() {
        path.removeLast(path.count)
    }
}
```

### Pattern 2: Root NavigationStack with navigationDestination

**What:** One `NavigationStack(path:)` at the app root. All screens are declared as `navigationDestination(for: AppCoordinator.Destination.self)`. The drawer calls `coordinator.navigate(to:)` which appends to the path.

**When to use:** This is the only correct pattern. Multiple stacks or per-screen stacks will break in Phase 2 when the session needs to control dismissal programmatically.

**Example:**
```swift
// Source: Apple NavigationStack documentation
@main
struct CaliTimerApp: App {
    @State private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $coordinator.path) {
                HomeView()
                    .navigationDestination(for: AppCoordinator.Destination.self) { dest in
                        switch dest {
                        case .history:    HistoryView()
                        case .upload:     UploadModeView()
                        case .settings:   SettingsView()
                        case .liveSession: LiveSessionView()
                        }
                    }
                    .environment(coordinator)
            }
            .overlay(
                DrawerView()
                    .environment(coordinator),
                alignment: .leading
            )
        }
        .modelContainer(for: [Session.self, Hold.self, SkillPersonalBest.self])
    }
}
```

### Pattern 3: Custom Slide-Out Drawer (ZStack Overlay)

**What:** The drawer is a `View` containing the three navigation items, rendered as a leading overlay on the `NavigationStack`. It is animated with `offset(x:)` and a dimming overlay behind it. Spring animation matches iOS system feel.

**When to use:** Whenever `coordinator.isDrawerOpen == true`. The hamburger button on HomeView (and potentially other screens) toggles this.

**Example:**
```swift
// Source: SwiftUI spring animation docs + common iOS drawer pattern
struct DrawerView: View {
    @Environment(AppCoordinator.self) private var coordinator
    private let drawerWidth: CGFloat = 260

    var body: some View {
        ZStack(alignment: .leading) {
            // Dim overlay — tapping outside closes drawer
            if coordinator.isDrawerOpen {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            coordinator.isDrawerOpen = false
                        }
                    }
            }

            // Drawer panel
            HStack {
                VStack(alignment: .leading, spacing: 32) {
                    DrawerItem(label: "History", icon: "clock") {
                        coordinator.navigate(to: .history)
                    }
                    DrawerItem(label: "Upload", icon: "square.and.arrow.up") {
                        coordinator.navigate(to: .upload)
                    }
                    DrawerItem(label: "Settings", icon: "gearshape") {
                        coordinator.navigate(to: .settings)
                    }
                    Spacer()
                }
                .padding(.top, 80)
                .padding(.horizontal, 24)
                .frame(width: drawerWidth)
                .background(Color.brandBackground)  // #0C0906
                Spacer()
            }
            .offset(x: coordinator.isDrawerOpen ? 0 : -drawerWidth)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: coordinator.isDrawerOpen)
        }
        .ignoresSafeArea()
    }
}
```

### Pattern 4: Brand Colors as Static Color Extensions

**What:** A single `BrandColors.swift` file defines all brand colors as `Color` static properties. This is the only place hex values appear in the codebase.

**When to use:** Every view uses these. No inline hex strings anywhere else.

**Example:**
```swift
// Source: Apple SwiftUI Color docs — Color(red:green:blue:) initializer
extension Color {
    // Hex convenience — SwiftUI has no built-in hex init
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static let brandBackground  = Color(hex: 0x0C0906)   // midnight
    static let brandEmber       = Color(hex: 0xFF6B2B)   // primary action
    static let brandAmber       = Color(hex: 0xFFAA3B)   // gradient mid
    static let brandGold        = Color(hex: 0xFFD166)   // gradient end
    static let textPrimary      = Color(hex: 0xFAF3EC)
    static let textSecondary    = Color(hex: 0xB8A090)
}
```

### Pattern 5: JetBrains Mono Font Registration

**What:** JetBrains Mono `.ttf` files are added to the Xcode target and declared in `Info.plist` under `UIAppFonts`. A `BrandFonts.swift` file provides typed `Font` helpers.

**When to use:** Everywhere a font is set. Dynamic Type scaling with `.relativeTo:` is optional — for a mono-aesthetic app, fixed sizes are acceptable.

**Example:**
```swift
// Info.plist entry (array of strings under UIAppFonts key):
// "JetBrainsMono-Regular.ttf"
// "JetBrainsMono-Bold.ttf"
// "JetBrainsMono-Italic.ttf"

// BrandFonts.swift
// Source: Apple "Applying custom fonts to text" documentation
extension Font {
    static func mono(_ size: CGFloat) -> Font {
        .custom("JetBrainsMono-Regular", size: size)
    }
    static func monoBold(_ size: CGFloat) -> Font {
        .custom("JetBrainsMono-Bold", size: size)
    }
}
```

PostScript name for JetBrains Mono is `JetBrainsMono-Regular` (verify in Font Book after embedding). Usage: `.font(.mono(16))`.

### Pattern 6: Ember Gradient Hero on Home

**What:** The Home screen background is a full-screen `LinearGradient` in a `ZStack`. The gradient uses the three brand colors matching the style guide specification.

**Example:**
```swift
struct HomeView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            // Full-screen midnight background base
            Color.brandBackground.ignoresSafeArea()

            // Ember gradient hero (fills upper portion or full screen)
            LinearGradient(
                colors: [.brandEmber, .brandAmber, .brandGold],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .opacity(0.15)  // subtle glow; Claude's discretion on exact opacity

            VStack {
                Text("CaliTimer")
                    .font(.monoBold(36))
                    .foregroundStyle(.textPrimary)

                Spacer()

                Button("Start Session") {
                    coordinator.navigate(to: .liveSession)
                }
                .font(.monoBold(18))
                .foregroundStyle(.brandBackground)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.brandEmber, .brandAmber, .brandGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        coordinator.isDrawerOpen = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.textPrimary)
                }
            }
        }
    }
}
```

### Pattern 7: Session Screen Shell — Full Screen, No Chrome

**What:** The LiveSession screen hides the navigation bar completely. It has a dark rectangle placeholder for the camera feed and a back/end button positioned in the view (not the nav bar).

**Example:**
```swift
struct LiveSessionView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ZStack {
            Color.brandBackground.ignoresSafeArea()

            VStack {
                // Dark camera preview placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.85))
                    .overlay(
                        Text("Camera feed coming in Phase 2")
                            .font(.mono(14))
                            .foregroundStyle(.textSecondary)
                    )
                    .padding()

                Spacer()

                // End session control placeholder
                Button("End Session") {
                    coordinator.popToRoot()
                }
                .font(.monoBold(16))
                .foregroundStyle(.brandEmber)
                .padding()
            }
        }
        .navigationBarHidden(true)  // full-screen, no chrome
    }
}
```

### Anti-Patterns to Avoid

- **Nested NavigationStacks:** Placing a second `NavigationStack` inside any destination view. This causes the back button to appear in wrong places and breaks programmatic path manipulation. One stack, at the root, always.
- **TabView as the root:** User decision is a drawer — do not reintroduce tabs. TabView always renders the tab bar regardless of `navigationBarHidden`.
- **Inline hex strings:** All color values must live in `BrandColors.swift`. No `Color(hex: 0xFF6B2B)` scattered across view files.
- **System fonts on any UI element:** JetBrains Mono is the stated preference for the entire app. No `.body`, `.headline`, or other system font shortcuts.
- **SwiftData model bodies in Phase 1:** The `@Model` classes are empty scaffolds. Do not add properties, relationships, or `@Query` usage in Phase 1 — that work belongs to Phase 6 and later.
- **Setting `navigationBarHidden` on the NavigationStack root:** Hide the nav bar only on the LiveSession screen, not globally. History, Upload, and Settings need visible back buttons.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drawer animation timing | Custom `CAAnimation` or timer-based offset | SwiftUI `withAnimation(.spring(...))` on `@State` Bool | Spring parameters are tunable; framework handles interruptions and velocity |
| Back navigation | Custom dismiss button that manipulates UIKit navigation controller | `coordinator.popToRoot()` or `.popLast()` on `NavigationPath` | NavigationPath is the source of truth; UIKit manipulation bypasses it and creates desynced state |
| Color hex parsing | Regex or string scanner | Simple bit-shift `Color(hex:)` extension (~10 lines) | Standard pattern; no library needed for 6 static colors |
| Font loading | Runtime `CTFontManager` registration | `UIAppFonts` in `Info.plist` | System handles registration before app finishes launching; no async ceremony required |

---

## Common Pitfalls

### Pitfall 1: Multiple NavigationStack Instances

**What goes wrong:** A second `NavigationStack` placed inside a destination view (e.g., HistoryView wrapping its own stack) creates a "nested navigation" situation. The back button appears twice, the path state is split, and `coordinator.popToRoot()` only clears the inner stack.

**Why it happens:** It feels natural to give each section its own stack for "independent navigation." SwiftUI does not prevent this but the behavior is incorrect on iPhone.

**How to avoid:** Every destination view is a plain `View` with no `NavigationStack` wrapper. Only `CaliTimerApp.swift` contains a `NavigationStack`.

**Warning signs:** Back button appears at both the top-left (system) and inside the view body. `coordinator.path.count` doesn't change when the inner back is tapped.

### Pitfall 2: JetBrains Mono PostScript Name Mismatch

**What goes wrong:** Font loads silently on nil and SwiftUI falls back to system font with no error. The app appears to work but uses San Francisco everywhere.

**Why it happens:** The PostScript name (used in `Font.custom(...)`) must exactly match the name registered in the system, which differs from the filename. Common confusion: `JetBrainsMono-Regular` vs `JetBrainsMono_Regular` vs `JetBrains Mono Regular`.

**How to avoid:** After adding the `.ttf` files to the target, open them in Font Book and read the PostScript name from the info panel. Use that exact string. Add a debug assertion in development:
```swift
// Debug check — remove before shipping
assert(UIFont(name: "JetBrainsMono-Regular", size: 12) != nil,
       "JetBrainsMono-Regular not found — check UIAppFonts in Info.plist")
```

**Warning signs:** Text in the app looks like the default system font (rounded, proportional spacing). `UIFont(name:size:)` returns nil for the PostScript name.

### Pitfall 3: NavigationBarHidden Leaking to Other Screens

**What goes wrong:** Setting `.navigationBarHidden(true)` on the `NavigationStack` root or on a view that pushes others causes the bar to remain hidden on subsequent pushed views even if they don't set it.

**Why it happens:** `navigationBarHidden` is inherited by the navigation stack in some iOS versions; toggling it is not reliably reversed.

**How to avoid:** Only set `.navigationBarHidden(true)` on `LiveSessionView`. All other screens rely on the default (shown) navigation bar. If the session screen needs to be completely chrome-free, use `.toolbar(.hidden, for: .navigationBar)` (iOS 16+) — more reliable than `navigationBarHidden`.

**Warning signs:** History or Upload screen missing its back button after returning from Session.

### Pitfall 4: Drawer Overlay Blocking NavigationStack Gesture

**What goes wrong:** The drawer's `Color.clear` or `Color.black.opacity(0)` overlay captures the edge-swipe-back gesture even when the drawer is closed.

**Why it happens:** If the full-screen dim overlay is always present in the view hierarchy (just transparent), it intercepts touch events including the system back swipe.

**How to avoid:** Only add the dim overlay to the view hierarchy when `coordinator.isDrawerOpen == true`. Use SwiftUI's `if coordinator.isDrawerOpen { ... }` — the view is removed from the hierarchy, not just made invisible.

**Warning signs:** Swipe-back from History/Upload doesn't work; the view snaps back instead of dismissing.

### Pitfall 5: SwiftData ModelContainer Failure Causing App Crash

**What goes wrong:** If the `@Model` classes have syntax errors or conflicting schema, `modelContainer(for:)` throws a fatal error and the app crashes on launch with no UI displayed.

**Why it happens:** SwiftData schema validation happens at runtime when the container is initialized. Empty `@Model` classes are valid, but any property type SwiftData can't store (e.g., an unannotated `AVAsset`) causes a fatal crash.

**How to avoid:** Phase 1 `@Model` scaffolds must be truly empty — just the class declaration with `@Model` and no stored properties. Add properties only in the phase that needs them.

**Warning signs:** App crashes immediately on launch with a SwiftData migration or schema error in the console.

---

## Code Examples

Verified patterns from official sources:

### NavigationStack with NavigationPath (Apple official)
```swift
// Source: https://developer.apple.com/documentation/SwiftUI/NavigationStack
NavigationStack(path: $coordinator.path) {
    HomeView()
        .navigationDestination(for: AppCoordinator.Destination.self) { destination in
            // switch on destination
        }
}
```

### Custom Font Application (Apple official)
```swift
// Source: https://developer.apple.com/documentation/SwiftUI/applying-custom-fonts-to-text
Text("CaliTimer")
    .font(.custom("JetBrainsMono-Bold", size: 36))
```

### Spring Animation on State Toggle (Apple official)
```swift
// Source: https://developer.apple.com/documentation/SwiftUI/Animation/spring(response:dampingFraction:blendDuration:)
withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
    coordinator.isDrawerOpen.toggle()
}
```

### Toolbar Hidden (iOS 16+ preferred over navigationBarHidden)
```swift
// Source: Apple SwiftUI toolbar documentation
.toolbar(.hidden, for: .navigationBar)
```

### Empty SwiftData @Model Scaffold
```swift
// Source: SwiftData documentation — @Model requires no properties to be valid
import SwiftData

@Model
final class Session {
    // Properties added in Phase 6
}

@Model
final class Hold {
    // Properties added in Phase 6
}

@Model
final class SkillPersonalBest {
    // Properties added in Phase 6
}
```

### ModelContainer at App Root
```swift
// Source: SwiftData documentation
@main
struct CaliTimerApp: App {
    var body: some Scene {
        WindowGroup {
            // ...
        }
        .modelContainer(for: [Session.self, Hold.self, SkillPersonalBest.self])
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NavigationView` + `NavigationLink(isActive:)` | `NavigationStack(path:)` + `navigationDestination(for:)` | iOS 16 (WWDC22) | Programmatic navigation is now reliable; deprecated API still compiles but shows warnings |
| `@ObservedObject` / `ObservableObject` | `@Observable` macro | iOS 17 (WWDC23) | Less boilerplate; per-property granular re-rendering; no `@Published` needed |
| `UIAppDelegate` font registration | `UIAppFonts` in `Info.plist` | Long-standing; preferred pattern | Fonts available before any app code runs |
| `navigationBarHidden(_:)` | `.toolbar(.hidden, for: .navigationBar)` | iOS 16 | More explicit, less likely to leak to other screens |

**Deprecated/outdated:**
- `NavigationView`: deprecated iOS 16; do not use
- `NavigationLink(isActive:)` and `NavigationLink(tag:selection:)`: deprecated iOS 16; do not use
- `@Published` + `ObservableObject`: not deprecated but superseded by `@Observable` for iOS 17+ targets

---

## Open Questions

1. **JetBrains Mono exact PostScript names**
   - What we know: The font family is "JetBrains Mono"; typical PostScript names follow `JetBrainsMono-Regular` / `JetBrainsMono-Bold` pattern
   - What's unclear: Exact PostScript names depend on the specific version of the font files obtained from jetbrains.com; must be verified after embedding
   - Recommendation: After adding font files to the Xcode target, verify with `UIFont.familyNames` debug print or Font Book before writing `BrandFonts.swift`

2. **Drawer edge-swipe conflict resolution**
   - What we know: SwiftUI's `NavigationStack` uses a screen-edge pan gesture for back navigation
   - What's unclear: Whether adding a `DragGesture` to open the drawer from the left edge will conflict with the system back gesture on screens pushed onto the stack
   - Recommendation: Do not add drag-to-open for Phase 1; hamburger button tap is sufficient; revisit in a polish phase if needed

3. **Home screen gradient intensity**
   - What we know: Style guide specifies `linear-gradient(135deg, #FF6B2B 0%, #FFAA3B 50%, #FFD166 100%)` as a full background; CONTEXT.md says "similar to the style guide landing page feel"
   - What's unclear: Whether the hero gradient should be full-opacity covering the midnight background, or a glow/overlay at reduced opacity — this is Claude's discretion
   - Recommendation: Implement as a full-screen gradient overlay at ~15% opacity over the midnight base for a subtle glow; increase the Start Session button's gradient to full opacity for contrast

---

## Sources

### Primary (HIGH confidence)
- `/websites/developer_apple_swiftui` (Context7) — NavigationStack path binding, navigationDestination, spring animation, custom font APIs
- Apple Developer Documentation: [NavigationStack](https://developer.apple.com/documentation/SwiftUI/NavigationStack) — path, navigationDestination, programmatic navigation
- Apple Developer Documentation: [Applying custom fonts to text](https://developer.apple.com/documentation/SwiftUI/applying-custom-fonts-to-text) — UIAppFonts, Font.custom()
- Apple Developer Documentation: [Animation.spring](https://developer.apple.com/documentation/SwiftUI/Animation/spring(response:dampingFraction:blendDuration:)) — spring parameters
- `.planning/research/ARCHITECTURE.md` — established project structure, AppCoordinator pattern, component boundaries
- `.planning/research/STACK.md` — SwiftData @Model patterns, SwiftUI as root, UIViewRepresentable scope

### Secondary (MEDIUM confidence)
- `.planning/phases/01-app-layout-navigation/01-CONTEXT.md` — locked user decisions (authoritative for this phase)

### Tertiary (LOW confidence)
- None — all critical claims verified against official Apple documentation or project planning docs

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all first-party Apple frameworks, established in STACK.md
- Architecture: HIGH — NavigationStack + NavigationPath is official Apple pattern; drawer pattern is idiomatic SwiftUI using documented primitives
- Pitfalls: HIGH — navigation bar leakage and nested stack issues are documented Apple behavior; font name mismatch is a common and verifiable failure mode

**Research date:** 2026-03-01
**Valid until:** 2026-06-01 (stable APIs; SwiftUI navigation and SwiftData APIs are not fast-moving)
