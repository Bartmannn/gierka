# gierka

Mroczna gra 2D o walkach z bossami, w której muzyka powstaje w trakcie walki.
Gracz widzi świat oczami rannego bohatera i steruje jego przyjacielem. Walkę widać w odbiciu w kałuży.
Pomysł i decyzje opisuje [docs/DESIGN.md](docs/DESIGN.md).

## Co jest teraz

### Las nad jeziorkiem (scena startowa)

Nocny las z grafiki `grafika/sceny/las_jeziorko`, na razie bez przeciwnika:

- **Przyjaciel jest żwawy jak w Hollow Knight:** biegnie (przez cały ekran w 5 s), rusza i staje
  od razu, stopy nie ślizgają się po ziemi, a spod nóg sypie się pył. W bezruchu stoi w czujnej
  postawie i oddycha. Krawędzie sylwetki łapią światło od strony księżyca.
- **Przewrót** (unik): przysiad, kłębek, przetoczenie o 60 px, przyklęk. W środku przewrotu postać
  będzie nietykalna, gdy pojawią się przeciwnicy.
- **Cięcia** przed siebie i w górę: szybki zamach i biała smuga sierpem (z góry w dół albo łukiem
  nad głową), która po ułamku sekundy rozpada się. Można ciąć w biegu; świst ostrza słychać od razu.
- **Księżyc żyje:** przez tarczę przepływa smuga chmur, poświata powoli „oddycha” razem ze snopami światła,
  gwiazdy mrugają, a księżycowa ścieżka na wodzie skrzy się i drży. Mgły lekko dryfują.
- **Dźwięki lasu:** wiatr w koronach drzew, chlupot wody przy brzegu (z prawej), dwa świerszcze,
  co jakiś czas puszczyk i plusk ryby, kroki na mchu. Dźwięki z lewej strony sceny słychać z lewej.

### Prototyp rytmu (`scenes/main.tscn`)

Żeby go uruchomić, otwórz w edytorze scenę `scenes/main.tscn` i naciśnij **F6** (uruchom bieżącą scenę).

Jedna 20-sekundowa walka zbudowana z pliku MIDI (`music/prototyp.mid`):

- **Serce** bije w tle i nadaje tempo. Księżyc w kałuży pulsuje razem z nim.
- **Boss** zadaje muzyczne pytanie: niskie dźwięki, a jego kroki kołyszą wodą.
- **Ty odpowiadasz**: na wodzie zbiega się fala, a ostrze błyska pomarańczowo.
  Uderz, gdy błysk jest najjaśniejszy. Trafienie wygrywa nutę melodii szczękiem oręża.
  Chybiona nuta znika z utworu.
- **Przytomność zamiast paska zdrowia.** Po chybieniach powieki opadają, obraz ciemnieje,
  świat brzmi głucho, a serce coraz głośniej. Po omdleniu walka zaczyna się od nowa.
- **Nagroda:** po wygranej robi się cicho, a potem pierwszy raz słychać cały utwór.

W grze nie ma żadnych napisów ani pasków.

## Jak uruchomić

1. Pobierz **Godot 4.7** (zwykła wersja, nie .NET): https://godotengine.org/download
2. Uruchom Godota, wybierz **Importuj** i wskaż plik `project.godot` z tego repozytorium.
3. Naciśnij **F5**, żeby zagrać.

| Akcja | Klawiatura | Pad | Mysz |
|---|---|---|---|
| Ruch w lewo / w prawo | A / D, strzałki | krzyżak, lewa gałka | |
| Cięcie | J | X | lewy przycisk |
| Cięcie w górę | W lub strzałka w górę + cięcie | góra + X | |
| Przewrót | K, Shift | B, RB | prawy przycisk |
| Cios (prototyp rytmu) | Spacja, J, Enter | A, X | lewy przycisk |
| Od nowa | R | Start | |
| Wyjście | Esc | Back | |

Najlepiej grać w słuchawkach.

### Strojenie bez pisania kodu

W edytorze kliknij węzeł **Main** w scenie `scenes/main.tscn`. W panelu Inspektor po prawej
możesz zmieniać m.in.:

- okna trafień (jak dokładnie trzeba trafić),
- obrażenia za chybienie i leczenie za trafienie,
- długość ciszy przed nagrodą,
- **input_offset_ms**: kalibrację, gdy czujesz, że gra ocenia twoje ciosy jako spóźnione albo za wczesne.

Węzeł **View** ma `glint_lead`, czyli ile sekund wcześniej widać zapowiedź ciosu.

W scenie lasu (`scenes/forest_lake.tscn`):

- węzeł **Friend**: prędkość biegu, rozpędzanie i hamowanie, długość i czas przewrotu,
  czas cięcia i odstęp między cięciami, tempo oddechu,
- węzeł **Ambience**: jak często odzywa się sowa i pluska ryba; głośność każdej pętli
  ustawisz w jej węźle (Wind, Water, CricketLeft, CricketRight),
- materiały warstw (np. **Sky**: szybkość chmur, siła „oddechu” poświaty; **Lake**: falowanie i iskry).

## Muzyka: jak komponować w LMMS

Gra czyta zwykły plik MIDI. Rolę ścieżki rozpoznaje **po nazwie ścieżki** w LMMS
(wielkość liter nie ma znaczenia, wystarczy, że nazwa zawiera słowo):

| Nazwa ścieżki zawiera | Rola w walce |
|---|---|
| `gracz` / `player` / `odpowiedz` | nuty, które wybija gracz; słychać je **tylko po trafieniu** |
| `boss` | pytania bossa, grają same |
| `serce` / `heart` / `puls` | puls w tle, gra sam |
| cokolwiek innego | tło (harmonia, plamy dźwięku), gra samo |

Kroki:

1. W LMMS otwórz `music/prototyp.mid` (**Plik → Importuj…**). Zobaczysz cztery nazwane ścieżki.
   Możesz też zacząć od zera i tylko nazwać ścieżki jak w tabeli.
2. Komponuj. Instrumenty w LMMS nie mają znaczenia: gra bierze z MIDI tylko nuty,
   a brzmienia na razie generuje sama.
3. Wyeksportuj **Plik → Eksportuj MIDI…** i zapisz jako `music/prototyp.mid`, nadpisując stary plik.
4. Uruchom grę (F5). W panelu Wyjście w Godocie zobaczysz np.
   `Dźwięk przygotowany w 900 ms (utwór: 20.0 s, nut gracza: 13)`.
   Jeśli liczba nut gracza się nie zgadza, sprawdź nazwy ścieżek.

Wskazówki:

- Nuty gracza zagrane jednocześnie (akord) wybija się jednym ciosem.
- Nie dawaj nut gracza gęściej niż co ok. 0,25 s, bo trudno je wtedy odczytać.
- Pytanie bossa przed odpowiedzią gracza daje czas, żeby zrozumieć rytm.
- Kulminacja utworu powinna wypadać razem z kulminacją walki.

## Praca z AI

Kod jest pisany tak, żeby AI (np. Claude Code) mogło go czytać, zmieniać i sprawdzać bez pomocy:
jasny podział na pliki, komentarze po polsku, testy uruchamiane bez okna i zasady w [CLAUDE.md](CLAUDE.md).
Wystarczy opisać po polsku, co ma się zmienić. Zmiany trafiają na gałąź w tym repozytorium,
a ty pobierasz je i sprawdzasz w Godocie.

## Struktura

```
project.godot          ustawienia projektu (480x270, pixel art, lekki renderer)
scenes/forest_lake.tscn  scena startowa: las nad jeziorkiem, ruch postaci, dźwięki lasu
scenes/main.tscn       scena prototypu rytmu (320x180)
scripts/forest/        las: teren, ruch przyjaciela (FriendMotor), wygląd postaci, pył, dźwięki otoczenia
shaders/               ruch księżyca, chmur, wody, mgły i poświata na sylwetce postaci
grafika/               grafika od czatu graficznego (warstwy sceny, postacie, generator)
sounds/otoczenie/      dźwięki lasu (WAV, do podmiany na nagrania)
sounds/postac/         świst ostrza, przewrót, lądowanie
scripts/main.gd        przebieg walki: intro → walka → cisza → nagroda / omdlenie
scripts/midi/          czytanie plików MIDI
scripts/music/         utwór: role ścieżek, nuty gracza (Cue), kursor po nutach
scripts/fight/         ocena trafień (Judge)
scripts/audio/         syntezator: serce, boss, tło, szczęk oręża
scripts/view/          obraz: kałuża, księżyc, fale, błyski, powieki, paleta
music/prototyp.mid     utwór prototypu
tools/                 generatory: demonstracyjne MIDI, klatki ruchu postaci, dźwięki lasu
tests/                 testy logiki
docs/DESIGN.md         ustalenia projektowe
```
