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
    },
    {
      version: '0.0.4'
      migrate: (db, versionRequest, next) ->
        store = versionRequest.transaction.objectStore('gifters')
        store.deleteIndex('gplusIdIndex')
        store.createIndex('accountIndex', 'account', unique: false)
        next()
    },
    {
      version: '0.0.8'
      before: (db, next) ->
        txn = db.transaction(['gifters'], webkitIDBTransaction.READ_WRITE)
        store = txn.objectStore('gifters')
        cursor = store.openCursor()

        readCount = 0
        writeCount = 0
        deleteCount = 0
        done = false
        cursor.onsuccess = (event) ->
          if not event.target.result
            done = true
            next() if writeCount is readCount is deleteCount
          else
            readCount++

            obj = event.target.result.value

            dtxn = store.delete(obj.id)
            dtxn.onsuccess ->
              next() if ++deleteCount is writeCount is readCount && done

            obj.id = "#{obj.toAccount}-#{obj.account}"
            obj.oid = obj.account

            wtxn = store.put(obj)
            wtxn.onsuccess = ->
              next() if ++writeCount is readCount is deleteCount && done


            event.target.result.continue()

      migrate: (db, versionRequest, next) ->
        store = versionRequest.transaction.objectStore('gifters')
        store.deleteIndex('accountIndex')
        store.createIndex('oidIndex', 'oid', unique: false)
        next()
      after: (db, next) ->
        txn = db.transaction(['gifters'], webkitIDBTransaction.READ_WRITE)
        store = txn.objectStore('gifters')
        cursor = store.openCursor()

        readCount = 0
        writeCount = 0
        done = false
        cursor.onsuccess = (event) ->
          if not event.target.result
            done = true
            next() if writeCount is readCount
          else
            readCount++

            obj = event.target.result.value
            delete obj['account']

            wtxn = store.put(obj)
            wtxn.onsuccess = ->
              next() if ++writeCount is readCount && done

            event.target.result.continue()
    },
    {
      version: '0.0.9'
      before: (db, next) ->
        txn = db.transaction(['gifters'], webkitIDBTransaction.READ_WRITE)
        store = txn.objectStore('gifters')
        cursor = store.openCursor()

        readCount = 0
        writeCount = 0
        done = false
        cursor.onsuccess = (event) ->
          if not event.target.result
            done = true
            next() if writeCount is readCount
          else
            readCount++

            obj = event.target.result.value
            obj.active = true

            wtxn = store.put(obj)
            wtxn.onsuccess = ->
              next() if ++writeCount is readCount && done


            event.target.result.continue()
      migrate: (db, versionRequest, next) ->
        store = versionRequest.transaction.objectStore('gifters')
        store.createIndex('activeIndex', 'active', unique: false)
        next()
    },
    {
      version: '0.1.0'
      migrate: (db, versionRequest, next) ->
        store = versionRequest.transaction.objectStore('gifters')
        store.deleteIndex('activeIndex')
        next()
    }
  ]

class AutoIdModel extends Backbone.Model
  save: ->
    @set({id}) if !(@id || @get('id')) && id = @_autoId()
    super

  fetch: ->
    @set({id}) if !(@id || @get('id')) && id = @_autoId()
    super


class TimestampModel extends AutoIdModel
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
  _autoId: ->
    [token, toAccount] = [@get('token'), @get('toAccount')]
    "#{toAccount}-#{token}" if token && toAccount

  url: ->
    params = btoa(JSON.stringify(page: 'acceptedGift', token: @get('token')))
    params = encodeURIComponent(JSON.stringify(encPrms: params))
    "https://plus.google.com/games/867517237916/params/#{params}/source/3/"

class Gifts extends Backbone.Collection
  model: Gift

class Gifter extends TimestampModel
  database: database
  storeName: 'gifters'

  _autoId: ->
    [oid, toAccount] = [@get('oid'), @get('toAccount')]
    "#{toAccount}-#{oid}" if oid && toAccount

  isGiftable: ->
    @get('active') && (!@get('lastGift') || @get('lastGift') < (new Date() - 1000 * 60 * 60 * 24))

class Gifters extends Backbone.Collection
  model: Gifter
