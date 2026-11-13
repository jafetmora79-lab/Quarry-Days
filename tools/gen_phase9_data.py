#!/usr/bin/env python3
"""Phase 9.1: the 12-stage progression, the unlock table and the re-gated tool ladder, written into data/progression.json."""
import json
P='data/progression.json'
d=json.load(open(P))
S=lambda i,t,g,req,unl: {"id":i,"title":t,"goal":g,"req":req,"unlocks":unl}
d['stages']=[
 S("grandpa","Grandpa's Legacy","Break stone with Grandpa's hammer, clear the overgrown site and sell what you cut.",{},["Rock Hammer"]),
 S("better_tools","Better Tools","Earn $150, clear the site, get Grandpa's excavator running and haul away the first soil. Then buy better hand tools at the workbench.",{"earned":150,"milestones":["cleanup_done","excavator_running","soil_hauled"]},["Pointed Chisel","Worn Pickaxe","Flat Chisel","Hand Cart","Repaired Pickaxe"]),
 S("workshop","The Workshop","Earn $600 and own a pickaxe. The workshop sells heavier, more specialised tools.",{"earned":600,"owns":["pickaxe"]},["Reinforced Pickaxe","Sledgehammer","Steel Pickaxe","Reinforced Wheelbarrow","Workshop upgrades"]),
 S("breaking_ground","Breaking Ground","Earn $1,800 and make a workbench upgrade. Start processing stone.",{"earned":1800,"owns":["reinforced"],"milestones":["workshop_upgrade"]},["Hardened Pickaxe","Hand Rock Splitter","Stone Crusher","Output Storage"]),
 S("first_employee","First Employee","Earn $4,000, find iron and run a crusher. Then you can hire help.",{"earned":4000,"discover":["iron_ore"],"milestones":["crusher_built"]},["Hire workers","Conveyors","Employee improvements"]),
 S("power_pressure","Power and Pressure","Earn $9,000, hire a worker and sell crushed stone. Powered tools come next.",{"earned":9000,"employees":1,"delivered":{"crushed_stone":30}},["Powered Hammer","Air Compressor","Corded Rock Drill","Pneumatic Chisel","Front Loader"]),
 S("moving_mountains","Moving Mountains","Earn $20,000, own a crusher and open the first bench of the quarry.",{"earned":20000,"crushers":1,"quarry_level":2},["Drilling Rig","Dump Truck","Excavator"]),
 S("industrial_quarry","Industrial Quarry","Earn $45,000 and keep the first bench open. (Further industrial equipment arrives in a later update.)",{"earned":45000,"quarry_level":2},["Existing industrial machines"]),
 S("deeper_ground","Deeper Ground","Earn $100,000 and open the third level.",{"earned":100000,"quarry_level":3},["Excavation permit","Industrial truck","Rock breakers"]),
 S("mass_production","Mass Production","Earn $250,000. (Future content.)",{"earned":250000,"quarry_level":3},[]),
 S("beneath_mountain","Beneath the Mountain","Earn $600,000 and reach the lowest level. (Future content.)",{"earned":600000,"quarry_level":4},[]),
 S("quarry_empire","Quarry Empire","Earn $1,500,000. (Future content.)",{"earned":1500000,"quarry_level":4},[]),
]
PRICE_MULT=[0.22,0.10,0.12,0.13,0.15,0.4,1.0,1.0,1.0,1.0,1.0,1.0]
for i,stg in enumerate(d['stages']):
    stg['price_mult']=PRICE_MULT[i]
d['legacy_stage_ids']={"manual":"grandpa","tools":"better_tools","crew":"first_employee","industry":"power_pressure","large":"moving_mountains","deep":"deeper_ground"}
d['legacy_stage_map']=[0,1,4,5,6,8]
d['legacy_stage_map_comment']="Phase 9.1: an old six-stage save lands on the new stage that unlocks everything it already had (manual, tools, crew->first_employee, industry->power_pressure, large->moving_mountains, deep->deeper_ground). Never lower."
d['feature_gates']={"hire":"first_employee","crusher":"breaking_ground","output":"breaking_ground","loader":"power_pressure","truck":"moving_mountains","permit":"deeper_ground","hopper":"first_employee","sorter":"breaking_ground"}
d['vehicle_gates']={"loader":"power_pressure","compact_truck":"power_pressure","truck":"moving_mountains","heavy_truck":"moving_mountains","industrial_truck":"deeper_ground","compact_excavator":"moving_mountains","heavy_excavator":"deeper_ground"}
# machines carried a numeric old stage index: re-base on the new ids
rebase={4:"moving_mountains",5:"deeper_ground"}
for k,m in d['machines'].items():
    if isinstance(m.get('stage'),int) and k!='advanced_crusher':
        m['stage_id']=rebase.get(m['stage'],"moving_mountains"); 
    elif k=='advanced_crusher':
        m['stage_id']="moving_mountains"
# tool ladder: same five tools (saves keep their tier), new prices, titles and gates
T={t['id']:t for t in d['tools']}
T['pickaxe'].update(title="Worn Pickaxe",cost=90,desc="Worn but sound. Bites into stone and can crack iron.")
T['reinforced'].update(cost=350)
T['drill'].update(title="Corded Rock Drill",cost=4500,desc="Hold to drill. Needs a corded supply. Cuts copper veins.")
T['jackhammer'].update(title="Heavy Jackhammer",cost=14000)
d['unlocks']={
 "pickaxe":{"stage":"better_tools"},
 "reinforced":{"stage":"workshop"},
 "drill":{"stage":"power_pressure","owns":["reinforced"],"discover":["iron_ore"],"delivered":{"iron_ore":10}},
 "jackhammer":{"stage":"industrial_quarry","owns":["drill"],"discover":["copper_ore"]},
}
d['unlocks_comment']="Phase 9.1 hybrid unlocks: every entry lists what must be true BEFORE the item can be bought (money is the item's price). stage = a stage id; owns = tools/equipment already owned; discover = minerals found; delivered = minerals sold; milestones = built-in or story milestones; earned; quarry_level; story = story flags."
d['milestone_titles']={"cleanup_done":"Clear Grandpa's overgrown site","workshop_upgrade":"Buy a workbench upgrade","crusher_built":"Build a crusher","excavator_running":"Repair Grandpa's excavator","soil_hauled":"Haul 24 loads of soil to the spoil heap"}
# ---- Phase 9.2: the extra tools (a precision / general / impact / continuous mix) and the hauling aids
T['drill'].update(dps=100,powered=True)
T['jackhammer'].update(dps=180,powered=True)
T['jackhammer']['desc']="Shatters anything, including gold-bearing rock."
d['unlocks']['jackhammer']={"stage":"industrial_quarry","owns":["drill"]}
G={}
def g(id,title,cost,cls,model,desc,**k):
    G[id]=dict(title=title,cost=cost,**{"class":cls},model=model,desc=desc,**k)
g("pointed_chisel","Pointed Chisel",35,"precision",0,"Fast, light taps. Cuts soft stone and coal far quicker than the hammer, but cannot touch iron.",power=2.6,interval=0.2,max_hardness=1,affinity={"limestone":1.5,"coal":1.5},sound="hit_hammer",pitch=1.4)
g("flat_chisel","Flat Chisel",110,"precision",0,"Wide, clean cuts through stone and coal: the best tool for soft rock until you can afford power.",power=3.6,interval=0.2,max_hardness=1,affinity={"limestone":1.7,"coal":1.7},sound="hit_hammer",pitch=1.25)
g("repaired_pickaxe","Repaired Pickaxe",180,"general",1,"A properly re-handled pickaxe. Solid on stone, coal and iron.",power=11.0,interval=0.54,max_hardness=2,sound="hit_pick")
g("sledgehammer","Sledgehammer",450,"impact",0,"Heavy and slow. Each blow also hits two neighbouring exposed blocks at half strength.",power=20.0,interval=0.95,max_hardness=2,aoe=2,aoe_frac=0.5,sound="hit_reinforced",pitch=0.8)
g("steel_pickaxe","Steel Pickaxe",700,"general",2,"Steel head, steady swing. Gets into copper-hard rock.",power=20.0,interval=0.5,max_hardness=3,sound="hit_reinforced")
g("hardened_pickaxe","Hardened Pickaxe",1200,"general",2,"Hardened steel: the best hand pick you can buy.",power=28.0,interval=0.48,max_hardness=3,sound="hit_reinforced",pitch=1.1)
g("hand_splitter","Hand Rock Splitter",1600,"impact",0,"Wedges and drives a seam: each blow also splits up to three neighbouring exposed blocks at 60%.",power=34.0,interval=1.0,max_hardness=3,aoe=3,aoe_frac=0.6,sound="hit_reinforced",pitch=0.7)
g("powered_hammer","Powered Hammer",2500,"impact",3,"A motor-driven hammer: quick heavy blows that also hit two neighbours.",power=30.0,interval=0.42,max_hardness=3,aoe=2,aoe_frac=0.5,powered=True,sound="hit_reinforced",pitch=0.9)
g("pneumatic_chisel","Pneumatic Chisel",6500,"precision",4,"Hold to chisel at speed. Superb on stone and coal. Needs the compressor.",dps=90,continuous=True,max_hardness=3,affinity={"limestone":1.6,"coal":1.6},powered=True,sound="jackhammer_loop")
g("air_compressor","Air Compressor",3500,"equipment",3,"Powers the pneumatic tools: every powered tool you hold works 15% faster.",kind="equipment",power_mult=1.15)
g("hand_cart","Hand Cart",120,"cart",0,"Wheel your load: the bag holds 20 more.",kind="cart",capacity=20)
g("wheelbarrow","Wheelbarrow",280,"cart",0,"A proper barrow: the bag holds 40 more.",kind="cart",capacity=40)
g("reinforced_wheelbarrow","Reinforced Wheelbarrow",750,"cart",0,"Steel tray, pneumatic tyre: the bag holds 70 more.",kind="cart",capacity=70)
d['gear']=G
d['gear_comment']="Phase 9.2: extra tools and hauling aids beyond the five-tool ladder (saves keep their tier). class: precision / general / impact / equipment / cart. affinity = damage multiplier per mineral; aoe = neighbouring exposed blocks hit at aoe_frac; powered = gets the compressor bonus; model = the ladder tool whose existing 3D model is shown (no unique models yet)."
U=d['unlocks']
U.update({"pointed_chisel":{"stage":"better_tools"},"flat_chisel":{"stage":"better_tools","owns":["pointed_chisel"]},"repaired_pickaxe":{"stage":"better_tools","owns":["pickaxe"]},
 "hand_cart":{"stage":"better_tools"},"sledgehammer":{"stage":"workshop","owns":["pickaxe"]},"steel_pickaxe":{"stage":"workshop","owns":["reinforced"]},
 "wheelbarrow":{"stage":"workshop","owns":["hand_cart"]},"reinforced_wheelbarrow":{"stage":"workshop","owns":["wheelbarrow"]},
 "hardened_pickaxe":{"stage":"breaking_ground","owns":["steel_pickaxe"]},"hand_splitter":{"stage":"breaking_ground","owns":["sledgehammer"]},
 "powered_hammer":{"stage":"power_pressure","owns":["hand_splitter"]},"air_compressor":{"stage":"power_pressure","owns":["hardened_pickaxe"]},
 "pneumatic_chisel":{"stage":"power_pressure","owns":["air_compressor","drill"]}})
U['drill']['owns']=["reinforced","steel_pickaxe"]
json.dump(d,open(P,'w'),indent=1)
e=json.load(open('data/economy.json'))
e['crusher_price']=2200
e['cart_capacity']={k:v['capacity'] for k,v in G.items() if v.get('kind')=='cart'}
json.dump(e,open('data/economy.json','w'),indent=2)

b=json.load(open('data/business.json'))
b['conveyor_price']=450
b['wage_scale']=3.0
b.update({"hopper_price":1000,"hopper_capacity":60,"sorter_price":200,"sorter_capacity":36,"sort_batch":10,"sort_seconds":6.0,"sort_bonus":1.3})
json.dump(b,open('data/business.json','w'),indent=2)

# ---- Phase 9.3: tougher rock for hand tools. Rock hit points x3; every machine, rig, excavator and hired miner is scaled x3 too,
# so late-game output is exactly what it was; only hand mining (and so the first hours) is slower.
d=json.load(open(P))
HP_SCALE=3
for k,hp in {"limestone":30,"coal":42,"iron_ore":66,"copper_ore":102,"gold_ore":150}.items():
    d['materials'][k]['hp']=hp
for k,dps in {"drill_rig":78.0,"improved_rig":144.0,"rock_breaker":270.0,"heavy_breaker":600.0}.items():
    d['machines'][k]['dps']=dps
d['worker_tool']['damage']=27.0
json.dump(d,open(P,'w'),indent=1)
vv=json.load(open('data/vehicles.json'))
vv['vehicles']['compact_excavator']['dig_dps']=60.0
vv['vehicles']['heavy_excavator']['dig_dps']=255.0
json.dump(vv,open('data/vehicles.json','w'),indent=2)
