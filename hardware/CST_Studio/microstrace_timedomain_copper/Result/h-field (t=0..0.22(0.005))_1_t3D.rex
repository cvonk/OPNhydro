<?xml version="1.0" encoding="UTF-8"?>
<MetaResultFile version="20211011" creator="Solver HFTD - Field 3DTD Monitor">
  <MetaGeometryFile filename="model.gex" lod="1"/>
  <SimulationProperties fieldname="h-field (t=0..0.22(0.005)) [1]" frequency="0" encoded_unit="&amp;U:A^1.:m^-1" fieldtype="H-Field" fieldscaling="INSTANTANEOUS" dB_Amplitude="20"/>
  <ResultDataType vector="1" complex="0" timedomain="1" frequencymap="0"/>
  <SimulationDomain min="-2.75300002 -1 -15" max="2.17000008 1 17"/>
  <PlotSettings Plot="4" ignore_symmetry="0" deformation="0" enforce_culling="0" integer_values="0" combine="CombineNone" default_arrow_type="ARROWS" default_scaling="NONE"/>
  <Source type="SOLVER"/>
  <SpecialMaterials>
    <Background type="NORMAL"/>
    <Material name="Copper (pure)" type="FIELDFREE"/>
    <Material name="PEC" type="FIELDFREE"/>
  </SpecialMaterials>
  <SupplementalMesh/>
  <AuxGeometryFile/>
  <AuxResultFile/>
  <FieldFreeNodes/>
  <SurfaceFieldCoefficients/>
  <UnitCell/>
  <SubVolume/>
  <Units/>
  <ProjectUnits/>
  <TimeSampling start="0" end="0.22" step="0.0050000000000000001"/>
  <LocalAxes/>
  <MeshViewSettings/>
  <WaveguidePort/>
  <ResultGroups num_steps="1" transformation="1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1" process_mesh_group="0">
    <SharedDataWith>
      <Result treepath="2D/3D Results\Surface Current\surface current (t=0..0.22(0.005)) [1]" rexname="h-field (t=0..0.22(0.005))_1_t3D_sct.rex"/>
    </SharedDataWith>
    <Frame index="0">
      <PortModeInfoFile/>
      <FieldResultFile filename="h-field (t=0..0.22(0.005))_1.t3D" type="t3D"/>
    </Frame>
  </ResultGroups>
  <AutoScale>
    <SmartScaling log_strength="1" log_anchor="0" log_anchor_type="0" db_range="40" phase="0"/>
  </AutoScale>
</MetaResultFile>
