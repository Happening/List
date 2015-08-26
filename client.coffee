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
Social = require 'social'
Time = require 'time'
Ui = require 'ui'
{tr} = require 'i18n'

exports.render = !->
	itemId = Page.state.get(0)
	if itemId
		renderItem(itemId)
	else
		renderList()

renderMenu = (key) !->
	Modal.show tr("Options"), !->
		Dom.style width: '80%', maxWidth: '400px'
		Dom.div !->
			Dom.style
				maxHeight: '70%'
				backgroundColor: '#eee'
				margin: '-12px'
			Dom.overflow()
			Ui.list !->
				Ui.item !->
					if Db.shared.peek(key, 'completed')
						Dom.span !->
							Dom.style Flex: 1
							Dom.text tr("Set to uncompleted")
						Dom.span !->
							Dom.style fontSize: '24px'
							Dom.text "✗"
						Dom.onTap !->
							Server.sync 'complete', key, false, !->
								Db.shared.set key, 'completed', false
							Modal.remove()
					else
						Dom.span !->
							Dom.style Flex: 1
							Dom.text tr("Mark as Complete")
						Dom.span !->
							Dom.style fontSize: '30px'
							Dom.text "✓"
						Dom.onTap !->
							Server.sync 'complete', key, true, !->
								Db.shared.set key, 'completed', true
							Modal.remove()
				Ui.item !->
					Dom.span !->
						Dom.style Flex: 1
						Dom.text tr("Add subitem")
					Dom.span !->
						Dom.style fontSize: '30px', paddingRight: '4px'
						Dom.text "+"
				if Plugin.userId() is Db.shared.peek(key, 'by') or Plugin.userIsAdmin()
					Ui.item !->
						Dom.span !->
							Dom.style Flex: 1
							Dom.text tr("Delete")
						Icon.render
							data: 'trash'
							color: '#444'
						Dom.onTap !->
							Modal.confirm null, tr("Are you sure you want to delete this item?"), !->
								Server.sync 'remove', key, !->
									Db.shared.remove key
								Modal.remove()
				Dom.h4 tr("Assign users")
				Plugin.users.iterate (user) !->
					Ui.item !->
						Ui.avatar user.get('avatar')
						Dom.text user.get('name')

						if false #+user.key() is +value.get()
							Dom.style fontWeight: 'bold'

							Dom.div !->
								Dom.style
									Flex: 1
									padding: '0 10px'
									textAlign: 'right'
									fontSize: '150%'
									color: Plugin.colors().highlight
								Dom.text "✓"

						Dom.onTap !->
							log user.key()
							Server.sync 'assign', key, parseInt(user.key()), !->
								log "lawl"
								# Db.shared.set(key, 'assigned', user.key())
							# handleChange [parseInt(user.key())]
							# value.set user.key()
							# Modal.remove()


# input that handles selection of a member
selectMember = (opts) !->
	log opts
	opts ||= {}
	[handleChange, initValue] = Form.makeInput opts, (v) -> 0|v

	# value = Obs.create(initValue)
	value = Obs.create(opts.value())
	Form.box !->
		Dom.div !->
			Dom.style fontSize: '125%', paddingRight: '56px'
			Dom.text opts.title||tr("Selected member")
		v = value.get()
		# Dom.div !->
			# Dom.style color: (if v then 'inherit' else '#aaa')
			# Dom.text (if v then Plugin.userName(v) else tr("Nobody"))
		log v
		Dom.div !->
			Dom.style
				Box: 'right'
		if v.length > 0
			for vi in v
				log vi
				Ui.avatar Plugin.userAvatar(vi),
					style:
						# position: 'absolute'
						# right: '6px'
						top: '50%'
						marginTop: '-20px'

		Dom.onTap !->
			Modal.show opts.selectTitle||tr("Select member"), !->
				Dom.style width: '80%'
				Dom.div !->
					Dom.style
						maxHeight: '40%'
						backgroundColor: '#eee'
						margin: '-12px'
					Dom.overflow()

					Plugin.users.iterate (user) !->
						Ui.item !->
							Ui.avatar user.get('avatar')
							Dom.text user.get('name')

							if +user.key() is +value.get()
								Dom.style fontWeight: 'bold'

								Dom.div !->
									Dom.style
										Flex: 1
										padding: '0 10px'
										textAlign: 'right'
										fontSize: '150%'
										color: Plugin.colors().highlight
									Dom.text "✓"

							Dom.onTap !->
								handleChange [parseInt(user.key())]
								value.set user.key()
								Modal.remove()
			, (choice) !->
				log 'choice', choice
				if choice is 'clear'
					handleChange []
					value.set ''
			, ['cancel', tr("Cancel"), 'clear', tr("Clear")]

renderItem = (itemId) !->
	Page.setTitle tr("Item")
	item = Db.shared.ref(itemId)
	Event.showStar item.get('text')
	if Plugin.userId() is item.get('by') or Plugin.userIsAdmin()
		Page.setActions
			icon: 'trash'
			action: !->
				Modal.confirm null, tr("Delete item?"), !->
					Server.sync 'remove', itemId, !->
						Db.shared.remove(itemId)
					Page.back()
	Dom.div !->
		Dom.style margin: '-8px -8px 0', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

		Form.setPageSubmit (values) !->
			Server.sync "edit", itemId, values, !->
				Db.shared.merge itemId, values
			Page.back()

		Form.box !->
			Dom.style padding: '8px'
			Form.input
				name: 'text'
				value: item.func('text')
				title: tr("Item")

			Dom.div !->
				Dom.style
					fontSize: '70%'
					color: '#aaa'
				Dom.text tr("Added by %1", Plugin.userName(item.get('by')))
				Dom.text " • "
				Time.deltaText item.get('time')

		Form.label tr("Notes")

		Form.box !->
			Dom.style padding: '8px'
			Form.text
				name: 'notes'
				text: tr 'Notes'
				autogrow: true
				value: item.func('notes')
				inScope: !->
					Dom.style fontSize: '140%'
					Dom.prop 'rows', 1

		Form.sep()

		Form.check
			name: 'completed'
			value: item.func('completed')
			text: tr("Completed")

		Form.sep()

		selectMember
			name: 'assigned'
			title: tr("Assigned to")
			value: item.func('assigned')
			selectTitle: tr("Assign to")

	Dom.div !->
		Dom.style margin: '0 -8px'
		Social.renderComments(itemId)

renderList = !->
	mobile = Plugin.agent().ios or Plugin.agent().android
	listE = []
	reorderSpace = 0

	DragToComplete = (element, key) !->
		# if mobile
		Dom.trackTouch (touches...) ->
			if touches.length == 1
				element.style transform: "translateX(#{touches[0].x + 'px'})"
				if touches[0].op is 4 #touch is stopped
					if touches[0].x > 50 #treshhold
						Server.sync 'complete', key, true, !->
							Db.shared.set key, 'completed', true
					if touches[0].x < -50 #treshhold
						Server.sync 'complete', key, false, !->
							Db.shared.set key, 'completed', false
					element.style transform: "translateX(0px)"
			return true #"bubble"
		, element

	DragToReorder = (element) !->
		Dom.trackTouch (touches...) ->
			if touches.length == 1
				y = element.getOffsetXY().y + touches[0].y + (element.height()/2)
				if touches[0].op is 1
					reorderSpace = element.height()
					# if element in listE then listE.splice(listE.indexOf(element), 1)
				element.style transform: "translateY(#{touches[0].y + 'px'})"
				#check dragover
				log listE
				for li in listE
					if li is element then continue
					liY = li.getOffsetXY().y
					if y < liY+li.height() and y > liY
						li.style backgroundColor: 'wheat'
					else
						li.style backgroundColor: 'inherit'
				log element.getOffsetXY().y + touches[0].y
				if touches[0].op is 4 #touch is stopped
					element.prop 'dragging', false
					log "done"
					element.style transform: "translateY(0)"
			return true
		,element

	Dom.style
		overflowX: 'hidden'

	Dom.css
		".item":
			marginLeft: '0px'
			transition: "marginLeft 3s ease 1s"
		".item-reset":
			marginLeft: '0px'

	editingItem = Obs.create(false)
	Ui.list !->
		#Dom.style backgroundColor: '#fff', margin: '-4px -8px', borderBottom: '1px solid #ccc'

		# Top entry: adding an item
		Ui.item !->
			Dom.style paddingLeft: '10px'
			save = !->
				return if !addE.value().trim()
				Server.sync 'add', addE.value().trim(), !->
					id = Db.shared.incr 'maxId'
					Db.shared.set(id, {time:0, by:Plugin.userId(), text: addE.value().trim()})
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
		Db.shared.iterate (item) !->
			empty.set(!++count)
			Obs.onClean !->
				empty.set(!--count)

			Dom.div !->
				itemE = Dom.get()
				Dom.style
					minHeight: '50px'
					Box: 'middle'
					flex: true
					_BackfaceVisibility: 'hidden' #transform fix
				# if !mobile
				# 	Dom.div !->
				# 		Dom.style Box: 'center middle'
				# 		item.get('completed')
				# 			# temp fix for problems arising from marking completed in edit item screen
				# 		Form.check
				# 			value: item.func('completed')
				# 			inScope: !->
				# 				Dom.style padding: '28px 32px 28px 14px'
				# 			onChange: (v) !->
				# 				Server.sync 'complete', item.key(), v, !->
				# 					item.set('completed', v)
				# 		Form.vSep()

				# Rearrange icon
				Dom.div !->
					Dom.style
						fontSize: '30px'
						color: "#999"
					Dom.text "≡"
					DragToReorder itemE

				# Content and avatar
				Dom.div !->
					Dom.style
						Flex: 1
						Box: 'left middle'
						padding: 0

					Dom.div !->
						Dom.style
							boxSizing: 'border-box'
							Box: 'middle'
							Flex: 1
							padding: '8px 4px 8px 12px'
							textDecoration: if item.get('completed') then 'line-through' else 'none'
							color: if item.get('completed') then '#aaa' else 'inherit'
							fontSize: '16px' #'21px'
						Dom.div !->
							Dom.style
								Flex: 1
								color: (if Event.isNew(item.get('time')) then '#5b0' else 'inherit')
								# overflow: 'hidden'
								# whiteSpace: 'nowrap'
								# textOverflow: 'ellipsis'
								# width: '0px' #Firefox hack. But.. errrgh... whut?
							Dom.userText item.get('text')
							if notes = item.get('notes')
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
							Event.renderBubble [item.key()]
					Dom.div !->
						Dom.style marginRight: '4px'
							# height: '60px'
							# Box: 'middle'
							# position: 'relative'
						assigned = item.get('assigned')
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
									top: '20px'
									left: '50%'
									color: '#fff'
								Dom.text assigned.length
					Dom.onTap !->
						Page.nav item.key()
					# DragToComplete itemE, item.key()

				#Overflow menu
				Form.vSep()
				Dom.last().style margin: '0px'
				Dom.div !->
					Dom.style
						lineHeight: '9px'
						padding: '8px'
					Dom.userText "▪\n▪\n▪"
					Dom.onTap !->
						renderMenu(item.key())
				listE.push itemE
			Form.sep()
		, (item) ->
			if +item.key()
				-item.key() + (if item.peek('completed') then 1e9 else 0)

		Dom.div !->
			Dom.style
				width: '100%'
				height: '40px'
				backgroundColor: 'wheat'
			Dom.text "dragelement"
			dragElement = Dom.get()

		Obs.observe !->
			log 'empty now', empty.get()
			if empty.get()
				Ui.item !->
					Dom.style
						padding: '12px 6px'
						textAlign: 'center'
						color: '#bbb'
					Dom.text tr("No items")

	Dom.div !->
		Dom.style
			textAlign: 'center'
			margin: '20px'
			color: '#999'
		Dom.text tr("Swipe an item left to check it, and to the right to uncheck it")
