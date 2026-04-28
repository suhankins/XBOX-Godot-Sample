@tool
extends EditorPlugin
## GDK Packaging Editor Plugin — adds a toolbar dropdown menu and dock panel
## for Microsoft GDK PC packaging tools (makepkg, GameConfigEditor).

const PackagingPanel = preload("res://addons/godot_gdk_packaging/editor/packaging_panel.gd")
const GDKToolchainScript = preload("res://addons/godot_gdk_packaging/editor/gdk_toolchain.gd")
const GameConfigManagerScript = preload("res://addons/godot_gdk_packaging/editor/game_config_manager.gd")

# Documentation URLs
const DOC_PC_PACKAGING := "https://learn.microsoft.com/en-us/gaming/gdk/_content/gc/packaging/pc/pc-packaging-getting-started"
const DOC_MAKEPKG := "https://learn.microsoft.com/en-us/gaming/gdk/_content/gc/packaging/deployment/makepkg-package-creation"
const DOC_GAME_CONFIG_EDITOR := "https://learn.microsoft.com/en-us/gaming/gdk/_content/gc/system/overviews/game-config-editor"

var _menu_button: MenuButton
var _packaging_panel: Control
var _toolchain: RefCounted
var _config_mgr: RefCounted

# Menu item IDs
enum MenuID {
	CREATE_PACKAGE,
	GENERATE_MAP,
	VALIDATE,
	SEP_1,
	EDIT_CONFIG,
	CREATE_CONFIG,
	SEP_2,
	DOC_PACKAGING,
	DOC_MAKEPKG,
	DOC_CONFIG_EDITOR,
}


func _enter_tree() -> void:
	_toolchain = GDKToolchainScript.new()
	_config_mgr = GameConfigManagerScript.new(_toolchain)

	# ── Toolbar dropdown menu ──
	_menu_button = MenuButton.new()
	_menu_button.text = "GDK Packaging"
	_menu_button.tooltip_text = "Microsoft GDK PC Packaging Tools"

	var popup := _menu_button.get_popup()
	popup.add_item("Create MSIXVC Package...", MenuID.CREATE_PACKAGE)
	popup.add_item("Generate Mapping File...", MenuID.GENERATE_MAP)
	popup.add_item("Validate Package...", MenuID.VALIDATE)
	popup.add_separator("", MenuID.SEP_1)
	popup.add_item("Edit MicrosoftGame.config", MenuID.EDIT_CONFIG)
	popup.add_item("Create MicrosoftGame.config", MenuID.CREATE_CONFIG)
	popup.add_separator("", MenuID.SEP_2)
	popup.add_item("📖 PC Packaging Overview", MenuID.DOC_PACKAGING)
	popup.add_item("📖 makepkg Reference", MenuID.DOC_MAKEPKG)
	popup.add_item("📖 GameConfigEditor Reference", MenuID.DOC_CONFIG_EDITOR)
	popup.id_pressed.connect(_on_menu_item_pressed)

	add_control_to_container(CONTAINER_TOOLBAR, _menu_button)

	# ── Packaging dock panel ──
	_packaging_panel = PackagingPanel.new()
	_packaging_panel.name = "GDK Packaging"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _packaging_panel)

	if not _toolchain.is_gdk_available():
		push_warning("[GDK Packaging] Microsoft GDK not detected — packaging tools unavailable.")

	print("[GDK Packaging] Editor plugin loaded")


func _exit_tree() -> void:
	if _packaging_panel:
		remove_control_from_docks(_packaging_panel)
		_packaging_panel.queue_free()
		_packaging_panel = null

	if _menu_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _menu_button)
		_menu_button.queue_free()
		_menu_button = null

	_toolchain = null
	_config_mgr = null
	print("[GDK Packaging] Editor plugin unloaded")


func _on_menu_item_pressed(id: int) -> void:
	match id:
		MenuID.CREATE_PACKAGE:
			# Focus the packaging panel — user clicks "Create Package" there
			_focus_packaging_panel()

		MenuID.GENERATE_MAP:
			_focus_packaging_panel()

		MenuID.VALIDATE:
			_focus_packaging_panel()

		MenuID.EDIT_CONFIG:
			if _config_mgr.config_exists():
				_config_mgr.launch_editor()
			else:
				push_warning("[GDK Packaging] MicrosoftGame.config not found — create one first.")

		MenuID.CREATE_CONFIG:
			var err = _config_mgr.create_template()
			if err == OK:
				print("[GDK Packaging] Created template MicrosoftGame.config")
			elif err == ERR_ALREADY_EXISTS:
				push_warning("[GDK Packaging] MicrosoftGame.config already exists.")

		MenuID.DOC_PACKAGING:
			OS.shell_open(DOC_PC_PACKAGING)

		MenuID.DOC_MAKEPKG:
			OS.shell_open(DOC_MAKEPKG)

		MenuID.DOC_CONFIG_EDITOR:
			OS.shell_open(DOC_GAME_CONFIG_EDITOR)


func _focus_packaging_panel() -> void:
	if _packaging_panel:
		# Make the dock visible and bring it to focus
		_packaging_panel.visible = true
		_packaging_panel.grab_focus()
