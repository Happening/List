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

		Form.input
			simple: true
			name: 'subitem'
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
				if item.get("assigned") and item.get("assigned").length > 0
					for a in item.get('assigned')
						Dom.div !->
							Dom.style
								display: 'inline-block'
								textAlign: 'center'
								position: 'relative'
								padding: '2px'
								# boxSizing: 'border-box'
								# borderRadius: '2px'
								# width: '60px'

							Ui.avatar Plugin.userAvatar(a),
								style:
									display: 'inline-block'
									margin: '0 0 1px 0'

							# Dom.div !->
							# 	Dom.style fontSize: '18px'
							# 	Dom.text Form.smileyToEmoji Plugin.userName(a)
				else
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
							Menu.selectMember(itemId)

	Dom.div !->
		Dom.style margin: '0 -8px'
		Social.renderComments(itemId)

