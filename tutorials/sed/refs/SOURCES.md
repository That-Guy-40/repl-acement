Vendored references
===================

Fetched on 2026-10-29 with `curl`, byte for byte as served (the Krumins
sheet keeps its CRLF line endings). Nothing here was edited.

| File | Source | Author | What it is |
|------|--------|--------|------------|
| `mcmahon-sed.ms` | <https://9p.io/7thEdMan/vol2/sed> | Lee E. McMahon, Bell Laboratories, 15 August 1978 | *SED -- A Non-interactive Text Editor*, the original paper, as troff `-ms` source from Volume 2 of the Seventh Edition UNIX Programmer's Manual (`/usr/doc/sed`). Identical bytes are served from the unix-history-repo on GitHub (`Research-V7-Snapshot-Development/usr/doc/sed`) |
| `mcmahon-sed.html` | <https://wolfram.schneider.org/bsd/7thEdManVol2/sed/sed.html> | the same paper | an HTML rendering of that troff source (generated with unroff 1.0, 1997), readable in a browser; the text is the same |
| `sed1line.txt` | <https://www.pement.org/sed/sed1line.txt> | Eric Pement, "Useful one-line scripts for sed", version 5.5, 29 December 2005 | the one-liner sheet |
| `sed.stream.editor.cheat.sheet.txt` | <https://catonmat.net/ftp/sed.stream.editor.cheat.sheet.txt> | Peteris Krumins, "Sed Cheat Sheet" | the cheat sheet |
| `catonmat-sed-cheat-sheet.html` | <https://catonmat.net/sed-stream-editor-cheat-sheet> | Peteris Krumins, the blog post that introduces the cheat sheet | the post |

Checksums as fetched (run `sha256sum` here to compare):

```
4413e6907c9cfc95853243e3737faeeb97587073cb6d727170727d5cf0f816a8  mcmahon-sed.ms
555dfca58b5e16fd5c59bbd4cf1c422f01a1755967308ead731c26d492c834cd  mcmahon-sed.html
1938a44bedf566f0727a4b9913c8c82dd299a0cef64176d4bbcdf98251084e8d  sed1line.txt
e49317259087d262a69a5039d1b65c00970449db09d55a77697764668ce757d6  sed.stream.editor.cheat.sheet.txt
a734451f6928318497f321d33d27f9b49a2f5e48e47b6cd0d42293eb0c0d51f8  catonmat-sed-cheat-sheet.html
```

Terms
-----

The McMahon paper is part of the Seventh Edition UNIX distribution, which
Caldera International released in 2002 under a BSD-style licence that
permits redistribution with attribution (the "Caldera licence"; see
<https://www.tuhs.org/Archive/Caldera-license.pdf>). The HTML rendering
carries no terms of its own beyond that source.

Neither the Pement sheet nor the Krumins sheet states a licence. Both are
widely mirrored and are kept here, with attribution, for personal study
alongside the tutorials; if either author's current terms say otherwise,
remove the file and use the link.
