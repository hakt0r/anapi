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
  register : (opts={},p) =>
    p = @rules unless p?
    for k,v of opts
      rule = p[k]
      if not rule? then p[k] = v
      else
        if typeof rule is "function" then p[k] = [rule,v]
        else if rule.length? then rule.push v
        else @register v,rule
  route : (message,rule) =>
    rule = @rules unless rule?
    for k,v of message
      if rule[k]?
        if typeof rule[k] is "function"
          console.log "api:call", k
          rule[k].call(null,v)
        else if rule[k].length?
          for r in rule[k]
            console.log "api:call",k,v
            r.call(null,v)
        else
          console.log "+",k
          @route v,rule[k]
      else console.log "api:unbound", k


module.exports.AnonymousApi = AnonymousApi

if document?
  class WebApi extends AnonymousApi
    constructor : (@address,@service) -> super()
    send : (m) => @socket.send JSON.stringify m
    send_binary : (id=0,segment=0,m) => @socket.send '@'+id+':'+segment+'@'+m
    connect: =>
      @socket  = new WebSocket(@address,@service)    if WebSocket?
      @socket  = new MozWebSocket(@address,@service) if MozWebSocket?
      @socket.message   = (m) -> @send JSON.stringify m
      @socket.onerror   = (e) ->
        console.log "sock:error #{e}"
        setTimeout @connect, 1000
      @socket.onopen    = (s) ->
        console.log "sock:connected"
      @socket.onmessage = (m) =>
        try m = JSON.parse(m.data)
        catch e
          return console.log {}, e, m
        @route m

  module.exports.WebApi = WebApi
