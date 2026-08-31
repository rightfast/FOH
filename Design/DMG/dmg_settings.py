import os

application = defines["app"]  # noqa: F821
background_image = defines["background"]  # noqa: F821

format = "UDZO"
filesystem = "HFS+"
compression_level = 9

files = [application]
symlinks = {"Applications": "/Applications"}
background = background_image
window_rect = ((200, 120), (560, 380))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = True

icon_locations = {
    "FOH.app": (145, 198),
    "Applications": (415, 198),
}
icon_size = 128
text_size = 14
label_pos = "bottom"

badge_icon = os.path.join(application, "Contents", "Resources", "AppIcon.icns")
