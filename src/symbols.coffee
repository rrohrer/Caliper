fs = require 'fs-plus'
path = require 'path'
mkdirp = require 'mkdirp'
formidable = require 'formidable'

# callback is of the form (error, destination).
module.exports.saveSymbols = (req, callback) ->
  form = new formidable.IncomingForm()
  return form.parse req, (error, fields, files) ->
    # return if this is a malformed request.
    return callback new Error("Invalid symbol file") unless files.symbol_file?
    return callback new Error("Invalid symbol file name") unless files.symbol_file.name?
    return callback new Error("Invalid symbol debug file") unless fields.debug_file?
    return callback new Error("Invalid symbol debug identifier") unless fields.debug_identifier?

    # this puts files in a path of:
    # destination + fields.debug_file + debug_identifier
    output_file_name = fields.debug_file.replace ".pdb", ".sym"
    # TODO: make this serialize-able
    destination = "pool/symbols"
    destination = path.join destination, fields.debug_file
    destination = path.join destination, fields.debug_identifier

    # make the destination directory, and copy the POST'd symbol file.
    return mkdirp destination, (error) ->
      return callback new Error("Could not create directory: #{destination}") if error?

      destination = path.join destination, output_file_name
      # copy the POST to destination.
      fs.copy files.symbol_file.path, destination, (error) ->
        return callback new Error("Cannot create file: #{destination}") if error?
        return callback null, destination
