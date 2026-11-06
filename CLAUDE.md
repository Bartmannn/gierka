# Wskazówki dla AI pracującego nad tym repozytorium

Autor nie czyta kodu: rozmawia po polsku, opisuje efekty i sprawdza grę w Godocie.
Odpowiadaj po polsku, prostym językiem. Najpierw przeczytaj `docs/DESIGN.md`.

## Projekt
- Godot **4.7**, GDScript, renderer GL Compatibility, rozdzielczość wewnętrzna **480×270**
  (okno 1440×810, skalowanie całkowitą wielokrotnością).
- Scena startowa: `scenes/forest_lake.tscn`, las nad jeziorkiem nocą. Przyjaciel biega, robi przewroty
  i tnie przed siebie albo w górę (styl Hollow Knight, bez skoku); księżyc, woda i mgła są animowane,
  słychać las. Skrypty w `scripts/forest/`, shadery w `shaders/`.
- Walka z bestią: logika bez obrazu i dźwięku, z testami - `scripts/fight/forest_fight.gd` (`ForestFight`:
  kolejność kroku, trafienia, przytomność, hitstop), `scripts/fight/beast_brain.gd` (`BeastBrain`: ataki,
  zapowiedzi, wzory błysku oczu, sztuczna inteligencja, `start_attack` pod przyszłe MIDI),
  `scripts/fight/hitbox_math.gd`, `scripts/forest/friend_motor.gd` (`FriendMotor`: ruch przyjaciela).
  Hitboxy to prostokąty względem stóp postaci zwróconej w prawo. Węzły `friend.gd` i `beast.gd` tylko
  dobierają klatki i dźwięki do logiki; prowadzi to `forest_lake.gd` (metody `configure` i `present`).
- Oczy bestii zapowiadają ataki (biel z palety, każdy atak ma inny wzór) - to jedyna zapowiedź poza dźwiękiem,
  więc każdy nowy atak musi mieć własny, czytelny wzór w `BeastBrain.eye_glint()`.
- Prototyp rytmu: `scenes/main.tscn`, walka budowana z pliku MIDI (`music/prototyp.mid`).
  Rysuje na starej siatce 320×180 (sam ustawia sobie ten rozmiar). Opis w `README.md`.

## Zasady nadrzędne (z ustaleń z autorem)
- **Żadnego UI w grze**: bez tekstu, pasków i liczników. Każda informacja musi wynikać z otoczenia
  (woda, światło, księżyc, powieki, dźwięk). Wyjątek: `print()` do konsoli na potrzeby debugowania.
- **Dokładny pixel art**: rysuj na siatce 480×270, pozycje zaokrąglaj do całych pikseli,
  bez wygładzania i obrotów o dowolny kąt. Miękkie przejścia rób ditheringiem, nie gradientem.
- **Kolory tylko z `scripts/view/palette.gd`** (w shaderach: `PAL` z `shaders/pixel_common.gdshaderinc`,
  te same kolory; shader zawsze wybiera kolor z palety, nigdy nie miesza). Bez półprzezroczystości:
  zanikanie robi się ditheringiem. Kolor akcentu (`Palette.ACCENT`) jest zarezerwowany
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
- Jeśli sesja Claude Code działa w kopii roboczej (`.claude/worktrees/...`), autor tego nie widzi w Godocie:
  gotowe zmiany trzeba przenieść do `E:/Projekty/gierka` (gałąź `main`).
- Godot leży w katalogu głównym repozytorium (pliki ignorowane przez git):
  - `Godot_v4.7.2-stable_win64.exe`: zwykła wersja, autor gra i otwiera w niej edytor,
  - `Godot_v4.7.2-stable_win64_console.exe`: wersja z konsolą; jej używaj do testów,
    bo wypisuje komunikaty i zwraca kod wyjścia.

Z katalogu repozytorium, w PowerShellu (kod wyjścia w `$LASTEXITCODE`):
```powershell
$GODOT = ".\Godot_v4.7.2-stable_win64_console.exe"
& $GODOT --headless --path . --import                          # pierwsze uruchomienie: indeks klas
& $GODOT --headless --path . --script res://tests/run_tests.gd # testy logiki, kod 0 = OK
& $GODOT --headless --path . --quit-after 300 -- --demo-walk   # scena lasu: czy startuje bez błędów
$PROTO = "--scene", "res://scenes/main.tscn"                    # prototyp rytmu nie jest już sceną startową
& $GODOT --headless --path . @PROTO -- --autoplay --exit-when-done  # cała walka z automatem; kod 0 = nagroda
& $GODOT --headless --path . @PROTO -- --exit-when-done             # bez grania; kod 1 = omdlenie
```
Podgląd obrazu i dźwięku (klatki PNG + plik WAV). Na Windowsie nie trzeba wirtualnego ekranu:
na chwilę otworzy się okno gry. Klatki zapisuj poza repozytorium, np. w folderze tymczasowym:
```powershell
New-Item -ItemType Directory -Force "$env:TEMP/gierka_klatki" | Out-Null
& $GODOT --path . --write-movie "$env:TEMP/gierka_klatki/f.png" --fixed-fps 30 --quit-after 540 -- --demo-walk
& $GODOT --path . @PROTO --write-movie "$env:TEMP/gierka_klatki/f.png" --fixed-fps 30 --quit-after 700 -- --autoplay
```
`--demo-walk`: postać sama biega, tnie i robi przewroty (pętla 10 s, plan w `forest_lake.gd`); bestia nie atakuje.
`--demo-fight`: automat gra za gracza i wypisuje przebieg (`[pokaz]`, `[walka]`); z `--exit-when-done` kończy
z kodem 0 = bestia pokonana, 1 = omdlenie, 2 = walka się nie skończyła. Szybko, bez czekania:
```powershell
& $GODOT --headless --path . --fixed-fps 60 -- --demo-fight --exit-when-done
```
`--show-hitboxes`: ramki hitboxów od startu (jak F1). Smuga cięcia i błyski trwają ułamki sekundy -
do ich oglądania nagrywaj z `--fixed-fps 60`.
W prototypie utwór zaczyna się po intrze (2 s). Nuty w demonstracyjnym MIDI: 96 BPM, 1 ćwierćnuta = 0,625 s.

## Grafika i dźwięki
- `grafika/` przygotowuje osobny czat od grafiki (nazwy po polsku, generator `grafika/narzedzia/scena_las.py`).
  Foldery `podglady/`, `szkice/`, `narzedzia/` mają plik `.gdignore`, więc Godot ich nie importuje.
  Teren sceny (wysokość ziemi, księżyc) jest przepisany w `scripts/forest/forest_terrain.gd`;
  przy zmianie grafiki popraw i jego (test `test_friend_stands_on_ground` to wykryje).
- Klatki ruchu przyjaciela (`grafika/postacie/przyjaciel_ruch.png`, klatki 80×72, stopy na granicy
  kolumn 39/40 nad wierszem 69; rzędy: stanie, bieg, przewrót, cięcie przed siebie, cięcie w górę, trafiony)
  i białą smugę cięcia (`grafika/efekty/ciecie.png`) rysuje `tools/make_friend_sprites.gd`.
  Obrys od księżyca dokłada shader `shaders/moonlit_silhouette.gdshader`, więc klatki to sama ciemna sylwetka.
  Po zmianie PNG uruchom `--import`, zanim puścisz testy (inaczej czytają starą wersję).
- Klatki bestii (`grafika/postacie/bestia_ruch.png`, klatki 208×112, stopy w kolumnie 104 nad wierszem 108)
  rysuje `tools/make_beast_sprites.gd` z kształtu szkicu (`bestia()` w `scena_las.py`); zapisuje też
  `scripts/forest/beast_frame_data.gd` (położenie oka w każdej klatce) - tego pliku nie poprawiaj ręcznie.
  Na zboczu shader obrysu przycina nogi bestii do linii ziemi (`clip_to_ground`).
- Wspólne rysowanie pikseli dla obu narzędzi: `tools/pixel_canvas.gd`.
- Dźwięki (`sounds/otoczenie/`, `sounds/postac/`, `sounds/bestia/`) wylicza `tools/make_sounds.gd`; pętle mają
  zapisany punkt zapętlenia w pliku. Można je podmienić na nagrania o tych samych nazwach.
  Serce bohatera powstaje w grze z syntezatora prototypu (`Synth`, instrument HEART).
- Szyna `World` (`scripts/audio/audio_buses.gd`) głuchnie przy słabej przytomności; serce gra poza nią.
- Narzędzia uruchamia się tak: `& $GODOT --headless --path . --script res://tools/<plik>.gd`.

## Muzyka
- Role ścieżek MIDI wynikają z ich nazw (`Song.ROLE_KEYWORDS`): gracz / boss / serce / tło.
- `tools/make_demo_midi.py` odtwarza demonstracyjny `music/prototyp.mid`. Nie nadpisuj pliku,
  jeśli autor wgrał już własny utwór.
- Przy eksporcie gry trzeba dodać `*.mid` w "Filters to export non-resource files",
  bo pliki MIDI nie są zasobami Godota.
