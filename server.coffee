Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'

# Onupgrade, move all items to 'items' and give them an order.

exports.client_add = (text) !->
	# reorder to make room
	Db.shared.forEach 'items', (item) !->
		if item.key() isnt 'maxId' and item.key() isnt 'comments'
			item.incr 'order', 1

	# make new item and write
	item =
		text: text
		time: 0|(new Date()/1000)
		by: Plugin.userId()
		order: 1

	maxId = Db.shared.incr('maxId')
	Db.shared.set('items', maxId, item)

	name = Plugin.userName()
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

exports.client_reoder = (id, pos) !->
	log "reorder", id, pos
	if id == pos then return
	if pos > id
		Db.shared.forEach 'items', (item) !->
			if item.get('order') > id and item.get('order') <= pos
				item.incr 'order', -1
			else if item.get('order') is id
				item.set 'order', pos
	else
		Db.shared.forEach 'items', (item) !->
			if item.get('order') < id and item.get('order') >= pos
				item.incr 'order', 1
			else if item.get('order') is id
				item.set 'order', pos

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