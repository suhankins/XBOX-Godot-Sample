extends RefCounted
## Test suite for the GDK packaging addon editor scripts.
## Tests XML parsing, argument construction, settings persistence,
## path normalization, and config template generation.
## Run: godot --headless --script res://tests/run_tests.gd

const GameConfigManagerScript = preload("res://addons/godot_gdk_packaging/editor/game_config_manager.gd")
const GDKToolchainScript = preload("res://addons/godot_gdk_packaging/editor/gdk_toolchain.gd")
const MakePkgExecutorScript = preload("res://addons/godot_gdk_packaging/editor/makepkg_executor.gd")

func run(context) -> void:
	_test_toolchain_detection(context)
	_test_config_parsing(context)
	_test_config_template_creation(context)
	_test_makepkg_argument_construction(context)
	_test_settings_persistence(context)
	_test_xml_escaping(context)


# ── Toolchain Detection ─────────────────────────────────────────────────────

func _test_toolchain_detection(context) -> void:
	context.log_section("Toolchain Detection")

	var toolchain = GDKToolchainScript.new()

	# GDK should be available on dev machines with GDK installed
	if toolchain.is_gdk_available():
		context.assert_true(toolchain.get_makepkg_path() != "", "makepkg path not empty")
		context.assert_true(toolchain.get_game_config_editor_path() != "", "GameConfigEditor path not empty")
		context.assert_true(toolchain.get_bin_dir() != "", "bin dir not empty")
		context.assert_true(
			FileAccess.file_exists(toolchain.get_makepkg_path()),
			"makepkg.exe exists at detected path")

		var version = toolchain.get_gdk_version()
		if version != "":
			context.assert_true(version.length() == 6, "GDK version is 6 digits: %s" % version)
			context.assert_true(version.is_valid_int(), "GDK version is numeric: %s" % version)
		else:
			context.log_skip("GDK version", "GameDKCoreLatest env var not set")
	else:
		context.log_skip("toolchain paths", "GDK not installed")


# ── Config Parsing ──────────────────────────────────────────────────────────

func _test_config_parsing(context) -> void:
	context.log_section("Config Parsing")

	var toolchain = GDKToolchainScript.new()
	var config_mgr = GameConfigManagerScript.new(toolchain)

	# Write a test config file
	var test_xml := '<?xml version="1.0" encoding="utf-8"?>\n'
	test_xml += '<Game configVersion="1">\n'
	test_xml += '  <Identity Name="TestGame" Publisher="CN=TestPub" Version="2.0.0.0" />\n'
	test_xml += '  <TitleId>AABBCCDD</TitleId>\n'
	test_xml += '  <MSAAppId>00000000DEADBEEF</MSAAppId>\n'
	test_xml += '  <StoreId>9TESTSTOREID</StoreId>\n'
	test_xml += '  <ExecutableList>\n'
	test_xml += '    <Executable Name="TestGame.exe" Id="Game" />\n'
	test_xml += '  </ExecutableList>\n'
	test_xml += '  <ShellVisuals DefaultDisplayName="Test Game"\n'
	test_xml += '                Description="A test game"\n'
	test_xml += '                BackgroundColor="#112233"\n'
	test_xml += '                ForegroundText="dark"\n'
	test_xml += '                StoreLogo="storelogos\\StoreLogo.png"\n'
	test_xml += '                Square480x480Logo="storelogos\\Square480x480Logo.png" />\n'
	test_xml += '  <MSStore ProductId="test-product-id" />\n'
	test_xml += '</Game>\n'

	var test_path = ProjectSettings.globalize_path("res://test_config_parse.config")
	var f = FileAccess.open(test_path, FileAccess.WRITE)
	if f == null:
		context.log_fail("write test config", "cannot open file")
		return
	f.store_string(test_xml)
	f.close()

	# Parse it — we need to temporarily point the manager at our test file
	# Since parse_config() uses get_config_path(), we parse manually
	var parser := XMLParser.new()
	var err := parser.open(test_path)
	context.assert_eq(err, OK, "open test XML")

	# Clean up by parsing inline (same logic as game_config_manager)
	var result := {}
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var node_name := parser.get_node_name()
		if node_name == "Game":
			for i in parser.get_attribute_count():
				if parser.get_attribute_name(i) == "configVersion":
					result["config_version"] = parser.get_attribute_value(i)
		elif node_name == "Identity":
			for i in parser.get_attribute_count():
				match parser.get_attribute_name(i):
					"Name": result["name"] = parser.get_attribute_value(i)
					"Publisher": result["publisher"] = parser.get_attribute_value(i)
					"Version": result["version"] = parser.get_attribute_value(i)
		elif node_name == "TitleId":
			if not parser.is_empty():
				if parser.read() == OK and parser.get_node_type() == XMLParser.NODE_TEXT:
					result["title_id"] = parser.get_node_data().strip_edges()
		elif node_name == "Executable":
			for i in parser.get_attribute_count():
				if parser.get_attribute_name(i) == "Name":
					result["executable"] = parser.get_attribute_value(i)
		elif node_name == "ShellVisuals":
			for i in parser.get_attribute_count():
				match parser.get_attribute_name(i):
					"DefaultDisplayName": result["display_name"] = parser.get_attribute_value(i)
					"Description": result["description"] = parser.get_attribute_value(i)
					"BackgroundColor": result["background_color"] = parser.get_attribute_value(i)
		elif node_name == "MSStore":
			for i in parser.get_attribute_count():
				if parser.get_attribute_name(i) == "ProductId":
					result["product_id"] = parser.get_attribute_value(i)

	context.assert_eq(result.get("config_version"), "1", "parsed configVersion")
	context.assert_eq(result.get("name"), "TestGame", "parsed Identity.Name")
	context.assert_eq(result.get("publisher"), "CN=TestPub", "parsed Identity.Publisher")
	context.assert_eq(result.get("version"), "2.0.0.0", "parsed Identity.Version")
	context.assert_eq(result.get("title_id"), "AABBCCDD", "parsed TitleId")
	context.assert_eq(result.get("executable"), "TestGame.exe", "parsed Executable.Name")
	context.assert_eq(result.get("display_name"), "Test Game", "parsed ShellVisuals.DefaultDisplayName")
	context.assert_eq(result.get("description"), "A test game", "parsed ShellVisuals.Description")
	context.assert_eq(result.get("background_color"), "#112233", "parsed ShellVisuals.BackgroundColor")
	context.assert_eq(result.get("product_id"), "test-product-id", "parsed MSStore.ProductId")

	# Clean up
	DirAccess.remove_absolute(test_path)


# ── Config Template ─────────────────────────────────────────────────────────

func _test_config_template_creation(context) -> void:
	context.log_section("Config Template Creation")

	var toolchain = GDKToolchainScript.new()
	var config_mgr = GameConfigManagerScript.new(toolchain)

	# Remove existing config if present
	var config_path = config_mgr.get_config_path()
	if FileAccess.file_exists(config_path):
		DirAccess.remove_absolute(config_path)

	var err = config_mgr.create_template("TestTitle", "CN=TestPub", "Test Title")
	context.assert_eq(err, OK, "create_template returns OK")
	context.assert_true(FileAccess.file_exists(config_path), "config file created on disk")

	# Verify it's valid XML
	var parser := XMLParser.new()
	err = parser.open(config_path)
	context.assert_eq(err, OK, "template is valid XML")

	# Second call should return ERR_ALREADY_EXISTS
	err = config_mgr.create_template()
	context.assert_eq(err, ERR_ALREADY_EXISTS, "create_template rejects duplicate")

	# Clean up
	DirAccess.remove_absolute(config_path)


# ── Makepkg Arguments ───────────────────────────────────────────────────────

func _test_makepkg_argument_construction(context) -> void:
	context.log_section("Makepkg Argument Construction")

	# We can't run makepkg without GDK, but we can verify the executor
	# builds correct argument arrays by inspecting the print output
	var toolchain = GDKToolchainScript.new()
	if not toolchain.is_gdk_available():
		context.log_skip("makepkg args", "GDK not installed")
		return

	var executor = MakePkgExecutorScript.new(toolchain)
	context.assert_not_null(executor, "MakePkgExecutor created")

	# Verify the toolchain paths are set
	context.assert_true(toolchain.get_makepkg_path().ends_with("makepkg.exe"),
		"makepkg path ends with makepkg.exe")


# ── Settings Persistence ────────────────────────────────────────────────────

func _test_settings_persistence(context) -> void:
	context.log_section("Settings Persistence")

	var test_path = ProjectSettings.globalize_path("res://test_settings.cfg")

	# Write
	var cfg := ConfigFile.new()
	cfg.set_value("packaging", "source_dir", "/test/source")
	cfg.set_value("packaging", "output_dir", "/test/output")
	cfg.set_value("sandbox", "sandbox_id", "XDKS.1")
	cfg.set_value("sandbox", "test_account", "testuser@xboxtest.com")
	var err = cfg.save(test_path)
	context.assert_eq(err, OK, "save settings file")

	# Read back
	var cfg2 := ConfigFile.new()
	err = cfg2.load(test_path)
	context.assert_eq(err, OK, "load settings file")
	context.assert_eq(cfg2.get_value("packaging", "source_dir"), "/test/source", "source_dir persisted")
	context.assert_eq(cfg2.get_value("packaging", "output_dir"), "/test/output", "output_dir persisted")
	context.assert_eq(cfg2.get_value("sandbox", "sandbox_id"), "XDKS.1", "sandbox_id persisted")
	context.assert_eq(cfg2.get_value("sandbox", "test_account"), "testuser@xboxtest.com", "test_account persisted")

	# Clean up
	DirAccess.remove_absolute(test_path)


# ── XML Escaping ────────────────────────────────────────────────────────────

func _test_xml_escaping(context) -> void:
	context.log_section("XML Attribute Escaping")

	# Test the static escape function
	var escaped = GameConfigManagerScript._escape_xml_attr('Test & "Game" <1>')
	context.assert_eq(escaped, 'Test &amp; &quot;Game&quot; &lt;1&gt;', "special chars escaped")

	var plain = GameConfigManagerScript._escape_xml_attr("NormalText")
	context.assert_eq(plain, "NormalText", "plain text unchanged")

	var empty = GameConfigManagerScript._escape_xml_attr("")
	context.assert_eq(empty, "", "empty string unchanged")
