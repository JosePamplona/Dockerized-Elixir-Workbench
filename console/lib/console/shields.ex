defmodule Console.Shields do
  @moduledoc """
  A shields.io static badge, drawn here from its own address: the SVG
  the service would have sent, to the byte, with no request to anyone.

  The console's policy loads no image from another origin, and a badge
  under a README's title is exactly that. But a static badge says
  everything in its address — `/badge/<label>-<message>-<colour>`, the
  style and the overrides in the query — and what shields does with it
  is published: badge-maker (CC0) lays the text out by looking its
  width up in a table of Verdana's advances (anafanafo, MIT — the
  tables are `priv/shields/`) and pins it with `textLength`, so the
  badge is the same on a machine without Verdana. This module is that
  renderer, followed line by line and checked against the service's own
  answers (`test/fixtures/shields/`): the route's expression and its
  escapes, the colour names and the CSS ones, the brightness that turns
  the text dark on a light ground, the rounding up to odd widths, the
  four styles whose tables are here — flat, flat-square, plastic,
  for-the-badge.

  What it does not draw, it says it does not (`:error`), and the paper
  falls back to a link: the social style (Helvetica's table, another
  layout), a logo (simple-icons, which is a request), and anything
  that is not a static badge — a dynamic one's message is the service's
  to know.
  """

  @named %{
    "brightgreen" => "#4b0",
    "green" => "#67ac09",
    "yellow" => "#d8b800",
    "yellowgreen" => "#95991a",
    "orange" => "#ea7233",
    "red" => "#dd4343",
    "blue" => "#007ec6",
    "grey" => "#555",
    "lightgrey" => "#939393"
  }

  @aliases %{
    "gray" => "grey",
    "lightgray" => "lightgrey",
    "critical" => "red",
    "important" => "orange",
    "success" => "brightgreen",
    "informational" => "blue",
    "inactive" => "lightgrey"
  }

  # CSS's colour names (the `color-name` package, as css-color-converter reads them).
  @css %{
    "aliceblue" => {240, 248, 255},
    "antiquewhite" => {250, 235, 215},
    "aqua" => {0, 255, 255},
    "aquamarine" => {127, 255, 212},
    "azure" => {240, 255, 255},
    "beige" => {245, 245, 220},
    "bisque" => {255, 228, 196},
    "black" => {0, 0, 0},
    "blanchedalmond" => {255, 235, 205},
    "blue" => {0, 0, 255},
    "blueviolet" => {138, 43, 226},
    "brown" => {165, 42, 42},
    "burlywood" => {222, 184, 135},
    "cadetblue" => {95, 158, 160},
    "chartreuse" => {127, 255, 0},
    "chocolate" => {210, 105, 30},
    "coral" => {255, 127, 80},
    "cornflowerblue" => {100, 149, 237},
    "cornsilk" => {255, 248, 220},
    "crimson" => {220, 20, 60},
    "cyan" => {0, 255, 255},
    "darkblue" => {0, 0, 139},
    "darkcyan" => {0, 139, 139},
    "darkgoldenrod" => {184, 134, 11},
    "darkgray" => {169, 169, 169},
    "darkgreen" => {0, 100, 0},
    "darkgrey" => {169, 169, 169},
    "darkkhaki" => {189, 183, 107},
    "darkmagenta" => {139, 0, 139},
    "darkolivegreen" => {85, 107, 47},
    "darkorange" => {255, 140, 0},
    "darkorchid" => {153, 50, 204},
    "darkred" => {139, 0, 0},
    "darksalmon" => {233, 150, 122},
    "darkseagreen" => {143, 188, 143},
    "darkslateblue" => {72, 61, 139},
    "darkslategray" => {47, 79, 79},
    "darkslategrey" => {47, 79, 79},
    "darkturquoise" => {0, 206, 209},
    "darkviolet" => {148, 0, 211},
    "deeppink" => {255, 20, 147},
    "deepskyblue" => {0, 191, 255},
    "dimgray" => {105, 105, 105},
    "dimgrey" => {105, 105, 105},
    "dodgerblue" => {30, 144, 255},
    "firebrick" => {178, 34, 34},
    "floralwhite" => {255, 250, 240},
    "forestgreen" => {34, 139, 34},
    "fuchsia" => {255, 0, 255},
    "gainsboro" => {220, 220, 220},
    "ghostwhite" => {248, 248, 255},
    "gold" => {255, 215, 0},
    "goldenrod" => {218, 165, 32},
    "gray" => {128, 128, 128},
    "green" => {0, 128, 0},
    "greenyellow" => {173, 255, 47},
    "grey" => {128, 128, 128},
    "honeydew" => {240, 255, 240},
    "hotpink" => {255, 105, 180},
    "indianred" => {205, 92, 92},
    "indigo" => {75, 0, 130},
    "ivory" => {255, 255, 240},
    "khaki" => {240, 230, 140},
    "lavender" => {230, 230, 250},
    "lavenderblush" => {255, 240, 245},
    "lawngreen" => {124, 252, 0},
    "lemonchiffon" => {255, 250, 205},
    "lightblue" => {173, 216, 230},
    "lightcoral" => {240, 128, 128},
    "lightcyan" => {224, 255, 255},
    "lightgoldenrodyellow" => {250, 250, 210},
    "lightgray" => {211, 211, 211},
    "lightgreen" => {144, 238, 144},
    "lightgrey" => {211, 211, 211},
    "lightpink" => {255, 182, 193},
    "lightsalmon" => {255, 160, 122},
    "lightseagreen" => {32, 178, 170},
    "lightskyblue" => {135, 206, 250},
    "lightslategray" => {119, 136, 153},
    "lightslategrey" => {119, 136, 153},
    "lightsteelblue" => {176, 196, 222},
    "lightyellow" => {255, 255, 224},
    "lime" => {0, 255, 0},
    "limegreen" => {50, 205, 50},
    "linen" => {250, 240, 230},
    "magenta" => {255, 0, 255},
    "maroon" => {128, 0, 0},
    "mediumaquamarine" => {102, 205, 170},
    "mediumblue" => {0, 0, 205},
    "mediumorchid" => {186, 85, 211},
    "mediumpurple" => {147, 112, 219},
    "mediumseagreen" => {60, 179, 113},
    "mediumslateblue" => {123, 104, 238},
    "mediumspringgreen" => {0, 250, 154},
    "mediumturquoise" => {72, 209, 204},
    "mediumvioletred" => {199, 21, 133},
    "midnightblue" => {25, 25, 112},
    "mintcream" => {245, 255, 250},
    "mistyrose" => {255, 228, 225},
    "moccasin" => {255, 228, 181},
    "navajowhite" => {255, 222, 173},
    "navy" => {0, 0, 128},
    "oldlace" => {253, 245, 230},
    "olive" => {128, 128, 0},
    "olivedrab" => {107, 142, 35},
    "orange" => {255, 165, 0},
    "orangered" => {255, 69, 0},
    "orchid" => {218, 112, 214},
    "palegoldenrod" => {238, 232, 170},
    "palegreen" => {152, 251, 152},
    "paleturquoise" => {175, 238, 238},
    "palevioletred" => {219, 112, 147},
    "papayawhip" => {255, 239, 213},
    "peachpuff" => {255, 218, 185},
    "peru" => {205, 133, 63},
    "pink" => {255, 192, 203},
    "plum" => {221, 160, 221},
    "powderblue" => {176, 224, 230},
    "purple" => {128, 0, 128},
    "rebeccapurple" => {102, 51, 153},
    "red" => {255, 0, 0},
    "rosybrown" => {188, 143, 143},
    "royalblue" => {65, 105, 225},
    "saddlebrown" => {139, 69, 19},
    "salmon" => {250, 128, 114},
    "sandybrown" => {244, 164, 96},
    "seagreen" => {46, 139, 87},
    "seashell" => {255, 245, 238},
    "sienna" => {160, 82, 45},
    "silver" => {192, 192, 192},
    "skyblue" => {135, 206, 235},
    "slateblue" => {106, 90, 205},
    "slategray" => {112, 128, 144},
    "slategrey" => {112, 128, 144},
    "snow" => {255, 250, 250},
    "springgreen" => {0, 255, 127},
    "steelblue" => {70, 130, 180},
    "tan" => {210, 180, 140},
    "teal" => {0, 128, 128},
    "thistle" => {216, 191, 216},
    "tomato" => {255, 99, 71},
    "turquoise" => {64, 224, 208},
    "violet" => {238, 130, 238},
    "wheat" => {245, 222, 179},
    "white" => {255, 255, 255},
    "whitesmoke" => {245, 245, 245},
    "yellow" => {255, 255, 0},
    "yellowgreen" => {154, 205, 50}
  }

  @font_family "Verdana,Geneva,DejaVu Sans,sans-serif"
  @route ~r"^/badge/((?:[^-]|--)*?)-?((?:[^-]|--)*)-((?:[^-.]|--)+)(?:\.(svg|png|gif|jpg|json))?$"
  @styles ~w(flat flat-square plastic for-the-badge social)

  @doc """
  The badge at this address: `{:ok, %{svg:, width:, height:, alt:}}`, or
  `:error` when it is not a static badge this module draws.
  """
  @spec badge(String.t()) :: {:ok, map()} | :error
  def badge(url) when is_binary(url) do
    with %URI{host: "img.shields.io", path: path} = uri when is_binary(path) <- URI.parse(url),
         [_, label, message, colour | ext] <- Regex.run(@route, path),
         true <- ext != ["json"],
         query = URI.decode_query(uri.query || ""),
         true <- query["logo"] in [nil, ""],
         style = style(query["style"]),
         true <- style != "social" do
      [label, message, colour] =
        Enum.map([label, message, colour], &(&1 |> decode() |> unescape()))

      label = String.trim(query["label"] || label)
      message = String.trim(message)
      colour = svg_colour(query["color"] || query["colorB"] || colour)
      label_colour = svg_colour(query["labelColor"] || query["colorA"])

      {:ok, render(style, label, message, colour, label_colour)}
    else
      _ -> :error
    end
  end

  defp style(style) when style in @styles, do: style
  defp style(_), do: "flat"

  defp decode(text) do
    URI.decode(text)
  rescue
    _ -> text
  end

  # The badge format's escapes (shields' `escapeFormat`): a single
  # underscore is a space, a double one an underscore, a double dash a dash.
  defp unescape(text) do
    text
    |> then(&Regex.replace(~r/(^|[^_])((?:__)*)_(?!_)/, &1, "\\1\\2 "))
    |> String.replace("__", "_")
    |> String.replace("--", "-")
  end

  # --- colours --------------------------------------------------------------------

  # badge-maker's `toSvgColor`: a shields name or alias is its hex; bare
  # hex digits get their `#`; anything CSS reads is kept, lowercased;
  # the rest is no colour, and the renderer's default stands.
  defp svg_colour(nil), do: nil

  defp svg_colour(colour) do
    cond do
      Map.has_key?(@named, colour) -> @named[colour]
      Map.has_key?(@aliases, colour) -> @named[@aliases[colour]]
      Regex.match?(~r/^([\da-f]{3}){1,2}$/i, colour) -> "#" <> String.downcase(colour)
      rgb(String.trim(colour)) -> String.downcase(colour)
      true -> nil
    end
  end

  # css-color-converter's `fromString`, as far as red, green and blue:
  # a name, hex with its `#`, `rgb()` in its four spellings, `hsl()`.
  defp rgb(colour) do
    cond do
      Map.has_key?(@css, colour) ->
        @css[colour]

      m =
          Regex.run(
            ~r/^#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})?$/,
            colour
          ) ->
        m |> Enum.slice(1, 3) |> Enum.map(&String.to_integer(&1, 16)) |> List.to_tuple()

      m = Regex.run(~r/^#([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])?$/, colour) ->
        m |> Enum.slice(1, 3) |> Enum.map(&String.to_integer(&1 <> &1, 16)) |> List.to_tuple()

      m =
          Regex.run(
            ~r/^rgba?\(\s*(\d+%?)\s*,\s*(\d+%?)\s*,\s*(\d+%?)(?:\s*,\s*(?:0|1|0?\.\d+|\d+%))?\s*\)$/,
            colour
          ) ||
            Regex.run(
              ~r/^rgba?\(\s*(\d+%?)\s+(\d+%?)\s+(\d+%?)(?:\s*\/\s*(?:0|1|0?\.\d+|\d+%))?\s*\)$/,
              colour
            ) ->
        parts = Enum.slice(m, 1, 3)
        percents = Enum.count(parts, &String.ends_with?(&1, "%"))

        if percents in [0, 3] do
          parts
          |> Enum.map(fn part ->
            {n, rest} = Integer.parse(part)
            value = if rest == "%", do: trunc(n * 255 / 100), else: n
            value |> min(255) |> max(0)
          end)
          |> List.to_tuple()
        end

      m =
          Regex.run(
            ~r/^hsla?\(\s*(\d+)(deg|rad|grad|turn)?\s*,\s*(\d+)%\s*,\s*(\d+)%(?:\s*,\s*(?:0|1|0?\.\d+|\d+%))?\s*\)$/,
            colour
          ) ->
        [_, h, unit, s, l | _] = m
        h = String.to_integer(h)

        degrees =
          case unit do
            "rad" -> h * 180 / :math.pi()
            "grad" -> h * 0.9
            "turn" -> h * 360
            _ -> h
          end

        hsl_to_rgb(degrees, String.to_integer(s), String.to_integer(l))

      true ->
        nil
    end
  end

  defp hsl_to_rgb(h, s, l) do
    hp = h / 60
    sp = s / 100
    lp = l / 100
    c = (1 - abs(2 * lp - 1)) * sp
    x = c * (1 - abs(:math.fmod(hp, 2) - 1))
    m = lp - c / 2

    {r, g, b} =
      cond do
        hp < 1 -> {c, x, 0}
        hp < 2 -> {x, c, 0}
        hp < 3 -> {0, c, x}
        hp < 4 -> {0, x, c}
        hp < 5 -> {x, 0, c}
        true -> {c, 0, x}
      end

    [r, g, b]
    |> Enum.map(&(trunc((&1 + m) * 255) |> min(255) |> max(0)))
    |> List.to_tuple()
  end

  # The text on a ground: white with a dark shadow, and past a
  # brightness of .69 dark with a light one.
  defp inks(colour) do
    brightness =
      case rgb(colour) do
        {r, g, b} -> Float.round((r * 299 + g * 587 + b * 114) / 255_000, 2)
        nil -> 0.0
      end

    if brightness <= 0.69, do: {"#fff", "#010101"}, else: {"#333", "#ccc"}
  end

  # --- widths ---------------------------------------------------------------------

  @tables %{
    "11px Verdana" => "verdana-11px-normal.json",
    "10px Verdana" => "verdana-10px-normal.json",
    "bold 10px Verdana" => "verdana-10px-bold.json"
  }

  # anafanafo's measure: the advances of the text's code points, added
  # left to right as doubles — the order is the sum's last digit, and
  # `| 0` reads it. A control character has no width, and one the table
  # lacks is as wide as an `m`.
  defp width_of(text, font) do
    table = table(font)
    em = advance(table, ?m)

    text
    |> String.to_charlist()
    |> Enum.reduce(0.0, fn cp, sum ->
      cond do
        cp <= 31 or cp == 127 -> sum
        w = advance(table, cp) -> sum + w
        true -> sum + em
      end
    end)
  end

  defp table(font) do
    key = {__MODULE__, font}

    case :persistent_term.get(key, nil) do
      nil ->
        table =
          :console
          |> Application.app_dir("priv/shields/" <> @tables[font])
          |> File.read!()
          |> Jason.decode!()
          |> Enum.map(&List.to_tuple/1)
          |> List.to_tuple()

        :persistent_term.put(key, table)
        table

      table ->
        table
    end
  end

  defp advance(table, cp), do: search(table, cp, 0, tuple_size(table) - 1)

  defp search(_table, _cp, low, high) when low > high, do: nil

  defp search(table, cp, low, high) do
    mid = div(low + high, 2)
    {lower, upper, width} = elem(table, mid)

    cond do
      cp < lower -> search(table, cp, low, mid - 1)
      cp > upper -> search(table, cp, mid + 1, high)
      true -> width * 1.0
    end
  end

  # Increase chances of pixel grid alignment, in badge-maker's words.
  defp odd_width(text) do
    w = trunc(width_of(text, "11px Verdana"))
    if rem(w, 2) == 0, do: w + 1, else: w
  end

  # --- rendering ------------------------------------------------------------------

  defp render("for-the-badge", label, message, colour, label_colour),
    do: for_the_badge(label, message, colour || "#4b0", label_colour)

  defp render(style, label, message, colour, label_colour) do
    colour = colour || "#4b0"
    has_label = label != "" or label_colour != nil
    label_colour = if has_label, do: label_colour || "#555", else: colour

    {height, margin, shadow?} =
      case style do
        "plastic" -> {18, -10, true}
        "flat" -> {20, 0, true}
        "flat-square" -> {20, 0, false}
      end

    label_width = if label == "", do: 0, else: odd_width(label)
    left = if has_label, do: label_width + 10, else: 0
    message_width = odd_width(message)
    message_margin = left - if(message == "", do: 0, else: 1) + if(has_label, do: 0, else: 1)
    right = message_width + 10
    width = left + right

    text = fn content, left_margin, ground, text_width ->
      if content == "" do
        ""
      else
        {ink, shade} = inks(ground)
        x = 10 * left_margin + 5 * text_width + 50
        y = 140 + margin
        len = 10 * text_width
        fill = if ink == "#fff", do: "", else: ~s| fill="#{ink}"|
        t = xml(content)

        if shadow? do
          ~s|<g transform="scale(.1)"><g aria-hidden="true" fill="#{shade}">| <>
            ~s|<text x="#{x}" y="#{y + 10}" fill-opacity=".8" filter="url(#blur)" textLength="#{len}">#{t}</text>| <>
            ~s|<text x="#{x}" y="#{y + 10}" fill-opacity=".3" textLength="#{len}">#{t}</text></g>| <>
            ~s|<text x="#{x}" y="#{y}" textLength="#{len}"#{fill}>#{t}</text></g>|
        else
          ~s|<text x="#{x}" y="#{y}" textLength="#{len}" transform="scale(.1)"#{fill}>#{t}</text>|
        end
      end
    end

    rects =
      ~s|<rect width="#{left}" height="#{height}" fill="#{xml(label_colour)}"/>| <>
        ~s|<rect x="#{left}" width="#{right}" height="#{height}" fill="#{xml(colour)}"/>|

    gradient = ~s|<rect width="#{width}" height="#{height}" fill="url(#s)"/>|
    blur = ~s|<filter id="blur"><feGaussianBlur stdDeviation="16"/></filter>|

    clip = fn rx ->
      ~s|<clipPath id="r"><rect width="#{width}" height="#{height}" rx="#{rx}"/></clipPath>|
    end

    body =
      case style do
        "flat" ->
          blur <>
            ~s|<linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/>| <>
            ~s|<stop offset="1" stop-opacity=".1"/></linearGradient>| <>
            clip.(3) <> ~s|<g clip-path="url(#r)">| <> rects <> gradient <> "</g>"

        "plastic" ->
          blur <>
            ~s|<linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#fff" stop-opacity=".7"/>| <>
            ~s|<stop offset=".1" stop-color="#aaa" stop-opacity=".1"/><stop offset=".9" stop-color="#000" stop-opacity=".3"/>| <>
            ~s|<stop offset="1" stop-color="#000" stop-opacity=".5"/></linearGradient>| <>
            clip.(4) <> ~s|<g clip-path="url(#r)">| <> rects <> gradient <> "</g>"

        "flat-square" ->
          ~s|<g shape-rendering="crispEdges">| <> rects <> "</g>"
      end

    foreground =
      ~s|<g fill="#fff" text-anchor="middle" font-family="#{@font_family}" text-rendering="geometricPrecision" font-size="110">| <>
        text.(label, 1, label_colour, label_width) <>
        text.(message, message_margin, colour, message_width) <> "</g>"

    svg(width, height, label, message, body <> foreground)
  end

  # All caps, the message bold, and the letters spaced: the widths are
  # Verdana 10px's, plus 1.25 for each UTF-16 unit — badge-maker counts
  # `.length`, and says it should not.
  defp for_the_badge(label, message, colour, label_colour) do
    label = String.upcase(label)
    message = String.upcase(message)
    label_colour = label_colour || "#555"
    has_label = label != ""

    label_width =
      if has_label, do: trunc(width_of(label, "10px Verdana")) + 1.25 * units(label), else: 0

    message_width =
      if message == "",
        do: 0,
        else: trunc(width_of(message, "bold 10px Verdana")) + 1.25 * units(message)

    label_rect = if has_label, do: 12 + label_width + 12, else: 0
    message_min = if has_label, do: label_rect + 12, else: 12
    message_rect = 24 + message_width

    text = fn content, min_x, text_width, ground, bold ->
      {ink, _shade} = inks(ground)
      fill = if ink == "#fff", do: "", else: ~s| fill="#{ink}"|

      ~s|<text transform="scale(.1)" x="#{num(10 * (min_x + 0.5 * text_width))}" y="175" textLength="#{num(10 * text_width)}"#{bold}#{fill}>#{xml(content)}</text>|
    end

    rects =
      if has_label do
        ~s|<rect width="#{num(label_rect)}" height="28" fill="#{xml(label_colour)}"/>| <>
          ~s|<rect x="#{num(label_rect)}" width="#{num(message_rect)}" height="28" fill="#{xml(colour)}"/>|
      else
        ~s|<rect width="#{num(message_rect)}" height="28" fill="#{xml(colour)}"/>|
      end

    body =
      ~s|<g shape-rendering="crispEdges">| <>
        rects <>
        "</g>" <>
        ~s|<g fill="#fff" text-anchor="middle" font-family="#{@font_family}" text-rendering="geometricPrecision" font-size="100">| <>
        if(has_label, do: text.(label, 12, label_width, label_colour, ""), else: "") <>
        text.(message, message_min, message_width, colour, ~s| font-weight="bold"|) <> "</g>"

    svg(label_rect + message_rect, 28, label, message, body)
  end

  defp svg(width, height, label, message, body) do
    alt = if label == "", do: message, else: "#{label}: #{message}"

    %{
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" width="#{num(width)}" height="#{height}" role="img" aria-label="#{xml(alt)}">| <>
          "<title>#{xml(alt)}</title>" <> body <> "</svg>",
      width: width,
      height: height,
      alt: alt
    }
  end

  defp units(text),
    do: text |> :unicode.characters_to_binary(:utf8, {:utf16, :big}) |> byte_size() |> div(2)

  # A number as JavaScript writes it: no `.0` on a whole one.
  defp num(n) when is_integer(n), do: Integer.to_string(n)

  defp num(n) when is_float(n),
    do: if(n == trunc(n), do: Integer.to_string(trunc(n)), else: Float.to_string(n))

  defp xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
