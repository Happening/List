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
			Ui.list !->
				Ui.item !->
					value = Db.shared.get('items', key, 'completed')
					Dom.span !->
						Dom.style Flex: 1
						Dom.text tr("Set to uncompleted")
					complete = Form.check
						simple: true
						value: value
					Dom.onTap !->
						Server.sync 'complete', key, !value, !->
							Db.shared.set 'items', key, 'completed', !value
						Modal.remove()
				Ui.item !->
					Dom.span !->
						Dom.style Flex: 1
						Dom.text tr("Allow subitems")
					Dom.span !->
						Dom.style fontSize: '30px', paddingRight: '4px'
						Icon.render
							data: 'add'
							color: Plugin.colors().highlight
							size: 22
							style: {marginRight: '2px'}
					Dom.onTap !->
						item.setShowPlus(key)
						# Modal.prompt tr("Add subitem")
						# , (value) !->
						# 	Server.sync 'add', value, key, !->
						# 		SF.add(value, key, Plugin.userId())
						Modal.remove()

				if Plugin.userId() is Db.shared.peek('items', key, 'by') or Plugin.userIsAdmin()
					Ui.item !->
						Dom.span !->
							Dom.style Flex: 1
							Dom.text tr("Delete")
						Icon.render
							data: 'trash2'
							color: Plugin.colors().highlight
							style: {marginRight: '5px'}
						Dom.onTap !->
							Modal.confirm null, (if children.length>1 then tr("Are you sure you want to delete this item and its #{children.length-1} subitems?") else tr("Are you sure you want to delete this item?")), !->
								Server.sync 'remove', key, children, !->
									SF.remove(key, children)
								Modal.remove()

				Dom.h4 tr("Assign to")
				selectMember(key)

# input that handles selection of a member
exports.selectMember = selectMember = (key) !->
	Plugin.users.observeEach (user) !->
		Ui.item !->
			Ui.avatar user.peek('avatar')
			Dom.text user.peek('name')
			log "render", user.peek('name'), Db.shared.peek('items', key, 'assigned', user.key())

			if Db.shared.get('items', key, 'assigned', user.key())
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
				log user.key()
				Server.sync 'assign', key, parseInt(user.key()), !->
					if Db.shared.get('items', key, 'assigned', user.key())
						Db.shared.remove('items', key, 'assigned', user.key())
					else
						Db.shared.set('items', key, 'assigned', user.key(), true)
