extends Node

# Centralized Project Catalogue Configuration Matrix
# --- NORMALIZED DATABASE MODEL MATRIX ---
const BUILDING_DATABASE = {
	"services": {
		"utilities": {
			"sheet_path": "res://assets/ui/facilities_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "Utilities",
			"items": [
				{"name": "Water Tower", "region": Rect2(1 * 64, 0 * 64, 64, 64), "cost": 5000},
				{"name": "Sewage Treatment Plant", "region": Rect2(2 * 64, 0 * 64, 64, 64), "cost": 2000},
				{"name": "Electric Substation", "region": Rect2(3 * 64, 0 * 64, 64, 64), "cost": 2000},
				{"name": "Telecommunication Tower", "region": Rect2(4 * 64, 0 * 64, 64, 64), "cost": 2000}
			]
		}
	},
	"building": {
		"block": {
			"sheet_path": "res://assets/ui/building_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "Building Block",
			"items": [
				{"name": "Campus block", "region": Rect2(1 * 64, 0 * 64, 64, 64), "cost": 5000}
			]
		}
	},
	"facilities": {
		"general": {
			"sheet_path": "res://assets/ui/facilities_spritesheet.svg",
			"tab_icon_region": Rect2(5 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "General Campus Facilities",
			"items": [
				{"name": "Front Gate", "region": Rect2(6 * 64, 0 * 64, 64, 64), "cost": 20000},
				{"name": "Security Guard House", "region": Rect2(7 * 64, 0 * 64, 64, 64), "cost": 15000},
				{"name": "Outdoor Assembly Area", "region": Rect2(0 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Assembly Hall", "region": Rect2(1 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "All Faith Center", "region": Rect2(2 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Internal Road", "region": Rect2(3 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Walkway", "region": Rect2(4 * 64, 1 * 64, 64, 64), "cost": 20000}
			]
		},
		"sports": {
			"sheet_path": "res://assets/ui/facilities_spritesheet.svg",
			"tab_icon_region": Rect2(5 * 64, 1 * 64, 64, 64), # Fixed typo multiplier box
			"tab_tooltip": "Sports and Recreations",
			"items": [
				{"name": "Soccer Field", "region": Rect2(6 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Tennis Court", "region": Rect2(7 * 64, 1 * 64, 64, 64), "cost": 15000},
				{"name": "Basketball Court", "region": Rect2(0 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Baseball Park", "region": Rect2(1 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Sprint Track", "region": Rect2(2 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Stadium Arena", "region": Rect2(3 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Indoor Gymnasium", "region": Rect2(4 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Jogging Track", "region": Rect2(5 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Swimming Pool", "region": Rect2(6 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Picnic Park", "region": Rect2(7 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Playground", "region": Rect2(0 * 64, 3 * 64, 64, 64), "cost": 20000}
			]
		},
		"parking": {
			"sheet_path": "res://assets/ui/facilities_spritesheet.svg",
			"tab_icon_region": Rect2(1 * 64, 3 * 64, 64, 64),
			"tab_tooltip": "Transit and Parking",
			"items": [
				{"name": "Bus Stop", "region": Rect2(2 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Bus Parking Garage", "region": Rect2(3 * 64, 3 * 64, 64, 64), "cost": 15000},
				{"name": "Car Parking Space", "region": Rect2(4 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Motorcycle Parking Space", "region": Rect2(5 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Bicycle Parking Shed", "region": Rect2(6 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "EV Car Parking Space with Charging Station", "region": Rect2(7 * 64, 3 * 64, 64, 64), "cost": 20000}
			]
		}
	},
	"residential": {
		"housing": {
			"sheet_path": "res://assets/ui/residential_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "residential and housing",
			"items": [
				{"name": "Male Students Residential", "region": Rect2(1 * 64, 0 * 64, 64, 64), "cost": 5000},
				{"name": "Female Students Residential", "region": Rect2(2 * 64, 0 * 64, 64, 64), "cost": 2000},
				{"name": "Teachers and Staffs Apartments", "region": Rect2(3 * 64, 0 * 64, 64, 64), "cost": 2000},
				{"name": "Principal Villa", "region": Rect2(4 * 64, 0 * 64, 64, 64), "cost": 2000},
				{"name": "Vice-Principal Town House", "region": Rect2(5 * 64, 0 * 64, 64, 64), "cost": 2000},
				{"name": "Residential Advisor House", "region": Rect2(6 * 64, 0 * 64, 64, 64), "cost": 2000}
			]
		}
	},
	"rooms": {
		"general": {
			"sheet_path": "res://assets/ui/room_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "General Education",
			"items": [
				{"name": "Classroom", "region": Rect2(1 * 64, 0 * 64, 64, 64), "cost": 20000},
				{"name": "Library", "region": Rect2(2 * 64, 0 * 64, 64, 64), "cost": 15000},
				{"name": "Student Lounge", "region": Rect2(3 * 64, 0 * 64, 64, 64), "cost": 20000},
				{"name": "Student Council Room", "region": Rect2(4 * 64, 0 * 64, 64, 64), "cost": 20000},
				{"name": "Self-Study Room", "region": Rect2(5 * 64, 0 * 64, 64, 64), "cost": 20000},
				{"name": "Examination Hall", "region": Rect2(6 * 64, 0 * 64, 64, 64), "cost": 20000},
				{"name": "Mock Interview Room", "region": Rect2(7 * 64, 0 * 64, 64, 64), "cost": 20000},
				{"name": "Textbook Store", "region": Rect2(8 * 64, 0 * 64, 64, 64), "cost": 20000},
				{"name": "Auditorium Hall", "region": Rect2(9 * 64, 0 * 64, 64, 64), "cost": 20000},
			]
		},
		"admin": {
			"sheet_path": "res://assets/ui/room_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 1 * 64, 64, 64),
			"tab_tooltip": "Administration",
			"items": [
				{"name": "Administration Area", "region": Rect2(1 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Principal Office", "region": Rect2(2 * 64, 1 * 64, 64, 64), "cost": 15000},
				{"name": "Vice-Principal Office", "region": Rect2(3 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Admin Assistant Office", "region": Rect2(4 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Department Office", "region": Rect2(5 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Head of Department Office", "region": Rect2(6 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Media Teacher Office", "region": Rect2(7 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Staff Break Room", "region": Rect2(8 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Dormitory Staff Office", "region": Rect2(9 * 64, 1 * 64, 64, 64), "cost": 20000},
				{"name": "Counselor Office", "region": Rect2(1 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Librarian Office", "region": Rect2(2 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Examination Secretary Office", "region": Rect2(3 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Safebox Room", "region": Rect2(4 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Janitor Room", "region": Rect2(5 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Maintenance Office", "region": Rect2(6 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Technician Office", "region": Rect2(7 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Meeting Room", "region": Rect2(8 * 64, 2 * 64, 64, 64), "cost": 20000},
				{"name": "Conference Room", "region": Rect2(9 * 64, 2 * 64, 64, 64), "cost": 20000},
			]
		},
		"stem": {
			"sheet_path": "res://assets/ui/room_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 3 * 64, 64, 64),
			"tab_tooltip": "Science, Technology, Engineering, Mathematics",
			"items": [
				{"name": "General Science Lab", "region": Rect2(1 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Physics Lab", "region": Rect2(2 * 64, 3 * 64, 64, 64), "cost": 15000},
				{"name": "Chemistry Lab", "region": Rect2(3 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Biology Lab", "region": Rect2(4 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Woodmaking Workshop", "region": Rect2(5 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Engine Workshop", "region": Rect2(6 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "HVAC Workshop", "region": Rect2(7 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Electric Workshop", "region": Rect2(8 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Electronic Lab", "region": Rect2(9 * 64, 3 * 64, 64, 64), "cost": 20000},
				{"name": "Lab Equipment Store", "region": Rect2(1 * 64, 4 * 64, 64, 64), "cost": 20000},
				{"name": "Chemicals Store", "region": Rect2(2 * 64, 4 * 64, 64, 64), "cost": 20000},
				{"name": "Lab Preparation Room", "region": Rect2(3 * 64, 4 * 64, 64, 64), "cost": 20000},
				{"name": "Workshop Tools Store", "region": Rect2(4 * 64, 4 * 64, 64, 64), "cost": 20000},
				{"name": "Computer Lab", "region": Rect2(5 * 64, 4 * 64, 64, 64), "cost": 20000},
			]
		},
		"social sciences": {
			"sheet_path": "res://assets/ui/room_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 5 * 64, 64, 64),
			"tab_tooltip": "Humanities, Sports, Arts and Music",
			"items": [
				{"name": "Home Economics Lab", "region": Rect2(1 * 64, 5 * 64, 64, 64), "cost": 20000},
				{"name": "Fine Art Studio", "region": Rect2(2 * 64, 5 * 64, 64, 64), "cost": 15000},
				{"name": "Digital Art Studio", "region": Rect2(3 * 64, 5 * 64, 64, 64), "cost": 20000},
				{"name": "Sculpture Studio", "region": Rect2(4 * 64, 5 * 64, 64, 64), "cost": 20000},
				{"name": "Music Room", "region": Rect2(5 * 64, 5 * 64, 64, 64), "cost": 20000},
				{"name": "Piano Room", "region": Rect2(6 * 64, 5 * 64, 64, 64), "cost": 20000},
				{"name": "Recording Room", "region": Rect2(7 * 64, 5 * 64, 64, 64), "cost": 20000},
				{"name": "Sports Equipment Store", "region": Rect2(8 * 64, 5 * 64, 64, 64), "cost": 20000},
				{"name": "Arts Equipment Store", "region": Rect2(9 * 64, 5 * 64, 64, 64), "cost": 20000},
				{"name": "Debate Room", "region": Rect2(1 * 64, 6 * 64, 64, 64), "cost": 20000},
				{"name": "Concert Hall", "region": Rect2(2 * 64, 6 * 64, 64, 64), "cost": 20000},
				{"name": "Theater Hall", "region": Rect2(3 * 64, 6 * 64, 64, 64), "cost": 20000}
			]
		},
		"business": {
			"sheet_path": "res://assets/ui/room_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 7 * 64, 64, 64),
			"tab_tooltip": "Campus Store and Dining",
			"items": [
				{"name": "Cafeteria", "region": Rect2(1 * 64, 7 * 64, 64, 64), "cost": 20000},
				{"name": "Dining Hall", "region": Rect2(2 * 64, 7 * 64, 64, 64), "cost": 15000},
				{"name": "Bookstore", "region": Rect2(3 * 64, 7 * 64, 64, 64), "cost": 20000},
				{"name": "Convenience Store", "region": Rect2(4 * 64, 7 * 64, 64, 64), "cost": 20000}
			]
		},
		"public": {
			"sheet_path": "res://assets/ui/room_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 8 * 64, 64, 64),
			"tab_tooltip": "Campus Amenities",
			"items": [
				{"name": "Male Student Washroom", "region": Rect2(1 * 64, 8 * 64, 64, 64), "cost": 20000},
				{"name": "Female Student Washroom", "region": Rect2(2 * 64, 8 * 64, 64, 64), "cost": 15000},
				{"name": "Male Staff Washroom", "region": Rect2(3 * 64, 8 * 64, 64, 64), "cost": 20000},
				{"name": "Female Staff Washroom", "region": Rect2(4 * 64, 8 * 64, 64, 64), "cost": 20000},
				{"name": "Male Changing Room", "region": Rect2(5 * 64, 8 * 64, 64, 64), "cost": 20000},
				{"name": "Female Changing Room", "region": Rect2(6 * 64, 8 * 64, 64, 64), "cost": 20000},
				{"name": "Male Shower Room", "region": Rect2(7 * 64, 8 * 64, 64, 64), "cost": 20000},
				{"name": "Female Shower Room", "region": Rect2(8 * 64, 8 * 64, 64, 64), "cost": 20000},
				{"name": "Laundry Room", "region": Rect2(9 * 64, 8 * 64, 64, 64), "cost": 20000},
				{"name": "Male Dormitory", "region": Rect2(1 * 64, 9 * 64, 64, 64), "cost": 20000},
				{"name": "Female Dormitory", "region": Rect2(2 * 64, 9 * 64, 64, 64), "cost": 20000},
				{"name": "Dormitory Hall", "region": Rect2(3 * 64, 9 * 64, 64, 64), "cost": 20000},
				{"name": "Commons Hall", "region": Rect2(4 * 64, 9 * 64, 64, 64), "cost": 20000},
				{"name": "Kitchen", "region": Rect2(5 * 64, 9 * 64, 64, 64), "cost": 20000},
				{"name": "Infirmary", "region": Rect2(6 * 64, 9 * 64, 64, 64), "cost": 20000},
				{"name": "Dentist Clinic", "region": Rect2(7 * 64, 9 * 64, 64, 64), "cost": 20000},
				{"name": "Sickbays", "region": Rect2(8 * 64, 9 * 64, 64, 64), "cost": 20000},
				{"name": "Student Guidance Room", "region": Rect2(9 * 64, 9 * 64, 64, 64), "cost": 20000},
			]
		}
	},
	"doors": {
		"entrance": {
			"sheet_path": "res://assets/ui/door_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "entrance",
			"items": [
				{"name": "Single Door", "region": Rect2(1 * 64, 0 * 64, 64, 64), "cost": 5000},
				{"name": "Double Door", "region": Rect2(2 * 64, 0 * 64, 64, 64), "cost": 2000},
				{"name": "Staff Only Door", "region": Rect2(3 * 64, 0 * 64, 64, 64), "cost": 2000}
			]
		}
	},
	"corridor": {
		"hallway": {
			"sheet_path": "res://assets/ui/other_spritesheet.svg",
			"tab_icon_region": Rect2(0 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "hallway",
			"items": [
				{"name": "Campus Hallway", "region": Rect2(1 * 64, 0 * 64, 64, 64), "cost": 5000}
			]
		}
	},
	"upper floor": {
		"new floor": {
			"sheet_path": "res://assets/ui/other_spritesheet.svg",
			"tab_icon_region": Rect2(2 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "new floor",
			"items": [
				{"name": "New Floor", "region": Rect2(3 * 64, 0 * 64, 64, 64), "cost": 5000}
			]
		}
	},
	"staircase": {
		"stairs": {
			"sheet_path": "res://assets/ui/other_spritesheet.svg",
			"tab_icon_region": Rect2(4 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "staircase",
			"items": [
				{"name": "New Staircase", "region": Rect2(5 * 64, 0 * 64, 64, 64), "cost": 5000}
			]
		}
	},
	"elevator": {
		"elevator": {
			"sheet_path": "res://assets/ui/other_spritesheet.svg",
			"tab_icon_region": Rect2(6 * 64, 0 * 64, 64, 64),
			"tab_tooltip": "elevator",
			"items": [
				{"name": "New Elevator", "region": Rect2(7 * 64, 0 * 64, 64, 64), "cost": 5000}
			]
		}
	}
}

static func is_room_type(item_name: String) -> bool:
	return item_name in ["Classroom", "Male Student Washroom", "Female Student Washroom", "Administration Area", "Principal Office", "Cafeteria"]

## Helper method allowing any map node script to check item pricing globally
func get_item_cost(category: String, subcategory: String, item_name: String) -> int:
	if BUILDING_DATABASE.has(category) and BUILDING_DATABASE[category].has(subcategory):
		for item in BUILDING_DATABASE[category][subcategory]["items"]:
			if item["name"] == item_name:
				return item["cost"]
	return 0
