# Patternaut

Patternaut er en native macOS-app til musikere, der bruger Polyend Tracker+ eller Polyend Tracker Mini.

Appen hjælper med at skabe, transformere og organisere tracker-patterns, før de overføres til hardware. Den fungerer som et kreativt companion-værktøj til Polyends tracker-workflow og fokuserer på hurtig pattern-generering, kontrolleret variation, MIDI-konvertering og visuel forståelse af tracker-data.

Patternaut er ikke en fuld software-tracker og skal ikke erstatte Tracker+ eller Tracker Mini. Appen skal i stedet gøre det hurtigere at udvikle idéer, som passer til maskinernes særlige struktur og begrænsninger.

## Produktidé

Tracker-workflowet er stærkt, fordi noter, instrumenter og effekter kan redigeres meget præcist på hver enkelt row. Den samme præcision kan dog gøre det tidskrævende at:

- Oprette komplekse rytmer fra bunden
- Programmere probability og microtiming
- Fordele akkorder og polyfoni over flere monofoniske tracks
- Skabe variationer af eksisterende patterns
- Konvertere idéer fra en DAW eller MIDI-fil
- Eksperimentere med alternative taktarter og patternlængder
- Huske og kombinere trackerens mange FX-kommandoer

Patternaut gør disse opgaver visuelle, hurtige og ikke-destruktive.

Brugeren kan generere eller importere et pattern, ændre det med musikalske transformationsværktøjer og derefter eksportere resultatet til et format, der kan bruges sammen med Tracker+ eller Tracker Mini.

## Understøttede enheder

Patternaut udvikles med fælles understøttelse af:

- Polyend Tracker+
- Polyend Tracker Mini

Appens interne pattern-model skal være enhedsneutral. En enhedsprofil definerer derefter de relevante begrænsninger og eksportmuligheder.

Det gør det muligt senere at understøtte andre tracker-baserede enheder uden at ændre appens grundlæggende arkitektur.

## Kerneprincipper

Patternaut skal være:

- Kreativ frem for administrativ
- Hurtig at bruge
- Ikke-destruktiv
- Tydeligt tilpasset tracker-workflowet
- Brugbar uden internetforbindelse
- Fokuseret på musikalske resultater frem for teknisk kompleksitet
- Et supplement til hardware, ikke en erstatning for den

## Primært workflow

Et typisk workflow kan være:

1. Opret et nyt pattern eller importer en MIDI-fil
2. Vælg mål-enhed
3. Angiv patternlængde, tempo og musikalske parametre
4. Generer eller rediger noter og events
5. Tilføj variation, probability, rolls og microtiming
6. Preview resultatet
7. Opret alternative versioner
8. Eksporter patternet eller en guide til overførsel

## Pattern Editor

Patternaut viser data i et klassisk tracker-grid.

Et pattern består af:

- Rows
- Tracks
- Note-events
- Instrumentnumre
- Velocity eller volume
- FX-felter
- Parameterdata
- Note-off og note-cut events
- Probability
- Microtiming
- Metadata

Eksempel:

```text
ROW   TRACK 01        TRACK 02        TRACK 03        TRACK 04
00    C-3 01 V90      ---             F#4 04 V72      ---
01    ---             ---             ---             ---
02    ---             D-3 02 V84      ---             ---
03    ---             ---             A-4 04 V65      ---
04    C-3 01 V96      ---             ---             G-4 04 V74
```

Editoren skal gøre store patterns nemme at navigere med keyboard, mus og trackpad.

## Pattern Generator

Brugeren kan generere et pattern ud fra musikalske parametre.

Mulige indstillinger:

- Patternlængde
- Antal aktive tracks
- Tempo
- Taktart
- Density
- Syncopation
- Variation
- Swing
- Probability
- Humanization
- Register
- Toneart eller skala
- Musikalsk rolle

Eksempler på roller:

- Kick
- Snare
- Hi-hat
- Percussion
- Bass
- Chords
- Melody
- Arpeggio
- Texture
- Drone
- FX
- Fill

Eksempel på en generatorbeskrivelse:

```text
Length: 64 rows
Meter: 7/8
Style: Broken beat
Density: Medium
Variation: High
Kick: Sparse
Snare: Late
Hi-hat: Unstable
```

Generatoren skal skabe resultater, der kan redigeres videre, ikke færdige eller låste kompositioner.

## Groove Generator

Patternaut kan generere rytmer ud fra forskellige modeller.

Mulige generatorer:

- Euclidean rhythms
- Probability-based rhythms
- Step division
- Polyrhythms
- Polymeters
- Rotating patterns
- Cellular variation
- Controlled randomness
- Rule-based drum patterns
- Accent patterns
- Ghost notes
- Conditional fills

Alle genererede patterns skal kunne reproduceres via en seed-værdi.

Brugeren skal kunne låse enkelte tracks eller events, så de ikke ændres ved ny generering.

## Pattern Transformations

Et eksisterende pattern kan transformeres uden at ændre originalen.

Mulige transformationer:

- Half-time
- Double-time
- Broken
- Sparse
- Dense
- Humanize
- Quantize
- Rotate
- Reverse
- Mirror
- Shift
- Reduce
- Fill
- Glitch
- Stutter
- Accent
- Ghost notes
- Alternate ending
- Increase variation
- Decrease variation
- Convert to another meter

Transformationerne skal kunne anvendes på:

- Hele patternet
- Udvalgte tracks
- Udvalgte rows
- Udvalgte eventtyper

## Pattern Mutation

Mutation skaber beslægtede versioner af et pattern.

Brugeren kan vælge mutationsstyrke:

- Subtle
- Moderate
- Strong
- Chaotic

Eksempel:

```text
A01 Original
A02 Sparse
A03 Syncopated
A04 Probability variation
A05 Fill ending
A06 Half-time
A07 Glitch
A08 Breakdown
```

Mutationer skal bevare patternets grundlæggende identitet, medmindre brugeren aktivt vælger et kaotisk resultat.

Brugeren skal kunne sammenligne versioner og markere favoritter.

## MIDI Import

Patternaut kan importere Standard MIDI Files og konvertere dem til tracker-data.

> Bemærk: Dette er import *ind i Patternaut* (typisk fra en DAW). Polyend Tracker+/Mini kan **ikke** selv loade en `.mid`-fil ind i et pattern. Data kommer ind i hardwaren via live-MIDI-optagelse eller direkte fil-skrivning — se afsnittet "Overførsel til hardware".

Ved import skal appen kunne:

- Vælge bestemte MIDI-tracks
- Kvantisere events til rows
- Bevare eller konvertere velocity
- Konvertere note-længder til note-off eller note-cut
- Fordele polyfoni over flere monofoniske tracks
- Opdele lange arrangementer i patterns
- Identificere overlappende noter
- Markere events, der ikke kan konverteres entydigt
- Tilpasse materialet til en valgt enhedsprofil

Eksempel:

> Akkorden kræver fire monofoniske tracks. Stemmerne er fordelt på Track 5–8.

Brugeren skal kunne ændre trackfordelingen før eksport.

## MIDI Export

MIDI-eksport er primært til DAW'er og andet MIDI-grej — ikke vejen ind i Trackeren (den importerer ikke MIDI-filer). Patternaut kan eksportere patterns som MIDI til brug i:

- Ableton Live
- Logic Pro
- Bitwig Studio
- Renoise
- Andre hardware-sequencere
- Andre MIDI-kompatible programmer

MIDI-eksport kan indeholde:

- Noter
- Velocity
- Note-længder
- Trackopdeling
- Tempo
- Patternmarkører
- Valgfri konvertering af probability til konkrete variationer

## Overførsel til hardware

Dette er kernen i hele værdiforslaget, så vejene er dokumenteret eksplicit. Verificeret mod Polyend Tracker Manual 1.7.0.

Der findes tre broer fra Patternaut til hardwaren:

### Vej A — Live MIDI-optagelse (primær bro i MVP)

Trackeren kan optage indkommende MIDI i realtid via `[Rec] + [Play]`. Patternaut sender patternet ud over CoreMIDI (USB), og maskinen skriver det ind i steps.

- Overfører: noter og note-off. Velocity følger kun med, hvis brugeren har slået `Config > General > Recording Options` til på maskinen (ellers fast værdi) — appen skal minde om dette.
- Overfører **ikke**: FX-kommandoer, probability, microtiming.
- Trackerens MIDI er per-step, ikke per-track (via dedikerede MIDI-instrumenter, ét pr. kanal). Polyfoni skal derfor være fordelt på monofoniske tracks *før* afspilning (se Chord Distributor).
- Trackeren kører 192 PPQN internt og kan følge ekstern clock. Patternaut bør kunne fungere som clock-leader for ren kvantisering under optagelse.

### Vej B — Direkte fil-skrivning til SD-kort (v1.x, fuld troværdighed)

Patterns gemmes på maskinen som separate binære filer, `Pattern_01.mtp`, `Pattern_02.mtp` osv., i `/Projects/<navn>/Patterns/` ved siden af et `project.mt` (projekt-index). Projekter, der lægges på SD-kortet fra en Mac, genkendes af Trackeren, forudsat de ligger i hoved-`/Projects`-folderen.

Denne vej kan i princippet overføre *alt* — inkl. FX, probability og microtiming — som et færdigt pattern klar til at loade.

Formatet er allerede løst: **Polyend har udgivet et officielt bibliotek, [`polyend/tracker-lib`](https://github.com/polyend/tracker-lib)** (MIT-licens, TypeScript), der både læser og skriver `.pti`, `.mtp` og `.mt` inkl. FX/automation på step-niveau. Vej B er dermed *integrations-/porteringsarbejde*, ikke reverse engineering. Community-værktøjet [`iannuz92/midi-to-mtp`](https://github.com/iannuz92/midi-to-mtp) demonstrerer allerede MIDI → `.mtp` ende-til-ende.

**Status:** Hele SD-kort-eksporten er implementeret i `PatternautCore` og verificeret byte-for-byte mod `tracker-lib` (begge retninger, læs+skriv):

- `.mtp`-patterns (`MTPExporter`/`MTPImporter`) — round-trip begge veje.
- `.mt`-projekter (`MTProjectExporter`/`MTProjectImporter`) — patcher kendte felter ind i en embedded template.
- `ProjectBundleWriter` — skriver en komplet, loadbar `<Projekt>/project.mt` + `Patterns/Pattern_NN.mtp`-mappe klar til SD-kortet.

`.pti`-instrumenter er også implementeret (`PTIExporter` + `WavFile`, byte-eksakt mod `tracker-lib`) og kan skrives ind i projektets `Instruments`-mappe via `ProjectBundleWriter`, så projekter kan definere egne sample-lyde.

Udestående — kræver test på fysisk hardware: at loade en genereret bundle på en rigtig Tracker+/Mini; om enheden kræver en reel CRC-32 (skrives pt. `0` som i `tracker-lib`; standard CRC-32 er implementeret men slået fra); track-`length`-bytens præcise betydning.

Hensyn ved implementering:

- **Native app vs. TS-bibliotek.** Patternaut er Swift/SwiftUI; `tracker-lib` er TypeScript. Anbefalet: portér formatlogikken til Swift med `tracker-lib`s kildekode som autoritativ spec (ingen JS-afhængighed). Alternativ: kør biblioteket via JavaScriptCore. MIT-licensen tillader begge dele.
- **Verificér mod målfirmware.** `tracker-lib` er tidligt stadie (v0.1.2). Bekræft FX/probability/microtiming-dækning mod den firmware, der køres på Tracker+/Mini. Enhedsprofilerne skal versionere selve filformat-skemaet, ikke kun begrænsningerne.
- **Eksport-enheden bør være pattern-niveau (`.mtp`)** — den mindste selvstændige enhed, der matcher appens formål.

Supplerende referencer: [`DataGreed/polyendtracker-midi-export`](https://github.com/DataGreed/polyendtracker-midi-export) (parser + formatdiagram) og [`ejconlon/polyendtracker-formats`](https://github.com/ejconlon/polyendtracker-formats) (formatdok, firmware 1.6.0).

### Vej C — Cheat sheet og manuel indtastning (fallback)

Tekst-grid, PNG og PDF-cheat sheet med step-by-step transfer guide. Virker altid, uafhængigt af format-arbejde. Dette er også den eneste vej for FX-data, indtil Vej B er på plads.

## Chord Distributor

Trackerens monofoniske trackstruktur gør akkorder til en særlig opgave.

Chord Distributor fordeler automatisk akkordtoner over flere tracks.

Funktionen skal kunne:

- Fordele stemmer over ledige tracks
- Bevare voice leading
- Prioritere grundtone eller topnote
- Reducere akkorder, hvis der ikke er nok tracks
- Oprette inversioner
- Sprede akkorder over flere oktaver
- Arpeggiere akkorder
- Markere trackkonflikter

Brugeren skal kunne vælge mellem:

- Compact
- Open
- Wide
- Drop voicing
- Arpeggiated
- Minimal

## FX Command Designer

FX Command Designer gør trackerens kommandoer lettere at forstå og programmere.

I stedet for kun at arbejde med koder og numeriske værdier kan brugeren vælge almindelige musikalske beskrivelser.

Eksempel:

```text
Roll:
1/32
Accelerating
70% probability

Timing:
Slightly late

Variation:
Every fourth repetition
```

Patternaut oversætter indstillingerne til den relevante tracker-repræsentation.

Funktionen skal indeholde:

- Søgbar FX-reference
- Visuelle parameterkontroller
- Forklaring af kommandoer
- Preview af resultatet
- Presets
- Favoritter
- Advarsler ved konflikter
- Enhedsspecifik tilpasning

FX-data kan ikke overføres via MIDI (Vej A). Indtil `.mtp`-eksporten (Vej B) er implementeret, når FX Command Designers output hardwaren som cheat sheet (Vej C), og funktionen fungerer da som et planlægnings- og referenceværktøj. Med `.mtp`-eksport på plads kan FX skrives direkte ind i patternet, da det officielle `tracker-lib` dækker FX/automation på step-niveau.

## Preview

Patternaut skal kunne afspille et hurtigt preview af et pattern.

Preview kan bruge:

- Simple indbyggede placeholderlyde
- Brugerens egne samples
- MIDI-output til ekstern hardware
- MIDI-output til en DAW
- Metronom
- Solo og mute pr. track
- Loop playback

Previewet skal prioritere timing og struktur frem for at efterligne Trackerens lydmotor fuldstændigt.

## Pattern Library

Brugeren kan gemme patterns i et lokalt bibliotek.

Et pattern kan indeholde:

- Navn
- Beskrivelse
- Tempo
- Taktart
- Patternlængde
- Mål-enhed
- Tags
- Seed
- Oprettelsesdato
- Seneste ændring
- Favoritstatus
- Parent pattern
- Versioner
- Noter

Eksempler på tags:

- Jungle
- IDM
- Ambient
- Broken beat
- 7/8
- Fill
- Live
- Then the Letting Go
- Album
- Sketch

## Collections

Patterns kan samles i collections.

En collection kan eksempelvis repræsentere:

- Et nummer
- Et live-set
- En EP
- En genre
- Et eksperiment
- En trommemaskine
- En bestemt enhed

Collections kan have egne noter og eksportindstillinger.

## Export

Patternaut skal understøtte flere eksportniveauer.

### Første version

- Live MIDI-optagelse til hardwaren (Vej A) — den primære bro til Tracker+/Mini
- MIDI-fileksport (til DAW'er, ikke til Trackeren)
- Tracker-grid som tekst
- CSV eller JSON
- PNG
- PDF-cheat sheet med step-by-step transfer guide
- Copy to clipboard

### Senere versioner

- Direkte `.mtp`-pattern-eksport til SD-kort (Vej B) — via portering af det officielle `tracker-lib`-format til Swift
- Enhedsspecifik filgenerering pr. profil og firmwareversion
- Fuld projekt-eksport (`.mt` + `/Patterns`)
- Synkronisering med understøttede projektformater

Formaterne er dokumenteret via det officielle `tracker-lib` (se "Overførsel til hardware"), men appen bør ikke love direkte eksport i markedsføringen, før den er verificeret ende-til-ende mod målfirmwaren på Tracker+/Mini.

## Enhedsprofiler

Hver enhedsprofil beskriver:

- Maksimalt antal tracks
- Maksimal patternlængde
- Tilgængelige eventtyper
- Tilgængelige FX-kommandoer
- Understøttede instrumenttyper
- Eksportmuligheder
- Filbegrænsninger
- Kendte kompatibilitetsproblemer

Profilerne skal være versionsstyrede, så appen kan håndtere forskelle mellem firmwareversioner — inkl. versionering af selve filformat-skemaet (`.mtp`/`.mt`), ikke kun begrænsningerne.

Alle værdier nedenfor er udtrukket fra det officielle `tracker-lib` (`ProjectConstants`, `PatternConstants`, `PatternFX`) og er autoritative for filformatet.

### Fælles begrænsninger (Tracker Mini 2.0 og Tracker+)

- 1–128 steps pr. track (default 32); 6 bytes pr. step; **max 2 FX pr. step**
- Max 255 patterns pr. projekt (`PATTERN_INDEX_MAX`); song-playlist = 255 slots (værdi 0 = ingen pattern)
- 48 instrumenter pr. projekt
- Navnelængder: projekt 32 tegn, track 21 tegn, pattern 30 tegn
- Metadata-fil-id `PAMD` (v1); pattern-fil type `2`
- SD-kort: FAT32 med Master Boot Record; projekter skal ligge i hoved-`/Projects`-folderen for at være synlige
- **Samme `.mt`/`.mtp`-format med 16 tracks** — Mini 2.0 og Tracker+ er projektkompatible. Patternaut kan derfor bruge én intern model og én exporter; profilen begrænser blot per-track-type.

### Step-encoding (autoritativt)

- `note`: 0–127; specialværdier `-1` tom, `-2` off/fade, `-3` off/cut, `-4` off (default)
- `instrument`: **0–47 = sample-instrumenter · 48–63 = MIDI-instrumenter (16 kanaler) · 64–66 = synth-engines (3 slots)**

### Track-antal pr. format-generation

- `OLD` = 8 tracks (tidligste firmware)
- `OG` = 12 tracks (original Tracker)
- `MINI_PLUS` = **16 tracks** (Tracker Mini 2.0 og Tracker+)

Layoutet i 16-track-formatet: tracks 1–8 er fulde tracks ("Track 1"…"Track 8"), tracks 9–16 er MIDI-tracks ("Midi 9"…"Midi 16").

### Profil: Tracker Mini (firmware 2.0+)

- **16 tracks** i formatet (tracks 1–8 audio/MIDI/synth; tracks 9–16 MIDI/synth). Mini *før* 2.0 havde 8 tracks — 2.0 blev aligned med Tracker+ og gjorde projekter kompatible.
- 4 synth-engines (ACD, FAT, VAP, WTFM) + PERC drum-synth
- Stereo samples, 32 MB RAM
- Audio + MIDI over USB-C; MIDI også via 3,5 mm TRS

### Profil: Tracker+

- **16 tracks**: tracks 1–8 kan sequence audio/MIDI/synth; **tracks 9–16 kun MIDI/synth** (ingen sampleafspilning) — profilen skal håndhæve dette ved fordeling og eksport
- 5 synth-engines (ACD, FAT, VAP, WTFM, PERC), 3 slots, op til 6 stemmers polyfoni
- Stereo samples, udvidet RAM
- Audio + MIDI over USB-C; MIDI også via 3,5 mm TRS

### FX-kommandoer (autoritativ fra `tracker-lib`, 43 poster, index 0–42)

Hvert FX-record har `index` (gemmes i patternet), `symbol` (vises), `name`, `min`/`max` og evt. `scaled` min/max (præsenteret værdi).

| idx | sym | navn | min–max (skaleret) |
|----|----|------|------|
| 0 | `-` | None | 0–100 |
| 1 | `!` | Off | — |
| 2 | `m` | Micro-move | 0–100 |
| 3 | `R` | Roll | 0–47 |
| 4 | `C` | Chance | 0–100 |
| 5 | `n` | Random Note | 0–100 |
| 6 | `i` | Random Instrument | 0–100 |
| 7 | `v` | Random Volume | 0–100 |
| 8–12 | `a`–`e` | MIDI CC A–E | 0–127 |
| 13 | `x` | Break Pattern | 1 |
| 14 | `0` | MIDI Chord | 0–15 |
| 15 | `T` | Tempo | 4–200 (8–400) |
| 16 | `x` | Random FX Value | 0–255 |
| 17 | `I` | Swing | 25–75 (−25–+25) |
| 18 | `V` | Volume/Velocity | 0–100 |
| 19 | `G` | Glide | 0–100 |
| 20 | `q` | Gate Length | 0–100 |
| 21 | `A` | Arp | 0–33 |
| 22 | `p` | Position | 0–100 |
| 23 | `g` | Volume LFO | 0–24 |
| 24 | `h` | Panning LFO | 0–30 |
| 25 | `S` | Slice | 0–47 (1–48) |
| 26 | `r` | Reverse Playback | 0–1 |
| 27 | `L` | Low-pass | 0–100 |
| 28 | `H` | High-pass | 0–100 |
| 29 | `B` | Band-pass | 0–100 |
| 30 | `s` | Delay Send | 0–100 |
| 31 | `P` | Panning | 0–100 (−50–+50) |
| 32 | `t` | Reverb Send | 0–100 |
| 33 | `l` | Finetune LFO | 0–30 |
| 34 | `M` | Micro-tune/Pitchbend | 0–198 (−99–+99) |
| 35 | `j` | Filter LFO | 0–30 |
| 36 | `k` | Position LFO | 0–30 |
| 37 | `f` | MIDI CC F | 0–127 |
| 38 | `D` | Overdrive | 0–100 |
| 39 | `E` | Bit Depth | 1–16 |
| 40 | `U` | Tune | 0–48 (−24–+24) |
| 41 | `F` | Slide Up | 0–255 |
| 42 | `J` | Slide Down | 0–255 |

Bemærk: symbolerne afviger fra den gamle Tracker-manual (fx moderne `L`/`H`/`B` = low-/high-/band-pass, hvor manual 1.7.0 brugte `B` = low-pass). Brug altid `tracker-lib` som kilde. FX-tabellen versioneres pr. firmware i enhedsprofilen.

> Note: Den **oprindelige** Tracker (format `OLD`/`OG`, 8–12 tracks) kan ikke køre den moderne firmware (CPU/RAM) og er en separat, ældre profil — kun relevant, hvis ældre hardware skal understøttes.

## Brugeroplevelse

Patternaut skal føles som en moderne native macOS-app.

Den primære navigation kan bestå af:

- Library
- New Pattern
- Generator
- Editor
- Mutations
- Collections
- FX Reference
- Export
- Settings

Appen skal understøtte:

- Keyboard-first navigation
- Drag and drop
- Multi-selection
- Copy and paste
- Undo og redo
- Native context menus
- Quick Look
- Dark mode og light mode
- Autosave
- Tabs eller separate vinduer
- MIDI drag-and-drop
- Hurtig global søgning

## Visuel retning

Designet skal hente inspiration fra trackerens præcision uden at kopiere Polyends interface.

Udtrykket skal være:

- Grid-baseret
- Roligt
- Teknisk, men tilgængeligt
- Kompakt uden at være klaustrofobisk
- Tydeligt omkring aktive events
- Velegnet til lange sessioner

Vigtige designprincipper:

- Patternet er altid i centrum
- Farve må ikke være den eneste informationsbærer
- Mutationer og generatorer skal føles kontrollerbare
- Original og variation skal være nemme at sammenligne
- Komplekse FX-data skal kunne forstås visuelt
- Der skal være en tydelig forskel mellem data, preview og eksport

## Teknisk retning

Patternaut bygges som en native macOS-app i Swift og SwiftUI.

Mulige teknologier:

- SwiftUI til interface
- SwiftData til patterns, metadata og collections
- AVFoundation til audio-preview
- CoreMIDI til MIDI-import, eksport og live-output
- Uniform Type Identifiers til filhåndtering
- FileManager til lokale biblioteker og eksport
- Accelerate til timing- og analysefunktioner
- PDFKit til cheat sheets
- StoreKit 2 til køb eller licens

Appen skal fungere lokalt uden krav om konto eller cloud.

## Intern datamodel

Patternaut skal have et internt, enhedsneutralt pattern-format.

Et pattern kan konceptuelt bestå af:

```text
Pattern
├── Metadata
├── Device profile
├── Tempo
├── Meter
├── Row count
├── Tracks
│   ├── Track settings
│   └── Events
│       ├── Note
│       ├── Instrument
│       ├── Velocity
│       ├── Length
│       ├── FX 1
│       ├── FX 2
│       ├── Probability
│       └── Microtiming
└── Versions
```

Det interne format skal kunne serialiseres som JSON, så patterns kan sikkerhedskopieres og deles uafhængigt af appens database.

## Sikkerhed og dataintegritet

Patternaut skal behandle brugerens arbejde konservativt.

Grundregler:

- Originale imports ændres aldrig
- Transformationer opretter nye versioner
- Automatisk lagring må ikke overskrive eksplicitte snapshots
- Eksport skal kunne previewes
- Appen skal advare om tab af data ved konvertering
- Enhedsprofiler skal validere patterns før eksport
- Brugeren skal kunne eksportere hele sit bibliotek i et åbent format

## MVP

Første version skal fokusere på den kreative kerne.

### MVP-funktioner

1. Native macOS-app
2. Enhedsprofiler til Tracker+ og Tracker Mini
3. Opret patterns med valgfrit antal rows
4. Tracker-grid med noter, instruments og velocity
5. Keyboard-baseret redigering
6. Euclidean rhythm generator
7. Probability-generator
8. Swing og humanize
9. Pattern rotation og shifting
10. Subtle, moderate og strong mutation
11. MIDI-import (ind i Patternaut, fra DAW)
12. Automatisk fordeling af polyfoni
13. MIDI-eksport (til DAW)
14. Live MIDI-optagelse til hardwaren (Vej A)
15. Tekst- og PNG-eksport med transfer guide
16. Lokalt pattern-bibliotek
17. Tags, favoritter og collections
18. Undo, redo og versionshistorik

### Ikke en del af MVP

- Fuld audio-engine
- Sample editor
- Direkte redigering af Tracker-projektfiler
- Direkte USB-synkronisering
- Cloud-konto
- AI-chat
- Samarbejde mellem flere brugere
- Understøttelse af alle trackere

## Senere muligheder

Efter MVP kan Patternaut udvides med:

- Direkte `.mtp`/`.mt`-eksport til Polyend-projektformater (Vej B)
- Flere FX-kommandoer
- Audio-preview med brugerens samples
- Generative melodier
- Bassline-generator
- Chord progression generator
- Wavetable- og granular pattern helpers
- Intelligent voice leading
- Scale locking
- Pattern morphing
- A/B-comparison
- Arrangement mode
- Live-set collections
- Random seed browser
- Community pattern packs
- Delbare generator-presets
- Understøttelse af andre tracker-formater

## Mulig AI-funktionalitet

AI bør ikke være nødvendig for appens kernefunktioner.

En senere lokal eller valgfri AI-funktion kan oversætte naturligt sprog til generatorindstillinger.

Eksempel:

> Lav et 64-row jungle-pattern med en enkel kick, ustabile hi-hats og et fill i de sidste otte rows.

Resultatet skal stadig genereres af Patternauts deterministiske pattern-motor, så brugeren kan forstå, redigere og reproducere det.

AI-funktionen må ikke skjule tracker-data eller gøre resultatet til en lukket proces.

## Målgruppe

Den primære målgruppe er brugere af Tracker+ og Tracker Mini, som:

- Arbejder med breakbeats, jungle, IDM, ambient eller eksperimenterende musik
- Gerne vil generere variationer hurtigere
- Importerer idéer fra en DAW
- Programmerer komplekse rytmer
- Arbejder med alternative taktarter
- Har brug for at fordele akkorder over monofoniske tracks
- Ønsker et visuelt værktøj til probability og microtiming
- Vil forberede materiale på Mac og færdiggøre det på hardware

Den sekundære målgruppe er musikere, der er nysgerrige på tracker-workflowet, men som ønsker en mere tilgængelig indgang til det.

## Positionering

Patternaut er ikke en DAW og ikke en traditionel software-tracker.

Det er et kreativt pattern-værktøj, som hjælper musikere med at skabe komplekse, kontrollerede og hardware-klare idéer til Polyend Tracker+ og Tracker Mini.

Produktets løfte er:

> Build the pattern. Break the pattern. Take it to the Tracker.
