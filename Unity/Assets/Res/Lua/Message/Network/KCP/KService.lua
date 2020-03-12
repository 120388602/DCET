-- Generated by CSharp.lua Compiler
local System = System
local DCET = DCET
local MicrosoftIO = Microsoft.IO
local SystemNet = System.Net
local SystemNetSockets = System.Net.Sockets
local ArrayByte = System.Array(System.Byte)
local ListInt64 = System.List(System.Int64)
local QueueInt64 = System.Queue(System.Int64)
local HashSetInt64 = System.HashSet(System.Int64)
local MultiMap_2Int64Int64 = DCET.MultiMap_2(System.Int64, System.Int64)
local DCET
local DictInt64KChannel
local DictUInt32KChannel
System.import(function (out)
  DCET = out.DCET
  DictInt64KChannel = System.Dictionary(System.Int64, DCET.KChannel)
  DictUInt32KChannel = System.Dictionary(System.UInt32, DCET.KChannel)
end)
System.namespace("DCET", function (namespace)
  namespace.class("KcpProtocalType", function (namespace)
    return {}
  end)

  namespace.class("KService", function (namespace)
    local Dispose, Recv, GetKChannel, GetChannel, Output, ConnectChannel, ConnectChannel1, Remove, 
    AddToUpdateNextTime, Update, class, internal, __ctor1__, __ctor2__
    internal = function (this)
      this.localConnChannels = DictInt64KChannel()
      this.cache = ArrayByte:new(8192)
      this.removedChannels = QueueInt64()
      this.MemoryStreamManager = MicrosoftIO.RecyclableMemoryStreamManager()
      this.waitConnectChannels = DictUInt32KChannel()
      this.updateChannels = HashSetInt64()
      this.timeId = MultiMap_2Int64Int64()
      this.timeOutTime = ListInt64()
      this.ipEndPoint = SystemNet.IPEndPoint(SystemNet.IPAddress.Any, 0)
    end
    __ctor1__ = function (this)
      internal(this)
      System.base(this).__ctor__(this)
      this.StartTime = DCET.TimeHelper.ClientNow()
      this.TimeNow = System.toUInt32(DCET.TimeHelper.ClientNow() - this.StartTime)
      this.socket = SystemNetSockets.Socket(2 --[[AddressFamily.InterNetwork]], 2 --[[SocketType.Dgram]], 17 --[[ProtocolType.Udp]])
      --this.socket.Blocking = false;
      this.socket:Bind(SystemNet.IPEndPoint(SystemNet.IPAddress.Any, 0))
      class.Instance = this
    end
    __ctor2__ = function (this, ipEndPoint, acceptCallback)
      internal(this)
      System.base(this).__ctor__(this)
      this:addAcceptCallback(acceptCallback)

      this.StartTime = DCET.TimeHelper.ClientNow()
      this.TimeNow = System.toUInt32(DCET.TimeHelper.ClientNow() - this.StartTime)
      this.socket = SystemNetSockets.Socket(2 --[[AddressFamily.InterNetwork]], 2 --[[SocketType.Dgram]], 17 --[[ProtocolType.Udp]])
      --this.socket.Blocking = false;
      this.socket:Bind(ipEndPoint)
      class.Instance = this
    end
    Dispose = function (this)
      if this:getIsDisposed() then
        return
      end

      System.base(this).Dispose(this)

      for _, keyValuePair in System.each(this.localConnChannels) do
        keyValuePair.Value:Dispose()
      end

      this.socket:Close()
      this.socket = nil
      class.Instance = nil
    end
    Recv = function (this)
      if this.socket == nil then
        return
      end

      while this.socket ~= nil and this.socket:getAvailable() > 0 do
        local continue
        repeat
          local messageLength = 0
          System.try(function ()
            local default
            default, this.ipEndPoint = this.socket:ReceiveFrom(this.cache, this.ipEndPoint)
            messageLength = default
          end, function (default)
            local e = default
            DCET.Log.Exception(e)
            continue = true
            return
          end)

          -- 长度小于1，不是正常的消息
          if messageLength < 1 then
            continue = true
            break
          end
          -- accept
          local flag = this.cache:get(0)

          -- conn从1000开始，如果为1，2，3则是特殊包
          local remoteConn = 0
          local localConn = 0
          local kChannel = nil
          repeat
            local default = flag
            if default == 1 --[[KcpProtocalType.SYN]] then
              if messageLength ~= 5 then
                break
              end
              local acceptIpEndPoint = System.cast(SystemNet.IPEndPoint, this.ipEndPoint)
              this.ipEndPoint = SystemNet.IPEndPoint(0, 0)
              remoteConn = System.BitConverter.ToUInt32(this.cache, 1)
              local extern
              extern, kChannel = this.waitConnectChannels:TryGetValue(remoteConn)
              if extern then
                break
              end
              local ref = this.IdGenerater + 1
              this.IdGenerater = ref
              localConn = ref
              kChannel = DCET.KChannel(localConn, remoteConn, this.socket, acceptIpEndPoint, this)
              this.localConnChannels:set(kChannel:getLocalConn(), kChannel)
              this.waitConnectChannels:set(remoteConn, kChannel)
              this:OnAccept(kChannel)
              break
            elseif default == 2 --[[KcpProtocalType.ACK]] then
              if messageLength ~= 9 then
                break
              end
              remoteConn = System.BitConverter.ToUInt32(this.cache, 1)
              localConn = System.BitConverter.ToUInt32(this.cache, 5)
              kChannel = GetKChannel(this, localConn)
              if kChannel ~= nil then
                kChannel:HandleConnnect(remoteConn)
              end
              break
            elseif default == 3 --[[KcpProtocalType.FIN]] then
              if messageLength ~= 13 then
                break
              end
              remoteConn = System.BitConverter.ToUInt32(this.cache, 1)
              localConn = System.BitConverter.ToUInt32(this.cache, 5)
              kChannel = GetKChannel(this, localConn)
              if kChannel ~= nil then
                -- 校验remoteConn，防止第三方攻击
                if kChannel.RemoteConn == remoteConn then
                  kChannel:Disconnect(102008 --[[ErrorCode.ERR_PeerDisconnect]])
                end
              end
              break
            elseif default == 4 --[[KcpProtocalType.MSG]] then
              if messageLength < 9 then
                break
              end
              remoteConn = System.BitConverter.ToUInt32(this.cache, 1)
              localConn = System.BitConverter.ToUInt32(this.cache, 5)
              this.waitConnectChannels:RemoveKey(remoteConn)
              kChannel = GetKChannel(this, localConn)
              if kChannel ~= nil then
                -- 校验remoteConn，防止第三方攻击
                if kChannel.RemoteConn == remoteConn then
                  kChannel:HandleRecv(this.cache, 5, messageLength - 5)
                end
              end
              break
            end
          until 1
          continue = true
        until 1
        if not continue then
          break
        end
      end
    end
    GetKChannel = function (this, id)
      local aChannel = GetChannel(this, id)
      if aChannel == nil then
        return nil
      end

      return System.cast(DCET.KChannel, aChannel)
    end
    GetChannel = function (this, id)
      if this.removedChannels:Contains(id) then
        return nil
      end
      local channel
      local _
      _, channel = this.localConnChannels:TryGetValue(id)
      return channel
    end
    Output = function (bytes, count, user)
      if class.Instance == nil then
        return
      end
      local aChannel = GetChannel(class.Instance, System.cast(System.UInt32, user))
      if aChannel == nil then
        DCET.Log.Error("not found kchannel, " .. System.cast(System.UInt32, user))
        return
      end

      local kChannel = System.as(aChannel, DCET.KChannel)
      kChannel:Output(bytes, count)
    end
    ConnectChannel = function (this, remoteEndPoint)
      local localConn = System.toUInt32(DCET.RandomHelper.RandomNumber(1000, 2147483647 --[[Int32.MaxValue]]))
      local oldChannel
      local default
      default, oldChannel = this.localConnChannels:TryGetValue(localConn)
      if default then
        this.localConnChannels:RemoveKey(oldChannel:getLocalConn())
        oldChannel:Dispose()
      end

      local channel = System.new(DCET.KChannel, 2, localConn, this.socket, remoteEndPoint, this)
      this.localConnChannels:set(channel:getLocalConn(), channel)
      return channel
    end
    ConnectChannel1 = function (this, address)
      local ipEndPoint2 = DCET.NetworkHelper.ToIPEndPoint1(address)
      return ConnectChannel(this, ipEndPoint2)
    end
    Remove = function (this, id)
      local channel
      local default
      default, channel = this.localConnChannels:TryGetValue(id)
      if not default then
        return
      end
      if channel == nil then
        return
      end
      this.removedChannels:Enqueue(id)

      -- 删除channel时检查等待连接状态的字典是否要清除
      local waitConnectChannel
      local extern
      extern, waitConnectChannel = this.waitConnectChannels:TryGetValue(channel.RemoteConn)
      if extern then
        if waitConnectChannel:getLocalConn() == channel:getLocalConn() then
          this.waitConnectChannels:RemoveKey(channel.RemoteConn)
        end
      end
    end
    AddToUpdateNextTime = function (this, time, id)
    end
    Update = function (this)
      this.TimeNow = System.toUInt32(DCET.TimeHelper.ClientNow() - this.StartTime)

      Recv(this)

      for _, kv in System.each(this.localConnChannels) do
        kv.Value:Update()
      end

      while #this.removedChannels > 0 do
        local continue
        repeat
          local id = this.removedChannels:Dequeue()
          local channel
          local default
          default, channel = this.localConnChannels:TryGetValue(id)
          if not default then
            continue = true
            break
          end
          this.localConnChannels:RemoveKey(id)
          channel:Dispose()
          continue = true
        until 1
        if not continue then
          break
        end
      end
    end
    class = {
      base = function (out)
        return {
          out.DCET.AService
        }
      end,
      IdGenerater = 1000,
      StartTime = 0,
      TimeNow = 0,
      minTime = 0,
      Dispose = Dispose,
      Recv = Recv,
      GetKChannel = GetKChannel,
      GetChannel = GetChannel,
      Output = Output,
      ConnectChannel = ConnectChannel,
      ConnectChannel1 = ConnectChannel1,
      Remove = Remove,
      AddToUpdateNextTime = AddToUpdateNextTime,
      Update = Update,
      __ctor__ = {
        __ctor1__,
        __ctor2__
      }
    }
    return class
  end)
end)