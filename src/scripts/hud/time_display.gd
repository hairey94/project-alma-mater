extends RefCounted
class_name TimeDisplay

var time_date_label: RichTextLabel
var season_label: Label
var days_left_label: Label

func setup(time: RichTextLabel, season: Label, days: Label) -> void:
	time_date_label = time
	season_label = season
	days_left_label = days

func on_time_tick(hour: int, minute: int, day: int, month: String, year: int, season_index: int) -> void:
	if time_date_label:
		time_date_label.text = "[color=#ffffff]%d %s %d[/color]  [color=#38bdf8][%02d:%02d][/color]" % [day, month, year, hour, minute]

	if season_label:
		match season_index:
			0: season_label.text = "Autumn"
			1: season_label.text = "Spring"
			2: season_label.text = "Summer"
			3: season_label.text = "Winter"
			_: season_label.text = "Unknown Season"

	if days_left_label and is_instance_valid(TimeManager):
		var max_days = TimeManager.DAYS_IN_MONTHS[TimeManager.current_month_index]
		var remaining = (max_days - day) + 1
		var months_left = 2 - (TimeManager.current_month_index % 3)
		for m in range(1, months_left + 1):
			var idx = (TimeManager.current_month_index + m) % 12
			remaining += TimeManager.DAYS_IN_MONTHS[idx]
		days_left_label.text = "(%d Days Left)" % remaining
