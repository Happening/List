Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'

# Onupgrade, move all items to 'items' and give them an order and depth of 0

exports.client_add = (text, parent) !->

	# make new item and write
	o = 1
	if parent
		o = Db.shared.get('items', parent, 'order')+1
		d = Db.shared.get('items', parent, 'depth')+1
		item =
			text: text
			time: 0|(new Date()/1000)
			by: Plugin.userId()
			order: o
			depth: d
	else
		item =
			text: text
			time: 0|(new Date()/1000)
			by: Plugin.userId()
			order: o
			depth: 0

	# reorder to make room
	Db.shared.forEach 'items', (item) !->
		if item.get('order') >=o
			item.incr 'order', 1

	maxId = Db.shared.incr('maxId')
	Db.shared.set('items', maxId, item)

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

exports.client_remove = (id) !->
	return if Plugin.userId() isnt Db.shared.get('items', id, 'by') and !Plugin.userIsAdmin()
	Db.shared.remove('items', id)

exports.client_complete = (id, value) !->
	log "setting completed", id
	if Db.shared.get('items', id)
		Db.shared.set 'items', id, 'completed', !!value

exports.client_reoder = (id, pos, length = 1) !->
	if id == pos then return
	delta = pos-id
	if pos > id
		Db.shared.forEach 'items', (item) !->
			if item.get('order') > id+length-1 and item.get('order') <= pos
				item.incr 'order', -length
			else if item.get('order') >= id and item.get('order') < pos
				item.incr 'order', delta-(length-1)
	else
		Db.shared.forEach 'items', (item) !->
			if item.get('order') < id and item.get('order') >= pos
				item.incr 'order', length
			else if item.get('order') >= id and item.get('order') < id+length
				item.incr 'order', delta

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
		log "item set to " + order