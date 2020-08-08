defmodule TelemetryDecoratorTest do
  use ExUnit.Case, async: true

  defmodule MyApp.MyModule do
    use TelemetryDecorator

    @decorate telemetry([:my_app, :succeed], include: [:type])
    def succeed(why, opts \\ []) do
      type = Keyword.get(opts, :type, :ok)
      {type, why}
    end

    @decorate telemetry([:my_app, :crash])
    def crash(why), do: raise(RuntimeError, why)
  end

  def send_handler(name, measurements, metadata, pid) do
    send(pid, {:test_telemetry, name, measurements, metadata})
  end

  describe "happy path" do
    test "result passed through" do
      assert MyApp.MyModule.succeed(:result) == {:ok, :result}
    end

    test "got start" do
      :telemetry.attach(self(), [:my_app, :succeed, :start], &send_handler/4, self())
      MyApp.MyModule.succeed(:result)

      assert_received {
        :test_telemetry,
        [:my_app, :succeed, :start],
        %{system_time: _},
        %{opts: [], why: :result}
      }
    end

    test "got stop" do
      :telemetry.attach(self(), [:my_app, :succeed, :stop], &send_handler/4, self())
      MyApp.MyModule.succeed(:result)

      assert_received {
        :test_telemetry,
        [:my_app, :succeed, :stop],
        %{duration: _},
        %{opts: [], why: :result, type: :ok, result: {:ok, :result}}
      }
    end

    test "did not get exception" do
      :telemetry.attach(self(), [:my_app, :succeed, :exception], &send_handler/4, self())
      MyApp.MyModule.succeed(:result)

      refute_received {
        :test_telemetry,
        [:my_app, :succeed, :stop],
        %{},
        %{}
      }
    end
  end

  describe "unhappy path" do
    test "crash got passed through" do
      assert_raise RuntimeError, fn -> MyApp.MyModule.crash("ouch!") end
    end

    test "got start" do
      :telemetry.attach(self(), [:my_app, :crash, :start], &send_handler/4, self())
      assert_raise RuntimeError, fn -> MyApp.MyModule.crash("ouch!") end

      assert_received {
        :test_telemetry,
        [:my_app, :crash, :start],
        %{system_time: _},
        %{why: "ouch!"}
      }
    end

    test "got exception" do
      :telemetry.attach(self(), [:my_app, :crash, :exception], &send_handler/4, self())
      assert_raise RuntimeError, fn -> MyApp.MyModule.crash("ouch!") end

      assert_received {
        :test_telemetry,
        [:my_app, :crash, :exception],
        %{duration: _},
        %{
          # telemetry.span/3 supplies the reason:
          reason: %RuntimeError{message: "ouch!"},
          # we supply the arguments:
          why: "ouch!"
        }
      }
    end
  end

  describe "convenience functions" do
    test "watch/1 and unwatch/1" do
      handler_id = TelemetryDecorator.watch([:my_app, :succeed])
      assert handler_attached?([:my_app, :succeed], handler_id)
      TelemetryDecorator.unwatch(handler_id)
      refute handler_attached?([:my_app, :succeed], handler_id)
    end

    test "watch/2 and unwatch/1" do
      handler_id = make_ref()
      refute handler_attached?([:my_app, :succeed], handler_id)
      ^handler_id = TelemetryDecorator.watch([:my_app, :succeed], handler_id)
      assert handler_attached?([:my_app, :succeed], handler_id)
      TelemetryDecorator.unwatch(handler_id)
      refute handler_attached?([:my_app, :succeed], handler_id)
    end
  end

  def handler_attached?(event_name, handler_id) do
    event_name |> :telemetry.list_handlers() |> Enum.find_value(false, &(&1.id == handler_id))
  end
end
