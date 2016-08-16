path = require 'path'
express = require 'express'
expressSession = require 'express-session'
methodOverride = require 'method-override'
bodyParser = require 'body-parser'
passport = require 'passport'
passportLocal = require 'passport-local'
randomstring = require 'randomstring'
#local requirements
reader = require './reader'
saver = require './saver'
Database = require './database'
SymbolDatabase = require './symbol-database'
WebHook = require './webhook'
symbols = require './symbols'
GitHub        = require 'github-releases'

# THIS SHOULD BE CHANGED BEFORE RUNNING CALIPER
secret_session_string = process.env.MINI_BREAKPAD_SERVER_SECRET or randomstring.generate()
secret_admin_password = process.env.MINI_BREAKPAD_ADMIN_PASSWORD or randomstring.generate()
api_key = process.env.MINI_BREAKPAD_API_KEY or randomstring.generate()


root =
  if process.env.MINI_BREAKPAD_SERVER_ROOT?
    "#{process.env.MINI_BREAKPAD_SERVER_ROOT}/"
  else
    ''

# TODO change this to hit a database of users
# this is very temporary. just to get basic auth off the ground
localStrategy = new passportLocal.Strategy (username, password, callback) ->
  return callback null, false, message: "Incorrect Username" unless username is "admin"
  return callback null, false, message: "Incorrect Password" unless username is "admin" and password is secret_admin_password
  return callback null, user: "this is the user object"

passport.use localStrategy

passport.serializeUser (user, callback) ->
  callback null, user

passport.deserializeUser (user, callback) ->
  callback null, user

# simple function to check if user is logged in
isLoggedIn = (req, res, next) ->
  return next() if req.isAuthenticated()
  res.redirect("/#{root}login_page")

app = express()
db = new Database

startServer = () ->
  port = process.env.MINI_BREAKPAD_SERVER_PORT || process.env.PORT || 80
  app.listen port
  console.log "Listening on port #{port}"
  console.log "Using random admin password: #{secret_admin_password}" if secret_admin_password != process.env.MINI_BREAKPAD_ADMIN_PASSWORD
  console.log "Using random api_key: #{api_key}" if api_key != process.env.MINI_BREAKPAD_API_KEY
  console.log "Using random server secret" if !process.env.MINI_BREAKPAD_SERVER_SECRET
  console.log "Using provided github server token" if process.env.MINI_BREAKPAD_SERVER_TOKEN

symbDb = null
db.on 'load', ->
  console.log "crash db ready"
  symbDb = new SymbolDatabase
  webhook = new WebHook(symbDb)

  symbDb.on 'load', ->
    console.log "symb db ready"
    startServer()


app.set 'views', path.resolve(__dirname, '..', 'views')
app.set 'view engine', 'jade'
app.use bodyParser.json()
app.use bodyParser.urlencoded(extended : true)
app.use methodOverride()
app.use (err, req, res, next) ->
  res.send 500, "Bad things happened:<br/> #{err.message}"

app.on 'error', (err)->
  console.log "Whoops #{err}"
# set up session variables this is needed for AUTH
app.use expressSession(secret: secret_session_string, resave: true, saveUninitialized: true)
app.use passport.initialize()
app.use passport.session()

app.post "/#{root}webhook", (req, res, next) ->
  webhook.onRequest req

  console.log 'webhook requested', req.body.repository.full_name
  res.end()

app.get "/#{root}fetch", (req, res, next) ->
  return next "Invalid key" if req.query.key != api_key

  github = new GitHub
    repo: req.query.project
    token: process.env.MINI_BREAKPAD_SERVER_TOKEN

  processRel = (rel, rest) ->
    console.log "Processing symbols from #{rel.name}..."
    webhook.downloadAssets {'repository': {'full_name': req.query.project}, 'release': rel}, (err)->
      if err?
        console.log "Failed to process #{rel.name}: #{err}"  if err?
        return
      console.log "Processing symbols from #{rel.name}: Done..."
      return if rest.length == 0
      rel = rest.pop()
      processRel rel, rest

  github.getReleases {}, (err, rels)->
    return next err if err?
    return next "Error fetching releases from #{req.query.project}" if !rels?

    rel = rels.pop()
    processRel rel, rels
  res.end()

app.post "/#{root}crash_upload", (req, res, next) ->
  saver.saveRequest req, db, (err, filename) ->
    return next err if err?

    console.log 'saved', filename
    res.send path.basename(filename)
    res.end()

app.post "/#{root}symbol_upload", (req, res, next) ->
  return symbols.saveSymbols req, (error, destination) ->
    return next error if error?
    console.log "Saved Symbols: #{destination}"
    return res.end()

app.post "/#{root}login", passport.authenticate("local", successRedirect:"/#{root}", failureRedirect:"/#{root}login_page")

app.get "/#{root}login_page", (req, res, next) ->
  res.render 'login', {menu:'login', title: 'Login'}

app.get "/#{root}", isLoggedIn, (req, res, next) ->
  res.render 'index', {menu: 'crash', title: 'Crash Reports', records: db.getAllRecords()}

app.get "/#{root}view/:id", isLoggedIn, (req, res, next) ->
  db.restoreRecord req.params.id, (err, record) ->
    return next err if err?

    reader.getStackTraceFromRecord record, (err, report) ->
      return next err if err?
      fields = record.fields
      res.render 'view', {menu: 'crash', title: 'Crash Report', report, fields}

app.get "/#{root}symbol/", isLoggedIn, (req, res, next) ->
  res.render 'symbols', {menu: 'symbol', title: 'Symbols', symbols: symbDb.getAllRecords()}
