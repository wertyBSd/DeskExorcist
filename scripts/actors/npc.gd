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

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	mesh.mesh = capsule
	mesh.position = Vector3(0.0, 0.8, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#e8b98c")
	mat.emission_enabled = true
	mat.emission = Color("#6b4a6f")
	mat.emission_energy_multiplier = 0.3
	mesh.material_override = mat
	add_child(mesh)
	# Survivors reuse the exorcist silhouette until a dedicated NPC model exists.
	if ModelLibrary.attach(self, ModelLibrary.EXORCIST, 1.7) != null:
		mesh.visible = false

	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)

func _on_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("hud", "show_dialog", line)

func _on_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		get_tree().call_group("hud", "clear_dialog")
