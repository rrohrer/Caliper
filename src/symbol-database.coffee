path = require 'path'
dirty = require 'dirty'
mkdirp = require 'mkdirp'
{EventEmitter} = require 'events'
Symbol = require './symbol-record'

class SymbolDatabase extends EventEmitter
  db: null

  # Public: Create or open a SymbolDatabase with path to {filename}
  constructor: (filename=path.join('pool', 'database', 'dirty', 'symbols')) ->
    dist = path.resolve filename, '..'
    mkdirp dist, (err) =>
      throw new Error("Cannot create directory: #{dist}") if err?

      @db = dirty filename
      @db.on 'load', @emit.bind(this, 'load')

  # Public: Saves a symbol to database.
  saveSymbol: (release, name, callback) ->
    symbol = new Symbol
      release: release
      name: name
    console.log "+++", symbol.id
    @db.set symbol.id, symbol.serialize()
    callback null if callback

  # Public: Check if a symbol exists in the database.
  hasSymbol: (release, name, callback) ->
    raw = @db.get(Symbol.mkid(release, name))
    return callback raw?

  # Public: Restore a symbol from database according to its id.
  restoreSymbol: (release, name, callback) ->
    raw = @db.get(Symbol.mkid(release, name))
    return callback new Error("Symbol is not in database") unless raw?

    callback null, Symbol.unserialize(id, @db.get(id))

  # Public: Returns all records as an array.
  getAllRecords: ->
    records = []
    @db.forEach (id, symbol) -> records.push Symbol.unserialize(id, symbol)
    records.reverse()

module.exports = SymbolDatabase
