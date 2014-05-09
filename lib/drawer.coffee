_ = require "underscore"
Promise = require( "es6-promise" ).Promise

defer = ( ms ) ->
  reject = resolve = null
  p = new Promise (res, rej) -> [resolve, reject] = [res, rej]
  p.resolve = resolve
  p.reject = reject
  p

wait = (ms) ->
  d = defer()
  setTimeout ( -> d.resolve() ), ms
  d

class Chest
  constructor: ->
    @drawers = []
    @prev =  Promise.resolve true

  then: (fullfilled, rejected)->
    @prev.then fullfilled, rejected

  catch: (func)-> @prev.catch func

  promise: -> @prev

  clear: ->
    @rejectAll()
    @reset()
    @prev = Promise.resolve true
    
  reset: ->
    @drawers= []

  resolveAll: ->
    _.each @drawers, (e, i)->
      e.resolve("resolveAll")
      e.reject = e.resolve = null

  rejectAll: ->
    _.each @drawers, (e, i)-> e.reject("rejectAll")

  add: (promiseOrArray...) ->
    @prev = @prev.then =>
      drawer = _.map _.flatten( promiseOrArray, true ), (e, i) =>
        _.map _.flatten( e(), true), (f, i) => @wrap f
      drawer = _.flatten drawer, true
      @drawers = @drawers.concat drawer
      Promise.all( drawer )

  wrap: (value) ->
    d = defer()
    Promise.resolve( true )
    .then =>
      value
    .then ->
      d.resolve()
    , ->
      d.reject()
    d.catch -> value.reject?()
    d

#c = new Chest
#c.add -> wait 1300
#c.add [(-> wait 1300), (-> wait 300), (-> wait 1000)]

module.exports = Chest
