# mailer

You want to see the mail your app sends before anyone else does.

**Before:** a real SMTP account wired into dev, or `IO.inspect` on the email struct; a mail that leaves for a real address from a laptop.

**After:** every mail delivered in dev lands in `/dev/mailbox`, open in the browser; tests assert on it through the `Test` adapter; production sends through the adapter you configure in `runtime.exs`.

**Not for:** choosing a provider — that is your account and one config line, and `phx.new` leaves it as a comment.
