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
	log "setting completed", id
	if Db.shared.get(id)
		Db.shared.set id, 'completed', !!value

exports.client_assign = (id, user = Plugin.userId()) !->
	log "assigneing", id, user
	if ass = Db.shared.get(id, 'assigned')
		if user in ass
			ass.splice(ass.indexOf(user), 1)
			Db.shared.set id, 'assigned', ass
		else
			ass.push user
			Db.shared.set id, 'assigned', ass
			# Db.shared.set id, 'assigned', user
	else
		Db.shared.set id, 'assigned', [user]