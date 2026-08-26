#!/usr/bin/env python3
"""Generate CrealityPrint 7.x (Orca-format) profiles for the Creality CR-200B.

Source of truth: the CR-200B definitions Creality shipped in Creality Print 4.3.8
(Cura-format: resources/sliceconfig/default/{Machines,Extruders,Materials}), which
is the last release that supported this printer (GitHub issue #424).

Donor for the 7.x schema: Creality Ender-3 V2 0.4 nozzle -- the closest system
profile mechanically (i3 bedslinger, Bowden, Marlin) and numerically (identical
machine_max_* limits, identical purge-line geometry).
"""
import json, os, sys, collections

PROFILES = sys.argv[1]          # .../resources/profiles
C = os.path.join(PROFILES, "Creality")
DONOR = "Creality Ender-3 V2 0.4 nozzle"
NEW   = "Creality CR-200B 0.4 nozzle"
MODEL = "Creality CR-200B"

def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=collections.OrderedDict)

def save(p, obj):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(obj, f, indent=4, ensure_ascii=False)
        f.write("\n")

# ---------------------------------------------------------------- machine model
model = load(f"{C}/machine/Creality Ender-3 V2.json")
model.update({
    "name": MODEL,
    "nozzle_diameter": "0.4",
    "bed_model": "",
    "bed_texture": "",
    "default_bed_type": "Cool Plate",
    "model_id": "Creality_CR_200B",
    "default_materials": "Generic PLA;Generic PETG;Generic ABS",
})
save(f"{C}/machine/{MODEL}.json", model)

# ---------------------------------------------------------------------- machine
# 4.3.8 CR-200B.default, verbatim:
#   machine_width/depth/height = 200/200/200, rectangle, origin at corner
#   machine_extruder_type=Distal (Bowden), heated bed, 1 extruder, 0.4 nozzle
#   max feedrate x/y/z/e = 500/500/10/50 ; jerk xy/z/e = 10/0.4/5
#   max accel x/y/z/e = 500/500/100/5000
#   LED light present, platform motion, chamber fan present (unheated enclosure)
# Extruders/CR-200B/extruder_0_0.4.default:
#   retraction_amount=4, retraction_speed=retract=prime=40
START_GCODE = (
    "M220 S100 ;Reset Feedrate\n"
    "M221 S100 ;Reset Flowrate\n"
    "\n"
    "M140 S[bed_temperature_initial_layer_single] ;Set bed temp\n"
    "G28 ;Home\n"
    "G92 E0 ;Reset Extruder\n"
    "G1 Z2.0 F3000 ;Move Z Axis up\n"
    "M104 S[nozzle_temperature_initial_layer] ;Set nozzle temp\n"
    "G1 X10.1 Y20 Z0.28 F5000.0 ;Move to start position\n"
    "M190 S[bed_temperature_initial_layer_single] ;Wait for bed temp\n"
    "M109 S[nozzle_temperature_initial_layer] ;Wait for nozzle temp\n"
    "G1 X10.1 Y145.0 Z0.28 F1500.0 E15 ;Draw the first line\n"
    "G1 X10.4 Y145.0 Z0.28 F5000.0 ;Move to side a little\n"
    "G1 X10.4 Y20 Z0.28 F1500.0 E30 ;Draw the second line\n"
    "G92 E0 ;Reset Extruder\n"
    "G1 E-1.0000 F1800 ;Retract a bit\n"
    "G1 Z2.0 F3000 ;Move Z Axis up\n"
    "G1 E0.0000 F1800"
)
END_GCODE = (
    "G91 ;Relative positionning\n"
    "G1 E-2 F2700 ;Retract a bit\n"
    "G1 E-2 Z0.2 F2400 ;Retract and raise Z\n"
    "G1 X5 Y5 F3000 ;Wipe out\n"
    "G1 Z10 ;Raise Z more\n"
    "G90 ;Absolute positionning\n"
    "G1 X0 Y0 ;Present print\n"
    "M106 S0 ;Turn-off fan\n"
    "M104 S0 ;Turn-off hotend\n"
    "M140 S0 ;Turn-off bed\n"
    "M84 X Y E ;Disable all steppers but Z"
)

m = load(f"{C}/machine/{DONOR}.json")
m.update({
    "name": NEW,
    "setting_id": "CR200B0400",
    "printer_model": MODEL,
    "printer_structure": "i3",
    "printer_variant": "0.4",
    "nozzle_diameter": ["0.4"],
    "printable_area": "0x0,200x0,200x200,0x200",
    "printable_height": "200",
    "machine_start_gcode": START_GCODE,
    "machine_end_gcode": END_GCODE,
    "machine_max_acceleration_z": "100,100",
    "machine_LED_light_exist": "1",
    "machine_platform_motion_enable": "1",
    "retraction_length": "4",
    "retraction_speed": "40",
    "deretraction_speed": "40",
    "default_print_profile": f"0.20mm Standard @{NEW}",
    "default_filament_profile": [f"Generic PLA @{NEW}"],
})
save(f"{C}/machine/{NEW}.json", m)

# --------------------------------------------------------------------- processes
processes = []
for q in ("0.08mm Extra Fine", "0.16mm Optimal", "0.20mm Standard"):
    p = load(f"{C}/process/{q} @{DONOR}.json")
    p["name"] = f"{q} @{NEW}"
    p["compatible_printers"] = [NEW]
    save(f"{C}/process/{q} @{NEW}.json", p)
    processes.append(p["name"])

# --------------------------------------------------------------------- filaments
# Temps/fan/volumetric limits carried over from 4.3.8 Materials/CR-200B/*.default
FILAMENTS = [
    # (donor,                    new name,      bed, nozzle, max_vol, fan_min, fan_max, PA,     PA_on)
    (f"CR-PLA @{DONOR}",         "Generic PLA",  50,  210,    18,      50,      100,     0.04,  "0"),
    (f"Generic ABS @{DONOR}",    "Generic ABS", 100,  260,     9,      70,       70,     0.045, "1"),
    (f"CR-PETG @{DONOR}",        "Generic PETG", 70,  250,     9,     100,      100,     0.055, "1"),
]
PLATES = ("cool_plate_temp", "eng_plate_temp", "hot_plate_temp",
          "textured_plate_temp", "customized_plate_temp")

filaments = []
for donor, base, bed, noz, vol, fmin, fmax, pa, pa_on in FILAMENTS:
    fj = load(f"{C}/filament/{donor}.json")
    name = f"{base} @{NEW}"
    fj["name"] = name
    fj["compatible_printers"] = [NEW]
    fj["filament_vendor"] = ["Generic"]
    fj["nozzle_temperature"] = str(noz)
    fj["nozzle_temperature_initial_layer"] = str(noz)
    for plate in PLATES:
        fj[plate] = str(bed)
        fj[plate + "_initial_layer"] = str(bed)
    fj["filament_max_volumetric_speed"] = str(vol)
    fj["fan_min_speed"] = str(fmin)
    fj["fan_max_speed"] = str(fmax)
    fj["pressure_advance"] = str(pa)
    fj["enable_pressure_advance"] = pa_on
    fj["filament_diameter"] = "1.75"
    fj["filament_density"] = "1.24"
    save(f"{C}/filament/{name}.json", fj)
    filaments.append(name)

# ------------------------------------------------------------ register in vendor
vp = f"{PROFILES}/Creality.json"
v = load(vp)

def add(key, name, sub):
    lst = v[key]
    if any(e.get("name") == name for e in lst):
        lst[:] = [e for e in lst if e.get("name") != name]
    lst.append(collections.OrderedDict([("name", name), ("sub_path", sub)]))

add("machine_model_list", MODEL, f"machine/{MODEL}.json")
add("machine_list", NEW, f"machine/{NEW}.json")
for n in processes:
    add("process_list", n, f"process/{n}.json")
for n in filaments:
    add("filament_list", n, f"filament/{n}.json")
save(vp, v)

print(f"machine_model : {MODEL}")
print(f"machine       : {NEW}")
for n in processes: print(f"process       : {n}")
for n in filaments: print(f"filament      : {n}")
