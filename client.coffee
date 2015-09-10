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
Overview = require 'overview'
Menu = require 'menu'

exports.render = !->
	itemId = Page.state.get(0)
	if itemId
		renderItem(itemId)
	else
		Overview.renderList()

renderItem = (itemId) !->
	Page.setTitle tr("Item")
	item = Db.shared.ref 'items', itemId
	Event.showStar item.get('text')
	if Plugin.userId() is item.get('by') or Plugin.userIsAdmin()
		Page.setActions
			icon: 'trash'
			action: !->
				Modal.confirm null, tr("Delete item?"), !->
					Server.sync 'remove', itemId, !->
						Db.shared.remove(itemId)
					Page.back()

	assO = Obs.create(item.peek("assigned"))
	Obs.observe !->
		assO.set(item.get("assigned"))

	Dom.div !->
		Dom.style margin: '-8px -8px 0', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

		Form.setPageSubmit (values) !->
			log values.assigned
			Server.sync "edit", itemId, values, assO.peek(), !->
				values.subitem = null
				Db.shared.merge itemId, values
			Page.back()

		editTextO = Obs.create(false)
		Form.box !->
			Dom.style padding: '8px'
			Dom.style Box: 'right'
			if editTextO.get()
				Form.input
					name: 'text'
					value: item.func('text')
					title: tr("Item")
					style:
						margin: '8px'
						width: '100%'
			else
				Dom.div !->
					Dom.style Flex: 1
					Dom.div !->
						Dom.style
							fontSize: '24px'
							lineHeight: '26px'
						Dom.userText Form.smileyToEmoji(""+item.get("text"))

					Dom.div !->
						Dom.style
							fontSize: '70%'
							color: '#aaa'
						Dom.text tr("Added by %1", Plugin.userName(item.get('by')))
						Dom.text " • "
						Time.deltaText item.get('time')
				Dom.div !->
					Dom.style
						padding: '8px 2px'
					Icon.render
						data: 'edit'
						style:
							position: 'inherit'
							top: 'inherit'
							margin: 'inherit'
				Dom.onTap !->
					log "edit"
					editTextO.set true

		Form.sep()
		Dom.div !->
			Dom.style
				Box: 'middle'
				padding: '8px 8px 0px'
			Dom.h4 !->
				Dom.style
					Flex: 1
					# margin: '8px 8px 0px'
				Dom.text tr("Notes")
			Dom.div !->
				Dom.style
					padding: '8px 2px'
				Icon.render
					data: 'edit'
					style:
						position: 'inherit'
						top: 'inherit'
						margin: 'inherit'
				Dom.onTap !->
					log "edit"
					editNotesO.set true
		editNotesO = Obs.create(false)
		Form.box !->
			Dom.style padding: '8px'
			Dom.style Box: 'right'
			if editNotesO.get()
				Form.text
					name: 'notes'
					value: item.func('notes')
					title: tr("Item")
					style:
						width: '100%'
						padding: '0px 0px 20px 0px'
			else
				Dom.div !->
					Dom.style Flex: 1
					Dom.div !->
						Dom.style
							fontSize: '17px'
							lineHeight: '19px'
						Dom.userText Form.smileyToEmoji(if item.get("notes")? then item.get("notes") else "No notes ...")
				Dom.onTap !->
					log "edit"
					editNotesO.set true

		Form.sep()

		Form.check
			name: 'completed'
			value: item.func('completed')
			text: tr("Completed")

		Form.sep()

		# Form.input
		# 	simple: true
		# 	name: 'subitem'
		# 	text: tr("+ Add subitem")
		# 	# onChange: (v) !->
		# 	# 	item.editingItem.set(!!v?.trim())
		# 	# onReturn: save
		# 	inScope: !->
		# 		Dom.style
		# 			margin: '12px 8px'
		# 			border: 'none'

		# Form.sep()

		emptyO = Obs.create(true)
		Form.hidden('assigned', assO.func())

		Form.box !->
			Dom.style
				width: '100%'
				boxSizing: 'border-box'
				padding: '0px 8px'
			Dom.h4 tr("Assigned to")
			Dom.div !->
				Dom.style
					textAlign: 'center'
					margin: '0px -4px'
				emptyO.set true
				# assF.value = []
				for a of assO.get()
					emptyO.set false
					Dom.div !->
						Dom.style
							display: 'inline-block'
							textAlign: 'center'
							position: 'relative'
							padding: '2px'

						Ui.avatar Plugin.userAvatar(a),
							style:
								display: 'inline-block'
								margin: '0 0 1px 0'
				if emptyO.get()
					Dom.h4 !->
						Dom.style
							fontSize: '120%'
							padding: '8px 0px'
						Dom.text tr("None assigned")
				Dom.onTap !->
					Modal.show tr("Assign members"), !->
						Dom.style width: '80%', maxWidth: '400px'
						Dom.div !->
							Dom.style
								maxHeight: '70%'
								backgroundColor: '#eee'
								margin: '-12px'
							Dom.overflow()
							Menu.selectMember(itemId, assO)

	Dom.div !->
		Dom.style margin: '0 -8px'
		Social.renderComments(itemId)

