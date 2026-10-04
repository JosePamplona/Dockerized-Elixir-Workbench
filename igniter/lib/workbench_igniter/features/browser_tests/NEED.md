# browser_tests

You need to know the page works in a real browser, not only that the server answered.

**Before:** the tests read the HTML the server sent and stop there: a hook that never ran, an upload that never left or a button the script disabled are found by whoever clicks first.

**After:** a browser in the workspace opens the application as a person would, and tests in the project click, type and wait through it, on any machine that has Docker and in CI the same way.

**Not for:** what can be tested without a browser — a view's markup and its events are faster and steadier tested where they are rendered; a browser is for what only a browser does.
