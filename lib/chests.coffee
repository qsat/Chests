_ = require "underscore"
Promise = require( "es6-promise" ).Promise
Drawer = require "./drawer.coffee"

eventSplitter = /\s+/
optionalParam = /\((.*?)\)/g
namedParam    = /(\(\?)?:\w+/g
splatParam    = /\*\w+/g
escapeRegExp  = /[\-{}\[\]+?.,\\\^$|#\s]/g

class Chests
  debug: true
  drawer: null
  routes: null
  eventList: ['leave', 'close', 'open', 'enter']

  constructor: ->
    @routes = []
    @drawer = new Drawer

  log: -> console.log arguments... if @debug

  trigger: (url, event) ->
    @log "\t#{event.toUpperCase()}\t#{url}"

    results = _.map @routes, (e)=>
      param = e.re.exec url
      if param and ( e.event is event or e.event is "*" )
        param.unshift event
        # URLにひもづいた callback を実行
        e.callback.apply @, _.compact param
    
    ret = _.compact results
    str = "\t#{event.toUpperCase()}ED\t".replace("EE", "E")
    
    if ret.length > 0
      Promise.all(ret).then =>
        @log str, url
    else
      @log str, url, "didn't return value or no callbacks"
    ret

  off: (pathOrCallback, event=null)->
    if _.isFunction pathOrCallback
      @routes = _.filter @routes, (e, i)-> e.callback isnt pathOrCallback
    else if pathOrCallback? and event?
      @routes = _.filter @routes, (e, i) =>
        e.event isnt event or e.re.toString() isnt @_routeToRegExp( pathOrCallback ).toString()
    else
      throw new Error "Invalid arguments."

  on: (route, listenerOrEvent, cb = null) ->

    route = @_routeToRegExp route

    if _.isObject listenerOrEvent
      return _.each @eventList, (event) =>
        return unless (c = listenerOrEvent[event])
        @routes.push re: route, event: event, callback: c

    event = if _.isString listenerOrEvent then listenerOrEvent else null
    @routes.push re: route, event: event, callback: cb

  _routeToRegExp: (route) ->

    return route if _.isRegExp route

    route = route
      .replace escapeRegExp, '\\$&'
      .replace optionalParam, '(?:$1)?'
      .replace namedParam, ((match, optional)->if optional then match else '([^/?|:]+)')
      .replace splatParam, '([^?]*?)'
    new RegExp '^' + route + '(?:\\?([\\s\\S]*))?$'

  _parseUrl: (url) ->
    return [] unless url
    ["/"].concat _.compact url.split "/"

  _formatUrl: (url) ->
    url
      .replace /\/+/g, "/"
      .replace /(.+)\/$/, "$1"

  resolvePath: (prefix, paths) ->
    paths = _.compact(paths)
    _.compact _.map paths, (e, i) =>
      @_formatUrl prefix.concat( paths.slice 0, i+1 ).join "/"

  splitPath: (current, prev)->
    up = []
    down = []
    common = []
    separateFlg = false

    _.filter _.zip( @_parseUrl( current ), @_parseUrl( prev )), (e)->
      if e[0] is e[1] and not separateFlg
        common.push e[0]
      else
        separateFlg = true
        down.push e[0]
        up.push e[1]

    [up, down, common]

  findRoute: (current, prev)->
    [up, down, common] = @splitPath current, prev
    [ @resolvePath(common, up).reverse(), @resolvePath( common, down ) ]

  matchRoute: (current, prev)->
    [up, down] = @findRoute current, prev

    return @drawer.promise() if up.length is 0 and down.length is 0

    # UP 各URLを閉じていく
    if up and up.length > 0
      @drawer.add => @trigger up[0], "leave"
      _.each up, (url, i) => @drawer.add => @trigger url, "close"
    else if prev?
      if up.length is 0
        # console.log down, up, current, prev
        # 「/users」 ==> 「/users/edit」のとき
        # up は空になる
        @drawer.add => @trigger prev, "leave"
      else
        @drawer.add => @trigger '/', "leave"

    # down 各URLを開いていく
    if down and down.length > 0
      _.each down, (url, i) => @drawer.add => @trigger url, "open"
      @drawer.add => @trigger _.last(down), "enter"
    else if prev?
      if down.length is 0
        # 「/users/edit」 ==> 「/users」のとき
        # down は空になる。「/users」の enter だけ処理する
        @drawer.add => @trigger current, "enter"
      else
        @drawer.add => @trigger '/', "enter"

  activate: (url, interrupt = false) ->
    if interrupt and @drawer.drawers.length > 0
      @log "\n ---- Interrupted: all promises will be rejected :: #{@url.prev?.url ? null}----\n"
      @drawer.clear()

    @url = new Url prev: @url||null, url: url

    @drawer.then => 
      @log "\n「#{@url.prev?.url ? null}」 ================> 「#{url}」\n"

      @matchRoute( @url.url, @url.prev?.url ? null ).then =>
        @drawer.clear()
        @log "\n================= ACTIVATED 「#{url}」\n"

class Url
  prev: {}
  url: ""
  constructor: (opt)-> {@prev, @url} = opt

if typeof module is "object" && typeof module.exports is "object"
  module.exports = Chests
if typeof define is 'function' && define.amd 
  define 'chests', [], -> Chests
else if typeof window isnt "undefined" 
  window.Chests = Chests

