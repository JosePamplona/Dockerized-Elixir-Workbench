# rest

Other systems will talk to your app, and need a contract to do it.

**Before:** routes without a spec, documented by reading the controllers.

**After:** `/api/v1` as the home of every endpoint, an OpenAPI spec kept beside the code, SwaggerUI at `/dev/swagger`.

**Not for:** alongside `graphql` — one interface per project.
