# Bouwplan game-idee 2: Hearthside Solitaire

*14 november 2026*

## Waarom dit idee

Klassieke solitaire is een van de meest gespeelde en meest advertentie-gedreven genres in de App Store,
met een ouder publiek dat lang speelt en veel opbrengt per vertoning. Het is ook een goede tweede game
náást Sweet Arrows: een ander publiek, andere zoekwoorden, en de techniek kun je grotendeels hergebruiken.

| Feit | Waarom het telt | Bron |
|---|---|---|
| MobilityWare Solitaire: ca. 3,2 mln maandelijkse spelers, ca. 73% van de omzet uit advertenties | Het grootste klassieke solitaire-spel draait vooral op advertenties | AppGoblin |
| Kleinere solitaire-apps van 1–2 jaar oud halen 1,9–4,7 mln installs en $10K+ per maand, voor 56–59% uit advertenties | Er is ruimte naast de grote namen | AppGoblin |
| Solitaire haalde in 2024 een record van 348 mln downloads | Grote, stabiele vraag | PocketGamer.biz |
| Board-, solitaire- en woordspellen hebben een hoger aandeel advertentie-inkomsten dan in-app aankopen | Past bij ons verdienmodel | Tenjin |
| Eind 2025 zorgden nieuwe solitaire-hybrides (bijv. Solitaire Associations Journey, ca. 7 mln downloads in december) voor een nieuwe solitaire-golf | Het genre leeft weer | Mobidictum |

**Waarom niet het "level-solitaire"-model** (zoals Solitaire Grand Harvest of Disney Solitaire)? Die games zijn
eigenlijk levelpuzzels met een gok-economie en draaien vooral op aankopen. Grote studio's domineren dat segment.
Voor een solo-maker met een advertentiemodel is klassieke solitaire met een lichte, eigen meta-laag de betere gok.

**Het risico:** de zoekterm "Solitaire" is extreem druk. Je wint dus niet op de spelregels, maar op kwaliteit
(snel, rustig, mooi, weinig storende advertenties) en op een herkenbare eigen draai.

## Concept & onderscheid

Hearthside Solitaire is klassieke Klondike-solitaire met een rustige meta-laag: met elke gewonnen ronde verdien je
"warmte", en daarmee knap je tochtige oude huisjes in een dorp op tot warme, energiezuinige thuizen. Isolatie,
nieuwe ramen, een warmtepomp, zonnepanelen: elk huisje stijgt van energielabel G naar A, en het dorp kleurt mee
van grijs en koud naar warm en verlicht.

- **Waarom deze draai:** huis-decoreren is in solitaire al gedaan en overvol. Verduurzamen is nieuw, voelt zinvol,
  en geeft een duidelijk voortgangsgevoel (een label dat stijgt).
- **Doelgroep:** 35–70 jaar, speelt dagelijks 20–60 minuten, vaak 's avonds. VS, Canada, VK, Duitsland, Nederland.
- **Gevoel:** knus en rustig. Haardvuur, wollen dekens, warme lampjes in de ramen, regen buiten.

| | Gewone solitaire-apps | Level-solitaire | Hearthside Solitaire |
|---|---|---|---|
| Spel | Klassieke Klondike | TriPeaks-achtige levels | Klassieke Klondike (+ Spider, FreeCell later) |
| Voortgang | Statistieken, thema's | Saga-kaart, gok-economie | Dorp verduurzamen, huisjes van label G naar A |
| Verdienmodel | Vooral advertenties | Vooral aankopen | Vooral advertenties, plus Remove Ads en VIP |
| Sfeer | Groen vilt, standaard | Druk, kleurrijk | Knus, warm, rustig |
| Advertenties | Vaak opdringerig | Minder | Weinig en voorspelbaar; nooit midden in een spel |

**Wat we níet doen:** geen gok-economie of inzetten, geen tijdsdruk, geen verhaal met drama, geen
echt-geld-solitaire. Geen namen, iconen of stijlen die op MobilityWare, Microsoft Solitaire, Grand Harvest of
Disney Solitaire lijken.

## Merk & thema

- **Store-naam:** "Hearthside: Solitaire & Home" (28 tekens). **Ondertitel:** "Cozy Klondike card game".
- **Bundle-ID:** `com.<jouwstudio>.hearthside`; domein bijv. hearthsidegame.com.
- **Check:** App Store, domein, EUIPO- en BOIP-register.

**Visuele stijl**
- Kaarten: groot, crisp en goed leesbaar, warme crème kaartkleur. Keuze uit standaard en extra groot.
- Tafel: geen groen vilt, maar een houten tafel bij de haard, met een licht flakkerend vuur aan de rand.
- Dorp: hand-getekende illustratiestijl, licht isometrisch. Huisjes worden zichtbaar warmer: rook uit de
  schoorsteen verdwijnt, lampjes gaan aan, zonnepanelen verschijnen, sneeuw blijft op geïsoleerde daken liggen.
- Kleurenpalet: haardrood `#C8553D`, honing `#F2A541`, dennengroen `#3F6B4F`, avondblauw `#2E3A59`,
  crème `#FAF3E3`, houtbruin `#7A5236`.
- Lettertype: Nunito (open licentie), groot en rustig.
- Icoon: een warm verlicht huisje met een speelkaart (harten-aas) als deur, op avondblauw. Geen tekst.

**Het dorp (seizoen 1: 8 huisjes)**
1. Het bakkershuisje 2. De oude pastorie 3. Het molenaarshuis 4. De boerderij
5. Het schoolhuis 6. De vuurtorenwachterswoning 7. Het station 8. Het grote landhuis

Elk huisje heeft 6–8 maatregelen (kierdichting, dakisolatie, HR++-glas, spouwmuurisolatie, warmtepomp,
zonnepanelen…). Elke maatregel kost warmte en laat het label één stap stijgen. Klopt de volgorde met de
praktijk (eerst isoleren, dan pas warmtepomp), dan krijgt de speler een kleine bonus.

## Gameplay

**Spelregels en bediening**
- Klondike met 1 of 3 kaarten trekken, standaard of Vegas-score (zonder echt geld).
- Tikken én slepen: een tik zet de kaart op de beste plek; slepen voor wie dat liever doet.
- Onbeperkt ongedaan maken (gratis), automatisch afmaken als alles open ligt, linkshandige modus.
- Elke ronde hervat precies waar je was, ook na het afsluiten van de app.

**Winbare spellen (deal-solver)**
- Een solver bewijst dat een spel te winnen is. Spelers kiezen "Willekeurig" of "Altijd winbaar".
- Winbare spellen worden vooraf gegenereerd en ingedeeld in makkelijk, normaal en moeilijk.
- Een hint gebruikt dezelfde solver, dus een hint is altijd een echt goede zet.

**Voortgang en meta-laag**
- Gewonnen ronde = warmte (meer bij weinig zetten, snelle tijd of zonder hints).
- Dagelijkse uitdaging met kalender: elke dag een vast winbaar spel; een maand vol = een speciaal decorstuk.
- Dagelijkse beloning (7-dagenreeks) en een winreeks-teller. Statistieken: winpercentage, beste tijd, langste reeks.
- Cosmetica: kaartruggen, tafels en haardvuren. Game Center: prestaties en een ranglijst voor de dagelijkse uitdaging.

**Later (na v1):** Spider (1, 2, 4 kleuren) en FreeCell met eigen "buurt"; seizoensevents ("Winterweek", "Lenteschoonmaak").

**Moeilijkheid**
- Nieuwe spelers krijgen hun eerste 5 spellen uit de makkelijke winbare set.
- Daarna mengt de standaardmodus winbare normaal en moeilijk; "Willekeurig" blijft beschikbaar.
- Meet uitval per moeilijkheid en stuur bij via Remote Config.

## Monetisatie

| Formaat | Wanneer | Startregels (Remote Config) |
|---|---|---|
| Interstitial | Na een afgeronde ronde (winst of opgeven), vóór de volgende deal | Pas vanaf ronde 4; minimaal 3 minuten ertussen; nooit midden in een spel; nooit direct na een rewarded ad |
| Rewarded video | Warmte verdubbelen, extra hint, gemiste dag inhalen, dagbeloning ×2 | Altijd optioneel; maximaal 15 per dag |
| Banner | Alleen in het dorp en de menu's, nooit op de speeltafel | Adaptieve banner; uit te zetten via Remote Config |
| App-open ad | Niet in v1 | Te storend voor dit publiek |

- **Remove Ads** (eenmalig, ca. €5,99): geen interstitials en banners. Rewarded blijft beschikbaar.
- **Hearthside Club** (ca. €2,99/maand of €19,99/jaar, 7 dagen gratis): geen advertenties, dubbele warmte,
  onbeperkt hints, exclusieve kaartruggen en haardvuren.
- **Warmtepakketten** (€1,99–€9,99) en een **starterspakket** (na het eerste afgemaakte huisje).
- Aanbiedingen alleen op natuurlijke momenten: bij weinig warmte voor de volgende maatregel, of na het afmaken
  van een huisje. Nooit bij het opstarten.
- Log elke vertoning met opbrengst; stuur op ARPDAU per land.

## Tech, privacy & data

Stack: Swift 6, SwiftUI, SpriteKit, iOS 17+, XcodeGen, Google Mobile Ads + UMP, StoreKit 2, Firebase, GameKit,
CloudKit. Gedeelde services in een eigen Swift Package (GameServices).

| Onderdeel | Hergebruik | Nieuw voor Hearthside |
|---|---|---|
| Advertenties, toestemming, aankopen | AdService, ConsentService, PurchaseService | Eigen ad unit-ID's, producten, Remote Config |
| Analytics, Remote Config, opslag, iCloud | AnalyticsService, ConfigService, SaveService | Nieuwe events en sleutels |
| Spel | — | HearthsideCore: kaartmodel, Klondike-regels, solver, deal-generator |
| Weergave | — | SpriteKit-tafel met kaartanimaties; SwiftUI-dorp |
| Toegankelijkheid | Basis (geluid, trillen, Dynamic Type) | Extra grote kaarten, hoog contrast, VoiceOver ("harten zeven") |

**Privacy & wetgeving:** UMP-toestemming, ATT, privacylabel, `app-ads.txt`, handelaarsstatus. De app is voor
volwassenen; nergens "Vegas" of "casino" in combinatie met echt geld.

**Events:** `deal_start` (modus, winbaar, moeilijkheid), `deal_won` (zetten, tijd, hints), `deal_abandoned`,
`upgrade_bought` (huisje, maatregel, label voor/na), `house_completed`, `daily_challenge_done`.

**KPI-doelen v1:** D1 40%, D7 20%, D30 10%, 8 rondes per speler per dag, 25 min speeltijd per dag, 99,5% crashvrij.

## Fasering

1. **Fundament en gedeelde services** — GameServices-package, XcodeGen-project, thema (kleuren, Nunito), navigatie, NL/EN.
2. **Klondike-kern** — kaartmodel, regels (1/3 kaarten, standaard/Vegas, undo, auto-complete, legale zetten), SpriteKit-tafel met tikken/slepen, hervatten.
3. **Solver en winbare spellen** — DFS met transpositietabel; DealGen met 10.000 winbare deals (makkelijk/normaal/moeilijk); hints.
4. **Gevoel en toegankelijkheid** — houten tafel, haardvuur, geluiden, Core Haptics, overwinningsanimatie; extra groot, hoog contrast, linkshandig, VoiceOver; 60 fps op iPhone 11.
5. **Dorp en meta-laag** — warmte-economie, 8 huisjes, dagelijkse uitdaging, dagbeloning, winreeks, statistieken, cosmetica, Game Center, iCloud-sync.
6. **Advertenties, aankopen en analytics** — UMP + ATT, interstitials/rewarded, Remove Ads, Club (SubscriptionStoreView), pakketten, events, Crashlytics, debugmenu.
7. **Afwerking en release** — instellingen, privacylinks, DE/FR/ES/IT, icoon en launch screen, test SE t/m Pro Max en iPad, TestFlight.

## Lancering & checklist

Soft launch in Canada, Australië en Nederland; daarna VS, VK en Duitsland. ASO: "Solitaire" en "Klondike" in
naam en ondertitel; screenshots met grote kaarten en het verlichte dorp. Cross-promotie met Sweet Arrows.

- [ ] Naam "Hearthside" vrij in de App Store, domein geregistreerd, geen merkconflict
- [x] Klondike-regels volledig getest (1 en 3 kaarten, Vegas-score, undo, auto-complete)
- [x] 10.000 winbare deals door de solver goedgekeurd; hints altijd correct
- [ ] Elke zet vloeiend; 60 fps op iPhone 11; hervatten na afsluiten werkt
- [ ] Extra grote kaarten, hoog contrast, linkshandige modus en VoiceOver werken (op toestel)
- [x] 8 huisjes met alle maatregelen en zichtbare veranderingen
- [ ] Dagelijkse uitdaging, dagbeloning, statistieken en Game Center werken (op toestel)
- [x] Advertenties alleen tussen rondes, vanaf ronde 4, minimaal 3 minuten ertussen (unit-getest)
- [ ] Remove Ads, Hearthside Club en Aankopen herstellen werken (sandbox + TestFlight)
- [ ] UMP, ATT, privacylabel, app-ads.txt en privacybeleid in orde
- [ ] iCloud-sync getest met twee toestellen
- [ ] Alle analytics-events zichtbaar in Firebase DebugView
- [ ] 5 testspelers van 40+ zonder uitleg laten spelen
- [x] Licenties van artwork, lettertype en geluid in docs/licenses/
