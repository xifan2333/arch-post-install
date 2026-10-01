/* GTK3 & GTK4 / Libadwaita theme integration with CSD suppression
 * Managed by arch-theme-set template pipeline
 */

@define-color accent_color {{ accent }};
@define-color accent_bg_color {{ accent }};
@define-color accent_fg_color {{ dark_background }};

@define-color window_bg_color {{ background }};
@define-color window_fg_color {{ foreground }};
@define-color view_bg_color {{ background }};
@define-color view_fg_color {{ foreground }};
@define-color headerbar_bg_color {{ dark_background }};
@define-color headerbar_fg_color {{ foreground }};
@define-color headerbar_border_color {{ dark_background }};
@define-color headerbar_backdrop_color {{ background }};
@define-color card_bg_color {{ dark_background }};
@define-color card_fg_color {{ foreground }};
@define-color popover_bg_color {{ dark_background }};
@define-color popover_fg_color {{ foreground }};
@define-color dialog_bg_color {{ background }};
@define-color dialog_fg_color {{ foreground }};

/* Suppress CSD headerbars and window titles in tiling window manager */
headerbar.titlebar,
window.csd > headerbar.titlebar,
window > headerbar.titlebar,
.titlebar {
    min-height: 0;
    padding: 0;
    margin: 0;
    border: none;
    box-shadow: none;
}

/* Hide window controls (minimize, maximize, close buttons) */
headerbar windowcontrols,
windowcontrols,
.titlebar button.close,
.titlebar button.minimize,
.titlebar button.maximize {
    min-width: 0;
    min-height: 0;
    padding: 0;
    margin: 0;
    opacity: 0;
}
