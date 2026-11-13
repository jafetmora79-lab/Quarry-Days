"""Original restrained, seamless Quarry Days environment tiles. Python + Pillow; no renders."""
from pathlib import Path
import random,math,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'assets/environment';OUT.mkdir(exist_ok=True)
SPECS={'Asphalt':((74,77,77),'aggregate',.5),'Gravel':((150,139,116),'gravel',.5),'Siding':((191,184,158),'siding',1),'Metal':((107,128,124),'metal',1),'Roof':((135,76,54),'metal',1),'Trim':((215,205,171),'paint',1),'Concrete':((154,151,133),'concrete',.5),'Soil':((132,108,76),'soil',.5),'Grass':((133,140,93),'soil',.5)}
for seed,(name,(base,kind,uv)) in enumerate(SPECS.items()):
 rng=random.Random(810+seed);n=256;im=Image.new('RGB',(n,n));p=im.load()
 for y in range(n):
  for x in range(n):
   d=round(2*math.sin(x*math.tau/n)+2*math.cos(y*math.tau/n))
   if kind in ('aggregate','gravel','concrete','soil'):
    if rng.random()<(.07 if kind=='aggregate' else .12):d+=rng.choice([-7,-4,4,6])
   if kind=='siding':d+=(0,-2,-1,0,1,2,1,0)[(y//16)%8];d-=9 if y%16==0 else 0
   if kind=='metal':d+=round(5*math.cos(x*math.tau/12.8));d-=2 if y%64==0 else 0
   p[x,y]=tuple(max(0,min(255,c+d)) for c in base)
 if kind=='aggregate':
  for sx,sy in [(43,21),(149,181)]:
   for k in range(17):
    x=(sx+k)%n;y=(sy+int(2*math.sin(k*.5)))%n;p[x,y]=tuple(c-9 for c in base)
 im.save(OUT/f'T_{name}.png')
 sidecar=OUT/f'T_{name}.png.import'
 if sidecar.exists(): sidecar.write_text(sidecar.read_text().replace('mipmaps/generate=false','mipmaps/generate=true'))
 mat=f'''[gd_resource type="StandardMaterial3D" load_steps=2 format=3]
[ext_resource type="Texture2D" path="res://assets/environment/T_{name}.png" id="1"]
[resource]
resource_name = "Environment_{name}"
albedo_texture = ExtResource("1")
roughness = 0.93
metallic_specular = 0.15
uv1_scale = Vector3({uv}, {uv}, 1)
texture_filter = 4
'''
 (OUT/f'M_{name}.tres').write_text(mat)
manifest={'source':'Original deterministic Pillow pixel authoring with AI assistance; no third-party art','tile_size':[256,256],'materials':list(SPECS),'filter':'nearest with mipmaps and anisotropy','texel_density':'128 px/m ground, 256 px/m building details','approval':'Pending Windows visual QA'}
(OUT/'provenance.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Built',len(SPECS),'original environment tiles/materials')
