
mkid = (release, name) -> return release + "-" + name

class SymbolRecord
  id: null
  time: null
  release: null
  name: null

  constructor: ({@time, @release, @name}) ->
    @id = mkid @release, @name
    @time ?= new Date

  # Public: Restore a SymbolRecord from raw representation.
  @unserialize: (id, representation) ->
    new SymbolRecord
      id: representation.release + "-" + representation.name
      time: new Date(representation.time)
      release: representation.release
      name: representation.name

  @mkid: mkid

  # Public: Returns the representation to be stored in database.
  serialize: ->
    time: @time.getTime(), release: @release, name: @name

module.exports = SymbolRecord
