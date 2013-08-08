###

  anapi - simple dynamic api builder
  
  c) 2013 Sebastian Glaser <anx@ulzq.de>

  This file is part of the anapi project.

  anapi is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2, or (at your option)
  any later version.

  anapi is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this software; see the file COPYING.  If not, write to
  the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
  Boston, MA 02111-1307 USA

  http://www.gnu.org/licenses/gpl.html

###

class AnonymousApi
  rules : {}
  local :
    reply : console.log
    private_reply : console.log
    public_reply : console.log
  register : (opts={},p) =>
    p = @rules unless p?
    for k,v of opts
      rule = p[k]
      if not rule? then p[k] = v
      else
        if typeof rule is "function" then p[k] = [rule,v]
        else if rule.length? then rule.push v
        else @register v,rule
  route : (message, source, rule) =>
    rule   = @rules unless rule?
    source = @local unless source?
    for k,v of message
      if rule[k]?
        if typeof rule[k] is "function"
          console.log "api:call", k
          rule[k].call null, v, source
        else if rule[k].length?
          for r in rule[k]
            console.log "api:call", k
            r.call null, v, source
        else 
          console.log "+", k
          @route v, source, rule[k]
      else console.log "api:unbound", k
    true


### ##
    Anapi Websocket Client
## ###

if document?  
  class WebApi extends AnonymousApi
    constructor : (@address, @service) -> super()

    send : (m) =>
      @socket.send JSON.stringify m
      null

    send_binary : (id=0, segment=0, m) =>
      @socket.send '@'+id+':'+segment+'@'+m
      null

    connect : (callback) =>
      @socket = new WebSocket(@address,@service)    if WebSocket?
      @socket = new MozWebSocket(@address,@service) if MozWebSocket?
      @socket.message   = (m) ->
        @send JSON.stringify m
      @socket.onerror   = (e) ->
        console.log "sock:error #{e}"
        # setTimeout @connect, 1000
        callback false
      @socket.onopen    = (s) ->
        console.log "sock:connected"
        callback true
      @socket.onmessage = (m) =>
        try
          m = JSON.parse(m.data)
          @route m,
            reply : @socket.send
        catch e
          console.log {}, e, m
      true

  window.WebApi = WebApi

  ###
    Anapi Websocket Server
  ###

else
  WSS = require('ws').Server
  class AnapiWS extends WSS
    # Static infrastructure
    @conns : []
    @group : {}
    @there : (ws) ->
      AnapiWS.conns.push ws
      # AnapiWS.group['news'].push ws
      # AnapiWS.group['meta'].push ws
      # console.log "ws:new_connection", AnapiWS.group
    @gone  : (ws) ->
      delete AnapiWS.conns[AnapiWS.conns.indexOf(ws)]
      for group in Object.keys AnapiWS.group
        if (i = AnapiWS.group[group].indexOf ws) isnt -1
          delete AnapiWS.group[group][i]
    @chancast : (msg) ->
      for dest, m of msg
        continue unless AnapiWS.group[dest]
        grp = AnapiWS.group[dest]
        m = JSON.stringify(J(dest,m))
        for key, ws of grp
          try
            console.log "to:", ws.from
            ws.send m
          catch e
            console.log "gone", e
            AnapiWS.gone ws

    # Instance Elements
    fileid : 0
    constructor : (opts) ->
      _reply = console.error
      super opts
      ## PORT   _bot.on "sendMessage", AnapiWS.chancast
      @on "connection", (ws) ->
        ws.login = false
        ws.file   = {} # UPLOAD
        ws.fileid = 0  # UPLOAD
        ws.binary_message = (id=0,segment=0,m)->
          ws.send '@'+id+':'+segment+':'+m.length+':'+m+'@'
        ws.message = _reply = (m) -> ws.send JSON.stringify(m)
        ws.request =
          handle        : ws
          from          : "websocket"
          reply         : _reply
          public_reply  : _reply
          private_reply : _reply
        ws.on "message", (m) -> 
          if m[0] isnt "@"
            try m = JSON.parse(m.toString('utf8'))
            catch e
              _reply raw : e.toString()
            _api.route m, ws.request
          else
            idx = -1
            break for idx in [4...10] when m[idx] is '@'
            if idx isnt 10
              [ id, segment ] = m.slice(1,idx).toString('utf8').split(':')
              console.log 'upload'.blue, id, m.substr 0, 10
              ws.file[id].stream.write new Buffer m.slice(idx+1), 'binary'
            else console.log "Malformed", m.slice(0,10).toString 'utf8'
        ws.on "end",   -> AnapiWS.gone ws
        ws.on "error", -> AnapiWS.gone ws
        AnapiWS.there ws

      @api = _api = new AnonymousApi()
      _api.register ping  : (query, request) -> request.reply pong : true 

  module.exports =
    AnonymousApi : AnonymousApi
    Server : AnapiWS