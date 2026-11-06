class_name Palette
extends RefCounted
## Ograniczona paleta gry: zimne, nocne odcienie i jeden mocny kolor akcentu.
## Wszystkie kolory w grze biorą się stąd - zmiana tutaj zmienia nastrój całej sceny.

const NIGHT := Color("07080c")        ## tło, najciemniejsza noc
const GROUND := Color("0d0f15")       ## ziemia wokół kałuży
const WATER := Color("121926")        ## tafla wody
const WATER_EDGE := Color("1d2738")   ## brzeg tafli, odbite niebo
const MIST := Color("3b475a")         ## słabe światło, fale, poświaty
const MOON_GLOW := Color("6a7f99")    ## poświata księżyca
const MOON := Color("d3dfea")         ## księżyc w odbiciu
const ACCENT := Color("ff8a3d")       ## jedyny ciepły kolor: błysk ostrza, trafienie
const BLACK := Color("000000")        ## powieki, omdlenie
