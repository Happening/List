Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
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
	oldY = 0
	contentE = Dom.get()
	contentHeight = 0
	scrollDelta = 0
	startScrollDelta = 0
	scrolling = 0
	dragDirection = 0 # 1 for x, -1 for y
	dragPosition = -1
	draggedElement = null
	draggedDelta = 0
	draggedElementY = 0

	class Item
		constructor: (@dbRef, @element) ->
			log "constructor called"
			@key = dbRef.key()
			@time = dbRef.peek('time')
			@order = dbRef.peek('order')
			@depth = dbRef.peek('depth')
			@text = dbRef.peek('text')
			@notes = dbRef.peek('notes')
			@assigned = dbRef.peek('assigned')
			@completed = dbRef.peek('completed')
			@children = []
			@treeLength = 1 # always yourself
			@collapsed = Db.personal.peek 'collapsed', @key
			@arrowO = Obs.create(0)
			@offsetO = Obs.create(0)
			item = this
			Obs.observe !->
				item.order = dbRef.get('order')
				item.depth = dbRef.get('depth')
				item.text = dbRef.get('text')
				item.notes = dbRef.get('notes')
				item.assigned = dbRef.get('assigned')
				item.completed = dbRef.get('completed')
				# just rerender when one of the above attributes change...
				item.render()

		render: ->
			item = this # zucht. bijna goed dit.
			log "(Re-)rendering", @order, @key, @text

			Dom.addClass "sortItem"
			# offset for draggin
			# item.offsetO.set 0 # reset own offset when rendering
			# item.collapseO.set  0 # reset own offset when rendering
			Dom.style
				_transform: "translateY(#{'0px'})"
			Obs.observe !->
				o = item.offsetO.get()
				# c = collapseO.get(item.key)
				c = 0
				offset = o + c
				Dom.style _transform: "translateY(#{offset + 'px'})"
				Dom.style display: if c then 'none' else 'inherit'

			Dom.div !->
				Dom.addClass "sortItem"
				itemDE = Dom.get()
				Dom.style
					minHeight: '50px'
					Box: 'middle'
				# Rearrange icon
				Dom.div !->
					Dom.style
						padding: "0px 8px"
						marginLeft: "-8px"
					Icon.render
						data: 'reorder'
						color: '#999'
					dragToReorder item

				#checkbox for desktop
				if !mobile
					Dom.div !->
						Dom.style Box: 'center middle'
						Form.vSep()
						item.completed
							# temp fix for problems arising from marking completed in edit item screen
						Form.check
							value: item.completed
							inScope: !->
								Dom.style padding: '28px 32px 28px 14px'
							onChange: (v) !->
								Server.sync 'complete', item.key, v, !->
									Db.shared.set('items', item.key, 'completed', v)
						Form.vSep()


				# Content and avatar
				Dom.div !->
					Dom.style
						Flex: 1
						Box: 'left middle'
						padding: "0 0 0 #{item.depth*15}" # reactive
					Dom.div !->
						Dom.style
							boxSizing: 'border-box'
							Box: 'middle'
							Flex: 1
							padding: '8px 4px 8px 4px'
							textDecoration: if item.completed then 'line-through' else 'none'
							color: if item.completed then '#aaa' else 'inherit'
							fontSize: '16px' #'21px'
						Dom.div !->
							Dom.style
								Flex: 1
								color: (if Event.isNew(item.time) then '#5b0' else 'inherit')
								# overflow: 'hidden'
								# whiteSpace: 'nowrap'
								# textOverflow: 'ellipsis'
								# width: '0px' #Firefox hack. But.. errrgh... whut?
							Dom.userText item.order + " - " + item.text
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
						Dom.div !->
							Event.renderBubble [item.key]
					Dom.div !->
						Dom.style
							marginRight: '4px'
							# height: '60px'
							# Box: 'middle'
							position: 'relative'
						assigned = item.assigned
						if !assigned? or assigned.length is 0
							# Do nothing
						else if assigned.length is 1
							Ui.avatar Plugin.userAvatar(assigned[0]), size: 30, style: margin: '0 0 0 8px'
						else if assigned.length > 1
							Ui.avatar '#666', size: 30, style: margin: '0 0 0 8px'
							Dom.div !->
								Dom.style
									position: 'absolute'
									top: '10px'
									width: '100%'
									marginLeft: '4px'
									textAlign: 'center'
									color: '#fff'
								Dom.text assigned.length
					Dom.onTap !->
						Page.nav item.key
					if mobile then item.dragToComplete itemDE

				Obs.observe !->
					ad = item.arrowO.get()
					if ad isnt 0
						Dom.div !->
							Icon.render
								data: if ad is -1 then 'arrowup' else 'arrowdown'
								color: '#999'

							Dom.onTap !->
								log "toggling collapse"
								item.collapse(false, true)

				# Overflow menu
				Form.vSep()
				Dom.last().style margin: '0px'
				Dom.div !->
					Dom.style
						padding: '8px'
					Icon.render
						data: 'more'
						color: '#999'
					Dom.onTap !->
						Menu.renderMenu(item.key)
			Form.sep()

		seekChildren: !->
			@children = []
			@treeLength = 1
			log "seeking", @order, @text
			return unless @order < items.length # if we are the last. We have no children.
			for j in [@order..items.length-1]
				i = items[j]
				if i.depth is @depth+1
					log "Adding", i.order, i.text
					@children.push(i) # This makes a pointer right? Right?
					++@treeLength
				else
					if i.depth <= @depth # Lower or equal depth means not my child
						log "lower or equal", i.order, i.text
						break
					if i.depth > @depth+1 # higher indent means this is a grandchild of me
						log "grandchild", i.order, i.text
						++@treeLength
			if @treeLength > 1
				@arrowO.set 1

		collapse: (force = false, toggle = false, initial = false) !->
			return unless @children.length #of no children, never do any of this
			#either force it close, or restore it.
			log "Collapse", @order, force, toggle, @collapsed, @arrowO.peek()
			collapsed = @collapsed
			if initial and !collapsed then return
			if force
				collapsed = true #we are currently collapsed
			else
				#toggle state
				if toggle
					collapsed = @collapsed = !@collapsed
					Server.send "collapse", @key, collapsed
			@arrowO.set if collapsed then -1 else 1

			height = 0
			for c in @children
				height += c.element.height()
				log "collapsing child"
				c.collapse(collapsed)
				c.hide if collapsed then height else-1 # -1 unhides the item

		hide: (height) !->
			log "Hide!", @order, height
			if height >= 0
				@element.style display: 'none'
			else
				@element.style display: 'inherit'

		setOffset: (offset) !->
			@offsetO.set offset
		getOffset: ->
			@offsetO.peek()

		dragToComplete: (element) !->
			key = @key
			# if mobile
			Dom.trackTouch (touches...) ->
				if dragDirection is -1
					if touches.length == 1 and touches[0].op is 4 then dragDirection = 0
					return true
				if touches.length == 1
					# determine direction
					if dragDirection is 0
						if touches[0].x isnt 0 or touches[0].y isnt 0
							log touches[0].x, touches[0].y
							if touches[0].y is 0 or Math.abs(touches[0].x)/Math.abs(touches[0].y)|0.1 > 3
								dragDirection = 1
								element.addClass "dragging"
							else
								dragDirection = -1
								return true

					element.style _transform: "translateX(#{touches[0].x + 'px'})"
					if touches[0].op is 4 # touch is stopped
						dragDirection = 0
						if touches[0].x > swipeToCompleteTreshold # treshhold
							Server.sync 'complete', key, true, !->
								Db.shared.set key, 'completed', true
						if touches[0].x < -swipeToCompleteTreshold # treshhold
							Server.sync 'complete', key, false, !->
								Db.shared.set key, 'completed', false
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
			draggedElementY = draggedElement.element.getOffsetXY().y + draggedDelta + (draggedElement.element.height()/2) + scrollDelta - startScrollDelta
			onDrag()


	dragToReorder = (item) !->
		element = item.element
		elementO = item.order
		Dom.trackTouch (touches...) ->
			if touches.length == 1
				# drag element
				draggedDelta = touches[0].y

				if touches[0].op is 1
					scrollDelta = Page.scroll()
					startScrollDelta = Page.scroll()
					log scrollDelta, startScrollDelta
					contentHeight = element.height()
					element.addClass "dragging"
					draggedElement = item
					oldY = element.getOffsetXY().y + (element.height()/2)
					# Collapse if parent
					# Collapse(elementO, elementId, elementD, 0)
					log "forcing collapse"
					item.collapse(true)

				draggedElementY = element.getOffsetXY().y + draggedDelta + (element.height()/2) + scrollDelta - startScrollDelta

				onDrag()

				# scroll
				ph = Page.height()-100
				if (touches[0].yc-50) + dragScrollTreshold > ph
					scrolling = 1
				else if (touches[0].yc)-50 - dragScrollTreshold < 0
					scrolling = -1
				else scrolling = 0

				if touches[0].op is 4 # touch is stopped
					element.removeClass "dragging"
					if dragPosition > 0
						log "Done. Send reorder to server"
						Server.sync "reorder", elementO, dragPosition, item.treeLength, !->
							SF.reorder elementO, dragPosition, item.treeLength
					# reset lots of things
					draggedElement = null
					scrolling = 0
					dragPosition = -1
					element.style _transform: "translateY(0)"
					log "restoring collapse"
					item.collapse(false, false)
			return false
		,element

	onDrag = !->
		return unless draggedElement and draggedElement.order and draggedElementY isnt oldY

		direction = draggedElementY > oldY
		draggedElement.element.style _transform: "translateY(#{(draggedDelta + scrollDelta - startScrollDelta) + 'px'})"

		# check dragover
		overElement = -1
		i = null
		for item in items
			continue unless item #dealing with empty slots in the array
			continue unless item isnt draggedElement
			li = item.element
			trans = item.getOffset()
			liHalf = li.height()/2

			liY = li.getOffsetXY().y + trans
			if draggedElementY > liY+liHalf and oldY <= liY+liHalf
				overElement = item.order
				dragPosition = item.order
				break
			else if draggedElementY < liY+liHalf and oldY >= liY+liHalf
				overElement = item.order
				dragPosition = item.order-1
				break
		# move element out of the way
		draggedElementHeight = draggedElement.element.height()
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
				# log "normal"
				dragPosition = if draggedElement.order > item.order then item.order+1 else item.order-1
			else
				dragPosition = item.order
				# if t > 0 then log "down" else log "up"
			# log "dropped on:", dragPosition
			item.setOffset t
		oldY = draggedElementY

	Dom.style
		overflowX: 'hidden'
		_userSelect: 'none'

	editingItem = Obs.create(false)
	Ui.list !->
		# Dom.style backgroundColor: '#fff', margin: '-4px -8px', borderBottom: '1px solid #ccc'

		# Top entry: adding an item
		Ui.item !->
			Dom.style paddingLeft: '10px'
			save = !->
				return if !addE.value().trim()
				Server.sync 'add', addE.value().trim(), !->
					id = Db.shared.incr 'maxId'
					Db.shared.set('items', id, {time:0, by:Plugin.userId(), text: addE.value().trim()})
					# Sigh, and do order stuff...
				addE.value ""
				editingItem.set(false)
				Form.blur()

			addE = Form.input
				simple: true
				name: 'item'
				text: tr("+ Add")
				onChange: (v) !->
					editingItem.set(!!v?.trim())
				onReturn: save
				inScope: !->
					Dom.style
						Flex: 1
						display: 'block'
						border: 'none'
						fontSize: '21px'

			Obs.observe !->
				Ui.button !->
					Dom.style visibility: (if editingItem.get() then 'visible' else 'hidden')
					Dom.text tr("Add")
				, save


		count = 0
		empty = Obs.create(true)
		redrawO = Obs.create(0)

		# List of all items
		log "-------Initial Draw-----"
		Db.shared.observeEach 'items', (item) !->
			empty.set(!++count)
			Obs.onClean !->
				empty.set(!--count)

			redrawO.incr()

			Dom.div !->
				# Make a new item. It is also rendered here (called by its constructor)
				newItem =  new Item(item, Dom.get())
				items[newItem.order-1] = newItem
		, (item) ->
			item.get('order')
			# if +item.key()
			# 	-item.key() + (if item.peek('completed') then 1e9 else 0)

		#run through it again to look for children
		Obs.observe !->
			if redrawO.get()
				log "Redraw observe, do children and collapse"
				for i in items
					i.seekChildren()
				for i in items
					i.collapse(false, false, true) # update collapse from Db.personal

		Obs.observe !->
			log 'empty now', empty.get()
			if empty.get()
				Ui.item !->
					Dom.style
						padding: '12px 6px'
						textAlign: 'center'
						color: '#bbb'
					Dom.text tr("No items")

	if mobile then Dom.div !->
		Dom.style
			textAlign: 'center'
			margin: '20px'
			color: '#999'
		Dom.text tr("Swipe an item left to check it, and to the right to uncheck it")
	Ui.bigButton "reset order", !->
		Server.call "resetOrder"

Dom.css
	".sortItem.dragging":
		position: 'relative'
		zIndex: 99999
		backgroundColor: '#fff'
		opacity: '0.8'
		_transition: 'none'
		_backfaceVisibility: 'hidden'
	".sortItem":
		_backfaceVisibility: 'hidden'
		transition_: 'transform 0.2s ease-out'
		WebkitTransition_: 'transform 0.2s ease-out'