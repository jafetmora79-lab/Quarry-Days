#!/usr/bin/env python3
"""Copy selected THE VEIL assets into Quarry Days (read-only use of THE VEIL).

    python3 tools/import_veil_assets.py /path/to/theveil

Same owner, same art direction: Quarry Days reuses THE VEIL's props, pixel textures and Godot materials.
Each requested file is copied with its full dependency closure (GLB -> .glb.import -> external .tres
materials -> textures -> their .import files) to the SAME res:// path it has in THE VEIL
(res://THE_VEIL_ASSETS_V2/...), so every .import and .tres reference stays valid unmodified.
THE VEIL's repository is never written to.
"""
import os
import re
import shutil
import sys

ASSETS = [
    # office
    "03_Residential/Furniture/RES_Desk_Computer.glb", "03_Residential/Furniture/RES_DeskChair_Office.glb",
    "04_Commercial/Shared_Props/COM_NoticeBoard.glb", "04_Commercial/Shared_Props/COM_FilingCabinet.glb",
    "03_Residential/Furniture/RES_WallClock.glb", "03_Residential/Furniture/RES_WallCalendar.glb",
    "04_Commercial/Shared_Props/COM_WaitingChairs.glb", "04_Commercial/Shared_Props/COM_DocumentBoxes.glb",
    "02_Town/Street_Props/SP_Lamp_Wall.glb", "03_Residential/Exterior_Modules/RES_Ext_Door_Back_HalfGlass.glb",
    "03_Residential/Exterior_Modules/RES_Ext_Window_DoubleHung_1.1x1.3.glb",
    "03_Residential/Exterior_Modules/RES_Ext_Window_Picture_1.6x1.4.glb",
    # garage / workshop
    "03_Residential/Furniture/RES_Workbench.glb", "03_Residential/Furniture/RES_Shelving_Metal.glb",
    "03_Residential/Furniture/RES_Toolbox.glb", "04_Commercial/Shared_Props/COM_PalletRack.glb",
    "04_Commercial/Shared_Props/COM_PalletStack.glb", "03_Residential/Furniture/RES_CardboardBox_Stack.glb",
    "03_Residential/Furniture/RES_StorageBin.glb", "02_Town/Utilities/UT_ElectricalCabinet.glb",
    # site
    "02_Town/Street_Props/SP_RoadBarrier.glb", "02_Town/Street_Props/SP_TrafficCone.glb", "02_Town/Street_Props/SP_Dumpster.glb",
    "02_Town/Street_Props/SP_UtilityPole_Streetlight.glb", "02_Town/Street_Props/SP_Lamp_Commercial.glb",
    "02_Town/Street_Props/SP_Bench_Wood.glb", "02_Town/Street_Props/SP_TrashBin_Public.glb", "02_Town/Utilities/UT_JunctionBox.glb",
    "02_Town/Fences/FN_RetainingWall_2.5m.glb", "02_Town/Fences/FN_MetalRailing_2.5m.glb",
    "02_Town/Vegetation/VG_RocksSmall.glb", "02_Town/Vegetation/VG_DirtMound.glb", "02_Town/Vegetation/VG_GravelPile.glb",
    "02_Town/Vegetation/VG_Tree_Pine.glb", "02_Town/Vegetation/VG_TreeStump.glb", "02_Town/Vegetation/VG_Weeds.glb",
    "02_Town/Vegetation/VG_DeadVegetation.glb", "02_Town/Vegetation/VG_MudPatch.glb",
    # ground / building materials used directly by the quarry scene
    "Materials_Godot/Roads/M_Road_Gravel.tres", "Materials_Godot/Roads/M_Road_DirtRoad.tres",
    "Materials_Godot/Roads/M_Road_ConcreteCracked.tres", "Materials_Godot/Roads/M_Road_ParkingLotAsphalt.tres",
    "Materials_Godot/Roads/M_Road_MarkingYellow.tres", "Materials_Godot/Roads/M_Road_CurbConcrete.tres",
    "Materials_Godot/Ground/M_Grnd_Soil.tres", "Materials_Godot/Ground/M_Grnd_Mud.tres", "Materials_Godot/Ground/M_Grnd_GrassDry.tres",
    "Materials_Godot/Ground/M_Grnd_DeadVegetation.tres",
    "Materials_Godot/Architecture/M_Arch_ConcreteFoundation.tres", "Materials_Godot/Architecture/M_Arch_WindowGlassDirty.tres",
    "Materials_Godot/Architecture/M_Arch_SidingWhite.tres", "Materials_Godot/Architecture/M_Arch_TrimPainted.tres",
    "Materials_Godot/Commercial/M_Com_IndustrialWallDirty.tres", "Materials_Godot/Commercial/M_Com_MetalDoorPainted.tres",
    "Materials_Godot/Commercial/M_Com_StorageConcrete.tres", "Materials_Godot/Commercial/M_Com_SignageBacking.tres",
    "Materials_Godot/Interiors/M_Int_Linoleum.tres", "Materials_Godot/Interiors/M_Int_DrywallLight.tres",
    "Materials_Godot/Interiors/M_Int_BasementConcrete.tres", "Materials_Godot/Furniture/M_Furn_MetalBrushed.tres",
    "Materials_Godot/Furniture/M_Furn_MetalRusted.tres", "Materials_Godot/Furniture/M_Furn_Rubber.tres",
    "Materials_Godot/Furniture/M_Furn_WoodLight.tres", "05_Vehicles/Shared_Materials/M_Veh_Glass_Dirty.tres",
    "00_Art_Direction/GREYHAVEN_PALETTE.json", "00_Art_Direction/ART_DIRECTION.md",
]
RES = re.compile(r'res://THE_VEIL_ASSETS_V2/([^"\s]+)')


def main(veil):
    src_root = os.path.join(veil, "THE_VEIL_ASSETS_V2")
    dst_root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "THE_VEIL_ASSETS_V2")
    todo, done = list(ASSETS), set()
    while todo:
        rel = todo.pop()
        if rel in done:
            continue
        done.add(rel)
        for f in (rel, rel + ".import"):
            src = os.path.join(src_root, f)
            if not os.path.exists(src):
                if f == rel:
                    sys.exit(f"missing in THE VEIL: {rel}")
                continue
            dst = os.path.join(dst_root, f)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            if f.endswith((".import", ".tres", ".tscn")):
                for dep in RES.findall(open(src, encoding="utf-8", errors="ignore").read()):
                    if not dep.startswith(".godot") and dep != rel:
                        todo.append(dep)
    total = sum(os.path.getsize(os.path.join(dst_root, p)) for p in done if os.path.exists(os.path.join(dst_root, p)))
    print(f"copied {len(done)} files ({total // 1024} KB) into {dst_root}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/home/user/jafetmora79-lab/theveil")
