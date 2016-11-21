use Mix.Config

config :msgpack_rpc,
  transport: MessagePack.Transports.Stub,
  session: MessagePack.RPC.TestSession
