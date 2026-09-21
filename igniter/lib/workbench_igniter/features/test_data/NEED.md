# test_data

Your tests need records, and only one value of each is what the test is about.

**Before:** every test builds its user and its order by hand, and the value that matters is lost among the ones that do not.

**After:** `insert(:user, name: "Ana")` — valid defaults written once, the one value in the test, Faker for the rest; on Ash, `generate(user())` through the action.

**Not for:** replacing a collaborator the code calls — that is test_doubles — or the data a production database starts with.
