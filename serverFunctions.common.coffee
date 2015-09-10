Db = require 'db'

exports.add = (text, order, depth, userId) !->
	log "Adding new item", text, order, depth
	# make new item and write
	o = 1
	# if parent
	# 	o = Db.shared.get('items', parent, 'order')+1
	# 	d = Db.shared.get('items', parent, 'depth')+1
	if order
		o = order
		d = depth
		item =
			text: text
			time: 0|(new Date()/1000)
			by: userId
			order: order
			depth: depth
			assigned: {}
	else
		item =
			text: text
			time: 0|(new Date()/1000)
			by: userId
			order: o
			depth: 0
			assigned: {}

	# reorder to make room
	Db.shared.forEach 'items', (item) !->
		if item.get('order') >=o
			item.incr 'order', 1

	maxId = Db.shared.incr('maxId')
	Db.shared.set('items', maxId, item)

exports.reorder = (id, pos, indentDelta, length = 1) !->
	if id == pos and indentDelta == 0 then return
	delta = pos-id
	if pos > id
		Db.shared.forEach 'items', (item) !->
			if item.get('order') > id+length-1 and item.get('order') <= pos
				item.incr 'order', -length
			else if item.get('order') >= id and item.get('order') < pos
				item.incr 'order', delta-(length-1)
				item.incr 'depth', indentDelta
				log "SF: incr depth by", indentDelta, item.get('order')
	else
		Db.shared.forEach 'items', (item) !->
			if item.get('order') < id and item.get('order') >= pos
				item.incr 'order', length
			else if item.get('order') >= id and item.get('order') < id+length
				item.incr 'order', delta
				item.incr 'depth', indentDelta
				log "SF: incr depth by", indentDelta, item.get('order')

exports.remove = remove = (key, children) !->
	o = Db.shared.get('items', key, 'order')
	for c in children # mind you, the parent is also in this list
		Db.shared.remove('items', c)
	# reorder stuff
	Db.shared.forEach 'items', (item) !->
		if item.get('order') >o
			item.incr 'order', -(children.length)

exports.hideCompleted = (key, children) !->
	o = Db.shared.get('items', key, 'order')
	depthOffset = Db.shared.get('items', key, 'depth')
	# reorder completed list in advanced
	Db.shared.forEach 'completed', (i) !->
		# if i.get('cOrder') children.length
		i.incr 'cOrder', children.length
	# for each item
	cO = 0
	for c in children # mind you, the parent is also in this list
		++cO
		item = Db.shared.get('items', c)
		item.cDepth = item.depth - depthOffset
		item.cOrder = cO
		Db.shared.set 'completed', c, item
		Db.shared.remove('items', c)
	# reorder
	Db.shared.forEach 'items', (i) !->
		if i.get('order') >= o
			i.incr 'order', -(children.length)