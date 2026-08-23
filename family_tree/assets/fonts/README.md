# Bundled type

Manrope carries the Latin text; Noto Sans Ethiopic is registered as its
fallback, so a heading in አማርኛ has the same weight and colour as the same
heading in English.

These files are committed rather than fetched at runtime. `google_fonts`
downloads a face the first time it is asked for one, which means the first
launch on a slow connection shows system type — and Amharic in particular
falls back to whatever the device happens to have, which is the exact problem
the single-family choice was made to solve. A family member opening the app for
the first time, on a phone with little signal, is a case worth designing for
rather than one to leave to the network.

Both families are licensed under the SIL Open Font License 1.1; the licences
are next to them. Weights are static instances (400/500/600/700, plus 800 for
Manrope) rather than variable fonts, so Flutter picks a face by `fontWeight`
with no `FontVariation` plumbing.

To refresh them, take the URLs from:

    curl -A "" "https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&family=Noto+Sans+Ethiopic:wght@400;500;600;700"
