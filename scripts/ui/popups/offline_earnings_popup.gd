class_name OfflineEarningsPopup
extends ModalCard

var earnings := 0.0
var seconds := 0.0

func _init(amount: float, elapsed: float) -> void:
	earnings = amount
	seconds = elapsed

func build() -> void:
	add_centered_label("WELCOME BACK", 26, UIStyle.TEXT_FAINT, 800)
	add_centered_label("+%s" % GameManager.format_number(earnings), 96, UIStyle.GOLD, 800)
	var pct := roundi(float(GameManager.balance.get("offline_efficiency", 0.5)) * 100.0)
	add_centered_label("Your Automatic Fingers kept tapping for %s\n(offline rate %d%%)" % [_duration(seconds), pct], 28, UIStyle.TEXT_DIM, 500)
	add_button("Collect", UIStyle.TEXT, close)

static func _duration(s: float) -> String:
	var total := int(s)
	var h := total / 3600
	var m := (total % 3600) / 60
	if h > 0:
		return "%dh %dm" % [h, m]
	if m > 0:
		return "%dm" % m
	return "%ds" % total
