Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'
SF = require 'serverFunctions'

# Onupgrade, move all items to 'items' and give them an order and depth of 0
exports.onUpgrade = !->
	log "upgrading..."
	# take all items
	lastOrder = 0
	Db.shared.forEach (item) !-> # This could include, 'maxId', 'comments', 'items' and 'completed'
		# check if it is an item
		a = 0
		if item.key().toString().match ///^\d+$///i #is only numbers
			# give them a order, depth and assigned
			newItem = {}
			newItem.order = item.get('order') || ++lastOrder
			newItem.depth = item.get('depth')||0
			a = item.get('assigned')||0
			newItem.text = item.get('text')||""
			newItem.by = item.get('by')||""
			newItem.time = item.get('time')||0
			newItem.notes = item.get('notes')||null
			newItem.completed = item.get('completed')||null
			# move it into 'items'
			lastOrder = newItem.order
			Db.shared.set('items', item.key(), newItem)
			if a then Db.shared.set('items', item.key(), 'assigned', a, true)
			Db.shared.remove(item.key())
			log "upped", newItem.text, lastOrder, a
		else
			log item.key(), "not an number"
	# create 'completed' (but don't destroy if it already existed)
	Db.shared.merge('completed', {})
	# done
	log "upgrading completed!"

exports.client_add = add = (text, order, depth, parent) !->
	SF.add(text, order, depth, Plugin.userId())

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

exports.client_edit = (itemId, values, assigned, completed, children) !->
	SF.edit itemId, values, assigned, completed, children

exports.client_setText = (id, text) !->
	Db.shared.set('items', id, 'text', text)

exports.client_remove = (id, children, completed) !->
	# first check authentication
	if !completed
		return if Plugin.userId() isnt Db.shared.get('items', id, 'by') and !Plugin.userIsAdmin()
	else
		return if Plugin.userId() isnt Db.shared.get('completed', id, 'by') and !Plugin.userIsAdmin()
	SF.remove(id, children, completed)

exports.client_complete = (id, value, inList, children = []) !->
	SF.complete id, value, inList, children

exports.client_reorder = (id, pos, indent, length = 1) !->
	SF.reorder id, pos, indent, length

exports.client_assign = assign = (id, user) !->
	if Db.shared.get('items', id, 'assigned', user)
		Db.shared.remove('items', id, 'assigned', user)
	else
		Db.shared.set('items', id, 'assigned', user, true)

exports.client_collapse = (key, value) !->
	Db.personal(Plugin.userId()).set 'collapsed', key, value

exports.client_hideCompleted = (key, ch) !->
	SF.hideCompleted(key, ch)

exports.fixItems = (itemsFixed) !->
	log "WARNING: Client", Plugin.userId(), "had to fix", itemsFixed, "items!"
