/*
 * This file is part of budgie-desktop
 *
 * Copyright © 2015-2022 Budgie Desktop Developers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 */

/**
 * Return a string suitable for working on.
 * This works around the issue of GNOME Control Center and others deciding to
 * use soft hyphens in their .desktop files.
 */
static string? searchable_string(string input) {
	/* Force dup in vala */
	string mod = "" + input;
	return mod.replace("\u00AD", "").ascii_down().strip();
}

public class BudgieMenuWindow : Budgie.Popover {
	protected Gtk.Box main_layout;
	protected Gtk.SearchEntry search_entry;
	protected ApplicationView view;

	private UserButton user_indicator;
	private Gtk.Button power_button;
	private PowerMenu user_menu;

	public BudgieMenuWindow(Settings? settings, Gtk.Widget? leparent) {
		Object(relative_to: leparent);
		this.get_style_context().add_class("budgie-menu");

		this.main_layout = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
		this.add(main_layout);

		// Header items at the top with search input
		var header = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
		header.get_style_context().add_class("budgie-menu-header");

		this.search_entry = new Gtk.SearchEntry();
		this.search_entry.grab_focus();
		header.pack_start(search_entry, true, true, 0);

		this.main_layout.pack_start(header, false, false, 0);

		// middle holds the categories and applications
		var middle = new Gtk.Overlay();
		var view_container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

		this.user_menu = new PowerMenu();

		middle.add(view_container);
		middle.add_overlay(this.user_menu);

		this.view = new ApplicationListView(settings);

		view_container.pack_end(this.view, true, true, 0);
		this.main_layout.pack_start(middle, true, true, 0);

		// Footer at the bottom for user and power stuff
		var footer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		footer.get_style_context().add_class("budgie-menu-footer");

		this.user_indicator = new UserButton();
		user_indicator.valign = Gtk.Align.CENTER;
		user_indicator.halign = Gtk.Align.START;

		this.power_button = new Gtk.Button.from_icon_name("system-shutdown-symbolic");
		power_button.relief = Gtk.ReliefStyle.NONE;
		power_button.valign = Gtk.Align.CENTER;
		power_button.halign = Gtk.Align.END;
		power_button.set_tooltip_text(_("Power"));

		footer.pack_start(this.user_indicator, false, false, 0);
		footer.pack_end(this.power_button, false, false, 0);
		//  footer.set_child_non_homogeneous(this.user_indicator, true);
		this.main_layout.pack_end(footer, false, false, 0);

		// Close the power menu on click if it is open
		this.button_press_event.connect((event) => {
			// Only care about left clicks
			if (event.button != 1) {
				return Gdk.EVENT_PROPAGATE;
			}

			// Don't do work if we don't need to
			if (!this.user_menu.get_reveal_child()) {
				return Gdk.EVENT_PROPAGATE;
			}

			this.reset(false);
			return Gdk.EVENT_STOP;
		});

		// searching functionality :)
		this.search_entry.search_changed.connect(()=> {
			var search_term = searchable_string(this.search_entry.text);
			this.view.search_changed(search_term);
		});

		// Enabling activation by search entry
		this.search_entry.activate.connect(() => {
			// Make the view (and filter) is updated before calling activate
			var search_term = searchable_string(this.search_entry.text);
			this.view.search_changed(search_term);

			this.view.on_search_entry_activated();
		});

		// Open or close the session controls menu when
		// the user indicator is clicked
		this.power_button.clicked.connect(() => {
			if (this.user_menu.get_reveal_child()) {
				this.reset(false);
			} else {
				this.open_session_menu();
			}
		});

		// We should go away when a user menu button is clicked
		this.user_menu.item_clicked.connect(() => {
			this.hide();
		});

		// We should go away when an app is launched from the menu
		this.view.app_launched.connect(() => {
			this.hide();
		});
	}

	/**
	 * Refresh the category and application views.
	 */
	public void refresh(Tracker app_tracker, bool now = false) {
		if (now) {
			this.view.refresh(app_tracker);
		} else {
			this.view.queue_refresh(app_tracker);
		}
	}

	/**
	 * Reset the popover UI to the base state.
	 *
	 * If `clear_search` is set to true, the search entry text will be cleared.
	 */
	public void reset(bool clear_search) {
		this.user_menu.set_reveal_child(false);
		this.search_entry.sensitive = true;
		this.search_entry.grab_focus();
		this.view.set_sensitive(true);

		if (clear_search) {
			this.search_entry.text = "";
		}
	}

	/**
	 * We need to make some changes to our display before we go showing ourselves
	 * again! :)
	 */
	public override void show() {
		this.reset(true);
		base.show();
	}

	/**
	 * Opens our session menu and makes all other widgets insensitive.
	 */
	private void open_session_menu() {
		this.user_menu.set_reveal_child(true);
		this.search_entry.sensitive = false;
		this.view.set_sensitive(false);
	}
}
