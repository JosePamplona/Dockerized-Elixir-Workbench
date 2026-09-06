# The code faces

The faces the console's Terminal, Logs and code blocks can be set in,
from the workbench drawer (`?wb=ui`, *The code* and *The files*, chosen apart). Served as they are
from `/assets/fonts/`; `console.css` declares each `@font-face`, and
`hooks.js` knows which sizes each face brings.

| Face | Files | Where from | Licence |
| --- | --- | --- | --- |
| Fira Code | `fira_code00x14r.ttf`, `fira_code00x14b.ttf` | <https://github.com/tonsky/FiraCode> | SIL Open Font License 1.1 |
| Flexi IBM VGA True | `flexi_IBM_VGA00x20r.ttf` (`…b.ttf` is the same file: the pack has no bold) | The Ultimate Oldschool PC Font Pack, VileR — <https://int10h.org/oldschool-pc-fonts/> | CC BY-SA 4.0 |
| Tamzen 5x9 … 10x20 | `TamzenWWxHHr.ttf`, `TamzenWWxHHb.ttf`, one pair per size | Scott Fial, after Tamsyn — <https://github.com/sunaku/tamzen-font> | Tamsyn's, free to use and redistribute |

The file names say the cell, `WWxHH` in pixels, and the weight, `r` or
`b`. Tamzen is a bitmap face turned into outlines: each pair is one
drawing, right at its own pixel height and blurred at any other, so
the drawer offers exactly those seven sizes for it. The vector faces
take any size.