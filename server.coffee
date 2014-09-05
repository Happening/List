db = require 'db'
plugin = require 'plugin'
event = require 'event'

exports.client_title = (title) !->
	db.shared 'title', title

exports.client_add = (text) !->

	item =
		text: text
		time: 0|(new Date()/1000)
		by: plugin.userId()

	maxId = 1 + (0|(db.shared 'maxId'))
	data = {maxId}
	data[maxId] = item

	(db.shared data)

	#name = plugin.userName()

	#event.create
	#	unit: 'msg'
	#	text: "#{name}: #{text}"
	#	read: [plugin.userId()]

exports.client_remove = (id) !->
	(db.shared id, null)

exports.client_complete = (id) !->
	if item = (db.shared id)
		(item "completed", !(item "completed"))

