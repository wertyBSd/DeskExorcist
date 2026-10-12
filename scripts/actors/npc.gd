class_name NPCDialog
## A barricaded survivor (Level Design.MD section 7).
##
## Sits inside a trigger sphere; when the player walks in it pushes a one-line
## story beat to the HUD, and clears it on the way out.  Purely cosmetic -- it
## has no collision on the physics layers the player or demons care about.

extends Area3D

const LINES := [
	"They crawled right out of the coffee machine!",
	"The boss turned into a water cooler...",
	"Don't touch the paperwork, it bites!",
	"HR approved the summoning ritual. Of course they did.",
	"I'm not leaving until the copier stops screaming.",
]

var line := ""

func _ready() -> void:
	add_to_group("npc")
	line = LINES[randi() % LINES.size()]
	collision_layer = 0
	collision_mask = 1          # only the player triggers the dialog
	monitoring = true

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 3.0
	shape.shape = sphere
	add_child(shape)

	# Prefer a dedicated survivor .glb when the asset pipeline provides one;
	# otherwise fall back to the code-built silhouette below (never the reused
	# hero model, whose T-pose read as "a monster with its arms out").
	if ModelLibrary.has_model(ModelLibrary.NPC):
		ModelLibrary.attach(self, ModelLibrary.NPC, 1.7)
	else:
		_build_survivor_mesh()

## A calm, clearly-human survivor: arms at the sides, distinct palette, so NPCs
## are never mistaken for demons (GDD Level Design: barricaded survivors).
func _build_survivor_mesh() -> void:
	var skin := _mat(Color("#e8b98c"))
	var shirt := _mat(Color("#8f9bb3"))
	var vest := _mat(Color("#c8d2e6"))
	var legs := _mat(Color("#3b4055"))
	_add_box("LegL", Vector3(-0.11, 0.42, 0.0), Vector3(0.15, 0.84, 0.15), legs)
	_add_box("LegR", Vector3(0.11, 0.42, 0.0), Vector3(0.15, 0.84, 0.15), legs)
	_add_box("Torso", Vector3(0.0, 1.12, 0.0), Vector3(0.44, 0.56, 0.26), shirt)
	_add_box("Vest", Vector3(0.0, 1.12, -0.14), Vector3(0.40, 0.50, 0.04), vest)
	# Arms hang down at the sides (the crucial difference from the hero T-pose).
	_add_box("ArmL", Vector3(-0.30, 1.06, 0.0), Vector3(0.13, 0.62, 0.13), shirt)
	_add_box("ArmR", Vector3(0.30, 1.06, 0.0), Vector3(0.13, 0.62, 0.13), shirt)
	_add_box("Head", Vector3(0.0, 1.60, 0.0), Vector3(0.26, 0.28, 0.28), skin)

func _mat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 0.9
	return m

func _add_box(node_name: String, pos: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = material
	add_child(mesh)

	if not body_entered.is_connected(_on_entered):
		body_entered.connect(_on_entered)
	if not body_exited.is_connected(_on_exited):
		body_exited.connect(_on_exited)

func _on_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("hud", "show_dialog", line)

func _on_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("hud", "clear_dialog")
