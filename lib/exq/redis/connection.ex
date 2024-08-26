defmodule Exq.Redis.Connection do
  @moduledoc """
  The Connection module encapsulates interaction with a live Redis connection or pool.

  """
  require Logger

  alias Exq.Support.Config
  alias Exq.Support.Redis

  def flushdb!(redis) do
    {:ok, res} = q(redis, ["flushdb"])
    res
  end

  def decr!(redis, key) do
    {:ok, count} = q(redis, ["DECR", key])
    count
  end

  def incr!(redis, key) do
    {:ok, count} = q(redis, ["INCR", key])
    count
  end

  def get!(redis, key) do
    {:ok, val} = q(redis, ["GET", key])
    val
  end

  def set!(redis, key, val \\ 0) do
    q(redis, ["SET", key, val])
  end

  def del!(redis, key, options \\ []) do
    q(redis, ["DEL", key], options)
  end

  def expire!(redis, key, time \\ 10) do
    q(redis, ["EXPIRE", key, time])
  end

  def llen!(redis, list) do
    {:ok, len} = q(redis, ["LLEN", list])
    len
  end

  def keys!(redis, search \\ "*") do
    {:ok, keys} = q(redis, ["KEYS", search])
    keys
  end

  def scan!(redis, cursor, search, count) do
    {:ok, keys} = q(redis, ["SCAN", cursor, "MATCH", search, "COUNT", count])
    keys
  end

  def scard!(redis, set) do
    {:ok, count} = q(redis, ["SCARD", set])
    count
  end

  def smembers!(redis, set) do
    {:ok, members} = q(redis, ["SMEMBERS", set])
    members
  end

  def sadd!(redis, set, member) do
    {:ok, res} = q(redis, ["SADD", set, member])
    res
  end

  def srem!(redis, set, member) do
    {:ok, res} = q(redis, ["SREM", set, member])
    res
  end

  def sismember!(redis, set, member) do
    {:ok, res} = q(redis, ["SISMEMBER", set, member])
    res
  end

  def lrange!(redis, list, range_start \\ "0", range_end \\ "-1") do
    {:ok, items} = q(redis, ["LRANGE", list, range_start, range_end])
    items
  end

  def lrem!(redis, list, value, count \\ 1, options \\ []) do
    {:ok, res} =
      if is_list(value) do
        commands = Enum.map(value, fn v -> ["LREM", list, count, v] end)
        qp(redis, commands, options)
      else
        q(redis, ["LREM", list, count, value], options)
      end

    res
  end

  def rpush!(redis, key, value) do
    {:ok, res} = q(redis, ["RPUSH", key, value])
    res
  end

  def lpush!(redis, key, value) do
    {:ok, res} = q(redis, ["LPUSH", key, value])
    res
  end

  def lpop(redis, key) do
    q(redis, ["LPOP", key])
  end

  def zadd(redis, set, score, member, options \\ []) do
    q(redis, ["ZADD", set, score, member], options)
  end

  def zadd!(redis, set, score, member) do
    {:ok, res} = q(redis, ["ZADD", set, score, member])
    res
  end

  def zcard!(redis, set) do
    {:ok, count} = q(redis, ["ZCARD", set])
    count
  end

  def zcount!(redis, set, min \\ "-inf", max \\ "+inf") do
    {:ok, count} = q(redis, ["ZCOUNT", set, min, max])
    count
  end

  def zrangebyscore!(redis, set, min \\ "0", max \\ "+inf") do
    {:ok, items} = q(redis, ["ZRANGEBYSCORE", set, min, max])
    items
  end

  def zrangebyscorewithlimit!(redis, set, offset, size, min \\ "0", max \\ "+inf") do
    {:ok, items} = q(redis, ["ZRANGEBYSCORE", set, min, max, "LIMIT", offset, size])
    items
  end

  def zrangebyscore(redis, set, min \\ "0", max \\ "+inf") do
    q(redis, ["ZRANGEBYSCORE", set, min, max])
  end

  def zrangebyscorewithscore!(redis, set, min \\ "0", max \\ "+inf") do
    {:ok, items} = q(redis, ["ZRANGEBYSCORE", set, min, max, "WITHSCORES"])
    items
  end

  def zrangebyscorewithscoreandlimit!(redis, set, offset, size, min \\ "0", max \\ "+inf") do
    {:ok, items} = q(redis, ["ZRANGEBYSCORE", set, min, max, "WITHSCORES", "LIMIT", offset, size])
    items
  end

  def zrangebyscorewithscore(redis, set, min \\ "0", max \\ "+inf") do
    q(redis, ["ZRANGEBYSCORE", set, min, max, "WITHSCORES"])
  end

  def zrevrangebyscorewithlimit!(redis, set, offset, size, min \\ "0", max \\ "+inf") do
    {:ok, items} = q(redis, ["ZREVRANGEBYSCORE", set, max, min, "LIMIT", offset, size])
    items
  end

  def zrevrangebyscorewithscoreandlimit!(redis, set, offset, size, min \\ "0", max \\ "+inf") do
    {:ok, items} =
      q(redis, ["ZREVRANGEBYSCORE", set, max, min, "WITHSCORES", "LIMIT", offset, size])

    items
  end

  def zrange!(redis, set, range_start \\ "0", range_end \\ "-1") do
    {:ok, items} = q(redis, ["ZRANGE", set, range_start, range_end])
    items
  end

  def zrem!(redis, set, members) when is_list(members) do
    {:ok, res} = q(redis, ["ZREM", set | members])
    res
  end

  def zrem!(redis, set, member) do
    {:ok, res} = q(redis, ["ZREM", set, member])
    res
  end

  def zrem(redis, set, member) do
    q(redis, ["ZREM", set, member])
  end

  def q(redis, command, options \\ []) do
    Redis.with_retry_on_connection_error(
      fn ->
        redis
        |> Redix.command(command, timeout: Config.get(:redis_timeout))
        |> handle_response(redis)
      end,
      Keyword.get(options, :retry_on_connection_error, 0)
    )
  end

  def qp(redis, command, options \\ []) do
    Redis.with_retry_on_connection_error(
      fn ->
        redis
        |> Redix.pipeline(command, timeout: Config.get(:redis_timeout))
        |> handle_responses(redis)
      end,
      Keyword.get(options, :retry_on_connection_error, 0)
    )
  end

  def qp!(redis, command, options \\ []) do
    Redis.with_retry_on_connection_error(
      fn ->
        redis
        |> Redix.pipeline!(command, timeout: Config.get(:redis_timeout))
        |> handle_responses(redis)
      end,
      Keyword.get(options, :retry_on_connection_error, 0)
    )
  end

  defp handle_response({:error, %{message: "READONLY" <> _rest}} = error, redis) do
    disconnect(redis)
    error
  end

  defp handle_response({:error, %{message: "NOSCRIPT" <> _rest}} = error, _) do
    error
  end

  defp handle_response({:error, %Redix.ConnectionError{reason: :disconnected}} = error, _) do
    error
  end

  defp handle_response({:error, message} = error, _) do
    Logger.error(inspect(message))
    error
  end

  defp handle_response(response, _) do
    response
  end

  defp handle_responses({:ok, responses} = result, redis) do
    # Disconnect once for multiple readonly redis node errors.
    if Enum.any?(responses, &readonly_error?/1) do
      disconnect(redis)
    end

    result
  end

  defp handle_responses(responses, redis) when is_list(responses) do
    # Disconnect once for multiple readonly redis node errors.
    if Enum.any?(responses, &readonly_error?/1) do
      disconnect(redis)
    end

    responses
  end

  defp handle_responses(responses, _) do
    responses
  end

  defp readonly_error?(%{message: "READONLY" <> _rest}), do: true
  defp readonly_error?(_), do: false

  defp disconnect(redis) do
    pid = Process.whereis(redis)

    if !is_nil(pid) && Process.alive?(pid) do
      # Let the supervisor restart the process with a new connection.
      Logger.error("Redis failover - forcing a reconnect")
      Process.exit(pid, :kill)
      # Give the process some time to be restarted.
      :timer.sleep(100)
    end
  end
end
