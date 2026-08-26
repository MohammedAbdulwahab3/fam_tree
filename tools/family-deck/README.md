# The family tree as a presentation

Builds a PowerPoint deck of the whole tree — every name, and the parent that
places it — from the seed data in `backend/seed/seed.go`.

```bash
cd tools/family-deck
npm install
npm run build          # writes Mammaduu-Family-Tree.pptx
```

Nineteen slides: the seven sons, then each branch opened in turn, then a
complete index of everybody in tree order. The output is not committed — it is
regenerated from the source whenever the tree changes.

## Where the names come from

`parse_tree.py` reads the `familyTreeNodes` literal out of `seed/seed.go` and
writes it as JSON. It is a parser rather than a transcription on purpose: the
tree is 205 people deep in six generations, and a hand-copied version of it
would be wrong within a week of anybody editing the seed.

The check that matters is that the number of `n(...)` calls in the Go literal
equals the number of nodes parsed. Both are 205.

## Two things the deck does deliberately

**Names are title-cased for display only.** The recorded data is inconsistent —
`Eliyas seid`, `zikera Abduljebar`, `batool feysel` — and the record is left
exactly as it is. Only the slides are normalised.

**Surnames are never dropped to save space.** It is tempting, because most
children take their father's first name as their surname and repeating it reads
as noise. But 64 of the 204 children do not: a woman's children take their
husband's name, so Kheria Muzeyen's children are Muhaba, Almaz's are Mohammed,
and Temima Mustefa's are MohammedAmin. Shortening those would erase who the
father was.

## If the tree has moved on

This reads the seeded tree, not the live database. Once the family has been
edited through the app, point the parser at `GET /api/persons` instead — the
shape it produces is the same `{first, last, gender, children}` nesting.
