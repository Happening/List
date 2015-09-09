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
	oldY = 0
	contentE = Dom.get()
	scrollDelta = 0
	startScrollDelta = 0
	scrolling = 0
	dragDirection = 0 # 1 for x, -1 for y
	dragPosition = -1
	draggedElement = null
	draggedElementHeight = 0
	draggedDelta = 0
	draggedElementY = 0
	draggedIndeting = 0

	class Item
		constructor: (@dbRef, @element) ->
			@key = parseInt(dbRef.key())
			@time = dbRef.peek('time')
			@order = dbRef.peek('order')
			@depth = dbRef.peek('depth')
			@text = dbRef.peek('text')
			@notes = dbRef.peek('notes')
			@assigned = []
			@completed = dbRef.peek('completed')
			@children = []
			@treeLength = 1 # always yourself
			@collapsed = Db.personal.peek 'collapsed', @key
			@hidden = false
			@arrowO = Obs.create(0)
			@offsetO = Obs.create(0)
			@showPlus = Obs.create(-1)
			@plusOffset = Obs.create(0)
			@editingItem = Obs.create(false)
			@plusElement = null
			@contentElement = @element
			item = this

			# if we are ad depth 0 and new, show +
			if @depth is 0 and Event.isNew(item.time)
				@showPlus.set @key

			Obs.observe !->
				item.order = dbRef.get('order')
				item.depth = dbRef.get('depth')
				item.text = dbRef.get('text')
				item.notes = dbRef.get('notes')
				item.assigned = []
				item.assigned.push k for k of dbRef.get('assigned')
				item.completed = dbRef.get('completed')
				# just rerender when one of the above attributes change...
				item.render()

		render: ->
			item = this # zucht. bijna goed dit.
			log "(Re-)rendering", @order, @key, @text

			Dom.addClass "sortItem"
			# offset for draggin
			# item.offsetO.set 0 # reset own offset when rendering
			item.plusOffset.set 0 # reset plus offset when rendering
			Dom.style
				_transform: "translateY(#{'0px'})"
			Obs.observe !->
				offset = item.offsetO.get()
				Dom.style _transform: "translateY(#{offset + 'px'})"

			Dom.div !->
				Dom.addClass "sortItem"
				itemDE = Dom.get()
				Dom.style
					minHeight: '50px'
					Box: 'middle'
				# Rearrange icon
				Dom.div !->
					Dom.style
						padding: "8px"
						marginLeft: "-8px"
					Icon.render
						data: 'reorder'
						color: '#999'
					dragToReorder item

				# Content and avatar
				Dom.div !->
					Dom.style
						Flex: 1
						Box: 'left middle'
						padding: "0 0 0 #{item.depth*15}" # reactive

					Dom.div !->
						item.contentElement = Dom.get()
						Dom.style
							transition_: 'transform 0.2s ease-out'
							WebkitTransition_: 'transform 0.2s ease-out'
							_backfaceVisibility: 'hidden'
							boxSizing: 'border-box'
							Box: 'middle'
							Flex: 1
							padding: '8px 4px 8px 4px'
							textDecoration: if item.completed then 'line-through' else 'none'
							color: if item.completed then '#aaa' else 'inherit'
							fontSize: '16px' #'21px'
							wordBreak: 'break-word'

						#checkbox for desktop
						if !mobile
							Dom.div !->
								Dom.style Box: 'center middle'
								# Form.vSep()
								item.completed
									# temp fix for problems arising from marking completed in edit item screen
								Form.check
									value: item.completed
									inScope: !->
										Dom.style margin: '0px 5px 0px -10px'
									onChange: (v) !->
										Server.sync 'complete', item.key, v, !->
											Db.shared.set('items', item.key, 'completed', v)
								# Form.vSep()

						Dom.div !->
							Dom.style
								Flex: 1
								color: (if Event.isNew(item.time) then '#5b0' else 'inherit')
								# overflow: 'hidden'
								# whiteSpace: 'nowrap'
								# textOverflow: 'ellipsis'
								# width: '0px' #Firefox hack. But.. errrgh... whut?
							# Dom.userText item.order + " - " + item.text
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
								item.collapse(false, true)

				# Overflow menu
				# Form.vSep()
				# Dom.last().style margin: '0px'
				Dom.div !->
					Dom.style
						padding: '8px'
					Icon.render
						data: 'more'
						color: '#999'
					Dom.onTap !->
						# from pointers to keys
						ch = []
						findChild = (a) !->
							ch.push a.key
							for b in a.children
								findChild b
						findChild item
						Menu.renderMenu(item.key, ch, item)
			Form.sep()

			if (p = item.showPlus.get()) >= 0
				Dom.div !->
					item.plusElement = Dom.get()
					# Obs.observe !->
					offset = item.plusOffset.get()
					d = if p is parseInt(item.key) then 1 else 0
					desktopOffset = if mobile then 38 else 82
					Dom.addClass "sortItem"
					Dom.style
						_transform: "translateY(#{offset + 'px'})"
					Dom.div !->
						Dom.style Box: 'middle'
						save = !->
							return if !addE.value().trim()
							# d = if p is parseInt(item.key) then 1 else 0
							Server.sync 'add', addE.value().trim(), item.order+1, item.depth + d, p, !->
								SF.add(addE.value().trim(), item.order+1, item.depth + d, Plugin.userId())
							addE.value ""
							item.editingItem.set(false)
							Form.blur()

						addE = Form.input
							simple: true
							name: 'item' + item.key
							text: tr("+ Add subitem")
							onChange: (v) !->
								item.editingItem.set(!!v?.trim())
							onReturn: save
							inScope: !->
								Dom.style
									Flex: 1
									padding: "8 0 8 #{(item.depth+d)*15 + desktopOffset}" # reactive
									display: 'block'
									border: 'none'
									fontSize: '100%'

						Obs.observe !->
							Ui.button !->
								Dom.style visibility: (if item.editingItem.get() then 'visible' else 'hidden')
								Dom.text tr("Add")
							, save
					Form.sep()

		seekChildren: !->
			@children = []
			@treeLength = 1
			if @order < items.length # if we are the last. We have no children.
				for j in [@order..items.length-1]
					i = items[j]
					if i.depth is @depth+1
						if i.getShowPlus() >= 0
							i.setShowPlus -1 # remove subitem thing, so be sure
						@children.push(i) # This makes a pointer right? Right?
						++@treeLength
					else
						if i.depth <= @depth # Lower or equal depth means not my child
							break
						if i.depth > @depth+1 # higher indent means this is a grandchild of me
							++@treeLength

				# if I have children, set 'addSubItem' to the parent
				if @children?.length
					# and remove + from myself
					@setShowPlus -1
					@children[@children.length-1].setShowPlus @key

			@arrowO.set (if @treeLength > 1 then 1 else 0)

		collapse: (force = false, toggle = false, initial = false) !->
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
			@arrowO.set if collapsed then -1 else 1

			height = 0
			for c in @children
				height += c.element.height()
				c.collapse(collapsed)
				c.hide if collapsed then height else-1 # -1 unhides the item

		hide: (height) !->
			log "hiding", @text, height
			if height >= 0
				@element.style display: 'none'
				@hidden = true
			else
				@element.style display: 'inherit'
				@hidden = false

		setOffset: (offset) !->
			@offsetO.set offset
		getOffset: ->
			@offsetO.peek()
		setShowPlus: (show) !->
			@showPlus.set show
		getShowPlus: ->
			@showPlus.peek()
		setPlusOffset: (offset) !->
			@plusOffset.set offset
		getPlusOffset: ->
			@plusOffset.peek()
		hidePlus: !->
			@plusElement?.style display: 'none'
		unHidePlus: !-> # show is taken
			@plusElement?.style display: 'inherit'

		dragToComplete: (element) !->
			key = @key
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
						if touches[0].x > swipeToCompleteTreshold # treshhold
							Server.sync 'complete', key, true, !->
								Db.shared.set 'items', key, 'completed', true
						if touches[0].x < -swipeToCompleteTreshold # treshhold
							Server.sync 'complete', key, false, !->
								Db.shared.set 'items', key, 'completed', false
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
				horiontalDelta = touches[0].x

				if touches[0].op&1
					scrollDelta = Page.scroll()
					startScrollDelta = Page.scroll()
					item.hidePlus() # if we have a "+ add subitem" div, hide it
					draggedElementHeight = element.height()
					draggedElement = item
					dragPosition = item.order # Start position
					oldY = element.getOffsetXY().y + (element.height()/2)
					element.addClass "dragging"
					item.collapse(true)
					draggedIndeting = 0

				draggedElementY = element.getOffsetXY().y + draggedDelta + (element.height()/2) + scrollDelta - startScrollDelta

				onDrag()

				# scroll
				ph = Page.height()-100
				if (touches[0].yc-50) + dragScrollTreshold > ph
					scrolling = 1
				else if (touches[0].yc)-50 - dragScrollTreshold < 0
					scrolling = -1
				else scrolling = 0

				if touches[0].op&4# touch is stopped
					element.removeClass "dragging"
					if dragPosition isnt item.order or draggedIndeting != 0
						log "Done. Send reorder to server", elementO, dragPosition, draggedIndeting, item.treeLength
						# indentDelta = draggedIndeting - item.depth
						Server.sync "reorder", elementO, dragPosition, draggedIndeting, item.treeLength, !->
							SF.reorder elementO, dragPosition, draggedIndeting, item.treeLength
					else
						element.style _transform: "translateY(0)"
					# reset lots of things
					draggedElement = null
					scrolling = 0
					dragPosition = -1
					item.collapse(false, false)
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
				if liPlus
					draggedIndeting = item.depth - draggedElement.depth
				else
					draggedIndeting = (if items[i+1] then items[i+1].depth else 0) - draggedElement.depth # set depth to item beneath us
				break
			else if draggedElementY < liY and oldY >= liY
				overElement = item.order
				dragPosition = item.order - 1 # does this work with hidden stuff?
				draggedIndeting = item.depth - draggedElement.depth # set depth to item beneath us
				break

			if liPlus # And do the same on the "+ Add Subselement"
				liY += liHalf + item.getPlusOffset()
				# log "check", liY, "(",oldly, (liHalf*2),item.plusOffset.peek(), ") |", draggedElementY
				if draggedElementY > liY-17.5 and oldY <= liY-17.5 # from above
					# indentPlus = if item.getShowPlus() == item.key then 1 else 0
					# log item.getShowPlus(), item.key
					if item.getShowPlus() == parseInt(item.key)
						indentPlus = 1
					indentPlus = 0
					plusElement = item.order
					draggedIndeting = (if items[i+1] then items[i+1].depth else 0) + indentPlus - draggedElement.depth
					break
				else if draggedElementY < liY and oldY >= liY # from below
					indentPlus = if item.getShowPlus() is parseInt(item.key) then 1 else 0
					log item.getShowPlus(), item.key
					plusElement = item.order
					draggedIndeting = item.depth + indentPlus - draggedElement.depth # set depth to item
					break

		# actually visually position the dragged element
		draggedElement.element.style _transform: "translateY(#{(draggedDelta + scrollDelta - startScrollDelta) + 'px'})"
		draggedElement.contentElement.style _transform: "translateX(#{draggedIndeting*15 + 'px'})"
		draggedElement.contentElement.style paddingRight: "#{(draggedIndeting*15+4) + 'px'}"

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
				dragPosition = if draggedElement.order > item.order then item.order+1 else item.order-1
			else
				dragPosition = item.order
			item.setOffset t

			# do plus stuff
			if item.getShowPlus() >= 0
				if t<0
					item.plusOffset.set -t
				else if t == 0 and direction
					item.plusOffset.set draggedElementHeight
				else
					item.plusOffset.set 0

		# move plus element out of the way
		if plusElement >= 0 and item.key
			trans = item.getPlusOffset()
			if direction
				t = if trans > 0 then 0 else draggedElementHeight
			else
				t = if trans < 0 then 0 else draggedElementHeight
			item.setPlusOffset t
		oldY = draggedElementY

	# End of item class stuff.

	Dom.style
		overflowX: 'hidden'
		_userSelect: 'none'

	editingItem = Obs.create(false)
	Ui.list !->
		Dom.style
			backgroundColor: '#fff'
			margin: '-8px -8px 0px'
			borderBottom: '1px solid #aaa'
			borderRadius: '0px'
			_boxShadow: "0 1px 2px rgba(0,0,0,.1)"

		# Top entry: adding an item
		Ui.item !->
			Dom.style paddingLeft: '10px'
			save = !->
				return if !addE.value().trim()
				Server.sync 'add', addE.value().trim(), 1, 0, !->
					SF.add(addE.value().trim(), 1, 0, Plugin.userId())
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