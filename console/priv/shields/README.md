# Width tables for shields.io badges

`Console.Shields` draws a shields.io static badge from its own address,
to the byte the SVG the service would have sent — the console loads no
image from another origin. A badge's geometry is the width of its text
in Verdana, which shields does not measure either: it looks it up in
these tables and pins it with `textLength`.

The three files are [anafanafo](https://github.com/metabolize/anafanafo)
2.0.0's `data/`, unchanged: ranges of code points and the advance of
each, `[lower, upper, width]`, for Verdana 11px (the flat, flat-square
and plastic styles) and Verdana 10px normal and bold (for-the-badge).
MIT, `LICENSE-anafanafo` beside them. The rendering itself follows
[badge-maker](https://github.com/badges/shields/tree/master/badge-maker)
6.0.0, which is CC0.
