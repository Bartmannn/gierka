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

## Sprawdzanie zmian
Godot nie jest zainstalowany w systemie. Pobierz go (np. do katalogu tymczasowego):
```bash
curl -sSLO https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
```
Potem, z katalogu repozytorium (`GODOT` = ścieżka do rozpakowanego pliku):
```bash
$GODOT --headless --path . --import                      # pierwsze uruchomienie: indeks klas
$GODOT --headless --path . --script res://tests/run_tests.gd   # testy logiki, kod wyjścia 0 = OK
$GODOT --headless --path . -- --autoplay --exit-when-done      # cała walka z automatem; kod 0 = nagroda
$GODOT --headless --path . -- --exit-when-done                 # bez grania; kod 1 = omdlenie
```
Podgląd obrazu i dźwięku (klatki PNG + plik WAV) przez wirtualny ekran:
```bash
xvfb-run -a $GODOT --path . --rendering-driver opengl3 --write-movie /tmp/klatki/f.png --fixed-fps 30 --quit-after 700 -- --autoplay
```
Utwór zaczyna się po intrze (2 s). Nuty w demonstracyjnym MIDI: 96 BPM, 1 ćwierćnuta = 0,625 s.

## Muzyka
- Role ścieżek MIDI wynikają z ich nazw (`Song.ROLE_KEYWORDS`): gracz / boss / serce / tło.
- `tools/make_demo_midi.py` odtwarza demonstracyjny `music/prototyp.mid`. Nie nadpisuj pliku,
  jeśli autor wgrał już własny utwór.
- Przy eksporcie gry trzeba dodać `*.mid` w "Filters to export non-resource files",
  bo pliki MIDI nie są zasobami Godota.
