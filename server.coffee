Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'
SF = require 'serverFunctions'

# Onupgrade, move all items to 'items' and give them an order and depth of 0

exports.client_add = (text, parent) !->
	log "P:", parent
	SF.add(text, parent, Plugin.userId())

	name = Plugin.userName()
	if parent
		parent = Db.shared.get('items', parent, 'text')
		Event.create
			text: "#{name} added an item to #{parent}: #{text}"
			sender: Plugin.userId()
	else
		Event.create
			text: "#{name} added an item: #{text}"
			sender: Plugin.userId()

exports.client_edit = (itemId, values) !->
	Db.shared.merge('items', itemId, values)

exports.client_setText = (id, text) !->
	Db.shared.set('items', id, 'text', text)

exports.client_remove = (id, children) !->
	return if Plugin.userId() isnt Db.shared.get('items', id, 'by') and !Plugin.userIsAdmin()
	SF.remove(id, children)

exports.client_complete = (id, value) !->
	log "setting completed", id
	if Db.shared.get('items', id)
		Db.shared.set 'items', id, 'completed', !!value

exports.client_reorder = (id, pos, indent, length = 1) !->
	SF.reorder id, pos, indent, length

exports.client_assign = (id, user = Plugin.userId()) !->
	log "assigneing", id, user
	if ass = Db.shared.get('items', id, 'assigned')
		if user in ass
			ass.splice(ass.indexOf(user), 1)
			Db.shared.set 'items', id, 'assigned', ass
		else
			ass.push user
			Db.shared.set 'items', id, 'assigned', ass
			# Db.shared.set id, 'assigned', user
	else
		Db.shared.set 'items', id, 'assigned', [user]

exports.client_collapse = (key, value) !->
	log "collapse", key, value
	Db.personal(Plugin.userId()).set 'collapsed', key, value

exports.client_resetOrder = !->
	order = 0
	Db.shared.forEach 'items', (item) !->
		item.set 'order', ++order
		item.set 'depth', 0
