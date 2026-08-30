# gettext

Your users don't all read English, and the strings are already written.

**Before:** strings hard-coded in the components and layouts; a second language means touching every template, and a missing translation shows nothing.

**After:** every string `phx.new` wrote is a `gettext` call with the English as its own fallback; a locale is a `.po` file under `priv/gettext`; `mix gettext.extract` finds the strings you add once you wrap them.

**Not for:** translating for you — your own strings still have to be wrapped, and the locale files still have to be filled in.
