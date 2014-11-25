Db = require 'db'
Social = require 'social'
Dom = require 'dom'
Form = require 'form'
Time = require 'time'
Page = require 'page'
Obs = require 'obs'
Plugin = require 'plugin'
Modal = require 'modal'
Server = require 'server'
Ui = require 'ui'
{tr} = require 'i18n'

exports.render = !->
	itemId = Page.state.get(0)
	if itemId
		renderItem(itemId)
	else
		renderList()

# input that handles selection of a member
selectMember = (opts) !->
	opts ||= {}
	[handleChange, initValue] = Form.makeInput opts, (v) -> 0|v

	value = Obs.create(initValue)
	Form.box !->
		Dom.style fontSize: '125%', paddingRight: '56px'
		Dom.text opts.title||tr("Selected member")
		v = value.get()
		Dom.div !->
			Dom.style color: (if v then 'inherit' else '#aaa')
			Dom.text (if v then Plugin.userName(v) else tr("Nobody"))
		if v
			Ui.avatar Plugin.userAvatar(v), !->
				Dom.style position: 'absolute', right: '6px', top: '50%', marginTop: '-20px'

		Dom.onTap !->
			Modal.show opts.selectTitle||tr("Select member"), !->
				Dom.style width: '80%'
				Dom.div !->
					Dom.style
						maxHeight: '40%'
						overflow: 'auto'
						_overflowScrolling: 'touch'
						backgroundColor: '#eee'
						margin: '-12px'

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
								handleChange user.key()
								value.set user.key()
								Modal.remove()
			, (choice) !->
				log 'choice', choice
				if choice is 'clear'
					handleChange ''
					value.set ''
			, ['cancel', tr("Cancel"), 'clear', tr("Clear")]

renderItem = (itemId) !->
	Page.setTitle tr("Item")
	item = Db.shared.ref(itemId)
	if Plugin.userId() is item.get('by') or Plugin.userIsAdmin()
		Page.setActions
			icon: Plugin.resourceUri('icon-trash-48.png')
			action: !->
				Modal.confirm null, tr("Delete item?"), !->
					Server.sync 'remove', itemId, !->
						Db.shared.remove(itemId)
					Page.back()
	Dom.div !->
		Dom.style margin: '-8px -8px 0', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

		Form.setPageSubmit (values) !->
			Server.call "edit", itemId, values
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
	editingItem = Obs.create(false)
	Ui.list !->
		#Dom.style backgroundColor: '#fff', margin: '-4px -8px', borderBottom: '1px solid #ccc'

		if title = Db.shared.get('title')
			Dom.h2 title

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

			Ui.item !->
				Dom.style
					Box: 'middle'
					Flex: 1
					padding: 0

				Dom.div !->
					Dom.style Box: 'center middle'
					Form.check
						value: item.func('completed')
						inScope: !->
							Dom.style padding: '28px 32px 28px 14px'
						onChange: (v) !->
							Server.sync 'complete', item.key(), v, !->
								item.set('completed', true)

				Form.vSep()
				
				Dom.div !->
					Dom.style
						Box: 'middle'
						Flex: 1
						minHeight: '40px'
						padding: '8px'
						textDecoration: if item.get('completed') then 'line-through' else 'none'
						color: if item.get('completed') then '#aaa' else 'inherit'
						fontSize: '21px'

					Dom.div !->
						Dom.style Flex: 1
						Dom.text item.get('text')
						if unread = Social.newComments(item.key())
							Ui.unread unread, null, {marginLeft: '4px'}
						if notes = item.get('notes')
							Dom.div !->
								Dom.style
									color: '#aaa'
									whiteSpace: 'nowrap'
									fontSize: '70%'
									fontWeight: 'normal'
									overflow: 'hidden'
									textOverflow: 'ellipsis'
								Dom.text notes
					if assigned = item.get('assigned')
						Ui.avatar Plugin.userAvatar(assigned), !->
							Dom.style
								margin: '0 0 0 8px'

					Dom.onTap !->
						Page.nav item.key()


		, (item) ->
			if +item.key()
				-item.key() + (if item.peek('completed') then 1e9 else 0)

		Obs.observe !->
			log 'empty now', empty.get()
			if empty.get()
				Ui.item !->
					Dom.style
						padding: '12px 6px'
						textAlign: 'center'
						color: '#bbb'
					Dom.text tr("No items")

exports.renderConfig = exports.renderSettings = !->
	Form.input
		name: 'title'
		text: tr('Title')
		value: Db.shared.func('title') if Db.shared
