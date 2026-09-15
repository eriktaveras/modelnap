# Ajustes de dmgbuild para el instalador. Las rutas llegan con -D desde package.sh.
import os.path

app = defines["app"]  # noqa: F821 (dmgbuild inyecta `defines`)
app_name = os.path.basename(app)

format = "UDZO"
filesystem = "HFS+"
size = None

files = [app]
symlinks = {"Aplicaciones": "/Applications"}
icon = defines["icon"]  # noqa: F821

background = defines["background"]  # noqa: F821
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"

# 660x440 de contenido; Finder suma la barra de título por su cuenta.
window_rect = ((200, 160), (660, 440))
icon_size = 104
text_size = 12
arrange_by = None
label_pos = "bottom"

# Deben coincidir con la flecha que dibuja Tools/dmgbackground.swift.
icon_locations = {
    app_name: (170, 200),
    "Aplicaciones": (490, 200),
}
