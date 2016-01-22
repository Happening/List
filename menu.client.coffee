Db = require 'db'
Dom = require 'dom'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
Obs = require 'obs'
App = require 'app'
Server = require 'server'
Ui = require 'ui'
{tr} = require 'i18n'
SF = require 'serverFunctions'

exports.renderMenu = (key, children, item) !->
	key = parseInt(key)
	Modal.show tr("Options"), !->
		Ui.item !->
			value = Db.shared.get('items', key, 'completed')
			Dom.div !->
				Dom.style Flex: 1
				Dom.text tr("Completed")
			complete = Form.check
				simple: true
				value: value
			Dom.onTap !->
				Server.sync 'complete', key, !value, !->
					Db.shared.set 'items', key, 'completed', !value
				# Modal.remove()
		Ui.item !->
			Dom.div !->
				Dom.style Flex: 1
				Dom.text tr("Add subitem")
			Dom.span !->
				Dom.style fontSize: '30px', paddingRight: '4px'
				Icon.render
					data: 'add'
					color: App.colors().highlight
					size: 22
					style: {marginRight: '2px'}
			Dom.onTap !->
				if item.collapsed
					item.collapse(false, true) # expand item
				if item.plusChild?
					item.plusChild.editingItemO.set('focus')
					item.plusChild.setShowPlus(key)
				else
					item.editingItemO.set('focus')
					item.setShowPlus(key)
				Modal.remove()

		if App.userId() is Db.shared.peek('items', key, 'by') or App.userIsAdmin()
			Ui.item !->
				Dom.div !->
					Dom.style Flex: 1
					Dom.text tr("Delete")
				Icon.render
					data: 'delete'
					color: App.colors().highlight
					style: marginRight: '5px'
				Dom.onTap !->
					Modal.confirm null, (if children.length>1 then tr("Are you sure you want to delete this item and its %1 subitem|s?", children.length-1) else tr("Are you sure you want to delete this item?")), !->
						Server.sync 'remove', key, children, !->
							SF.remove(key, children)
						Modal.remove()

		Form.label tr("Assigned to")
		selectMember(key)

# input that handles selection of a member
exports.selectMember = selectMember = (key, observable = null) ->
	App.users.observeEach (user) !->
		Ui.item !->
			Ui.avatar user.peek('avatar'), style: marginRight: '8px'
			Dom.text user.peek('name')

			if observable # local obs
				if observable.get(user.key())
					Dom.style fontWeight: 'bold'

					Dom.div !->
						Dom.style
							Flex: 1
							textAlign: 'right'
						Icon.render
							data: 'done'
				else
					Dom.style fontWeight: 'normal'
				Dom.onTap !->
					if observable.get(user.key())
						observable.remove(user.key())
					else
						observable.set(user.key(), true)
			else # shared
				if Db.shared.get('items', key, 'assigned', user.key())
					Dom.style fontWeight: 'bold'

					Dom.div !->
						Dom.style
							Flex: 1
							textAlign: 'right'
						Icon.render
							data: 'done'
							style: marginRight: '5px'
				else
					Dom.style fontWeight: 'normal'
				Dom.onTap !->
					Server.sync 'assign', key, parseInt(user.key()), !->
						if Db.shared.get('items', key, 'assigned', user.key())
							Db.shared.remove('items', key, 'assigned', user.key())
						else
							Db.shared.set('items', key, 'assigned', user.key(), true)
