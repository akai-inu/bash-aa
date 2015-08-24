fs = require 'fs'
async = require 'async'
jpeg = require 'jpeg-js'
argv = require 'argv'
colorCalculator = require __dirname + '/color-calculator'

COLOR_1 = '1'
COLOR_16 = '16'
COLOR_256 = '256'

getArgs = ->
  argOptions = [
    {
      name: 'color256'
      type: 'boolean'
      description: 'convert to 256 colors (default)'
    },
    {
      name: 'color16'
      type: 'boolean'
      description: 'convert to 16 colors (WIP)'
    },
    {
      name: 'color1'
      type: 'boolean'
      description: 'convert to 1 color (WIP)'
    }
  ]

  argv.option(argOptions).run()



checkArgs = (args) ->
  getColorType = ->
    if args.options.color1? then throw 'currently convert to 1 color is WIP.'
    else if args.options?.color16? then return 'currently convert to 16 colors is WIP.'
    return COLOR_256

  getTargetFile = ->
    if args.targets.length is 0 then throw 'unknown target jpeg file'
    return args.targets[0]

  [getColorType(), getTargetFile()]



getColorData = (colorType) ->
  return require process.cwd() + '/color-data256.json'



convertRawToPixelList = (imageData, callback) ->
  async.times imageData.height / 2, (y, nextY) ->
    async.times imageData.width, (x, nextX) ->
      index = imageData.width * y * 2 * 4 + x * 4
      r = parseInt imageData.data[index]
      g = parseInt imageData.data[index + 1]
      b = parseInt imageData.data[index + 2]
      pixel =
        r: r
        g: g
        b: b
        x: x
        y: y
      nextX null, pixel
    , nextY
  , callback



assignColorId = (pixelRows, callback) ->
  async.map pixelRows, (row, nextY) ->
    async.map row, (pixel, nextX) ->
      colorCalculator.calc pixel, (err, result) =>
        pixel.id = result.id
        pixel.color = result.color
        nextX null, pixel
    , nextY
  , callback



pixelsToString = (pixelRows, callback) ->
  async.map pixelRows, (row, nextY) ->
    async.map row, (pixel, nextX) ->
      nextX null, "\x1b[38;5;#{pixel.id}m\x1b[48;5;#{pixel.id}m."
    , (err, pixelStrings) ->
      nextY err, "echo -e '#{pixelStrings.join('')}\x1b[0m'\n"
  , (err, rowStrings) ->
    callback err, rowStrings.join('')




colorType = null
targetFile = null

async.waterfall [
  (next) ->
    args = getArgs()
    [colorType, targetFile] = checkArgs(args)

    fs.readFile targetFile, next

  , (data, next) ->
    try
      imageData = jpeg.decode data
    catch error
      return next error, null

    [width, height, raw] = [imageData.width, imageData.height, imageData.data]

    if width > 240 or height > 50
      # TODO: automatic resize when the image is too large.
      return next 'The image is too large.', null

    convertRawToPixelList imageData, next

  , (pixelRows, next) ->
    colorData = getColorData colorType
    colorCalculator.init colorData
    assignColorId pixelRows, next

  , (pixelRows, next) ->
    pixelsToString pixelRows, next

  , (strings, next) ->
    fs.writeFile __dirname + '/output.sh', '#!/bin/bash\n\n' + strings, next

], (err, result) ->
  throw err if err?

  console.log 'Completed.'
