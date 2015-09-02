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

class Item
	constructor: (dbRef) ->
		@order
		@key



MakeObjects out of the element. listE is a mess

exports.renderList = !->
	mobile = Plugin.agent().ios or Plugin.agent().android
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
		log "-------redraw-----"
		listE = []
		offsetO = Obs.create({})
		collapseO = Obs.create({})
		collapseArrowO = Obs.create({})
		Db.shared.observeEach 'items', (item) !->
			empty.set(!++count)
			Obs.onClean !->
				empty.set(!--count)

			items.push new item(item)
			items.render()
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