Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'

exports.getTitle = ->
	Db.shared.get 'title'

exports.onInstall = (config) !->
	if config?
		Db.shared.merge config
		Event.create
			unit: 'other'
			text: "#{Plugin.userName(Plugin.ownerId())} added a list: #{config.title}"
			new: ['all', -Plugin.ownerId()]

exports.onConfig = (config) !->
	Db.shared.merge config

exports.client_add = (text) !->

	item =
		text: text
		time: 0|(new Date()/1000)
		by: Plugin.userId()

	maxId = Db.shared.incr('maxId')
	Db.shared.set(maxId, item)

	#name = Plugin.userName()

	#Event.create
	#	unit: 'msg'
	#	text: "#{name}: #{text}"
	#	read: [Plugin.userId()]

exports.client_edit = (itemId, values) !->
	Db.shared.merge(itemId, values)

exports.client_setText = (id, text) !->
	Db.shared.set(id, 'text', text)

exports.client_remove = (id) !->
	return if Plugin.userId() isnt Db.shared.get(id, 'by') and !Plugin.userIsAdmin()
	Db.shared.remove(id)

exports.client_complete = (id) !->
	if Db.shared.get(id)
		Db.shared.set(id, 'completed', !Db.shared.get(id, 'completed'))

