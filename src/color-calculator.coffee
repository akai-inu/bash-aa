async = require 'async'

class ColorCalculator
  init: (@colorData) =>

  calc: (pixel, next) =>
    async.reduce @colorData, {id: -1, diff: 9999999}, (memo, item, callback) ->
      rDiff = Math.abs item.r - pixel.r
      gDiff = Math.abs item.g - pixel.g
      bDiff = Math.abs item.b - pixel.b
      diff = (rDiff + gDiff + bDiff) / 3
      if memo.diff > diff then memo = {id: item.id, diff: diff, color: item}
      callback null, memo
    , next

module.exports = new ColorCalculator()
