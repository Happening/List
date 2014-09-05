Db = require 'db'
Dom = require 'dom'
Form = require 'form'
Obs = require 'obs'
Plugin = require 'plugin'
Server = require 'server'
Widgets = require 'widgets'
{tr} = require 'i18n'

exports.render = !->
	Dom.div !->
		Dom.style
			margin: '8px'
			fontSize: '21px'

		if Plugin.userIsAdmin()
			titleE = false
			titleE = Form.input
				name: 'title'
				value: -> (Db.shared 'title')
				title: tr("List title")
				onSave: (v) !->
					Server.sync 'title', v

		else if (t = (Db.shared 'title')) != ''
			Dom.text t
		else
			Dom.text tr("No title")

	editingItem = Obs.value(false)
	Dom.ol !->
		###
		Obs.observe !-> if editingItem()
			Dom.li !->
				Dom.style color: '#bbb'
				Dom.text tr('+ List item')
		###

		Dom.li !->
			Dom.style paddingLeft: '3px'
			save = !->
				return if !addE.value().trim()
				Server.sync 'add', addE.value().trim(), !->
					id = 1+(0|Db.shared 'maxId')
					(Db.shared id, {time:0, by:Plugin.userId(), text: addE.value().trim()})
					(Db.shared "maxId", id)
				addE.value ""
				(editingItem false)
				Form.blur()

			addE = Form.input
				simple: true
				name: 'item'
				text: tr("+ List item")
				onChange: (v) !->
					(editingItem !!v?.trim())
				onReturn: save
				inScope: !->
					Dom.style
						display: 'block'
						border: 'none'
						_boxFlex: 1
						fontSize: '21px'

			Obs.observe !->
				Widgets.button !->
					Dom.style visibility: (if editingItem() then 'visible' else 'hidden')
					Dom.text tr("Add")
				, save


		count = 0
		empty = Obs.value(true)

		Db.shared (id, data) !->
			(empty !++count)
			Obs.onClean !->
				(empty !--count)
			Dom.li !->
				
				Dom.style
					textDecoration: if (data 'completed') then 'line-through' else 'none'
					fontSize: '21px'

				Dom.text (data 'text')
				Dom.onTap !->
					require('modal').show null, tr("What do you want to do with the item?"), (choice) !->
						if choice is 'remove'
							Server.sync 'remove', id, !->
								(Db.shared id, null)
						else if choice is 'complete'
							Server.sync 'complete', id, !(data 'completed'), !->
								(data 'completed', !(data 'completed'))
					, ['cancel', tr("Cancel"), 'remove', tr("Remove"), 'complete', if (data 'completed') then tr("Uncomplete") else tr("Complete")]
		, (id) ->
			if +id then -id

		Obs.observe !->
			log 'empty now', empty()
			if empty()
				Dom.li !->
					Dom.style
						padding: '12px 6px'
						textAlign: 'center'
						color: '#bbb'
					Dom.text tr("No items")
