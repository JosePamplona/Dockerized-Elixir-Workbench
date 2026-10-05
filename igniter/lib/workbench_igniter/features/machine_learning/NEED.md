# machine_learning

You want a model's answer inside your application, without running a second service in another language beside it.

**Before:** the model lives in a service of its own: another runtime to deploy, a network call for every answer, and two codebases to keep in step.

**After:** the model is loaded once and served by the application's own supervision tree, which batches the requests of every caller; asking it is a function call.

**Not for:** training a model — it serves one that already exists; nor work that needs a GPU, which a container on a laptop usually does not have.
