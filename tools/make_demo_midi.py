#!/usr/bin/env python3
"""Tworzy music/prototyp.mid - 20-sekundowy motyw do pierwszego prototypu.

To tylko zastępstwo, dopóki autor nie wyeksportuje własnego utworu z LMMS.
Uruchomienie (z katalogu repozytorium):  python3 tools/make_demo_midi.py

Ścieżki są nazwane tak, jak oczekuje gra (patrz README, sekcja "Muzyka"):
  serce - puls w tle, gra go sama
  tlo   - plama harmonii w tle, gra ją sama
  boss  - pytania bossa, gra je sama
  gracz - odpowiedzi, które gracz wybija przyciskiem
"""

import struct
from pathlib import Path

PPQ = 480          # tyknięć na ćwierćnutę
BPM = 96           # 32 ćwierćnuty = 20 sekund
OUT = Path(__file__).resolve().parent.parent / "music" / "prototyp.mid"

# Nazwy dźwięków -> numery MIDI (C4 = 60).
NAMES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
         "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def pitch(name: str) -> int:
    note, octave = name[:-1], int(name[-1])
    return 12 * (octave + 1) + NAMES[note]


# (początek w ćwierćnutach, długość w ćwierćnutach, dźwięk, głośność 1-127)
HEART = []
for beat in range(32):
    HEART.append((beat, 0.2, "A1", 110))         # "lub"
    HEART.append((beat + 0.25, 0.2, "A1", 70))   # "dub"

BACKGROUND = []
for start, length, chord in [(4, 8, ["A2", "E3", "C4"]),
                             (12, 8, ["F2", "C3", "A3"]),
                             (20, 8, ["G2", "D3", "B3"]),
                             (28, 4, ["A2", "E3", "A3", "C4"])]:
    for name in chord:
        BACKGROUND.append((start, length, name, 50))

BOSS = [
    # takt 2: pierwsze pytanie
    (4, 1, "E3", 100), (5, 1, "D3", 100), (6, 2, "C3", 100),
    # takt 4
    (12, 0.5, "F3", 100), (12.5, 0.5, "E3", 100), (13, 1, "D3", 100), (14, 2, "C3", 100),
    # takt 6
    (20, 0.5, "G3", 105), (20.5, 0.5, "F3", 105), (21, 0.5, "E3", 105),
    (21.5, 0.5, "D3", 105), (22, 2, "B2", 105),
    # takt 8: kulminacja razem z graczem
    (28, 4, "A2", 120),
]

PLAYER = [
    # takt 3: odpowiedź
    (8, 1, "A4", 100), (9, 1, "C5", 100), (10, 2, "E5", 100),
    # takt 5
    (16, 0.5, "A4", 100), (16.5, 0.5, "C5", 100), (17, 1, "D5", 100), (18, 2, "E5", 100),
    # takt 7
    (24, 0.5, "G4", 105), (24.5, 0.5, "B4", 105), (25, 0.5, "D5", 105),
    (25.5, 0.5, "E5", 105), (26, 2, "G5", 105),
    # takt 8: kulminacja
    (28, 4, "A5", 120),
]


def varlen(value: int) -> bytes:
    out = [value & 0x7F]
    value >>= 7
    while value:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    return bytes(reversed(out))


def track_chunk(name: str, notes, channel: int, extra_meta: bytes = b"") -> bytes:
    events = []  # (tick, kolejność, bajty) - note off przed note on w tym samym tyknięciu
    for start, length, name_or_pitch, velocity in notes:
        p = pitch(name_or_pitch)
        on = round(start * PPQ)
        off = round((start + length) * PPQ)
        events.append((on, 1, bytes([0x90 | channel, p, velocity])))
        events.append((off, 0, bytes([0x80 | channel, p, 0])))
    events.sort(key=lambda e: (e[0], e[1]))

    name_bytes = name.encode("utf-8")
    data = b"\x00\xff\x03" + varlen(len(name_bytes)) + name_bytes + extra_meta
    last = 0
    for tick, _, payload in events:
        data += varlen(tick - last) + payload
        last = tick
    data += b"\x00\xff\x2f\x00"
    return b"MTrk" + struct.pack(">I", len(data)) + data


def main() -> None:
    tempo = round(60_000_000 / BPM)
    conductor_meta = (b"\x00\xff\x51\x03" + tempo.to_bytes(3, "big")
                      + b"\x00\xff\x58\x04\x04\x02\x18\x08")  # metrum 4/4
    tracks = [
        track_chunk("prototyp", [], 0, conductor_meta),
        track_chunk("serce", HEART, 0),
        track_chunk("tlo", BACKGROUND, 1),
        track_chunk("boss", BOSS, 2),
        track_chunk("gracz", PLAYER, 3),
    ]
    header = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), PPQ)
    OUT.write_bytes(header + b"".join(tracks))
    print(f"Zapisano {OUT}")


if __name__ == "__main__":
    main()
