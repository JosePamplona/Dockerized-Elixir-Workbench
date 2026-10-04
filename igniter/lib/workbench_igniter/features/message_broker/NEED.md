# message_broker

Two parts of your system have to talk to each other without waiting for each other.

**Before:** one calls the other and waits: when the second is slow or down, so is the first, and the work in flight is lost with the request.

**After:** a broker in the workspace takes the message and keeps it until it is handled; the app publishes and consumes through a supervised pipeline, and the broker's own page shows the queues.

**Not for:** work this application does later on its own — a job queue on the database you already have does that; nor a log that consumers read again — that is `event_stream`.
