# Hearthside Solitaire — knusse Klondike met dorp-verduurzaming (iOS, Swift)

## Doel
Klassieke Klondike-solitaire voor iPhone. Gewonnen rondes leveren "warmte" op waarmee de speler
oude huisjes verduurzaamt (energielabel G → A). Verdienmodel: interstitials tussen rondes,
rewarded ads, Remove Ads, Hearthside Club-abonnement. Zie docs/PLAN.md.

## Stack
Swift 6, SwiftUI, SpriteKit, iOS 17+, XcodeGen, gedeeld package GameServices (ads, consent,
aankopen, analytics, config, opslag), StoreKit 2, Firebase, GameKit, CloudKit (iCloud KVS), SwiftLint.

## Structuur
```
project.yml                 # XcodeGen
Hearthside/
    App/                    # app, routing, AppModel, thema, instellingen, config-sleutels
    Table/                  # SpriteKit: speeltafel, kaarten, drag/tap, animaties, GameController
    Village/                # SwiftUI: dorp, huisjes, maatregelen, labels
    Features/               # Home, DailyChallenge, Stats, Shop, Settings (+ Debug-menu)
    Services/               # geluid, haptics, Game Center, SDK-adapters (Google Ads/UMP/Firebase)
    Resources/              # Assets, Localizable.xcstrings, deals/, sounds/, Fonts/, .storekit
HearthsideTests/            # app-tests (layout, bundle-resources)
Packages/HearthsideCore/    # kaartmodel, Klondike-regels, solver, deal-generator, warmte-economie (pure Swift)
Packages/GameServices/      # gedeeld met Sweet Arrows (geen externe dependencies)
Tools/DealGen/              # CLI: swift run -c release dealgen
Tools/*.py                  # make_strings.py, check_strings.py, make_sounds.py, make_icon.py
```

## Regels
- Spelregels, solver en economie in HearthsideCore, 90%+ testdekking; geen UI-code daarin.
- Elke zet < 16 ms; geen haperingen bij slepen. Onbeperkt undo, auto-complete, hervatten na afsluiten.
- Kaarten altijd goed leesbaar: minimaal standaard + extra groot, hoog contrast mogelijk.
- Advertenties alleen tussen rondes, via AdService; grenzen uit Remote Config. Nooit tijdens een spel.
  Geen banner op de speeltafel.
- Geen gok-economie, geen tijdsdruk, geen echt geld. "Vegas" alleen als puntentelling.
- Alle tekst via Localizable.xcstrings. Nieuwe sleutels toevoegen in `Tools/make_strings.py`,
  daarna `python3 Tools/make_strings.py && python3 Tools/check_strings.py`.
- GameServices blijft game-agnostisch: geen Hearthside-types, geen externe SDK's (adapters horen in de app).
- Na elke wijziging: `xcodegen generate`; `xcodebuild test` moet slagen; SwiftLint zonder fouten.
- Packages kunnen ook los: `cd Packages/HearthsideCore && swift test` (draait ook op Linux/CI).
- Deals opnieuw genereren: `cd Tools/DealGen && swift run -c release dealgen --count 10000`
  (schrijft naar `Hearthside/Resources/deals/`, ~13 min per modus).
