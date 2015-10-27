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
SF = require 'serverFunctions'

exports.render = !->
	itemId = Page.state.get(0)
	if itemId
		renderItem(itemId)
	else
		Overview.renderList()

renderItem = (itemId) !->
	completed = Page.state.get("?completed")||false
	item = if completed then Db.shared.ref 'completed', itemId else Db.shared.ref 'items', itemId
	children = Page.state.get("?children")
	Page.setTitle Form.smileyToEmoji(""+item.get("text"))
	Event.showStar item.get('text')
	if Plugin.userId() is item.get('by') or Plugin.userIsAdmin()
		Page.setActions
			icon: 'trash'
			action: !->
				Modal.confirm null, (if children.length>1 then tr("Are you sure you want to delete this item and its %1 subitem|s?", children.length-1) else tr("Are you sure you want to delete this item?")), !->
					Server.sync 'remove', itemId, children, completed, !->
						SF.remove(itemId, children, completed)
					Page.back()

	assO = Obs.create(item.peek("assigned"))
	Obs.observe !->
		assO.set(item.get("assigned"))

	Dom.div !->
		Dom.style margin: '-8px -8px 0', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

		Form.setPageSubmit (values) !->
			Server.sync "edit", itemId, values, assO.peek(), completed, children, !->
				values.subitem = null
				SF.edit itemId, values, assO.peek(), completed, children
			Page.back()

		editTextO = Obs.create(true)
		Form.box !->
			Dom.style
				color: '#333'
				padding: '16px 8px 8px'
				backgroundColor: '#e9f1f7'
				borderBottom: '1px solid #bfcdd8'
			Form.text
				name: 'text'
				value: item.func('text')
				title: tr("Item")
				rows: 1
				style:
					margin: '0px'
					padding: '0px 4px 4px'
			Dom.div !->
				Dom.style
					margin: '8px 4px 0px'
					fontSize: '100%'
				for url in item.get("text")?.match(///(https?://|ftp://|www\.)[^\s/$.?][^\s,]*///gi)||[]
					Dom.userText url + " "

		Dom.div !->
			Dom.style
				margin: '8px'
				fontSize: '70%'
				color: '#aaa'
			Dom.text tr("Added by %1", Plugin.userName(item.get('by')))
			Dom.text " • "
			Time.deltaText item.get('time')

		editNotesO = Obs.create(false)
		Dom.h4 !->
			Dom.style
				padding: '8px 8px 0px'
			Dom.text tr("Notes")
		Form.box !->
			Dom.style padding: '8px 8px 16px 8px'
			Form.text
				name: 'notes'
				rows: 1
				value: item.func('notes')
				title: tr("Item")
				style:
					padding: '0px'
					margin: '0px 4px 4px'
			Dom.div !->
				Dom.style
					margin: '0px 4px'
					fontSize: '100%'
				for url in item.get("notes")?.match(///(https?://|ftp://|www\.)[^\s/$.?][^\s,]*///gi)||[]
					Dom.userText url + " "

		Form.sep()

		Form.check
			name: 'completed'
			value: item.func('completed')
			text: tr("Completed")

		Form.sep()

		emptyO = Obs.create(true)
		Form.hidden('assigned', assO.func())

		Form.box !->
			Dom.style
				width: '100%'
				boxSizing: 'border-box'
				padding: '0px 8px'
				marginTop: '16px'
			Dom.h4 tr("Assignee(s)")
			Dom.div !->
				Dom.style
					textAlign: 'center'
					margin: '0px -4px 8px'
					padding: '4px 0'
				emptyO.set true
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
					Dom.div !->
						Dom.style
							textAlign: 'left'
							padding: '8px 4px'
							color: '#aaa'
						Dom.text tr("No one, tap to assign")
				Dom.onTap !->
					Modal.show tr("Assign member(s)"), !->
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
