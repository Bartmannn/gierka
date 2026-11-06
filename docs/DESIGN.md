# Gra 2D o walkach z bossami: ustalenia

Dokument zbiera decyzje projektowe. Gdy coś się zmieni, poprawiamy go tutaj,
żeby kod i pomysł się nie rozjechały.

## Założenia
- Gra 2D nastawiona na widowiskowe walki z coraz trudniejszymi bossami, o różnych sekwencjach ataków.
- Sterowanie: ruch w lewo i prawo, uniki, ataki. Po pokonaniu bossa gracz wybiera nagrodę.
- Styl: mroczny, **dokładny** pixel art; atrakcyjna gra światła i cieni, sylwetki,
  ograniczona paleta i jeden mocny kolor akcentu.
- **Gra ma być immersyjna, bez interfejsu.** Żadnych pasków, liczników ani napisów w trakcie gry.
  O tempie i zdrowiu bohatera mówią wyłącznie elementy otoczenia i zmysły bohatera.
- Możliwa późniejsza premiera na Steamie za około 20 zł, ale projekt jest też robiony dla frajdy.
- Muzykę komponuje autor (na początek w **LMMS**); może dołączyć ktoś ze znajomych.
- Autor nie planuje czytać kodu, więc kod ma być czytelny i łatwy do poprawiania przez AI.
- Gra ma jak najmniej obciążać komputer.

## Fabuła i perspektywa
- Główny bohater poszedł tam, gdzie nie powinien, i został ranny.
- Na pomoc przychodzi jego najlepszy przyjaciel, który towarzyszył mu od początku podróży.
  **Przyjaciel to człowiek, druga postać.** Szedł śladem bohatera z troski
  i dogonił go w odpowiednim momencie.
- Gracz widzi świat oczami rannego bohatera, ale steruje przyjacielem.
- Walkę widać w odbiciu w kałuży, w mrocznym lesie: tylko poświaty i sylwetki w świetle księżyca.
- Mapa lub świat może pokazywać postacie tylko wtedy, gdy się poruszają. W bezruchu robi się cicho i spokojnie.

## Bez interfejsu: co zastępuje HUD
| Informacja | Jak ją widać i słychać |
|---|---|
| Zdrowie (przytomność bohatera) | opadające powieki, ciemnienie obrazu, przygasający księżyc, przytłumiony świat, coraz głośniejsze serce |
| Tempo | puls serca: księżyc w wodzie lekko pulsuje, od jego środka rozchodzi się fala |
| Nadchodzący cios | fala zbiegająca się na wodzie i rosnący błysk ostrza w kolorze akcentu; najjaśniejszy w chwili ciosu |
| Trafienie | ciepła fala, iskry, ciepłe światło odbite w wodzie, czysty szczęk oręża |
| Chybienie | ciemna fala, wstrząs obrazu, brakująca nuta w utworze |
| Pytanie bossa | kroki bossa rozkołysują taflę z daleka |

## Propozycje do rozwinięcia
- Rozmycie obrazu przy niskiej przytomności (w prototypie są już powieki i ciemnienie).
- Trafienia zaburzają taflę wody, a mocny cios może chwilowo rozbić obraz.
- Po walce przyjaciel ciągnie bohatera dalej; gracz widzi korony drzew, księżyc i sylwetki.
- Każda walka ma inne warunki, np. deszcz, mgłę, lód, zaćmienie.
- Nagrody mogą być wspomnieniami ze wspólnej podróży lub rzeczami przekazywanymi przyjacielowi.
- Widoczność tylko w ruchu raczej do mapy i przerywników; w walce oszczędnie.

## Muzyka: główna idea
- Utwór powstaje w trakcie walki: dźwięki oręża i otoczenia wygrywają muzykę autora.
- Ataki bossa wynikają z nut w MIDI, więc komponowanie jest też projektowaniem walki.
- Boss zadaje muzyczne pytanie, a blok, unik lub kontra na nie odpowiada.
- Gra delikatnie dopasowuje dźwięk do rytmu, a cios ma wyglądać na natychmiastowy.
- Przykładowe mapowanie: serce = puls, kroki bossa = bas, zderzenia oręża = melodia,
  deszcz = hi-hat, uderzenie w taflę = talerz, oddech lub wiatr = tło.
- Nieudana obrona wycina nutę, więc utwór traci kolejne warstwy.
- Po wygranej robi się cicho, a potem gracz po raz pierwszy słyszy pełny utwór.
- Melodie powinny być oszczędne. Kulminacje muzyki i walki powinny wypadać razem.
- Dźwięki gracza muszą grać bez wyczuwalnego opóźnienia.

## Technologia
- **Godot 4 (4.7), od razu, bez prototypu w przeglądarce.** GDScript, renderer GL Compatibility
  (najlżejszy), rozdzielczość wewnętrzna 480×270 (taką ma grafika sceny lasu), skalowana
  całkowitą wielokrotnością. Prototyp rytmu został przy 320×180.
- Muzyka: LMMS → eksport MIDI → gra czyta plik MIDI i sama z niego buduje walkę.
- Alternatywa na później: raylib, jeśli ważniejszy będzie mały plik wykonywalny.
- Assembler odrzucony: mały zysk wydajności, utrata przenośności i droższe poprawki.
- Grafika: bossowie mogą być złożeni z części poruszanych kodem, co ograniczy liczbę ręcznie rysowanych klatek.
- Steam: 100 USD za grę, zwrot po 1000 USD przychodu, 30 dni od opłaty do premiery.
  Z 20 zł zostaje około 11 zł przed podatkiem. Sprawdzić aktualne zasady ujawniania treści AI.

## Główne ryzyko
- Czytelność walki w odwróconym odbiciu, zwłaszcza przy szybkich atakach.
  Bez interfejsu to ryzyko rośnie: każdy sygnał musi być czytelny z samego otoczenia.

## Nierozstrzygnięte
- Ostateczny wygląd odbicia i sposób rozwiązania odwrócenia góra-dół.
- Wygląd i imiona bohatera oraz przyjaciela.
- Szczegółowa lista bossów, nagród i liczba poziomów.
- Jak pokazać różne rodzaje obrony (blok, unik, kontra) bez interfejsu.

## Rozstrzygnięte
- Przyjaciel: człowiek, druga postać, szedł śladem bohatera z troski.
- Program do komponowania: LMMS.
- Pierwszy prototyp: od razu w Godocie.
- Interfejs: brak; wszystko przez otoczenie.

## Etapy
1. **Prototyp rytmu (zrobiony):** 20 sekund motywu z MIDI, serce w tle, jeden przycisk
   do wybijania nut na zapowiedziane sygnały, przytomność zamiast paska zdrowia,
   cisza i pełny utwór po wygranej.
2. **Scena lasu z ruchem (zrobiona):** las nad jeziorkiem z grafiki, przyjaciel chodzi w lewo i w prawo,
   animowany księżyc (chmury, poświata), woda, mgła i dźwięki lasu. Bez przeciwnika.
3. **Ruch bojowy (zrobiony, bez przeciwnika):** żwawy bieg, przewrót (unik), cięcia przed siebie i w górę
   z białą smugą, w stylu Hollow Knight, bez skoku. Cięcia nie są jeszcze powiązane z rytmem MIDI.
4. **Następny test: walka w odbiciu.** Sylwetki przyjaciela i bossa w kałuży, odwrócenie obrazu,
   sprawdzenie czytelności szybkich ataków.
