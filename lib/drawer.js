// Generated by CoffeeScript 1.7.1
(function() {
  var Chest, Promise, defer, wait, _,
    __slice = [].slice;

  _ = require("underscore");

  Promise = require("es6-promise").Promise;

  defer = function(ms) {
    var p, reject, resolve;
    reject = resolve = null;
    p = new Promise(function(res, rej) {
      var _ref;
      return _ref = [res, rej], resolve = _ref[0], reject = _ref[1], _ref;
    });
    p.resolve = resolve;
    p.reject = reject;
    return p;
  };

  wait = function(ms) {
    var d;
    d = defer();
    setTimeout((function() {
      return d.resolve();
    }), ms);
    return d;
  };

  Chest = (function() {
    function Chest() {
      this.drawers = [];
      this.prev = Promise.resolve(true);
    }

    Chest.prototype.then = function(fullfilled, rejected) {
      return this.prev.then(fullfilled, rejected);
    };

    Chest.prototype["catch"] = function(func) {
      return this.prev["catch"](func);
    };

    Chest.prototype.promise = function() {
      return this.prev;
    };

    Chest.prototype.clear = function() {
      this.rejectAll();
      this.reset();
      return this.prev = Promise.resolve(true);
    };

    Chest.prototype.reset = function() {
      return this.drawers = [];
    };

    Chest.prototype.resolveAll = function() {
      return _.each(this.drawers, function(e, i) {
        e.resolve("resolveAll");
        return e.reject = e.resolve = null;
      });
    };

    Chest.prototype.rejectAll = function() {
      return _.each(this.drawers, function(e, i) {
        return e.reject("rejectAll");
      });
    };

    Chest.prototype.add = function() {
      var promiseOrArray;
      promiseOrArray = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this.prev = this.prev.then((function(_this) {
        return function() {
          var drawer;
          drawer = _.map(_.flatten(promiseOrArray, true), function(e, i) {
            return _.map(_.flatten(e(), true), function(f, i) {
              return _this.wrap(f);
            });
          });
          drawer = _.flatten(drawer, true);
          _this.drawers = _this.drawers.concat(drawer);
          return Promise.all(drawer);
        };
      })(this));
    };

    Chest.prototype.wrap = function(value) {
      var d;
      d = defer();
      Promise.resolve(true).then((function(_this) {
        return function() {
          return value;
        };
      })(this)).then(function() {
        return d.resolve();
      }, function() {
        return d.reject();
      });
      d["catch"](function() {
        return typeof value.reject === "function" ? value.reject() : void 0;
      });
      return d;
    };

    return Chest;

  })();

  module.exports = Chest;

}).call(this);