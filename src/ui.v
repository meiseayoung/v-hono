import ui

struct App {
mut:
	window     &ui.Window = unsafe { nil }
	first_name string
	last_name  string
}

fn main() {
	mut app := &App{}
	app.window = ui.window(
		width:    600
		height:   400
		title:    'V UI Demo'
		children: [
			ui.row(
				margin:   ui.Margin{10, 10, 10, 10}
				children: [
					ui.column(
						width:    200
						spacing:  13
						children: [
							ui.textbox(
								max_len:     20
								width:       200
								placeholder: 'First name'
								text:        &app.first_name
							),
							ui.textbox(
								max_len:     50
								width:       200
								placeholder: 'Last name'
								text:        &app.last_name
							),
						]
					),
				]
			),
		]
	)
	ui.run(app.window)
}
