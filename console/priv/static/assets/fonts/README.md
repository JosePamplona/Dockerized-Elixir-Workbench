# The code faces

The faces the console's Terminal, Logs and code blocks can be set in,
from the workbench drawer (`?wb=ui`, Terminal and Files, chosen apart). Served as they are
from `/assets/fonts/`; `console.css` declares each `@font-face`, and
`hooks.js` knows which sizes each face brings. The drawer's Faces part
credits them, with the three the pages load from Google Fonts; each
licence is here beside its files, `LICENSE-<face>.txt`, as the SIL Open
Font License, CC BY-SA and MIT ask of a copy that travels.

| Face | Files | Whose | Licence |
| --- | --- | --- | --- |
| Fira Code | `fira_code00x14r.ttf`, `fira_code00x14b.ttf` | Nikita Prokopov and the Fira Code Project Authors — <https://github.com/tonsky/FiraCode> | SIL Open Font License 1.1, `LICENSE-fira_code.txt` |
| Flexi IBM VGA True | `flexi_IBM_VGA00x20r.ttf` (the pack has no bold) | The Ultimate Oldschool PC Font Pack, VileR — <https://int10h.org/oldschool-pc-fonts/> | CC BY-SA 4.0, `LICENSE-flexi_IBM_VGA.txt` |
| Tamzen 5x9 … 10x20 | `TamzenWWxHHr.ttf`, `TamzenWWxHHb.ttf`, one pair per size | Suraj N. Kurapati, after Tamsyn by Scott Fial — <https://github.com/sunaku/tamzen-font> | Tamsyn's, free to use, copy, modify and distribute, `LICENSE-tamzen.txt` |
| Greybeard 6x11 … 11x22 | `GreybeardWWxHHr.woff2`, `GreybeardWWxHHb.woff2`, one pair per size; `…i.woff2` and `…bi.woff2` at 15 to 18 px, the sizes it draws an italic for | Andy Walker, after UW ttyp0 by Uwe Waldmann — <https://github.com/flowchartsman/greybeard> | MIT, `LICENSE-greybeard.txt` |

The file names say the cell, `WWxHH` in pixels, and the weight, `r` or
`b` (`i` and `bi`, the italics). Tamzen and Greybeard are bitmap faces
turned into outlines: each pair is one drawing, right at its own pixel
height and blurred at any other, so the drawer offers exactly its
sizes for each, seven and nine. The vector faces take any size.

Greybeard is here for what Tamzen leaves out: the box drawing, the
blocks and the shades (U+2500 to U+259F, all of them) and Powerline's
marks, each drawn in the face's own cell. Its files are the WOFF2 of
its release v1.0.0, renamed and nothing else.