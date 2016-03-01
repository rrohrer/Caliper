fs     = require 'fs-plus'
glob   = require 'glob'
mkdirp = require 'mkdirp'
path   = require 'path'
temp   = require 'temp'
os     = require 'os'
wrench = require 'wrench'
yauzl  = require 'yauzl'
GitHub = require 'github-releases'

temp.track()

cleanup = (dir) ->
  try wrench.rmdirSyncRecursive dir, true
  catch error
    console.log 'Failed to delete folder', dir, error

class WebHook
  symbDb: null

  constructor: (@symbDb)->

  onRequest: (req) ->
    event = req.headers['x-github-event']
    payload = req.body

    return unless event is 'release' and payload.action is 'published'
    @downloadAssets payload, (msg) ->
      console.log "Failed to process webhook: #{msg}..." if msg

  downloadAssets: (payload, callback) ->
    github = new GitHub
      repo: payload.repository.full_name
      token: process.env.MINI_BREAKPAD_SERVER_TOKEN

    sym_assets = (asset for asset in payload.release.assets when /sym/.test asset.name)
    if sym_assets.length == 0
      callback null
      return
    @downloadAsset github, payload.release.name, sym_assets, callback

  downloadAsset: (github, release, sym_assets, callback) ->
    asset = sym_assets.pop()
    asset.release_name = release
    @symbDb.hasSymbol release, asset.name, (exists) =>
      if exists
        console.log "Processing - #{sym_assets.length+1} #{asset.name}: Found cached..."
        if sym_assets.length == 0
          return callback null
        return @downloadAsset github, release, sym_assets, callback
      console.log "Processing - #{sym_assets.length+1} #{asset.name}..."
      dir = temp.mkdirSync()
      filename = path.join dir, asset.name
      try
        github.downloadAsset asset, (error, stream) =>
          if error?
            console.log 'Failed to download', asset.name, error
            cleanup dir
            callback "Failed to download asset"
            return
          file = fs.createWriteStream filename
          cb2 = (err) =>
            if err?
              callback err
              return
            if sym_assets.length == 0
              callback null
              return
            @downloadAsset github, release, sym_assets, callback
            
          stream.on 'end', @extractFile.bind(this, dir, filename, asset, cb2)
          stream.pipe file
      catch error
        console.log 'Failed to download', asset.name, error
        callback "Failed to download asset"
    
    
  extractFile: (dir, filename, asset, callback) ->
    targetDirectory = "#{filename}-unzipped"
    yauzl.open filename, {lazyEntries: true}, (err, zipfile) =>
      if err?
        console.log 'Failed to decompress', filename, err if err
        cleanup dir
        callback "Failed to decompress #{filename}"
      zipfile.readEntry()
      zipfile.on "close", ()=>
        fs.unlinkSync filename
        @copySymbolFiles dir, targetDirectory, asset, callback
        return
      zipfile.on 'entry', (entry)->
        tgFilename = path.join targetDirectory, entry.fileName
        if /\/$/.test(entry.fileName)
          mkdirp tgFilename, (err)->
            if err?
              cleanup dir
              callback "Failed to create tmp folder (decompress) #{filename}"
              return
            zipfile.readEntry()
        else if /sym$/.test(entry.fileName)
          zipfile.openReadStream entry, (err, readStream)->
            if err?
              cleanup dir
              callback "Failed to create tmp folder (decompress) #{filename}"
              return
            mkdirp path.dirname(tgFilename), (err) ->
              if err?
                cleanup dir
                callback "Failed to create tmp folder (decompress) #{filename}"
                return
              readStream.pipe fs.createWriteStream tgFilename
              readStream.on "end", ()->
                zipfile.readEntry()
        else
          zipfile.readEntry()
        

  copySymbolFiles: (dir, targetDirectory, asset, callback) ->
    glob '*.breakpad.syms', cwd: targetDirectory, (error, dirs) =>
      if error?
        console.log 'Failed to find breakpad symbols in', targetDirectory, error
        cleanup dir
        callback "Failed to find symbols"
        return

      symbolsDirectory = path.join 'pool', 'symbols'
      for symbol in dirs
        fs.copySync path.join(targetDirectory, symbol), symbolsDirectory
      cleanup dir
      @symbDb.saveSymbol asset.release_name, asset.name
      callback null


module.exports = WebHook
