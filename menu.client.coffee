Db = require 'db'
Dom = require 'dom'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Server = require 'server'
Ui = require 'ui'
{tr} = require 'i18n'
SF = require 'serverFunctions'

exports.renderMenu = (key, children, item) !->
	key = parseInt(key)
	Modal.show tr("Options"), !->
		Dom.style width: '80%', maxWidth: '400px'
		Dom.div !->
			Dom.style
				maxHeight: '70%'
				backgroundColor: '#eee'
				margin: '-12px'
			Dom.overflow()
			Dom.div !->
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
							color: Plugin.colors().highlight
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

				if Plugin.userId() is Db.shared.peek('items', key, 'by') or Plugin.userIsAdmin()
					Ui.item !->
						Dom.div !->
							Dom.style Flex: 1
							Dom.text tr("Delete")
						Icon.render
							data: 'trash2'
							color: Plugin.colors().highlight
							style: {marginRight: '5px'}
						Dom.onTap !->
							Modal.confirm null, (if children.length>1 then tr("Are you sure you want to delete this item and its %1 subitem|s?", children.length-1) else tr("Are you sure you want to delete this item?")), !->
								Server.sync 'remove', key, children, !->
									SF.remove(key, children)
								Modal.remove()

				Dom.h4 !->
					Dom.style margin: '12px 8px 4px 8px'
					Dom.text tr("Assignee(s)")
				selectMember(key)

# input that handles selection of a member
exports.selectMember = selectMember = (key, observable = null) ->
	Plugin.users.observeEach (user) !->
		Ui.item !->
			Ui.avatar user.peek('avatar')
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
							style: {marginRight: '5px'}
				else
					Dom.style fontWeight: 'normal'
				Dom.onTap !->
					Server.sync 'assign', key, parseInt(user.key()), !->
						if Db.shared.get('items', key, 'assigned', user.key())
							Db.shared.remove('items', key, 'assigned', user.key())
						else
							Db.shared.set('items', key, 'assigned', user.key(), true)
