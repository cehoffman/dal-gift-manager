(function () { /*global _: false, Backbone: false */
    // Generate four random hex digits.
    function S4() {
        return (((1 + Math.random()) * 0x10000) | 0).toString(16).substring(1);
    }

    // Generate a pseudo-GUID by concatenating random hexadecimal.
    function guid() {
        return (S4() + S4() + "-" + S4() + "-" + S4() + "-" + S4() + "-" + S4() + S4() + S4());
    }

    var indexedDB = window.indexedDB || window.webkitIndexedDB || window.mozIndexedDB;
    var IDBTransaction = window.IDBTransaction || window.webkitIDBTransaction; // No prefix in moz
    var IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange; // No prefix in moz

    /* Horrible Hack to prevent ' Expected an identifier and instead saw 'continue' (a reserved word).'*/
    if (window.indexedDB) {
         indexedDB.prototype._continue =  indexedDB.prototype.continue;
    } else if (window.webkitIDBRequest) {
        webkitIDBRequest.prototype._continue = webkitIDBRequest.prototype.continue;
    } else if(window.mozIndexedDB) {
        mozIndexedDB.prototype._continue = mozIndexedDB.prototype.continue;
    }
    
    // Driver object
    function Driver() {}

    function debug_log(str) {
        if (typeof window.console !== "undefined" && typeof window.console.log !== "undefined") {
            window.console.log(str);
        }
    }

    // Driver Prototype
    Driver.prototype = {

        // Performs all the migrations to reach the right version of the database
        migrate: function (db, migrations, version, options) {
            debug_log("Starting migrations from " + version);
            this._migrate_next(db, migrations, version, options);
        },

        // Performs the next migrations. This method is private and should probably not be called.
        _migrate_next: function (db, migrations, version, options) {
            var that = this;
            var migration = migrations.shift();
            if (migration) {
                if (!version || version < migration.version) {
                    // We need to apply this migration-
                    if (typeof migration.before == "undefined") {
                        migration.before = function (db, next) {
                            next();
                        };
                    }
                    if (typeof migration.after == "undefined") {
                        migration.after = function (db, next) {
                            next();
                        };
                    }
                    // First, let's run the before script
                    migration.before(db, function () {
                        var versionRequest = db.setVersion(migration.version);
                        versionRequest.onsuccess = function (e) {
                            migration.migrate(db, versionRequest, function () {
                                // Migration successfully appliedn let's go to the next one!
                                migration.after(db, function () {
                                    debug_log("Migrated to " + migration.version);
                                    that._migrate_next(db, migrations, version, options);
                                });
                            });
                        };
                    });
                } else {
                    // No need to apply this migration
                    debug_log("Skipping migration " + migration.version);
                    this._migrate_next(db, migrations, version, options);
                }
            } else {
                debug_log("Done migrating");
                // No more migration
                options.success();
            }
        },

        /* This is the main method. */
        execute: function (db, storeName, method, object, options) {
            switch (method) {
            case "create":
                this.write(db, storeName, object, options);
                break;
            case "read":
                if (object instanceof Backbone.Collection) {
                    this.query(db, storeName, object, options); // It's a collection
                } else {
                    if (object.id) {
                      // Do a speedy fetch if accessing by id
                      this.read(db, storeName, object, options);
                    } else {
                      // otherwise use the set attributes to build
                      // a query from the indexes present to fetch

                      // Wrap success method because it expects a
                      // single object
                      var wrappedSuccess = options.success;
                      options.success = function(items) {
                        wrappedSuccess(items[0]);
                      }
                      options.conditions = object.toJSON();
                      options.limit = 1;

                      this.query(db, storeName, object, options);
                    }
                }
                break;
            case "update":
                this.write(db, storeName, object, options); // We may want to check that this is not a collection
                break;
            case "delete":
                this.delete(db, storeName, object, options); // We may want to check that this is not a collection
                break;
            default:
                // Hum what?
            }
        },

        // Writes the json to the storeName in db.
        // options are just success and error callbacks.
        write: function (db, storeName, object, options) {
            var writeTransaction = db.transaction([storeName], IDBTransaction.READ_WRITE, 0);
            var store = writeTransaction.objectStore(storeName);
            var json = object.toJSON();

            if (!json.id) json.id = guid();

            var writeRequest = store.put(json);

            writeRequest.onerror = function (e) {
                options.error(e);
            };
            writeRequest.onsuccess = function (e) {
                options.success(json);
            };
        },

        // Reads from storeName in db with json.id if it's there of with any json.xxxx as long as xxx is an index in storeName 
        read: function (db, storeName, object, options) {
            var readTransaction = db.transaction([storeName], IDBTransaction.READ_ONLY);
            var store = readTransaction.objectStore(storeName);
            var getRequest = store.get(object.id);

            getRequest.onsuccess = function(event) {
              if (event.target.result) {
                options.success(event.target.result);
              } else {
                options.error('Not Found');
              }
            }

            getRequest.onerror = options.error;
        },

        // Deletes the json.id key and value in storeName from db.
        delete: function (db, storeName, object, options) {
            var deleteTransaction = db.transaction([storeName], IDBTransaction.READ_WRITE);
            var store = deleteTransaction.objectStore(storeName);
            var json = object.toJSON();

            var deleteRequest = store.delete(json.id);
            deleteRequest.onsuccess = function (event) {
                options.success(null);
            };
            deleteRequest.onerror = function (event) {
                options.error("Not Deleted");
            };
        },

        // Performs a query on storeName in db.
        // options may include :
        // - conditions : value of an index, or range for an index
        // - range : range for the primary key
        // - limit : max number of elements to be yielded
        // - offset : skipped items.
        // - order : how to order the final results
        query: function (db, storeName, collection, options) {
            var elements = {}, completedCursors = 0;
            var queryTransaction = db.transaction([storeName], IDBTransaction.READ_WRITE);
            var readCursors = {};
            var store = queryTransaction.objectStore(storeName);
            var index = null,
                lower = null,
                upper = null,
                bounds = null,
                keyPath = null;

            if (options.range) {
              options.conditions = options.conditons || {};
              options.conditions.id = options.range;
              delete options.range;
            }

            if (options.conditions) {
                // We have a condition, we need to use it for the cursor
                _.each(['id'].concat(Array.prototype.slice.apply(store.indexNames)), function (key) {
                    if (key === 'id') {
                      index = store;
                      keyPath = 'id';
                    } else {
                      index = store.index(key);
                      keyPath = index.keyPath;
                    }

                    if (_.isArray(options.conditions[keyPath])) {
                        lower = options.conditions[keyPath][0] > options.conditions[keyPath][1] ? options.conditions[keyPath][1] : options.conditions[keyPath][0];
                        upper = options.conditions[keyPath][0] > options.conditions[keyPath][1] ? options.conditions[keyPath][0] : options.conditions[keyPath][1];
                        bounds = IDBKeyRange.bound(lower, upper, true, true);
                        
                        // if (!options.order && _.size(options.conditions) === 1) {
                        //     if (options.conditions[keyPath][0] > options.conditions[keyPath][1]) {
                        //         // Looks like we want the DESC order
                        //         options.order = {}
                        //         options.order[keyPath] == 'desc';
                        //     } else {
                        //         // We want ASC order
                        //         options.order = keyPath;
                        //     }
                        // }

                        readCursors[keyPath] = index.openCursor(bounds);
                    } else if (options.conditions[keyPath]) {
                        bounds = IDBKeyRange.only(options.conditions[keyPath]);
                        readCursors[keyPath]= index.openCursor(bounds);
                    }
                });
            } else {
              readCursors['id'] = store.openCursor();
            }
            
            if (_.isEmpty(readCursors)) {
                options.error("No Cursor");
            } else {
                _.each(readCursors, function(readCursor, key) {
                    // Setup a handler for the cursor’s `success` event:
                    readCursor.onsuccess = function (e) {
                        var cursor = e.target.result;
                        if (!cursor) {
                            if (++completedCursors === _.size(readCursors)) {
                                var smallest = _.min(elements, function(value) {
                                    return _.size(value);
                                }), results = _.select(_.size(smallest) > 0 ? smallest : [], function(value, key) {
                                    return _.all(elements, function(value) { return value[key] });
                                })

                                // if (options.order) {
                                //     var prop, dir;
                                //     if (_.isString(options.order)) {
                                //       prop = options.order;
                                //       dir = 'asc';
                                //     } else {
                                //       _.each(options.order, function(value, key) { prop = key, dir = value; });
                                //     }
                                //     results = results.sort(function(left, right) {
                                //       return left[prop] < right[prop] ? dir === 'asc' ? -1 : 1 : left[prop] > right[prop] ? dir === 'asc' ? 1 : -1 : 0;
                                //     });
                                // }

                                if (options.offset) {
                                    results = results.slice(options.offset);
                                }

                                if (options.limit) {
                                    results = results.slice(0, options.limit);
                                }

                                if (_.isEmpty(results)) {
                                    options.success([]);
                                // } else if (options.addIndividually) {
                                //     _.each(results, function(item) {
                                //         collection.add(item);
                                //     });
                                } else if (options.clear) {
                                    var completedDeletes = 0;
                                    _.each(results, function(item) {
                                        var deleteRequest = store.delete(cursor.value.id);
                                        deleteRequest.onsuccess = function(event) {
                                            if (++compeltedDeletes == _.size(results)) {
                                                options.success(results);
                                            }
                                        }

                                        // No idea if this is the right thing to do
                                        deleteRequest.onerror = function(event) {
                                            options.error(event);
                                        }
                                    });
                                } else {
                                    options.success(results);
                                }
                            }
                        } else {
                          elements[key] = elements[key] || {};
                          elements[key][cursor.value.id] = cursor.value;
                          cursor.continue();
                        }
                    };
                });
            }
        }
    };


    // Keeps track of the connections
    var Connections = {};

    // ExecutionQueue object
    function ExecutionQueue(driver, database) {
        this.driver = driver;
        this.database = database
        this.started = false;
        this.stack = [];
        this.connection = null;
        this.dbRequest = indexedDB.open(database.id, database.description || "");
        this.error = null;

        this.dbRequest.onsuccess = function (e) {
            this.connection = e.target.result; // Attach the connection ot the queue.
            if (this.connection.version === _.last(database.migrations).version) {
                // No migration to perform!
                this.ready();
            } else if (this.connection.version < _.last(database.migrations).version) {
                // We need to migrate up to the current migration defined in the database
                driver.migrate(this.connection, database.migrations, this.connection.version, {
                    success: function () {
                        this.ready();
                    }.bind(this),
                    error: function () {
                        this.error = "Database not up to date. " + this.connection.version + " expected was " + _.last(database.migrations).version;
                    }.bind(this)
                });
            } else {
                // Looks like the IndexedDB is at a higher version than the current database.
                this.error = "Database version is greater than current code " + this.connection.version + " expected was " + _.last(database.migrations).version;
            }
        }.bind(this);

        this.dbRequest.onerror = function (e) {
            // Failed to open the database
            this.error = "Couldn't not connect to the database"
        }.bind(this);

        this.dbRequest.onabort = function (e) {
            // Failed to open the database
            this.error = "Connection to the database aborted"
        }.bind(this);


    }

    // ExecutionQueue Prototype
    ExecutionQueue.prototype = {

        ready: function () {
            this.started = true;
            _.each(this.stack, function (message) {
                this.execute(message);
            }.bind(this));
        },

        execute: function (message) {
            if (this.error) {
                message[3].error(this.error);
            } else {
                if (this.started) {
                    this.driver.execute(this.connection, message[2], message[0], message[1], message[3]); // Upon messages, we execute the query
                } else {
                    this.stack.push(message);
                }
            }
        }

    };

    Backbone.sync = function (method, object, options) {
        var database, storeName, driver = new Driver();
        if (object instanceof Backbone.Collection) {
          database = object.model.prototype.database;
          storeName = object.model.prototype.storeName;
        } else {
          database = object.database;
          storeName = object.storeName;
        }

        if (!Connections[database.id]) {
            Connections[database.id] = new ExecutionQueue(driver, database);
        }
        Connections[database.id].execute([method, object, storeName, options]);
    };
})();
