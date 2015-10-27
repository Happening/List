Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
Obs = require 'obs'
Page = require 'page'
Plugin = require 'plugin'
Server = require 'server'
Ui = require 'ui'
{tr} = require 'i18n'
Menu = require 'menu'
SF = require 'serverFunctions'

swipeToCompleteTreshold = 50 # in pixels
swipeToCompleteRespondTreshold = 5 # in pixels applied on Y axis!
dragScrollTreshold = 60 # in pixels

exports.renderList = !->
	mobile = Plugin.agent().ios or Plugin.agent().android
	items = []
	completedItems = []
	oldY = 0
	contentE = Dom.get()
	scrollDelta = 0
	startScrollDelta = 0
	scrolling = 0
	dragDirection = 0 # 1 for x, -1 for y
	dragPosition = -1
	draggedElement = null
	draggedElementHeight = 0
	draggedY = 0
	oldDraggedY = 0
	draggedElementY = 0
	draggedIndeting = 0
	showCompletedO = Obs.create(false)
	focusO = Obs.create(0) # used to focus on 'add (sub) item' fields

	class Item
		constructor: (@dbRef, @element, @inCompletedList = false) ->
			@key = parseInt(dbRef.key())
			@time = dbRef.peek('time')
			@order = dbRef.peek('order')
			@cOrder = dbRef.peek('cOrder')
			@depth = dbRef.peek('depth')
			@cDepth = dbRef.peek('cDepth')
			@text = dbRef.peek('text')
			@notes = dbRef.peek('notes')
			@assigned = []
			@completed = dbRef.peek('completed')
			@children = []
			@childrenKeys = [@key]
			@treeLength = 1 # always yourself
			@collapsed = Db.personal.peek 'collapsed', @key
			@hidden = false
			@arrowO = Obs.create(0)
			@offsetO = Obs.create(0)
			@showPlusO = Obs.create(-1)
			@plusOffsetO = Obs.create(0)
			@editingItemO = Obs.create(false)
			@pCompletedO = Obs.create(false)
			@plusElement = null
			@plusChild = null # which child would bear the add subitem
			@contentElement = @element
			item = this

			# if we are at depth 0 and new, show +
			# if parseInt(Db.local.peek('new')) is @key # I just added this
			# 	# if no children...
			# 	if @depth is 0 and Event.isNew(item.time)
			# 		@showPlusO.set @key

			Obs.observe !->
				item.order = dbRef.get('order')
				item.depth = dbRef.get('depth')
				item.cDepth = dbRef.get('cDepth')
				item.cOrder = dbRef.get('cOrder')
				item.text = dbRef.get('text')
				item.notes = dbRef.get('notes')
				item.assigned = []
				item.assigned.push k for k of dbRef.get('assigned')
				item.completed = dbRef.get('completed')
				# just rerender when one of the above attributes change...
				item.render()

		render: ->
			item = this
			# log "(Re-)rendering", @order, @key, @text

			Dom.addClass "sortItem"
			# offset for dragging
			# item.offsetO.set 0 # reset own offset when rendering
			item.plusOffsetO.set 0 # reset plus offset when rendering
			Dom.style
				_transform: "translateY(#{'0px'})"
			Obs.observe !->
				offset = item.offsetO.get()
				Dom.style _transform: "translateY(#{offset + 'px'})"

			Dom.div !->
				Dom.addClass "sortItem"
				Dom.style
					Box: 'middle'

				# The Box
				Dom.div !->
					itemDE = Dom.get()
					item.contentElement = Dom.get()
					Dom.addClass "sortItem"
					Dom.style
						Flex: 1
						Box: 'left middle'
						# padding: "0 0 0 #{item.depth*15}" # reactive
						margin: if !item.inCompletedList then "2 0 2 #{item.depth*15}" else "2 0 2 #{item.cDepth*15}"# reactive
						backgroundColor: '#fff'
						borderRadius: '2px'

					# Content and avatar
					Dom.div !->
						Dom.style
							boxSizing: 'border-box'
							Box: 'middle'
							Flex: 1
							padding: '8px'
							textDecoration: if item.completed or item.pCompletedO.get() then 'line-through' else 'none'
							color: if item.completed or item.pCompletedO.get() then '#aaa' else 'inherit'
							fontSize: '16px' #'21px'
							wordBreak: 'break-word'

						#check box for desktop
						if !mobile
							# Form.vSep()
							item.completed
								# temp fix for problems arising from marking completed in edit item screen
							Form.check
								value: item.completed
								inScope: !->
									Dom.style margin: '0px 5px 0px -10px', _transform: "translate3d(0,0,0)" # fix for delayed view on webkit
								onChange: (v) !->
									item.setCompleted(v)
							# Form.vSep()

						# The content
						Dom.div !->
							Dom.style
								Flex: 1
								color: (if Event.isNew(item.time) then '#5b0' else 'inherit')
							Dom.userText item.text
							if notes = item.notes
								Dom.div !->
									Dom.style
										color: '#aaa'
										whiteSpace: 'nowrap'
										fontSize: '80%'
										fontWeight: 'normal'
										overflow: 'hidden'
										textOverflow: 'ellipsis'
									Dom.text notes
						# Event bubble
						Dom.div !->
							Event.renderBubble [item.key], style:
								margin: '2px 0px'
						# Assigned
						Dom.div !->
							Dom.style
								marginRight: '-4px'
								position: 'relative'
							assigned = item.assigned
							if !assigned? or assigned.length is 0
								# Do nothing
							else if assigned.length is 1
								Ui.avatar Plugin.userAvatar(assigned[0]), size: 30, style: margin: '0 0 0 8px'
							else if assigned.length > 1
								Ui.avatar '#bbb', size: 30, style: margin: '0 0 0 8px'
								Dom.div !->
									Dom.style
										position: 'absolute'
										top: '6px'
										left: '8px'
										fontSize: '75%'
										fontWeight: 'bold'
										width: '32px'
										textAlign: 'center'
										color: '#fff'
									Dom.text assigned.length
						# if !item.inCompletedList
						Dom.onTap !->
							Page.nav {0:item.key, "?children": item.childrenKeys, "?completed": item.completed}
						if mobile then item.dragToComplete itemDE

					# collapse
					Obs.observe !->
						ad = item.arrowO.get()
						if ad isnt 0
							Dom.div !->
								Dom.style
									Box: 'middle'
									margin: '0 6px'
									borderRadius: '3px'
									paddingLeft: '2px'
								if ad < 0
									# calc hidden events and new items
									gray = 0
									green = 0
									countEvent = (item, initial = false) !->
										unless initial
											raw = Event.getRaw [item.key]
											gray += raw[5]
											green += raw[3]
											green += if Event.isNew [item.time] then 1 else 0
										for c in item.children
											countEvent c
									countEvent item, true
									# render bubbles
									if (green+gray)
										Dom.div !->
											Dom.addClass 'event-bubble-inner'
											Dom.style
												background: if green>0 then '#5b0' else '#666'
												margin: '2px'
											Dom.text (green + gray)
									# Rest of collapse box
									Dom.style border: '1px solid #bbb'
									Dom.div !->
										Dom.style
											paddingLeft: '4px'
											fontSize: '75%'
											fontWeight: 'bold'
											color: '#bbb'
										Dom.text Math.abs(ad)
								Dom.div !->
									Icon.render
										data: if ad is 1 then 'arrowup' else 'arrowdown'
										color: '#bbb'

								Dom.onTap !->
									item.collapse(false, true, false, item.element.getOffsetXY().y)

					return if item.inCompletedList

					# Overflow menu
					Dom.div !->
						Dom.style
							padding: '8px'
							borderRadius: '16px'
							margin: '8px 8px 8px 0'
						Icon.render
							data: 'more'
							color: '#bbb'
							size: 16
						Dom.onTap !->
							Menu.renderMenu(item.key, item.childrenKeys, item)

				# Rearrange icon
				Dom.div !->
					if !item.inCompletedList
						Dom.style
							padding: "8px"
							marginRight: "-8px"
						Icon.render
							data: 'reorder'
							color: '#bbb'
						dragToReorder item
					else
						Dom.style
							width: '32px'

			return if item.inCompletedList
			Obs.observe !->
				if (p = item.showPlusO.get()) >= 0 and not item.arrowO.get()
					Dom.div !->
						item.plusElement = Dom.get()
						# Obs.observe !->
						offset = item.plusOffsetO.get()
						d = if p is parseInt(item.key) then 1 else 0
						desktopOffset = 0 # if mobile then 32 else 32
						Dom.addClass "sortItem"
						Dom.style
							_transform: "translateY(#{offset + 'px'})"
							padding: '4px 4px 4px 8px'
							# height: '50px'
							margin: "2 32 2 #{(item.depth+d)*15 + desktopOffset}" # reactive.
							display: 'block'
							backgroundColor: '#fff'
							borderRadius: '2px'
							minHeight: '38px'
							Box: 'middle'
						Dom.div !->
							Dom.style Box: 'middle'
							save = !->
								return if !addE.value().trim()
								# d = if p is parseInt(item.key) then 1 else 0
								Server.sync 'add', addE.value().trim(), item.order+1, item.depth + d, p, !->
									SF.add(addE.value().trim(), item.order+1, item.depth + d, Plugin.userId())
								addE.value ""
								item.editingItemO.set(false)
								Form.blur()
								focusO.set(item.order+1) # focus on new 'add subitem'

							addE = Form.text
								simple: true
								name: 'item' + item.key
								text: tr("New subitem ...")
								onChange: (v) !->
									if v?.trim().length or item.editingItemO.peek() isnt 'focus'
										item.editingItemO.set(!!v?.trim())
								onReturn: save
								rows: 1
								inScope: !->
									Dom.style
										border: 'none'
										fontSize: '100%'
										padding: '0px 52px 0px 0px'
										minHeight: '1.2em'
										width: '100%'
										padding: '0px'
							Obs.observe !->
								if focusO.get() is item.order or item.editingItemO.get() is 'focus'
									Obs.onTime 450, !->
										focusO.set(0) # reset. causes weird stuff while dragging
										addE.focus()

							Obs.observe !->
								Ui.button !->
									Dom.style
										visibility: (if item.editingItemO.get() is true then 'visible' else 'hidden')
										right: '4px'
									Dom.text tr("Add")
								, save
						# Form.sep()

		seekChildren: !->
			@children = []
			@childrenKeys = [@key]
			@treeLength = 1
			if @order < items.length # if we are the last. We have no children.
				for j in [@order..items.length-1]
					i = items[j]
					if !i?
						repairOrder()
					if i.depth is @depth+1 # No Luke, I am your father
						if i.getShowPlus() >= 0 then i.setShowPlus -1 # remove subitem thing, so be sure
						@children.push(i) # This makes a pointer right? Right?
						@childrenKeys.push(i.key)
						++@treeLength
					else
						if i.depth <= @depth # Lower or equal depth means not my child
							break
						if i.depth > @depth+1 # higher indent means this is a grandchild of me
							if @children.length == 0
								repairOrder()
							@childrenKeys.push(i.key)
							++@treeLength

				# if I have children, set 'addSubItem' to the parent
				if @children?.length
					# and remove + from myself
					@setShowPlus -1
					@children[@children.length-1].setShowPlus @key
					@plusChild = @children[@children.length-1]

			@arrowO.set (if @treeLength > 1 then 1 else 0)

		seekCompletedChildren: !->
			@children = []
			@childrenKeys = [@key]
			@treeLength = 1
			for i in completedItems
				continue unless i?
				if i.cOrder > @cOrder
					if i.cDepth is @cDepth+1 # No Luke, I am your father
						@children.push(i) # This makes a pointer right? Right?
						@childrenKeys.push(i.key)
						++@treeLength
					else
						if i.cDepth <= @cDepth # Lower or equal cDepth means not my child
							break
						if i.cDepth > @cDepth+1 # higher indent means this is a grandchild of me
							@childrenKeys.push(i.key)
							++@treeLength

		collapse: (force = false, toggle = false, initial = false, sourcePos = 0) !->
			return unless @children.length #of no children, never do any of this
			#either force it close, or restore it.
			collapsed = @collapsed
			if initial and !collapsed then return
			if force
				collapsed = true #we are currently collapsed
			else
				#toggle state
				if toggle
					collapsed = @collapsed = !@collapsed
					Server.send "collapse", @key, collapsed
			@arrowO.set if collapsed then -(@treeLength-1) else 1

			# height = 0
			for c in @children
				# height += c.element.height()
				c.collapse(collapsed, false, false, sourcePos)
				c.hide((if collapsed then sourcePos else -1), sourcePos == 0) # -1 unhides the item

		hide: (height, immediately = true) !->
			if immediately
				if height >= 0
					@element.style
						display: 'none'
					@hidden = true
				else
					@element.style
						display: 'inherit'
						_transform: "translateY(0px)"
						marginBottom: "0px"
						opacity: 1
						zIndex: 0
					@hidden = false
			else # animate!
				if height >= 0
					height = @element.getOffsetXY().y-height
					@element.style
						opacity: 0
						zIndex: '-99'
						position: 'relative'
						_transform: "translateY(-#{@element.height()}px)"
					item = this
					Obs.onTime 350, !->
						item.element.style display: 'none'
						# item.element.style marginBottom: "0px"
					@hidden = true
				else
					item = this
					@element.style
						display: 'inherit'
						# marginBottom: "-#{@element.height()}px"
					Obs.onTime 2, !-> # display kills the animation
						item.element.style
							_transform: "translateY(0px)"
							# marginBottom: "0px"
							opacity: 1
					Obs.onTime 200, !->
						item.element.style
							zIndex: 0
					@hidden = false

		setCompleted: (c) !->
			k = @key
			ch = @childrenKeys
			if @inCompletedList
				Server.sync 'complete', k, c, true, ch, !->
					SF.complete k, c, true, ch
			else
				Server.sync 'complete', k, c, false, null, !->
					Db.shared.set('items', k, 'completed', c)
				ch.setCompleted(c) for ch in @children # set to children
		setOffset: (offset) !->
			@offsetO.set offset
		getOffset: ->
			@offsetO.peek()
		setShowPlus: (show) !->
			@showPlusO.set show
		getShowPlus: ->
			@showPlusO.peek()
		setPlusOffset: (offset) !->
			@plusOffsetO.set offset
		getPlusOffset: ->
			@plusOffsetO.peek()
		hidePlus: !->
			@plusElement?.style display: 'none'
		unHidePlus: !-> # show is taken
			@plusElement?.style display: 'inherit'

		dragToComplete: (element) !->
			key = @key
			item = this
			# if mobile
			Dom.trackTouch (touches...) ->
				if dragDirection is -1
					if touches.length == 1 and touches[0].op&4 then dragDirection = 0
					return true
				if touches.length == 1
					# determine direction
					if dragDirection is 0
						if touches[0].x isnt 0 or touches[0].y isnt 0
							if touches[0].y is 0 or Math.abs(touches[0].x)/Math.abs(touches[0].y)|0.1 > 3
								dragDirection = 1
								element.addClass "dragging"
							else
								dragDirection = -1
								return true

					element.style _transform: "translateX(#{Math.min(120, Math.max(-120, touches[0].x)) + 'px'})"
					if touches[0].op&4 # touch is stopped
						dragDirection = 0
						if Math.abs(touches[0].x) > swipeToCompleteTreshold # threshold
							item.setCompleted !item.completed
						element.removeClass "dragging"
						element.style _transform: "translateX(0px)"
				return dragDirection < 1 # do default
			, element

	log "Make scrolling interval"
	Obs.interval 25, !->
		return unless scrolling
		scrollDelta = Math.min(contentE.height()-(Page.height()-100), Math.max(0, scrollDelta + scrolling * 10))
		Page.scroll(scrollDelta, false)
		if draggedElement?
			draggedElementY = draggedElement.element.getOffsetXY().y + draggedY + (draggedElement.element.height()/2) + scrollDelta - startScrollDelta
			onDrag()


	dragToReorder = (item) !->
		element = item.element
		elementO = item.order
		Dom.trackTouch (touches...) ->
			if touches.length == 1
				# drag element
				draggedY = touches[0].y
				horiontalDelta = touches[0].x

				if touches[0].op&1
					scrollDelta = Page.scroll()
					startScrollDelta = Page.scroll()
					item.hidePlus() # if we have a "+ add subitem" div, hide it
					draggedElementHeight = element.height()
					draggedElement = item
					dragPosition = item.order # Start position
					oldY = element.getOffsetXY().y + (element.height()/2)
					oldDraggedY = draggedY
					element.addClass "dragging"
					item.collapse(true)
					# item.collapse(true, false, false, element.getOffsetXY().y)
					draggedIndeting = 0

				# higher sample rate
				draggedDelta = draggedY-oldDraggedY
				while Math.abs(draggedDelta) > 5
					draggedDelta += if draggedDelta > 0 then -5 else 5
					draggedElementY = element.getOffsetXY().y + draggedY + (element.height()/2) + scrollDelta - startScrollDelta - draggedDelta
					onDrag()

				draggedElementY = element.getOffsetXY().y + draggedY + (element.height()/2) + scrollDelta - startScrollDelta
				onDrag()

				oldDraggedY = draggedY

				# scroll
				ph = Page.height()-100
				if (touches[0].y+touches[0].yo-50) + dragScrollTreshold > ph
					scrolling = 1
				else if (touches[0].y+touches[0].yo-50) < dragScrollTreshold
					scrolling = -1
				else scrolling = 0

				if touches[0].op&4 # touch is stopped
					element.removeClass "dragging"
					if !(dragPosition > elementO and elementO+(item.treeLength-1) is dragPosition)
						if (dragPosition isnt item.order) or draggedIndeting != 0
							# indentDelta = draggedIndeting - item.depth
							Server.sync "reorder", elementO, dragPosition, draggedIndeting, item.treeLength, !->
								SF.reorder elementO, dragPosition, draggedIndeting, item.treeLength
						else
							element.style _transform: "translateY(0)"
					else
						element.style _transform: "translateY(0)"
					# reset lots of things
					draggedElement = null
					scrolling = 0
					dragPosition = -1
					item.collapse(false, false, false, 1)
					item.unHidePlus()
			return false
		,element

	onDrag = !->
		return unless draggedElement and draggedElement.order and draggedElementY isnt oldY

		direction = draggedElementY > oldY

		# check dragover
		overElement = -1
		plusElement = -1
		for item, i in items
			continue unless item # dealing with empty slots in the array
			continue unless item isnt draggedElement # ignore myself
			continue unless !item.hidden # ignore hidden
			li = item.element
			trans = item.getOffset()
			liHalf = li.height()/2
			liPlus = item.getShowPlus() >=0
			liPlusOffset = if item.getPlusOffset() <= 0 then -17.5 else 0

			liY = li.getOffsetXY().y + trans + liHalf + liPlusOffset
			# if draggedElementY > liY and draggedElementY < liY+liHalf+liHalf
				# I am visually hovering over someone!

			# Check if we are moving over the top or bottom half of an item

			if draggedElementY > liY and oldY <= liY
				overElement = item.order
				dragPosition = item.order
				if item.collapsed
					dragPosition += item.treeLength
				if liPlus
					if item.getShowPlus() is item.key
						draggedIndeting = item.depth+1 - draggedElement.depth
					else
						draggedIndeting = item.depth - draggedElement.depth
				else
					if item.collapsed
						draggedIndeting = (if items[i+item.treeLength] then items[i+item.treeLength].depth else 0) - draggedElement.depth # set depth to item beneath us
					else
						draggedIndeting = (if items[i+1] then items[i+1].depth else 0) - draggedElement.depth # set depth to item beneath us
				break
			else if draggedElementY < liY and oldY >= liY
				overElement = item.order
				dragPosition = item.order - 1 # does this work with hidden stuff?
				draggedIndeting = item.depth - draggedElement.depth # set depth to item beneath us
				break

			if liPlus # And do the same on the "+ Add Subelement"
				liY += liHalf + item.getPlusOffset()
				if draggedElementY > liY-17.5 and oldY <= liY-17.5 # from above
					if item.getShowPlus() == parseInt(item.key)
						indentPlus = 1
					indentPlus = 0
					plusElement = item.order
					draggedIndeting = (if items[i+1] then items[i+1].depth else 0) + indentPlus - draggedElement.depth
					break
				else if draggedElementY < liY and oldY >= liY # from below
					indentPlus = if item.getShowPlus() is parseInt(item.key) then 1 else 0
					plusElement = item.order
					draggedIndeting = item.depth + indentPlus - draggedElement.depth # set depth to item
					break

		# actually visually position the dragged element
		draggedElement.element.style _transform: "translateY(#{(draggedY + scrollDelta - startScrollDelta) + 'px'})"
		draggedElement.contentElement.style _transform: "translateX(#{draggedIndeting*15 + 'px'})"
		# draggedElement.contentElement.style marginRight: "#{(draggedIndeting*15) + 'px'}"

		# move element out of the way
		if overElement >= 0 and item.key
			if overElement > draggedElement.order
				t = if direction and trans > 0 then 0 else draggedElementHeight
				t = if !direction and trans < 0 then 0 else -draggedElementHeight
			else
				if direction
					t = if trans > 0 then 0 else -draggedElementHeight
				else
					t = if trans < 0 then 0 else draggedElementHeight
			if t == 0
				dragPosition = if draggedElement.order > item.order then (if item.collapsed then item.order+item.treeLength else item.order+1) else item.order-1
			else
				# dragPosition = item.order
				dragPosition = if t<0 then (if item.collapsed then item.order+(item.treeLength-1) else item.order) else item.order
			item.setOffset t

			# do plus stuff
			if item.getShowPlus() >= 0
				if t<0
					item.setPlusOffset -t
				else if t == 0 and direction
					item.setPlusOffset draggedElementHeight
				else
					item.setPlusOffset 0

		# move plus element out of the way
		if plusElement >= 0 and item.key
			trans = item.getPlusOffset()
			if direction
				t = if trans > 0 then 0 else draggedElementHeight
			else
				t = if trans < 0 then 0 else draggedElementHeight
			item.setPlusOffset t
		oldY = draggedElementY

	repairOrder = !-> # this is a debug function, to detect inconsistencies in the order and depth. If this occurs fix it for the user at least. (Not that it should occur ofc)
		holesFixed = 0
		orderFixed = 0
		depthFixed = 0
		for item, i in items #fix holes
			if !item?
				++holesFixed
				items.splice(i,1)
		lastDepth = 0
		for item, i in items
			if items.order isnt i
				++orderFixed
				items.order = i # reset order
			if item.depth > lastDepth+1
				++depthFixed
				item.depth = lastDepth+1 # reset depth
			lastDepth = item.depth
		log "repaired #{holesFixed} holes, #{orderFixed} order errors and #{depthFixed} depth errors"
	# End of item class stuff.

	Dom.style
		overflowX: 'hidden'
		_userSelect: 'none'

	empty = Obs.create(true)
	editingItemO = Obs.create(false)
	Dom.div !->
		Dom.style
			margin: '-8px -8px 0px'
			# backgroundColor: '#fff'
			# borderBottom: '1px solid #aaa'
			# borderRadius: '0px'
			# _boxShadow: "0 1px 2px rgba(0,0,0,.1)"
			padding: '8px'

		# Top entry: adding an item
		Ui.item !->
			Dom.style
				paddingLeft: '10px'
				# paddingBottom: '0px'
				backgroundColor: '#fff'
				borderRadius: '2px'
				margin: '0 32px 1px 0'
			save = !->
				return if !addE.value().trim()
				Db.local.set('new', (Db.shared.peek('maxId')|0)+1)
				Server.sync 'add', addE.value().trim(), 1, 0, !->
					SF.add(addE.value().trim(), 1, 0, Plugin.userId())
					# Sigh, and do order stuff...
				addE.value ""
				addE.style {height: '26px'} # reset height
				editingItemO.set(false)
				addE.focus() # Refocus on this

			addE = Form.text
				simple: true
				rows: 1
				name: 'item'
				text: tr("New item ...")
				onChange: (v) !->
					editingItemO.set(!!v?.trim())
				onReturn: save
				inScope: !->
					Dom.style
						Flex: 1
						display: 'block'
						border: 'none'
						fontSize: '21px'
						padding: '0px'
			Obs.observe !->
				Ui.button !->
					Dom.style visibility: (if editingItemO.get() then 'visible' else 'hidden')
					Dom.text tr("Add")
				, save


		count = 0
		redrawO = Obs.create(0)
		cRedrawO = Obs.create(0)

		# List of all items
		log "-------Initial Draw-----"
		Db.shared.observeEach 'items', (item) !->
			# trigger observe of depth change
			dontSave = item.get('depth')
			empty.set(!++count)
			Obs.onClean !->
				if !item.peek('order')? # filter onClean on existing items. this happens.
					empty.set(!--count)
					# splice latest of items. Since it will be too long now.
					items.pop()
					redrawO.incr()

			redrawO.incr()

			Dom.div !->
				# Make a new item. It is also rendered here (called by its constructor)
				newItem =  new Item(item, Dom.get(), false)
				items[newItem.order-1] = newItem
		, (item) ->
			item.get('order')

		#run through it again to look for children
		Obs.observe !->
			if redrawO.get()
				log "Redraw observe, do children and collapse"
				for i in items
					continue unless i?
					i.seekChildren()
				for i in items
					continue unless i?
					i.collapse(false, false, true) # update collapse from Db.personal

		Obs.observe !->
			if empty.get()
				Dom.div !->
					Dom.style
						padding: '14px'
						color: '#bbb'
					Dom.text tr("No items")

		log "----------Initial Completed Draw---------"
		Obs.observe !->
			if showCompletedO.get()
				Dom.div !->
					Dom.style margin: '8px -8px'
					Dom.div !->
						Dom.style
							width: '100%'
							borderBottom: "2px solid #bbb"
				if !cRedrawO.get()
					Dom.div !->
						Dom.style
							padding: '12px 6px'
							textAlign: 'center'
							color: '#bbb'
						Dom.text tr("No completed items")


		Db.shared.observeEach 'completed', (comp) !->
			Obs.onClean !->
				if !comp.peek('cOrder')? # filter onClean on existing items. this happens.
					#remove item from the completedList
					for compI, idx in completedItems
						continue unless compI? # Who do empty slots turn up in an for loop?
						if compI.key is parseInt(comp.key())
							completedItems.splice(compI.cOrder-1,1)
							break
					cRedrawO.incr() # trigger seekCompletedChildren
			return unless showCompletedO.get()
			Dom.div !->
				# Make a new item. It is also rendered here (called by its constructor)
				newComp = new Item(comp, Dom.get(), true)
				completedItems[newComp.cOrder-1] = newComp
			cRedrawO.incr()
		, (comp) ->
			comp.get('cOrder')

		Obs.observe !->
			if cRedrawO.get()
				log "Redraw observe completed, do children"
				for i in completedItems
					continue unless i?
					i.seekCompletedChildren()

	Obs.observe !->
		if !showCompletedO.get() and (!empty.get() or Db.shared.ref('completed').isHash())
			Dom.div !->
				Dom.style
					Flex: 1
					padding: '8px'
					margin: '4px 32px 4px 0'
					textAlign: 'center'
					borderRadius: '2px'
					border: '1px solid #ccc'
					color: Plugin.colors().highlight
				Dom.text "Show completed"
				Dom.onTap !->
					showCompletedO.set true

	if mobile then Dom.div !->
		Dom.style
			textAlign: 'center'
			margin: '20px'
			color: '#999'
		Dom.text tr("Swipe an item to (un)complete")


	# perhaps it's better if this only happens when we actually exit the plugin?
	# (not really possible right now though --Jelmer)
	Obs.onClean !->
		log "Leaving page. Hiding completed"
		for item, i in items
			if item.completed and not item.pCompletedO.peek()
				Server.sync 'hideCompleted', item.key, item.childrenKeys, !->
					SF.hideCompleted(item.key, item.childrenKeys)

Dom.css
	".sortItem.dragging":
		position: 'relative'
		zIndex: 999
		opacity: '0.8'
		_transition: 'none'
		_backfaceVisibility: 'hidden'
	".sortItem":
		_backfaceVisibility: 'hidden'
		transition_: 'transform 0.4s ease-out, opacity 0.4s, marginBottom 0.4s ease-out'
		WebkitTransition_: 'transform 0.4s ease-out, opacity 0.4s, marginBottom 0.4s ease-out'
