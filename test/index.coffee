# mocha index.coffee --compilers coffee:coffee-script/register -R spec -w

_ = require "underscore"
$ = require "jquery"
Promise = require( "es6-promise" ).Promise

# nodejs でテスト実行時に Expectは ./inject.coffee から読み込む

uu = new (require "../src/chests.coffee")
uu.debug = true

describe "urlの解析", ->
  it "parseUrl", ->
    expect( uu._parseUrl( "/" ).length ).to.be 1
    expect( uu._parseUrl( "/user" ).length ).to.be 2
    expect( uu._parseUrl( "user/index" ).length ).to.be 3
    expect( uu._parseUrl( "/user/index" ).length ).to.be 3
    expect( uu._parseUrl( "user/index/" ).length ).to.be 3
    expect( uu._parseUrl( "/user/index/" ).length ).to.be 3

describe "1回目のアクセス", ->
  it "findRoute: 2つのURLから通過部分をみつける", ->
    expect( uu.findRoute( "/", null ) ).to.be.an Array
    expect( uu.findRoute( "/", null )[1] ).to.contain "/"
    expect( uu.findRoute( "/news/id", null )[1] ).to.contain "/news"

describe "pushStateなどでのページ遷移時", ->
  it "findRoute: 2つのURLから通過部分をみつける", ->
    expect( uu.findRoute( "/", "/user/") ).to.be.an Array
    expect( uu.findRoute( "/user/edit", "/user/detail/id") ).to.be.an Array
    expect( uu.findRoute( "/user/edit/id", "/user/detail/id") ).to.be.an Array

describe "resolvePath", ->
  it "パス配列に接頭辞をつける", ->
    expect( uu.resolvePath ["/"], ["detail", "id"] ).to.be.contain "/detail", "/detail/id"
    expect( uu.resolvePath ["/user"], ["detail", "id"] ).to.be.contain "/user/detail", "/user/detail/id"
    

describe "splitPath", ->
  it "遷移前、遷移後のURLを共通部分、それ以外に分ける", ->
    [up, down, common] = uu.splitPath( "/user/edit/id", "/user/detail/id")

    _.tap expect( up ).to.be, (m) ->
      m.contain "detail"
      m.contain "id"

    _.tap expect( down ).to.be, (m) ->
      m.contain "edit"
      m.contain "id"

describe "findRoute", ->
  it "遷移時に通過するルートを見つける", ->
    [up, down] = uu.findRoute  "/user/edit/id", "/user/detail/id"
    expect( up ).to.have.length 2
    expect( down ).to.have.length 2

    [up, down] = uu.findRoute  "/user/edit", "/user/detail/id"
    expect( up ).to.have.length 2
    expect( down ).to.have.length 1

o = null

describe "URLパターンを登録する", ->

  it "パラメータ受け取りのパターン", ()->
    uu.on "/users/edit/:id-:page", "open", -> console.log "3"

    class obj
      constructor: (ms = 30 ) ->
        @wait = ms || 30
      enter: =>
        @ed = wait @wait
      open:  =>
        @od = wait @wait
      #leave: -> wait 30
      #close: -> wait 30
      leave: -> @ed.reject() if @ed
      close: -> @od.reject() if @od

    o = new obj 100

    uu.on "/",                      new obj
    uu.on "/users",                 o
    uu.on "/users/edit",            new obj 100
    uu.on "/users/edit/:id",        new obj
    uu.on "/users/detail",          new obj
    uu.on "/users/detail/:id",      new obj
    uu.on "/users/detail/:id|:opt", new obj


    #uu.off o.enter
    #uu.off "/users", "enter"

    # console.log uu.routes
#
#    uu.activate "/users/edit"
#    .then ->
#      uu.activate "/"
#    .then ->
#      uu.activate "/users/detail/1"
#    .then ->
#      uu.activate "/users/detail/1"
#    .then ->
#      uu.activate "/users/detail/3"
#    .then ->
#      uu.activate "/users/detail/1|13"
#    .then ->
#      uu.activate "/users/edit"
#    .then ->
#      uu.activate "/"
#
  it "遷移中に別のURLへ移動するパターン", (done) ->

    uu.activate "/users"
    wait 40
    .then ->
      uu.activate "/users/edit/1", interrupt:true
    .then ->
      uu.activate "/users", interrupt:true
    .then ->
      done()

describe "履歴操作", ->
  it "backメソッド",(done) ->
    wait 400
    .then ->
      uu.back()
    .then ->
      expect(uu.url.val).to.be "/users/edit/1"
      uu.back()
    .then ->
      expect(uu.url.val).to.be "/users"
      expect(uu.back()).to.be false
      uu.forward()
    .then ->
      expect(uu.url.val).to.be "/users/edit/1"
      uu.forward()
    .then ->
      expect(uu.url.val).to.be "/users"
      expect(uu.forward()).to.be false
      done()
    .catch (e)->
      console.log e


defer = ( ms ) ->
  reject = resolve = null
  p = new Promise (res, rej) -> [resolve, reject] = [res, rej]
  p.resolve = resolve
  p.reject = reject
  p

wait = (ms) ->
  d = defer()
  id = setTimeout ( -> d.resolve() ), ms

  #d.then -> console.log ms
  d.catch -> clearTimeout id
  d

describe "off", ->
  it "コールバックを指定して削除", ->
    len = uu.routes.length
    uu.off o.enter
    expect(uu.routes).to.have.length len-1

  it "URLとイベントを指定して削除", ->
    len = uu.routes.length
    uu.off "/users", "open"
    expect(uu.routes).to.have.length len-1

  it "引数なしで呼び出すとエラー", ->
    expect(uu.off).to.throwError(/Invalid arguments./)


describe "Promiseのテスト", ->
  
  it "normal", (done)->
    Promise.resolve(true).then ->
      expect(0).to.be 0
      throw new Error()
    .catch ->
      console.log "rejected"
      done()

  it "途中でReject", (done)->

    p = wait 100
    p.catch ->
      console.log "rejected 1"
      throw arguments
    .then ->
      wait 100
    .catch ->
      console.log "rejected 2, and wait"
      wait 100
    .then ->
      console.log "res"
    , ->
      console.log "rejected 3"
    .then ->
      console.log "finished"
      done()

    wait(70).then ->
      p.reject "interrupt"

