# healthcheck

Your teammates and your monitoring want to ask the app how it is.

**Before:** logging into the server to find out.

**After:** a public JSON route that answers at once — versions, environment and database details in dev, and an entry in the Swagger page.

**Not for:** an orchestrator's probes — for those, `healthcheck2`, which answers a probe and gets out of the way.
