# event_stream

You need a record of events that several consumers can read again, each at its own pace.

**Before:** an event is delivered once and gone: a consumer that arrives later starts from nothing, and one that fell behind or had a bug cannot go back.

**After:** a log in the workspace that keeps the events in order for as long as you say; each group of consumers reads from its own position, and can rewind it.

**Not for:** handing one task to one worker — `message_broker` does that with less to run; nor messages between the nodes of one application, which Phoenix PubSub already carries.
