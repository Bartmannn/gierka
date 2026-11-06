# Wskazówki dla AI pracującego nad tym repozytorium

Autor nie czyta kodu: rozmawia po polsku, opisuje efekty i sprawdza grę w Godocie.
Odpowiadaj po polsku, prostym językiem. Najpierw przeczytaj `docs/DESIGN.md`.

## Projekt
- Godot **4.7**, GDScript, renderer GL Compatibility, rozdzielczość wewnętrzna 320×180.
- Prototyp rytmu: walka budowana z pliku MIDI (`music/prototyp.mid`). Opis w `README.md`.

## Zasady nadrzędne (z ustaleń z autorem)
- **Żadnego UI w grze**: bez tekstu, pasków i liczników. Każda informacja musi wynikać z otoczenia
  (woda, światło, księżyc, powieki, dźwięk). Wyjątek: `print()` do konsoli na potrzeby debugowania.
- **Dokładny pixel art**: rysuj na siatce 320×180, pozycje zaokrąglaj do całych pikseli,
  bez wygładzania i obrotów o dowolny kąt. Miękkie przejścia rób ditheringiem, nie gradientem.
- **Kolory tylko z `scripts/view/palette.gd`**. Kolor akcentu (`Palette.ACCENT`) jest zarezerwowany
  dla tego, co dotyczy ciosu gracza.
- **Lekkość**: nic ciężkiego w `_process`. Dźwięk jest renderowany raz, przed walką.
- **Dźwięk gracza bez opóźnienia**: cios gra od razu przez `AudioStreamPolyphonic`.

## Konwencje kodu
- Nazwy (klasy, funkcje, zmienne) po angielsku, komentarze i komunikaty po polsku.
- Pełne typowanie GDScript (`var x: int`, `-> void`), wcięcia tabulatorami.
- Jedna klasa (`class_name`) na plik. Logikę bez obrazu i dźwięku (np. `Judge`, `Song`, `MidiReader`)
  trzymaj osobno, żeby dało się ją testować.
- Parametry do strojenia jako `@export` (autor zmienia je w Inspektorze), z komentarzem `##`.
- Sterowanie definiuje `scripts/input_setup.gd`.
- Commituj pliki `*.gd.uid` razem ze skryptami; nie commituj katalogu `.godot/`.

## Praca i sprawdzanie zmian (lokalnie, Windows)
- Pracujemy lokalnie na Windowsie, na gałęzi `main`, w folderze projektu (`E:/Projekty/gierka`).
  Zmiany zapisuj od razu na dysku; **przed commitem i wypchnięciem zapytaj autora**.
- Godot leży w katalogu głównym repozytorium (pliki ignorowane przez git):
  - `Godot_v4.7.2-stable_win64.exe`: zwykła wersja, autor gra i otwiera w niej edytor,
  - `Godot_v4.7.2-stable_win64_console.exe`: wersja z konsolą; jej używaj do testów,
    bo wypisuje komunikaty i zwraca kod wyjścia.

Z katalogu repozytorium, w PowerShellu (kod wyjścia w `$LASTEXITCODE`):
```powershell
$GODOT = ".\Godot_v4.7.2-stable_win64_console.exe"
& $GODOT --headless --path . --import                          # pierwsze uruchomienie: indeks klas
& $GODOT --headless --path . --script res://tests/run_tests.gd # testy logiki, kod 0 = OK
& $GODOT --headless --path . -- --autoplay --exit-when-done    # cała walka z automatem; kod 0 = nagroda
& $GODOT --headless --path . -- --exit-when-done               # bez grania; kod 1 = omdlenie
```
Podgląd obrazu i dźwięku (klatki PNG + plik WAV). Na Windowsie nie trzeba wirtualnego ekranu:
na chwilę otworzy się okno gry. Klatki zapisuj poza repozytorium, np. w folderze tymczasowym:
```powershell
New-Item -ItemType Directory -Force "$env:TEMP\gierka_klatki" | Out-Null
& $GODOT --path . --write-movie "$env:TEMP\gierka_klatki\f.png" --fixed-fps 30 --quit-after 700 -- --autoplay
```
Utwór zaczyna się po intrze (2 s). Nuty w demonstracyjnym MIDI: 96 BPM, 1 ćwierćnuta = 0,625 s.

## Muzyka
- Role ścieżek MIDI wynikają z ich nazw (`Song.ROLE_KEYWORDS`): gracz / boss / serce / tło.
- `tools/make_demo_midi.py` odtwarza demonstracyjny `music/prototyp.mid`. Nie nadpisuj pliku,
  jeśli autor wgrał już własny utwór.
- Przy eksporcie gry trzeba dodać `*.mid` w "Filters to export non-resource files",
  bo pliki MIDI nie są zasobami Godota.
