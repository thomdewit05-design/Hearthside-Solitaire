# Hearthside: Solitaire & Home

Knusse klassieke Klondike-solitaire voor iPhone en iPad. Gewonnen spellen leveren **warmte** op, en daarmee
verduurzaam je de huisjes in een dorp, van energielabel **G naar A**. Zie [`docs/PLAN.md`](docs/PLAN.md) voor het
volledige bouwplan en [`CLAUDE.md`](CLAUDE.md) voor de werkafspraken.

## Snel starten

```bash
brew install xcodegen swiftlint
```

```bash
xcodegen generate
```

```bash
open Hearthside.xcodeproj
```

Daarna in Xcode:
1. Vul je **Team ID** in (`DEVELOPMENT_TEAM` in `project.yml`, of in Signing & Capabilities) en pas de
   bundle-ID aan (`com.<jouwstudio>.hearthside`).
2. Zet **`GoogleService-Info.plist`** van je Firebase-project in `Hearthside/` (staat in `.gitignore`).
   Zonder dat bestand start de app gewoon, alleen zonder Firebase.
3. Vervang voor release het **AdMob app-ID** (`GADApplicationIdentifier` in `project.yml`) en de ad unit-ID's in
   `Hearthside/App/AppConfig.swift`. Debug-builds gebruiken altijd Google's test-advertenties.
4. Run het `Hearthside`-scheme. Aankopen werken in de simulator via `Hearthside/Resources/Hearthside.storekit`.

De pure-Swift-onderdelen kun je los testen, ook zonder Xcode (macOS of Linux):

```bash
swift test --package-path Packages/HearthsideCore
```

```bash
swift test --package-path Packages/GameServices
```

## Wat er staat

| Onderdeel | Waar | Status |
|---|---|---|
| Kaartmodel, Klondike-regels (1/3 trekken, standaard/Vegas-punten, onbeperkt undo, auto-complete, tik-naar-beste-plek, slepen, hervatten) | `Packages/HearthsideCore/Sources/HearthsideCore/Klondike` | ✅ getest |
| Solver (DFS + transpositietabel + talon-macrozetten + veilige auto-zetten), hints uit dezelfde solver | `…/Solver/KlondikeSolver.swift` | ✅ getest: elke oplossing wordt teruggespeeld tot winst |
| DealGen-CLI + **2 × 10.000 winbare deals** (makkelijk/normaal/moeilijk) | `Tools/DealGen`, `Hearthside/Resources/deals` | ✅ zie [`docs/DEALGEN_REPORT.md`](docs/DEALGEN_REPORT.md) |
| Warmte-economie, 8 huisjes met 6–8 maatregelen, labels G→A(++), bonus voor slimme volgorde (trias energetica) | `…/Economy` | ✅ getest |
| Dagelijkse uitdaging + kalender + maand-decoraties, 7-dagen-beloning, winreeks, statistieken, cosmetica, iCloud-merge | `…/Progress` | ✅ getest |
| GameServices: AdService + AdPolicy (vanaf ronde 4, ≥3 min, niet na rewarded, nooit tijdens spel, max 15 rewarded/dag), ConfigService, AnalyticsService, SaveService (lokaal + iCloud KVS), PurchaseService (StoreKit 2), ConsentService | `Packages/GameServices` | ✅ getest (logica); StoreKit-pad alleen op Apple-platformen |
| SDK-adapters Google Mobile Ads 12 / UMP 3 / Firebase 11 | `Hearthside/Services/SDKAdapters.swift` | ⚠️ nog niet gecompileerd tegen de echte SDK's |
| SpriteKit-speeltafel: houten tafel, flakkerend haardvuur, vonkjes, kaartanimaties, tik + slepen, hints, overwinningsanimatie | `Hearthside/Table` | ⚠️ nog niet gebouwd in Xcode |
| SwiftUI: Home, dorp met huisjes die zichtbaar warmer worden, huisdetail, dagelijkse uitdaging, statistieken, winkel (incl. `SubscriptionStoreView`), instellingen, debugmenu | `Hearthside/App`, `Village`, `Features` | ⚠️ nog niet gebouwd in Xcode |
| Toegankelijkheid: extra grote kaarten, hoog contrast, linkshandige indeling, VoiceOver per kaart ("harten zeven") | Table + Settings | ⚠️ testen op toestel |
| NL + EN (258 sleutels), Nunito (OFL), eigen gesynthetiseerde geluiden (CC0), app-icoon, privacy-manifest, StoreKit-config | `Hearthside/Resources`, `Tools/*.py` | ✅ |

**Testdekking HearthsideCore:** 62 tests, 97,8% van de regels.

## Belangrijk om te weten

- **Deze code is geschreven in een Linux-omgeving.** De packages (`HearthsideCore`, `GameServices`, `DealGen`)
  zijn daar gebouwd en getest met Swift 6.0. De iOS-app zelf (SwiftUI/SpriteKit/UIKit) kon daar niet
  gecompileerd worden. Verwacht bij de eerste `xcodebuild` een handvol compileerfouten die snel op te lossen zijn,
  vooral in `SDKAdapters.swift` (API-namen van de Google/Firebase-SDK's) en rond Swift 6-concurrency.
- **Sweet Arrows-services:** het plan zegt de services uit de Sweet Arrows-repo te halen. Die repo was hier niet
  beschikbaar, dus `GameServices` is opnieuw opgebouwd met dezelfde namen (`AdService`, `ConsentService`,
  `PurchaseService`, `AnalyticsService`, `ConfigService`, `SaveService`) en zonder game-specifieke code. Vergelijk
  het met de Sweet Arrows-versie en voeg samen wat daar beter is.
- **"Niet winbaar":** de solver doorzoekt geen foundation→tableau-zetten. "Winbaar" is dus altijd een bewijs;
  "geen oplossing gevonden" betekent niet 100% zeker onwinbaar. Voor de deal-pools maakt dat niet uit.

## Handige scripts

| Script | Doel |
|---|---|
| `cd Tools/DealGen && swift run -c release dealgen --count 10000` | Winbare deals opnieuw genereren (~13 min per modus) |
| `python3 Tools/make_strings.py` | `Localizable.xcstrings` opbouwen uit de vertaaltabel |
| `python3 Tools/check_strings.py` | Controleren dat elke sleutel in de code vertaald is |
| `python3 Tools/make_sounds.py` | Geluidseffecten opnieuw synthetiseren |
| `python3 Tools/make_icon.py` | App-icoon opnieuw tekenen (vereist Pillow) |

## Nog te doen (zie checklist in docs/PLAN.md)

- Eerste build in Xcode 16+ en compileerfouten oplossen; 60 fps meten met Instruments op een iPhone 11.
- App Store Connect: producten (`com.hearthside.*`), Game Center-leaderboard `hearthside.daily.time` (laag = beter)
  en de zeven achievements uit `AppConfig.swift` aanmaken.
- Firebase-project, AdMob-account, `app-ads.txt`, privacybeleid op hearthsidegame.com.
- Fase 7: DE/FR/ES/IT toevoegen (kolommen in `Tools/make_strings.py`), testen op iPhone SE t/m Pro Max en iPad,
  TestFlight.
- Naam en merk checken (App Store, EUIPO, BOIP), testspelers van 40+.
