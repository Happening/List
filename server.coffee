Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'
SF = require 'serverFunctions'

# Onupgrade, move all items to 'items' and give them an order and depth of 0
exports.onUpgrade = !->
	return # done already!


	log "upgrading..."
	# take all items
	walker = Db.shared.get('maxId') || 0
	log "max Id:", walker

	# count completed
	incompletedCnt = 0
	for i in [1..walker]
		item = Db.shared.get i
		continue if !item? or item.completed
		incompletedCnt++

	lastOrderIncompleted = 0
	lastOrderCompleted = incompletedCnt
	while walker>0
		# check if it is an item
		item = Db.shared.ref walker
		if item.isHash()
			# give them a order, depth and assigned
			newItem = {}
			if item.get('completed')
				newItem.order = ++lastOrderCompleted
			else
				newItem.order = ++lastOrderIncompleted
			newItem.depth = 0
			if a = (item.get('assigned')||0)
				(newItem.assigned = {})[a] = true
			newItem.text = item.get('text')||""
			newItem.by = item.get('by')||""
			newItem.time = item.get('time')||0
			newItem.notes = item.get('notes')||null
			newItem.completed = item.get('completed')||null
			# move it into 'items'
			Db.shared.set('items', item.key(), newItem)
			Db.shared.remove(item.key())
			log "upgraded", walker, lastOrderIncompleted, lastOrderCompleted, newItem.text, a
		else
			log "Item #{walker} is null"
		walker--
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
