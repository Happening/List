Comments = require 'comments'
Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
Obs = require 'obs'
Page = require 'page'
App = require 'app'
Server = require 'server'
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

exports.renderSettings = !->
	Form.input
		name: '_title'
		text: tr('List name')
		value: App.title()

renderItem = (itemId) !->
	item = Db.shared.ref('items', itemId)
	completed = false
	if !item || !item.isHash()
		item = Db.shared.ref('completed', itemId)
		if !item || !item.isHash()
			return Page.up()
		completed = true

	children = Page.state.get("?children")?.split(",")||[itemId]
	Page.setTitle Form.smileyToEmoji(""+item.get("text"))
	Event.showStar item.get('text')
	if App.userId() is item.get('by') or App.userIsAdmin()
		Page.setActions
			icon: 'delete'
			action: !->
				Modal.confirm null, (if children.length>1 then tr("Are you sure you want to delete this item and its %1 subitem|s?", children.length-1) else tr("Are you sure you want to delete this item?")), !->
					Server.sync 'remove', itemId, children, completed, !->
						SF.remove(itemId, children, completed)
					Page.back()

	assO = Obs.create(item.peek("assigned"))
	Obs.observe !->
		assO.set(item.get("assigned"))

	Form.setPageSubmit (values) !->
		Server.sync "edit", itemId, values, assO.peek(), completed, children, !->
			values.subitem = null
			SF.edit itemId, values, assO.peek(), completed, children
		Page.back()

	editTextO = Obs.create(true)
	Ui.top !->
		Dom.cls 'top1'
		Dom.cls 'invert'
		Dom.style marginBottom: "2px"
		Form.text
			name: 'text'
			value: item.func('text')
			title: tr("Item")
		for url in item.get("text")?.match(///(https?://|ftp://|www\.)[^\s/$.?][^\s,]*///gi)||[]
			Dom.div !->
				Dom.cls 'form-row'
				Dom.style padding: '8px'
				Dom.userText url + " "

	Dom.div !->
		Dom.style
			fontSize: '70%'
			color: '#aaa'
		Dom.text tr("Added by %1", App.userName(item.get('by')))
		Dom.text " • "
		Time.deltaText item.get('time')

	editNotesO = Obs.create(false)
	Form.label tr("Notes")
	Form.text
		name: 'notes'
		value: item.func('notes')
		text: tr("Notes")
		style:
			marginBottom: '4px'
	Dom.div !->
		Dom.cls 'form-row'
		for url in item.get("notes")?.match(///(https?://|ftp://|www\.)[^\s/$.?][^\s,]*///gi)||[]
			Dom.span !->
				Dom.style padding: '0 4px'
				Dom.userText url + " "

	Form.check
		name: 'completed'
		value: item.func('completed')
		text: tr("Completed")

	emptyO = Obs.create(true)
	Form.hidden('assigned', assO.func())

	Form.label tr("Assigned to")
	Dom.div !->
		emptyO.set true
		for a of assO.get()
			emptyO.set false
			Dom.div !->
				Dom.style
					display: 'inline-block'
					textAlign: 'center'
					position: 'relative'
					padding: '2px'

				Ui.avatar App.userAvatar(a),
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
				Dom.style
					paddingTop: 0
					paddingBottom: 0
				Menu.selectMember(itemId, assO)

	Comments.enable store: ['comments',itemId]

