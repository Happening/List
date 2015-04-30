Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'

exports.client_add = (text) !->

	item =
		text: text
		time: 0|(new Date()/1000)
		by: Plugin.userId()

	maxId = Db.shared.incr('maxId')
	Db.shared.set(maxId, item)

	name = Plugin.userName()
	Event.create
		text: "#{name} added an item: #{text}"
		sender: Plugin.userId()

exports.client_edit = (itemId, values) !->
	Db.shared.merge(itemId, values)

exports.client_setText = (id, text) !->
	Db.shared.set(id, 'text', text)

exports.client_remove = (id) !->
	return if Plugin.userId() isnt Db.shared.get(id, 'by') and !Plugin.userIsAdmin()
	Db.shared.remove(id)

exports.client_complete = (id, value) !->
	if Db.shared.get(id)
		Db.shared.set id, 'completed', !!value
