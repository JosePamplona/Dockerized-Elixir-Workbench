defmodule Console.EventsTest do
  use ExUnit.Case, async: true

  alias Console.Events

  # The app's death in the down of 2026-09-05 11:31, as the daemon told it.
  @die ~s({"status":"die","id":"62662fb9418c","from":"some-test:local","Type":"container","Action":"die","Actor":{"ID":"62662fb9418c","Attributes":{"com.docker.compose.project":"some_test","com.docker.compose.service":"app","exitCode":"137","image":"some-test:local","name":"some_test-app-1"}},"scope":"local","time":1788629493,"timeNano":1788629493000000000})

  test "a die keeps who, how and with what" do
    assert %{type: "container", action: "die", detail: nil, service: "app", project: "some_test", name: "some_test-app-1", exit: "137", ts: %DateTime{}} =
             Events.parse(@die)
  end

  test "the healthchecks' exec events are dropped at the source" do
    assert nil == Events.parse(~s({"Type":"container","Action":"exec_create: bash -c </dev/tcp/localhost/4000","Actor":{"ID":"x","Attributes":{}},"time":1}))
    assert nil == Events.parse(~s({"Type":"container","Action":"exec_die","Actor":{"ID":"x","Attributes":{}},"time":1}))
  end

  test "health_status carries its verdict as the detail" do
    assert %{action: "health_status", detail: "unhealthy", name: "a"} =
             Events.parse(~s({"Type":"container","Action":"health_status: unhealthy","Actor":{"ID":"x","Attributes":{"name":"a"}},"time":1}))
  end

  test "what is not JSON is not an event" do
    assert nil == Events.parse("Error response from daemon: dial unix /var/run/docker.sock: connect: no such file")
  end

  test "only a life event of this project's containers wakes the bench" do
    die = Events.parse(@die)
    assert Events.wakes?(die, "some_test")
    refute Events.wakes?(die, "other_project")
    # Before the status has said which project this is, any will do.
    assert Events.wakes?(die, nil)
    refute Events.wakes?(%{die | action: "attach"}, "some_test")
    refute Events.wakes?(%{die | type: "network"}, "some_test")
  end
end
