Db = require 'db'

exports.add = (text, order, depth, userId) ->
	# make new item and write
	o = 1
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
	else
		Db.shared.forEach 'items', (item) !->
			if item.get('order') < id and item.get('order') >= pos
				item.incr 'order', length
			else if item.get('order') >= id and item.get('order') < id+length
				item.incr 'order', delta
				item.incr 'depth', indentDelta

exports.remove = remove = (key, children, completed = false) !->
	if !completed
		o = Db.shared.get('items', key, 'order')
		for c in children # mind you, the parent is also in this list
			Db.shared.remove('items', c)

		# reorder stuff
		Db.shared.forEach 'items', (item) !->
			if item.get('order') >o
				item.incr 'order', -(children.length)
	else
		for c in children # mind you, the parent is also in this list
			Db.shared.remove('completed', c)

exports.edit = (itemId, values, assigned, completed, children) !->
	toggleCompleted = false
	if completed # in completed list or normal?
		if values.completed isnt !!Db.shared.get('completed', itemId, 'completed') then toggleCompleted = true
			# also, set completed.
		Db.shared.merge('completed', itemId, values)
		Db.shared.set('completed', itemId, 'assigned', assigned)
	else
		if values.completed isnt !!Db.shared.get('items', itemId, 'completed') then toggleCompleted = true
		Db.shared.merge('items', itemId, values)
		Db.shared.set('items', itemId, 'assigned', assigned)
	if toggleCompleted
		complete itemId, !completed, completed, children

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
		if item? # One does wonder...
			item.cDepth = item.depth - depthOffset
			item.cOrder = cO
			Db.shared.set 'completed', c, item
			Db.shared.remove('items', c)
	# reorder
	Db.shared.forEach 'items', (i) !->
		if i.get('order') >= o
			i.incr 'order', -(children.length)

exports.complete = complete = (id, value, inCompletedList, children) !->
	if !inCompletedList
		if Db.shared.get('items', id)
			Db.shared.set 'items', id, 'completed', !!value
		# set children value
		for c in children
			if Db.shared.get('items', c)
				Db.shared.set('items', c, 'completed', !!value)
	else # more from completed list to normal
		# make room
		item = Db.shared.get('completed', id)
		o = item.order
		potentialDepth = 0
		itemsLength = 0
		Db.shared.forEach 'items', (i) !-> # count
			++itemsLength
		o = Math.min(itemsLength+1,o)
		Db.shared.forEach 'items', (i) !->
			io = i.get('order')
			if io == o-1
				# this will be just above the stuff we're gonna move
				potentialDepth = i.get('depth')+1
			if io >= o
				i.incr 'order', children.length||1
		# move
		# depthOffset should be cDepth minus depth of item above where I am to go...
		depthOffset = item.depth-potentialDepth
		for c,i in children # mind you, the parent is also in this list
			item = Db.shared.get('completed', c)
			item.depth -= Math.max(0, depthOffset)
			item.order = o+i
			# item.order = Math.min(itemsLength+children.length, item.order)
			item.cDepth = null
			item.cOrder = null
			item.completed = null
			Db.shared.set('items', c, item)
			Db.shared.remove('completed', c)
