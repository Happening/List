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

swipeToCompleteTreshold = 50 # in pixels
swipeToCompleteRespondTreshold = 5 # in pixels applied on Y axis!
dragScrollTreshold = 60 # in pixels

exports.renderList = !->
	mobile = Plugin.agent().ios or Plugin.agent().android
	items = []
	listE = []
	offsetO = null
	collapseO = null
	collapseArrowO = null
	oldY = 0
	contentE = Dom.get()
	contentHeight = 0
	scrollDelta = 0
	startScrollDelta = 0
	scrolling = 0
	dragDirection = 0 # 1 for x, -1 for y
	dragPosition = -1
	draggedElement = null
	draggedElementO = null
	draggedDelta = 0
	draggedElementY = 0

	class Item
		constructor: (@dbRef, @element) ->
			# @dbRef = dbRef
			# @element = element 
			@key = dbRef.key()
			@time = dbRef.peek('time')
			@order = dbRef.peek('order')
			@depth = dbRef.peek('depth')
			@text = dbRef.peek('text')
			@notes = dbRef.peek('notes')
			@assigned = dbRef.peek('assigned')
			@completed = dbRef.peek('completed')
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
			offsetO.set item.key, 0 # reset own offset when rendering
			collapseO.set item.key, 0 # reset own offset when rendering
			Dom.style
				_transform: "translateY(#{'0px'})"
			Obs.observe !->
				log "offset observe", item.order
				o = offsetO.get(item.key)
				c = collapseO.get(item.key)
				offset = o + c
				# if listE[item.peek('order')] then listE[item.peek('order')][3] = offset
				Dom.style _transform: "translateY(#{offset + 'px'})"
				Dom.style display: if c then 'none' else 'inherit'

			Dom.div !->
				children = 0
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
					DragToReorder item.element, item.order, item.key

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
							log "Set Text:", item.text
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
							# Ui.avatar Plugin.userAvatar(Plugin.userId()), size: 30, style: 
							# 	margin: '0 0 0 8px'
							# 	opacity: 0.4
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
						log "ding"
						Page.nav item.key
					if mobile then DragToComplete itemDE, item.key

				Dom.div !->
					Obs.observe !->
						ad = collapseArrowO.get(item.key)
						Icon.render
							data: if ad then 'arrowup' else 'arrowdown'
							color: '#999'

					Dom.onTap !->
						children = Collapse(item.order, item.key, item.depth, children)

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
				log "add to listE", item.order, item.key, item.text
			Form.sep()
			# listE.push [item.peek('order'), item.key(), itemRE, 0]
			# order, db key, depth, Dom Element, trans, collapsetrans,
			listE[item.order-1] = [item.order, item.key, item.depth, item.element, 0, 0]

	log "Make scrolling interval"
	Obs.interval 25, !->
		return unless scrolling
		scrollDelta = Math.min(contentE.height()-(Page.height()-100), Math.max(0, scrollDelta + scrolling * 10))
		Page.scroll(scrollDelta, false)
		if draggedElement?
			draggedElementY = draggedElement.getOffsetXY().y + draggedDelta + (draggedElement.height()/2) + scrollDelta - startScrollDelta
			onDrag()

	Collapse = (elementO, elementId, elementD, elementC) ->
		log "Collapse", elementO, elementId, elementD, elementC
		#	check if next in listE is indented
		children = 0
		if elementC is 0
			if elementO < listE.length
				++children
				height = 0
				log elementO
				if listE[elementO][2] > elementD #Next in line is more indeted then I am. therefore, it must be my kiddo
					height += listE[elementO][3].height()
					collapseO.set listE[elementO][1], -height
				collapseArrowO.set elementId, true
			else
				log "slected last element. no children"
		else
			for i in [elementO..elementO+elementC-1]
				log i
				collapseO.set listE[i][1], 0
			collapseArrowO.set elementId, false
		children


	DragToComplete = (element, key) !->
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

	DragToReorder = (element, elementO, elementId, elementD) !->
		Dom.trackTouch (touches...) ->
			if touches.length == 1
				# drag element
				draggedDelta = touches[0].y
				draggedElementY = element.getOffsetXY().y + draggedDelta + (element.height()/2) + scrollDelta - startScrollDelta

				if touches[0].op is 1
					scrollDelta = Page.scroll()
					startScrollDelta = Page.scroll()
					log scrollDelta, startScrollDelta
					contentHeight = contentE.height()
					element.addClass "dragging"
					draggedElement = element
					draggedElementO = elementO
					oldY = element.getOffsetXY().y + (element.height()/2)
					# Collapse if parent
					Collapse(elementO, elementId, elementD, 0)

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
						log "Done. Write to order"
						Server.sync "reoder", elementO, dragPosition, !->
							if elementO != dragPosition
								if dragPosition > elementO
									Db.shared.forEach 'item', (item) !->
										if item.get('order') > elementO and item.get('order') <= dragPosition
											item.incr 'order', -1
										else if item.get('order') is elementO
											item.set 'order', dragPosition
								else
									Db.shared.forEach 'item', (item) !->
										if item.get('order') < elementO and item.get('order') >= dragPosition
											item.incr 'order', 1
										else if item.get('order') is elementO
											item.set 'order', dragPosition
					# reset lots of things
					draggedElement = null
					draggedElementO = null
					scrolling = 0
					dragPosition = -1
					element.style _transform: "translateY(0)"
			return false
		,element

	onDrag = !->
		return unless draggedElement and draggedElementO and draggedElementY isnt oldY

		direction = draggedElementY > oldY
		draggedElement.style _transform: "translateY(#{(draggedDelta + scrollDelta - startScrollDelta) + 'px'})"

		# check dragover
		overElement = -1
		i = null
		# for [o, i, li, trans], j in listE
		for val, j in listE
			continue unless val #dealing with empty slots in the array
			o = val[0]
			i = val[1]
			d = val[2]
			li = val[3]
			trans = val[4]
			collapsed = val[5]

			if li is draggedElement then continue
			liY = li.getOffsetXY().y + trans
			if draggedElementY > liY+li.height()/2 and oldY <= liY+li.height()/2
				overElement = o
				dragPosition = o
				break
			else if draggedElementY < liY+li.height()/2 and oldY >= liY+li.height()/2
				overElement = o
				dragPosition = o-1
				break
		# move element out of the way
		if overElement >= 0 and i
			if overElement > draggedElementO
				t = if direction and trans > 0 then 0 else draggedElement.height()
				t = if !direction and trans < 0 then 0 else -draggedElement.height()
			else
				if direction
					t = if trans > 0 then 0 else -draggedElement.height()
				else
					t = if trans < 0 then 0 else draggedElement.height()
			# log "set", o, i, t, trans, direction
			if t == 0
				log "normal"
				dragPosition = if draggedElementO > o then o+1 else o-1
			else
				dragPosition = o
				if t > 0 then log "down" else log "up"
			log "dropped on:", dragPosition
			offsetO.set i, t
			listE[o-1][4] = t
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

		# List of all items
		log "-------Initial Draw-----"
		listE = []
		offsetO = Obs.create({})
		collapseO = Obs.create({})
		collapseArrowO = Obs.create({})
		Db.shared.observeEach 'items', (item) !->
			empty.set(!++count)
			Obs.onClean !->
				empty.set(!--count)

			Dom.div !->
				# Make a new item. It is also rendered here (called by its constructor)
				items.push new Item(item, Dom.get())
		, (item) ->
			item.get('order')
			# if +item.key()
			# 	-item.key() + (if item.peek('completed') then 1e9 else 0)

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