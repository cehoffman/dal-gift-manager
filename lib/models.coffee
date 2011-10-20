database =
  id: 'dal-db'
  description: 'database of dragon age legend gift statuses'
  migrations: [
    {
      version: '0.0.1'
      migrate: (db, versionRequest, next) ->
        store = db.createObjectStore('gifts', keyPath: 'id')
        store.createIndex('tokenIndex', 'token', unique: false)
        store.createIndex('statusIndex', 'status', unique: false)
        store.createIndex('toAccountIndex', 'toAccount', unique: false)

        store = db.createObjectStore('gifters', keyPath: 'id')
        store.createIndex('toAccountIndex', 'toAccount', unique: false)
        store.createIndex('gplusIdIndex', 'gplusId', unique: false)
        
        next()
    }
  ]

# class Account extends Backbone.Model
#   database: database
#   storeName: 'account'

class TimestampModel extends Backbone.Model
  save: ->
    @set('createdAt': new Date()) if @isNew()
    @set('updatedAt': new Date())

    super

  touch: (callbacks) -> @save({}, callbacks)

class Gift extends TimestampModel
  database: database
  storeName: 'gifts'

  # Generate our own unique id from the token and toAccount
  # fields unless the id is already set
  generateId = (id, token, toAccount) ->
    if not id && token && toAccount
      "#{toAccount}-#{token}"
    else
      id

  constructor: ->
    super
    @set(id: generateId(@get('id'), @get('token'), @get('toAccount')))

  save: (props) ->
    @set(id: generateId(props?.id || @get('id'), props?.token || @get('token'), props?.toAccount || @get('toAccount')))
    super

  fetch: ->
    @set(id: generateId(@get('id'), @get('token'), @get('toAccount')))
    super

  url: ->
    params = btoa(JSON.stringify(page: 'acceptedGift', token: @get('token')))
    params = encodeURIComponent(JSON.stringify(encPrms: params))
    "https://plus.google.com/games/867517237916/params/#{params}/source/3/"

class Gifts extends Backbone.Collection
  model: Gift

class Gifter extends TimestampModel
  database: database
  storeName: 'gifters'

class Gifters extends Backbone.Collection
  model: Gifter
