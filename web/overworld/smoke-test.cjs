// Deterministic browser test for v15 stable GPS map and player marker.
// Public mapping and Overpass endpoints are mocked, so CI tests gameplay
// rather than depending on external rate limits, CORS, or DNS.
const {chromium}=require('/tmp/libation-test/node_modules/playwright-core');
const fs=require('fs');
(async()=>{
 const chrome=['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium'].find(fs.existsSync);
 if(!chrome)throw Error('No Chromium browser found on Actions runner');
 const browser=await chromium.launch({executablePath:chrome,headless:true,
  args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-webgl']});
 try{
 const context=await browser.newContext({
  viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,
  geolocation:{longitude:-76.284,latitude:36.771,accuracy:12},
  permissions:['geolocation']});
 const page=await context.newPage();
 const errors=[];
 page.on('pageerror',e=>errors.push(e.stack||e.message));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 const featureCollection={type:'FeatureCollection',features:[
  {type:'Feature',properties:{kind:'park'},geometry:{type:'Polygon',coordinates:[[[-76.285,36.7695],[-76.282,36.7695],[-76.282,36.7725],[-76.285,36.7725],[-76.285,36.7695]]]}},
  {type:'Feature',properties:{kind:'water'},geometry:{type:'Polygon',coordinates:[[[-76.28348,36.7693],[-76.28320,36.7693],[-76.28312,36.7703],[-76.28327,36.7711],[-76.28318,36.7726],[-76.28354,36.7726],[-76.28367,36.7711],[-76.28349,36.7703],[-76.28348,36.7693]]]}},
  {type:'Feature',properties:{kind:'forest'},geometry:{type:'Polygon',coordinates:[[[-76.28455,36.77185],[-76.28405,36.77185],[-76.28405,36.77265],[-76.28455,36.77265],[-76.28455,36.77185]]]}},
  {type:'Feature',properties:{kind:'sand'},geometry:{type:'Polygon',coordinates:[[[-76.28355,36.7717],[-76.28368,36.7717],[-76.28368,36.7723],[-76.28355,36.7723],[-76.28355,36.7717]]]}},
  {type:'Feature',properties:{kind:'building'},geometry:{type:'Polygon',coordinates:[[[-76.28448,36.7713],[-76.28430,36.7713],[-76.28430,36.77148],[-76.28448,36.77148],[-76.28448,36.7713]]]}},
  {type:'Feature',properties:{kind:'building'},geometry:{type:'Polygon',coordinates:[[[-76.28483,36.77149],[-76.28465,36.77149],[-76.28465,36.77166],[-76.28483,36.77166],[-76.28483,36.77149]]]}},
  {type:'Feature',properties:{kind:'building'},geometry:{type:'Polygon',coordinates:[[[-76.28398,36.77117],[-76.28380,36.77117],[-76.28380,36.77134],[-76.28398,36.77134],[-76.28398,36.77117]]]}},
  {type:'Feature',properties:{kind:'structure-3d'},geometry:{type:'Polygon',coordinates:[[[-76.28498,36.7711],[-76.28478,36.7711],[-76.28478,36.77126],[-76.28498,36.77126],[-76.28498,36.7711]]]}},
  {type:'Feature',properties:{class:'beer',subclass:'pub',name:'Test Fixture Tavern'},
   geometry:{type:'Point',coordinates:[-76.28408,36.77128]}},
  {type:'Feature',properties:{class:'brewery',subclass:'brewery',name:'Test Fixture Brewery'},
   geometry:{type:'Point',coordinates:[-76.28388,36.77143]}},
  {type:'Feature',properties:{class:'restaurant',subclass:'restaurant',name:'Unverified Restaurant'},
   geometry:{type:'Point',coordinates:[-76.28420,36.77090]}},
  {type:'Feature',properties:{kind:'road'},geometry:{type:'LineString',coordinates:[[-76.287,36.7706],[-76.285,36.7708],[-76.281,36.7713],[-76.277,36.772]]}},
  {type:'Feature',properties:{kind:'trail'},geometry:{type:'LineString',coordinates:[[-76.2847,36.769],[-76.2841,36.77],[-76.284,36.773]]}}
 ]};
 const mockStyle={version:8,sources:{nearby:{type:'geojson',data:featureCollection}},
  layers:[
   {id:'background',type:'background',paint:{'background-color':'#a1d2a0'}},
   {id:'park',type:'fill',source:'nearby',filter:['==',['get','kind'],'park'],paint:{'fill-color':'#6eaf83'}},
   {id:'water',type:'fill',source:'nearby',filter:['==',['get','kind'],'water'],paint:{'fill-color':'#55acc9'}},
   {id:'forest',type:'fill',source:'nearby',filter:['==',['get','kind'],'forest'],paint:{'fill-color':'#457c52'}},
   {id:'sand',type:'fill',source:'nearby',filter:['==',['get','kind'],'sand'],paint:{'fill-color':'#e3c38d'}},
   {id:'building',type:'fill',source:'nearby',filter:['==',['get','kind'],'building'],paint:{'fill-color':'#bdaa80'}},
   {id:'building-3d-test',type:'fill-extrusion',source:'nearby',
    filter:['==',['get','kind'],'structure-3d'],
    paint:{'fill-extrusion-color':'#a99178','fill-extrusion-height':7}},
   {id:'road-primary',type:'line',source:'nearby',filter:['==',['get','kind'],'road'],paint:{'line-color':'#e8d6b1','line-width':7}},
   {id:'path',type:'line',source:'nearby',filter:['==',['get','kind'],'trail'],paint:{'line-color':'#efe5c3','line-width':3}}
  ]};
 await page.route('**/styles/liberty**',route=>route.fulfill({
  status:200,contentType:'application/json',body:JSON.stringify(mockStyle)
 }));
 let attemptedExternalDirectory=0;
 await page.route('**/api/interpreter**',route=>{
  attemptedExternalDirectory++;
  return route.abort('failed');
 });

 await page.goto('http://127.0.0.1:8123/',{waitUntil:'domcontentloaded',timeout:30000});
 try{
  await page.waitForFunction(()=>{
   const c=document.querySelector('#map canvas.maplibregl-canvas');
   const gps=document.querySelector('#gpsMarker');
   const status=document.querySelector('#online')?.textContent||'';
   return !!(c&&gps&&(status.includes('LIVE')||status.includes('ONLINE'))&&
    (document.querySelector('#locationReadout')?.textContent||'').includes('GPS POSITION FOUND'));
  },null,{timeout:22000});
 }catch(err){
  console.log('GPS MAP LOAD DIAGNOSTIC',await page.evaluate(()=>({
   online:document.querySelector('#online')?.textContent,
   banner:document.querySelector('#liveLocationBanner')?.textContent,
   gps:!!document.querySelector('#gpsMarker'),
   baseMap:!!document.querySelector('#map canvas.maplibregl-canvas'),
   styleScripts:[...document.scripts].map(s=>s.src).filter(Boolean),
  })),errors.slice(0,8));
  await page.screenshot({path:'/tmp/libation-world-screenshot.png',fullPage:false});
  throw err;
 }
 await page.waitForTimeout(900);
 const inspect=await page.evaluate(()=>{
  const map=document.querySelector('#map');
  const base=map.querySelector('canvas.maplibregl-canvas');
  const avatar=document.querySelector('#gpsMarker');
  const oldCanvas=document.querySelector('#gameOverworldArt');
  const fake=document.querySelector('#illustratedBackdrop');
  const getStyle=e=>e?getComputedStyle(e):null;
  return {
    mapOpacity:Number(getStyle(map)?.opacity||0),
    baseOpacity:Number(getStyle(base)?.opacity||0),
    baseDisplay:getStyle(base)?.display,
    mapSize:[base.width,base.height],
    avatarVisible:!!avatar&&getStyle(avatar)?.display!=='none'&&
       Number(getStyle(avatar)?.opacity)>0.98,
    avatarGeoAnchored:!!avatar?.closest('.maplibregl-marker'),
    atlasVisible:!!oldCanvas&&getStyle(oldCanvas)?.display!=='none',
    fakeBackgroundVisible:!!fake&&getStyle(fake)?.display!=='none',
    oldWorldVisible:getStyle(document.querySelector('#gameWorld'))?.display!=='none',
    gpsMarkerPosition:avatar?.closest('.maplibregl-marker')?.style?.transform?.slice(0,180),
    region:document.querySelector('#regionName')?.textContent,
    liveLabel:document.querySelector('#online')?.textContent,
  };
 });
 const spriteDimensions=await page.evaluate(async()=>{
   const img=new Image();img.src='./avatar_snes.png';await img.decode();
   return [img.naturalWidth,img.naturalHeight];
 });
 inspect.spriteDimensions=spriteDimensions;
 // Verify actual map pixel placement, not merely DOM presence and CSS opacity.
 // A former position:relative override displaced MapLibre markers off-screen.
 async function inspectMarkerAnchors(){
  return page.evaluate(()=>{
   const host=document.querySelector('#map').getBoundingClientRect();
   const examine=el=>{
    if(!el)return {exists:false};
    const r=el.getBoundingClientRect(),st=getComputedStyle(el);
    const matches=[...(el.style.transform||'').matchAll(/translate\((-?[\d.]+)px,\s*(-?[\d.]+)px\)/g)];
    const match=matches.at(-1);
    return {exists:true,position:st.position,size:[r.width,r.height],
     onScreen:r.bottom>host.top&&r.top<host.bottom&&r.right>host.left&&r.left<host.right,
     anchorError:match?[Math.round(r.left+r.width/2-host.left-Number(match[1])),
       Math.round(r.bottom-host.top-Number(match[2]))]:null};
   };
   const avatar=document.querySelector('#gpsMarker'),sprite=avatar?.querySelector('img.sprite');
   const portals=[...document.querySelectorAll('.pixel-marker.maplibregl-marker')];
   return {avatar:examine(avatar),sprite:{loaded:!!sprite?.complete,
     width:sprite?.naturalWidth,height:sprite?.naturalHeight,
     display:sprite?getComputedStyle(sprite).display:'missing'},
    portals:portals.map(examine),portalTypes:portals.map(e=>e.className),
    venueStatus:document.querySelector('#venueCount')?.textContent};
  });
 }
 const positioned=m=>m.exists&&m.position==='absolute'&&
   m.size[0]>=30&&m.size[1]>=50&&Array.isArray(m.anchorError)&&
   m.anchorError.every(v=>Math.abs(v)<=4);
 const anchored=m=>positioned(m)&&m.onScreen;
 await page.waitForFunction(()=>document.querySelectorAll('.pixel-marker.maplibregl-marker').length===2,
  null,{timeout:12000});
 const portalSourceAudit=await page.evaluate(()=>({
  names:[...document.querySelectorAll('.pixel-marker.maplibregl-marker')]
   .map(m=>m.querySelector('.location-title')?.textContent),
  status:document.querySelector('#venueCount')?.textContent,
  provider:document.querySelector('#map')?.dataset.venueDirectory
 }));
 console.log('NETWORK-INDEPENDENT OSM PORTAL DATA:',JSON.stringify(portalSourceAudit));
 if(attemptedExternalDirectory!==0||portalSourceAudit.provider!=='map-tiles'||
   !portalSourceAudit.names.some(x=>/Test Fixture Tavern/.test(x||''))||
   !portalSourceAudit.names.some(x=>/Test Fixture Brewery/.test(x||''))||
   /failed to fetch|directory failed|unavailable/i.test(portalSourceAudit.status||''))
  throw Error('Venue discovery still requires broken browser Overpass requests: '+
   JSON.stringify({portalSourceAudit,attemptedExternalDirectory}));
 await page.evaluate(()=>document.querySelector('#refreshBtn').click());
 await page.waitForTimeout(250);
 if(attemptedExternalDirectory!==0||
   await page.locator('.pixel-marker.maplibregl-marker').count()!==2)
  throw Error('Refreshing venues reintroduced browser cross-origin directory failures');

 // A close, tilted local-world camera is part of the gameplay contract.
 const readCamera=()=>page.locator('#map').evaluate(el=>({
   zoom:Number(el.dataset.cameraZoom),pitch:Number(el.dataset.cameraPitch),
   bearing:Number(el.dataset.cameraBearing)
 }));
 const terrainReport=await page.locator('#map').evaluate(el=>({
   phase:el.dataset.terrainPhase,
   shorelineEdges:Number(el.dataset.shorelineEdges),
   routeShoulders:Number(el.dataset.routeShoulders),
   greenContours:Number(el.dataset.greenContours),
   pathDetails:Number(el.dataset.pathDetails),
   materials:Number(el.dataset.terrainMaterials)
 }));
 console.log('GEOGRAPHIC RPG TERRAIN PHASE:',JSON.stringify(terrainReport));
 if(terrainReport.phase!=='pixel-materials-2'||
   terrainReport.shorelineEdges<2||terrainReport.routeShoulders<2)
  throw Error('Water/coast/path artwork not tied to geographic layers: '+JSON.stringify(terrainReport));
 if(terrainReport.materials!==7||terrainReport.greenContours<1||terrainReport.pathDetails<1)
  throw Error('Biome/path detail materials missing: '+JSON.stringify(terrainReport));
 const materialAudit=await page.evaluate(()=>{
  const palette=['lw-ground','lw-meadow','lw-park','lw-forest',
   'lw-water','lw-sand','lw-settlement'];
  return window.LibationWorldDiagnostics?.materials?.()||
   {available:'not-exported'};
 });
 console.log('WORLD TEXTURE MATERIAL AUDIT:',JSON.stringify(materialAudit));
 if(materialAudit?.registered!==7||
   !materialAudit.results.every(r=>r.ready&&r.width===256&&r.height===256))
  throw Error('Geographic sprite materials missing or malformed: '+JSON.stringify(materialAudit));
 const texture=await page.locator('#map').getAttribute('data-terrain-tiles');
 if(texture!=='geographic')throw Error('Native georeferenced terrain tile materials absent: '+texture);
 const nativeArt=await page.locator('#map').evaluate(el=>({
  mode:el.dataset.geographicArt,
  trees:Number(el.dataset.artTrees||0),
  buildings:Number(el.dataset.artBuildings||0)
 }));
 console.log('NATIVE GEO-ANCHORED BUILDING AND WOODLAND ART:',JSON.stringify(nativeArt));
 if(nativeArt.mode!=='native-symbols'||nativeArt.trees<1||nativeArt.buildings!==0)
  throw Error('Repeated decorative cottages still in the live map: '+JSON.stringify(nativeArt));
 const buildingsPresentation=await page.locator('#map').evaluate(el=>({
  appearance:el.dataset.buildingPresentation,depth:el.dataset.geographicDepth,
  blocks:el.dataset.blockExtrusions,houseIcons:el.dataset.houseSymbolsRemoved,
  roofCount:Number(el.dataset.buildingLayers)
 }));
 console.log('REAL-FOOTPRINT ROOF ART:',JSON.stringify(buildingsPresentation));
 if(buildingsPresentation.appearance!=='dark-defined-footprints'||
  buildingsPresentation.depth!=='flat-outlines'||
  buildingsPresentation.blocks!=='removed'||
  buildingsPresentation.houseIcons!=='yes'||buildingsPresentation.roofCount<2)
  throw Error('Buildings still render as filled roofs or tall blocks: '+JSON.stringify(buildingsPresentation));
 const mappedPaint=await page.evaluate(()=>window.LibationWorldDiagnostics.buildingPaint());
 console.log('DARKER REAL BUILDING FOOTPRINT RENDER:',JSON.stringify(mappedPaint));
 if(!mappedPaint.footprint||mappedPaint.fillOpacity<.60||mappedPaint.fillOpacity>.75||
    !mappedPaint.border||mappedPaint.strokeOpacity<.90||
    mappedPaint.roofOrSolidLayers.length||mappedPaint.texture!=='subtle')
  throw Error('Building footprint contrast incorrect or old roof art returned: '+JSON.stringify(mappedPaint));
 const buildings=await page.locator('#map').evaluate(el=>({
  status:el.dataset.geographicBuildings,
  layers:Number(el.dataset.buildingLayers),
  visible:Number(el.dataset.visibleMappedBuildings)
 }));
 console.log('ACTUAL MAPPED BUILDING FOOTPRINT RENDER AUDIT:',JSON.stringify(buildings));
 if(buildings.status!=='footprints-visible'||buildings.layers<2||buildings.visible<1)
  throw Error('Mapped real-world building footprints were hidden by sprite collision: '+JSON.stringify(buildings));
 const solarThemes=await page.evaluate(()=>{
  const at=iso=>window.LibationWorldTime.resolve(new Date(iso),[-76.284,36.771]);
  return {night:at('2026-10-16T04:00:00Z'),
   morning:at('2026-10-16T12:00:00Z'),
   day:at('2026-10-16T17:00:00Z'),
   evening:at('2026-10-16T22:00:00Z'),
   late:at('2026-10-16T23:00:00Z')};
 });
 console.log('GPS SUNLIT WORLD PHASES:',JSON.stringify(solarThemes));
 for(const [key,expected] of Object.entries({
  night:'night',morning:'morning',day:'day',evening:'evening',late:'night'
 })){
  if(solarThemes[key]?.phase!==expected||solarThemes[key]?.source!=='gps-solar')
   throw Error('Solar position did not produce correct real-world phase: '+JSON.stringify({key,solarThemes}));
 }
 const liveTheme=await page.locator('#map').evaluate(el=>({
  phase:el.dataset.worldTimePhase,source:el.dataset.worldTimeSource,
  filter:getComputedStyle(el.querySelector('canvas.maplibregl-canvas')).filter}));
 if(!['morning','day','evening','night'].includes(liveTheme.phase)||
    liveTheme.source!=='gps-solar')
  throw Error('Live geographic map did not use solar time: '+JSON.stringify(liveTheme));
 console.log('CURRENT GPS LIGHTING:',JSON.stringify(liveTheme));
 const initialCamera=await readCamera();
 console.log('LOCAL EXPLORER CAMERA:',JSON.stringify(initialCamera));
 if(!(initialCamera.zoom>=18.1&&initialCamera.zoom<=18.4&&
   initialCamera.pitch>=59&&initialCamera.pitch<=68))
  throw Error('Camera regressed to distant overhead map: '+JSON.stringify(initialCamera));
 // The character is a world object: its feet/shadow stay on the GPS ground
 // point, while its visible size must change exponentially with map zoom.
 async function avatarGeometry(){
  return page.evaluate(()=>{
   const marker=document.querySelector('#gpsMarker');
   const rig=marker?.querySelector('.avatar-rig');
   const img=rig?.querySelector('img.sprite');
   const shadow=rig?.querySelector('.gps-ground');
   if(!marker||!rig||!img||!shadow)return null;
   const root=marker.getBoundingClientRect();
   const ir=img.getBoundingClientRect(),sr=shadow.getBoundingClientRect();
   const transform=getComputedStyle(rig).transform;
   return {
    zoom:Number(marker.dataset.avatarMapZoom),
    scale:Number(marker.dataset.avatarWorldScale),
    computedScale:new DOMMatrixReadOnly(transform).a,
    spriteHeight:ir.height,shadowWidth:sr.width,
    markerWidth:root.width,markerHeight:root.height,
    shadowGroundError:Math.abs(sr.bottom-root.bottom),
    lateralError:Math.abs((ir.left+ir.right)/2-(sr.left+sr.right)/2),
    footToShadowCenter:Math.abs((ir.bottom-6.4*new DOMMatrixReadOnly(transform).a)-
      (sr.top+sr.bottom)/2)
   };
  });
 }
 function checkWorldAvatar(v, expectedZoom){
  if(!v||Math.abs(v.zoom-expectedZoom)>.08||
     Math.abs(v.scale-Math.pow(2,v.zoom-18.25))>.02||
     Math.abs(v.computedScale-v.scale)>.002||
     v.shadowGroundError>2||v.lateralError>3||
     v.footToShadowCenter>8||
     Math.abs(v.markerWidth-90)>1||Math.abs(v.markerHeight-119)>1)
   throw Error('Character lost its geographic scale or ground contact: '+JSON.stringify(v));
 }
 const baseAvatar=await avatarGeometry();
 checkWorldAvatar(baseAvatar,initialCamera.zoom);
 // Local zoom is bounded; plus/minus buttons must change real map scale.
 await page.locator('#zoomOutBtn').click();
 await page.waitForTimeout(450);
 const zoomedOut=await readCamera();
 if(!(zoomedOut.zoom<initialCamera.zoom-.18&&zoomedOut.zoom>=17.54))
  throw Error('Zoom-out control is still locked: '+JSON.stringify({initialCamera,zoomedOut}));
 const smallAvatar=await avatarGeometry();
 checkWorldAvatar(smallAvatar,zoomedOut.zoom);
 if(smallAvatar.spriteHeight>=baseAvatar.spriteHeight*.92||
    smallAvatar.shadowWidth>=baseAvatar.shadowWidth*.92)
  throw Error('Avatar/shadow stayed fixed pixel-size while zooming out: '+JSON.stringify({baseAvatar,smallAvatar}));
 await page.screenshot({path:'/tmp/libation-world-zoomed-out.png',fullPage:false});
 await page.locator('#zoomInBtn').click();
 await page.waitForTimeout(450);
 const restored=await readCamera();
 if(Math.abs(restored.zoom-initialCamera.zoom)>.06)
  throw Error('Zoom-in failed to restore close camera: '+JSON.stringify(restored));
 const resetAvatar=await avatarGeometry();
 checkWorldAvatar(resetAvatar,restored.zoom);
 if(Math.abs(resetAvatar.spriteHeight-baseAvatar.spriteHeight)>3||
    Math.abs(resetAvatar.shadowWidth-baseAvatar.shadowWidth)>3)
  throw Error('Character size failed to restore after zooming in: '+JSON.stringify({baseAvatar,resetAvatar}));
 await page.waitForFunction(()=>window.LibationPaintedAvatar?.ready()===true,null,{timeout:12000});
 const illustration=await page.evaluate(async()=>{
  const atlas=new Image();atlas.src='./avatar_jrpg_strip.avif';await atlas.decode();
  const spr=document.querySelector('#gpsMarker .sprite');
  return {atlas:[atlas.naturalWidth,atlas.naturalHeight],
   rendered:[spr?.naturalWidth,spr?.naturalHeight],
   style:spr?getComputedStyle(spr).imageRendering:'missing',
   source:window.LibationPaintedAvatar?.source};
 });
 console.log('APPROVED JRPG ANIMATED ART:',JSON.stringify(illustration));
 if(illustration.atlas[0]!==640||illustration.atlas[1]!==140||
  illustration.rendered[0]!==80||illustration.rendered[1]!==140||
  illustration.style==='pixelated'||illustration.source!=='approved-illustration')
  throw Error('Approved high-resolution avatar art did not render: '+JSON.stringify(illustration));
 await page.screenshot({path:'/tmp/libation-approved-avatar.png',fullPage:false});
 const polishedAvatar=await page.evaluate(()=>{
  const module=window.LibationJRPGAvatar;
  const image=document.querySelector('#gpsMarker img.sprite');
  return {exists:!!module,style:module?.style,resolution:module?.resolution,
    directions:module?.directions,gaitFrames:module?.gaitFrames,
    decoded:image?.naturalWidth,decodedHeight:image?.naturalHeight,
    cssRendering:image?getComputedStyle(image).imageRendering:'missing',
    facingUnique:module?new Set(['up','right','down','left'].map(dir=>
      module.render(16,dir,{hair:1,skin:1,outfit:0,hairStyle:0,body:1}))).size:0,
    customizationChanges:module?module.render(16,'up',{hair:1,skin:1,outfit:0,hairStyle:0,body:1})!==
      module.render(16,'up',{hair:4,skin:1,outfit:2,hairStyle:0,body:1}):false};
 });
 console.log('POLISHED JRPG AVATAR RENDERER:',JSON.stringify(polishedAvatar));
 if(!polishedAvatar.exists||polishedAvatar.style!=='smooth-jrpg'||
   polishedAvatar.resolution[0]<200||polishedAvatar.resolution[1]<300||
   polishedAvatar.facingUnique!==4||!polishedAvatar.customizationChanges||
   polishedAvatar.cssRendering==='pixelated')
  throw Error('High-detail, anti-aliased customizable sprite regression: '+JSON.stringify(polishedAvatar));
 await page.screenshot({path:'/tmp/libation-jrpg-avatar.png',fullPage:false});
 const animationSpec=await page.evaluate(()=>window.LibationAvatarAnimation?.status());
 if(!animationSpec||animationSpec.targetFps<55||animationSpec.strideFrames<12||animationSpec.avatarWidth<64)
  throw Error('High-frame customizable avatar animation missing: '+JSON.stringify(animationSpec));
 await page.waitForFunction(()=>Number(document.querySelector('#map')?.dataset.natureDecor||0)>0,
  null,{timeout:7000});
 const natureReport=await page.locator('#map').evaluate(el=>({
  count:Number(el.dataset.natureDecor||0),trees:Number(el.dataset.natureTrees||0),
  types:Number(el.dataset.natureTypes||0),
  visible:!!document.querySelector('#worldScenery')&&
   getComputedStyle(document.querySelector('#worldScenery')).display!=='none'
 }));
 console.log('ACTUAL MOBILE NATURE / AVATAR ANIMATION:',JSON.stringify({natureReport,animationSpec}));
 if(!natureReport.visible||natureReport.count<8||natureReport.count>160||natureReport.types<3)
  throw Error('Nature density or biome diversity invalid: '+JSON.stringify(natureReport));
 const navLayout=await page.locator('#footnav .navbtn').evaluateAll(buttons=>{
  const bounds=buttons.map(b=>b.getBoundingClientRect());
  return {count:buttons.length,noOverlap:bounds.every((b,i)=>!i||b.left>=bounds[i-1].right-1),
   widths:bounds.map(b=>Math.round(b.width)),viewport:window.innerWidth};
 });
 if(navLayout.count!==5||!navLayout.noOverlap)
  throw Error('Android bottom navigation buttons overlap: '+JSON.stringify(navLayout));
 console.log('ANDROID NAV BUTTON LAYOUT:',JSON.stringify(navLayout));
 await page.screenshot({path:'/tmp/libation-nature-avatar-new.png',fullPage:false});
 console.log('GEOGRAPHIC AVATAR ZOOM SCALING:',JSON.stringify({baseAvatar,smallAvatar,resetAvatar}));
 await page.screenshot({path:'/tmp/libation-world-zoomed-in.png',fullPage:false});
 console.log('LOCAL ZOOM CONTROLS:',JSON.stringify({initialCamera,zoomedOut,restored}));
 const pixelAudit=await inspectMarkerAnchors();
 console.log('ON-SCREEN GEOGRAPHIC MARKER AUDIT:',JSON.stringify(pixelAudit));
 if(!anchored(pixelAudit.avatar)||!pixelAudit.sprite.loaded||
    pixelAudit.sprite.width<32||pixelAudit.sprite.height<32||
    pixelAudit.sprite.display==='none'||!pixelAudit.portals.every(anchored))
  throw Error('Player or portal sprite does not render at true GPS coordinates: '+JSON.stringify(pixelAudit));
 await page.waitForTimeout(3500); // Allow location toast to clear.
 await page.screenshot({path:'/tmp/libation-world-screenshot.png',fullPage:false});
 await page.screenshot({path:'/tmp/libation-fantasy-terrain.png',fullPage:false});
 await page.screenshot({path:'/tmp/libation-detailed-overworld.png',fullPage:false});
 await page.screenshot({path:'/tmp/libation-building-forest-sprites.png',fullPage:false});
 await page.screenshot({path:'/tmp/libation-visible-buildings.png',fullPage:false});
 await page.screenshot({path:'/tmp/libation-refined-rooftops.png',fullPage:false});
 // Exercise all lighting phases on the same fixed GPS geometry. A CSS filter
 // applied to only the geographic WebGL canvas must leave avatar/portals unfiltered.
 await page.evaluate(()=>{
  document.querySelector('#map canvas.maplibregl-canvas').style.transition='none';
  window.LibationWorldTime.apply(new Date('2026-10-16T17:00:00Z'));
 });
 await page.waitForTimeout(150);
 await page.screenshot({path:'/tmp/libation-time-day.png',fullPage:false});
 const daytime=await page.locator('#map canvas.maplibregl-canvas').evaluate(el=>getComputedStyle(el).filter);
 await page.evaluate(()=>window.LibationWorldTime.apply(new Date('2026-10-16T22:00:00Z')));
 await page.waitForTimeout(150);
 await page.screenshot({path:'/tmp/libation-time-evening.png',fullPage:false});
 const sunset=await page.locator('#map canvas.maplibregl-canvas').evaluate(el=>getComputedStyle(el).filter);
 await page.evaluate(()=>window.LibationWorldTime.apply(new Date('2026-10-16T04:00:00Z')));
 await page.waitForTimeout(150);
 await page.screenshot({path:'/tmp/libation-time-night.png',fullPage:false});
 const nighttime=await page.locator('#map canvas.maplibregl-canvas').evaluate(el=>getComputedStyle(el).filter);
 if(daytime==='none'||sunset==='none'||nighttime==='none'||sunset===nighttime)
  throw Error('Sunrise/sunset changes did not visibly recolor geographic world: '+
   JSON.stringify({daytime,sunset,nighttime}));
 await page.evaluate(()=>window.LibationWorldTime.apply(new Date()));
 console.log('DAY EVENING NIGHT MAP RENDER:',JSON.stringify({daytime,sunset,nighttime}));
 // Simulate actual location movement and then a horizontal camera swipe.
 await context.setGeolocation({longitude:-76.2838,latitude:36.77105,accuracy:6});
 await page.waitForFunction(()=>document.body.classList.contains('walking'),null,{timeout:4500});
 const walkingSamples=[];
 for(let n=0;n<7;n++){
  walkingSamples.push(await page.evaluate(()=>{
   const img=document.querySelector('#gpsMarker img.sprite');
   const src=img?.getAttribute('src')||'';
   // Do not log huge PNG contents or anything resembling location coordinates.
   return {len:src.length,tail:src.slice(-35),walking:document.body.classList.contains('walking'),
    hidden:document.hidden,phase:img?.dataset.walkFrame||''};
  }));
  await page.waitForTimeout(155);
 }
 const walkUnique=new Set(walkingSamples.map(v=>v.tail));
 console.log('WALK ANIMATION SAMPLES:',JSON.stringify(walkingSamples));
 const footAlignment=await page.evaluate(()=>{
   const image=document.querySelector('#gpsMarker img.sprite')?.getBoundingClientRect();
   const shadow=document.querySelector('#gpsMarker .gps-ground')?.getBoundingClientRect();
   return {imageCenter:image?(image.left+image.right)/2:null,
     shadowCenter:shadow?(shadow.left+shadow.right)/2:null};
 });
 if(!Number.isFinite(footAlignment.imageCenter)||!Number.isFinite(footAlignment.shadowCenter)||
   Math.abs(footAlignment.imageCenter-footAlignment.shadowCenter)>8)
  throw Error('Walking avatar detached from grounded GPS shadow: '+JSON.stringify(footAlignment));
 console.log('WALKING FOOT ALIGNMENT:',JSON.stringify(footAlignment));
 await page.screenshot({path:'/tmp/libation-world-walking.png',fullPage:false});
 if(walkUnique.size<2)
  throw Error('Walking still uses a single static avatar frame: '+JSON.stringify(walkingSamples));
 await page.waitForTimeout(2500); // GPS interpolation ends within 2400ms.
 const moved=await inspectMarkerAnchors();
 if(!anchored(moved.avatar)||!moved.portals.every(positioned))
   throw Error('Geographic markers detached after GPS movement: '+JSON.stringify(moved));
 // Real Chromium touch input; a mouse drag did not reproduce Android swipe problems.
 const cdp=await context.newCDPSession(page);
 async function swipeTouch(start,end){
  const touch=(x,y)=>({x,y,id:17});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',
   touchPoints:[touch(...start)]});
  for(let i=1;i<=12;i++){
   const t=i/12;
   await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',
    touchPoints:[touch(start[0]+(end[0]-start[0])*t,
     start[1]+(end[1]-start[1])*t)]});
   await page.waitForTimeout(20);
  }
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  await page.waitForTimeout(220);
 }
 const beforeSwipe=await readCamera();
 await swipeTouch([80,550],[260,550]);
 const afterTurn=await readCamera();
 console.log('REAL TOUCH CAMERA TURN:',JSON.stringify({beforeSwipe,afterTurn}));
 // Signed shortest change: a rightward drag must now turn the camera
 // in the reverse direction (negative bearing, rather than merely any turn).
 const bearingDelta=((afterTurn.bearing-beforeSwipe.bearing+540)%360)-180;
 if(bearingDelta>-45||bearingDelta<-110||Math.abs(afterTurn.pitch-beforeSwipe.pitch)>2)
  throw Error('Reversed Android right-swipe turn did not move left: '+JSON.stringify({beforeSwipe,afterTurn,bearingDelta}));
 await page.screenshot({path:'/tmp/libation-world-touch-turn.png',fullPage:false});
 // Two-finger pinch zooms only within the neighborhood-scale range.
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',
  touchPoints:[{id:31,x:135,y:470},{id:32,x:250,y:470}]});
 for(let i=1;i<=8;i++){
  await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',
   touchPoints:[{id:31,x:135+i*4,y:470},{id:32,x:250-i*4,y:470}]});
  await page.waitForTimeout(20);
 }
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.waitForTimeout(250);
 const pinched=await readCamera();
 if(!(pinched.zoom<beforeSwipe.zoom-.25&&pinched.zoom>=17.54))
  throw Error('Two-finger pinch failed to zoom out: '+JSON.stringify({beforeSwipe,pinched}));
 const pinchedAvatar=await avatarGeometry();
 checkWorldAvatar(pinchedAvatar,pinched.zoom);
 if(pinchedAvatar.spriteHeight>=baseAvatar.spriteHeight*.8)
  throw Error('Pinch zoom did not scale avatar as part of the geographic world: '+JSON.stringify(pinchedAvatar));
 console.log('TWO-FINGER PINCH:',JSON.stringify(pinched));
 await page.locator('#zoomInBtn').click();
 await page.locator('#zoomInBtn').click();
 await page.locator('#zoomInBtn').click();
 await page.waitForTimeout(500);
 await swipeTouch([90,650],[90,490]);
 const afterTilt=await readCamera();
 // After reversing tilt, an upward finger swipe now lowers the pitch.
 if(!(afterTilt.pitch<=beforeSwipe.pitch-8&&afterTilt.pitch>=47.8)||
    Math.abs(afterTilt.zoom-18.25)>.15)
  throw Error('Reversed Android upward swipe did not lower camera pitch: '+JSON.stringify({beforeSwipe,afterTilt}));
 const turned=await inspectMarkerAnchors();
 if(!anchored(turned.avatar)||!turned.portals.every(positioned))
   throw Error('Geographic markers detached after touch rotation: '+JSON.stringify(turned));
 console.log('REAL TOUCH CAMERA TILT:',JSON.stringify(afterTilt));
 const gpsState=await page.evaluate(()=>{
  const toast=document.querySelector('#toast'),banner=document.querySelector('#liveLocationBanner');
  return {readout:document.querySelector('#locationReadout')?.textContent,
   misleadingToast:toast?.classList.contains('toast-visible')&&/Unable to determine your position|Location request timed out/i.test(toast.textContent),
   misleadingBanner:banner?.classList.contains('visible')&&/Unable to determine your position|Location request timed out/i.test(banner.textContent)};
 });
 if(gpsState.misleadingToast||gpsState.misleadingBanner)
   throw Error('A transient GPS error hides a valid live position: '+JSON.stringify(gpsState));
 console.log('GPS SIGNAL STATUS:',JSON.stringify(gpsState));
 await page.screenshot({path:'/tmp/libation-world-movement.png',fullPage:false});
 console.log('GPS MOVEMENT + CAMERA SWIPE:',JSON.stringify({moved,turned}));

 // Developer mode and the actual dungeon are a separate, user-facing game.
 // Toggle development features explicitly; they never alter the OSM venue list.
 await page.locator('[data-panel="settings"]').click();
 await page.locator('#devModeToggle').click();
 await page.locator('#closeDrawer').click();
 const initially=await page.evaluate(()=>window.LibationDeveloper.enabled());
 if(!initially)throw Error('Settings failed to enable developer portals');
 // Claim two distinctly styled demo warriors using real user-facing buttons,
 // never inject ownership into the account or gameplay internals.
 for(const [index,upc] of ['712340000033','712340000032'].entries()){
  if(index===0)await page.locator('[data-panel="summon"]').click();
  else await page.locator('#collectionSummon').click();
  await page.locator('#upcInput').fill(upc);
  await page.locator('#claimDemo').click();
  await page.locator('#demoFinish').click();
  if(!await page.locator('#drawerContent').getByText('UPC '+upc).isVisible())
   throw Error('Demo warrior not visible in collection: '+upc);
 }
 await page.locator('#closeDrawer').click();
 await page.locator('#devAddRupture').click();
 await page.locator('#devAddWormhole').click();
 await page.waitForTimeout(250);
 const placed=await page.evaluate(()=>window.LibationDeveloper.portals());
 const nowCount=await page.locator('.pixel-marker.maplibregl-marker').count();
 if(placed.length!==2||nowCount!==4||placed[0].type!=='rupture'||placed[1].type!=='challenge'||
    !(await page.locator('#devPortalCount').textContent()).includes('FICTIONAL GPS TEST PORTALS · 2'))
  throw Error('Developer portals did not appear as separate GPS markers: '+JSON.stringify({placed,nowCount}));
 console.log('DEV GPS TEST PORTALS:',JSON.stringify(placed));
 await page.screenshot({path:'/tmp/libation-dev-portals.png',fullPage:false});
 // Select a real clickable portal marker, not an internal test-only function.
 await page.locator('.dev-select-portal[data-kind="challenge"]').click();
 await page.locator('#enterVenue').click();
 const choices=page.locator('#lwWarriorChoices [data-warrior-index]');
 if(await choices.count()!==2)throw Error('Dungeon staging cannot select both claimed warriors');
 const portraits=await page.locator('#lwWarriorChoices .lwWarriorSpritePreview').evaluateAll(imgs=>
  imgs.map(i=>i.src));
 if(portraits.length!==2||portraits[0]===portraits[1])
  throw Error('Male and female warrior sprites are not distinct');
 const frames=await page.evaluate(()=>{
  const d=window.LibationDungeon,w={id:'abc',gender:'female',faction:'Pirate'};
  const actions=['idle','walk','attack','hurt','defeat'],unique={};
  for(const action of actions){
   const a=d.previewWarrior(w,'down',action,0),b=d.previewWarrior(w,'down',action,1);
   unique[action]=a!==b;
  }
  unique.directions=new Set(['up','down','left','right'].map(dir=>
   d.previewWarrior(w,dir,'idle',0))).size===4;
  return unique;
 });
 if(!frames.walk||!frames.attack||!frames.hurt||!frames.directions)
  throw Error('Dungeon warrior directional frames are not genuinely animated: '+JSON.stringify(frames));
 await choices.nth(1).click();
 if(await choices.nth(1).getAttribute('aria-pressed')!=='true')
  throw Error('Second warrior selection not active');
 await page.screenshot({path:'/tmp/libation-warrior-selection.png',fullPage:false});
 await page.locator('#readyButton').click();
 await page.waitForFunction(()=>window.LibationDungeon?.snapshot().active===true);
 const selectedHero=await page.evaluate(()=>window.LibationDungeon.snapshot().warrior);
 if(selectedHero?.name!=='Moonblade'||selectedHero.gender!=='female')
  throw Error('Dungeon failed to use selected warrior: '+JSON.stringify(selectedHero));
 const buttonText=await page.locator('#lwDAttack').evaluate(btn=>({
  visibleText:btn.textContent.trim(),labelCount:btn.querySelectorAll('.lwDAttackLabel').length,
  label:btn.querySelector('.lwDAttackLabel')?.textContent,
  shadow:getComputedStyle(btn.querySelector('.lwDAttackLabel')).textShadow
 }));
 if(buttonText.label!=='ATTACK'||buttonText.labelCount!==1||buttonText.shadow!=='none')
  throw Error('Attack button has doubled / ghosted label: '+JSON.stringify(buttonText));
 console.log('SELECTED WARRIOR + ANIMATION FRAMES:',JSON.stringify({selectedHero,frames,buttonText}));
 // Graph property tests: generated world is connected, spatially unique,
 // reciprocal and different across many seeds and both dungeon difficulties.
 const layouts=await page.evaluate(()=>{
  const d=window.LibationDungeon,variants={};
  for(const kind of ['rupture','challenge']){
   const expected=kind==='challenge'?14:10,signatures=new Set();
   for(let k=0;k<90;k++){
    const p=d.inspectLayout('generated-room-test-'+k,kind);
    if(p.count!==expected||p.nodes.length!==expected||!p.nodes.some(n=>n.id===p.boss&&n.type==='boss')||
      !p.nodes.some(n=>n.id===p.treasure&&n.type==='treasure'))throw Error('Bad generated roles: '+kind);
    const coords=new Set(p.nodes.map(n=>n.gx+','+n.gy));
    if(coords.size!==expected)throw Error('Duplicate room coordinates: '+kind);
    const seen=new Set([0]),stack=[0];
    while(stack.length){
     const a=p.nodes[stack.pop()];
     for(const [dir,b] of Object.entries(a.edges)){
      const opposite={up:'down',down:'up',left:'right',right:'left'}[dir];
      if(p.nodes[b].edges[opposite]!==a.id)throw Error('Broken reciprocal door '+kind);
      if(!seen.has(b)){seen.add(b);stack.push(b)}
     }
    }
    if(seen.size!==expected)throw Error('Unreachable generated room '+kind);
    if(new Set(p.nodes.map(n=>n.template)).size<3)throw Error('Room art templates too repetitive '+kind);
    signatures.add(p.nodes.map(n=>n.gx+','+n.gy+':'+n.template).join(';'));
   }
   if(signatures.size<70)throw Error('Generator not diverse enough: '+kind);
   variants[kind]={count:expected,generated:90,unique:signatures.size};
  }
  return variants;
 });
 console.log('RANDOM DUNGEON LAYOUT PROPERTY TESTS:',JSON.stringify(layouts));
 const first=await page.evaluate(()=>window.LibationDungeon.snapshot());
 if(first.kind!=='challenge'||first.rooms!==14||first.node!==0||
    first.roomType!=='entrance'||first.room!==1)
  throw Error('Random wormhole entrance failed: '+JSON.stringify(first));
 await page.screenshot({path:'/tmp/libation-dungeon-room.png',fullPage:false});
 const positionBefore=first.player;
 await page.locator('[data-dmove="right"]').tap();
 const positionAfter=await page.evaluate(()=>window.LibationDungeon.snapshot().player);
 if(positionAfter.x<=positionBefore.x)
  throw Error('Touch D-pad did not move hero');
 if(!await page.evaluate(()=>window.LibationDungeon.debugCombatEncounter()))
  throw Error('Developer enemy combat unavailable');
 const beforeAttack=await page.evaluate(()=>window.LibationDungeon.snapshot());
 await page.locator('#lwDAttack').tap();
 const afterAttack=await page.evaluate(()=>window.LibationDungeon.snapshot());
 if(beforeAttack.enemies!==1||afterAttack.enemies!==0||afterAttack.gold<4||!afterAttack.cleared)
  throw Error('Forward sword strike did not defeat enemy: '+JSON.stringify({beforeAttack,afterAttack}));
 console.log('REAL TOUCH SWORD COMBAT:',JSON.stringify({beforeAttack,afterAttack}));
 if(!await page.locator('#lwDMap').isVisible()||!await page.locator('#lwDCanvas').isVisible())
  throw Error('Dungeon canvas or minimap is not visible');
 if(!await page.evaluate(()=>window.LibationDungeon.debugBossEncounter()))
  throw Error('Guardian fixture unavailable');
 const bossStart=await page.evaluate(()=>window.LibationDungeon.snapshot());
 if(bossStart.bossHP!==17||bossStart.hp!==14||bossStart.roomType!=='boss')
  throw Error('Full-strength boss not generated: '+JSON.stringify(bossStart));
 await page.screenshot({path:'/tmp/libation-dungeon-boss.png',fullPage:false});
 for(let strike=0;strike<10;strike++){
  await page.locator('#lwDAttack').tap();
  await page.waitForTimeout(375);
  if((await page.evaluate(()=>window.LibationDungeon.snapshot())).bossHP===null)break;
 }
 const bossEnd=await page.evaluate(()=>window.LibationDungeon.snapshot());
 if(bossEnd.bossHP!==null||bossEnd.enemies!==0||!bossEnd.cleared||bossEnd.defeated)
  throw Error('Full guardian not defeatable through touch: '+JSON.stringify({bossStart,bossEnd}));
 await page.screenshot({path:'/tmp/libation-dungeon-boss-cleared.png',fullPage:false});
 console.log('REAL TOUCH BOSS COMBAT:',JSON.stringify({bossStart,bossEnd}));
 const sealVictory=await page.evaluate(()=>{
  const d=window.LibationDungeon;for(let i=0;i<7;i++)d.move('right');
  return d.snapshot();
 });
 if(!sealVictory.completed)throw Error('Boss seal does not finish dungeon: '+JSON.stringify(sealVictory));
 await page.screenshot({path:'/tmp/libation-dungeon-victory.png',fullPage:false});
 await page.locator('#lwDRetry').click();
 const newSeed=await page.evaluate(()=>window.LibationDungeon.snapshot().layoutSeed);
 if(newSeed===first.layoutSeed)throw Error('Restart did not generate a new dungeon');
 // Physically walk through generated doorways with normal movement API.
 // Developer shortcuts clear combat only, never teleport between chambers.
 const progress=await page.evaluate(()=>{
  const d=window.LibationDungeon,plan=d.inspectLayout(d.snapshot().layoutSeed,'challenge');
  const opposite={up:'down',right:'left',down:'up',left:'right'};
  const offsets={up:[0,-1],right:[1,0],down:[0,1],left:[-1,0]};
  const doors={up:[8,1],right:[15,6],down:[8,11],left:[1,6]};
  const traversed=new Set(),allMoves=[];
  function walkTo(dir){
   const snap=d.snapshot(),start=snap.player,target=doors[dir];
   const walls=new Set(snap.walls),todo=[[start.x,start.y,[]]],seen=new Set();
   for(let i=0;i<todo.length;i++){
    const [x,y,path]=todo[i],key=x+','+y;
    if(seen.has(key))continue;seen.add(key);
    if(x===target[0]&&y===target[1]){
     for(const m of path)if(!d.move(m))throw Error('Cannot move through path: '+m);
     allMoves.push({from:snap.node,to:d.snapshot().node,direction:dir,length:path.length});
     return;
    }
    for(const [name,[dx,dy]] of Object.entries(offsets)){
     const xx=x+dx,yy=y+dy;
     if(xx<1||yy<1||xx>15||yy>11||walls.has(xx+','+yy)||seen.has(xx+','+yy))continue;
     todo.push([xx,yy,[...path,name]]);
    }
   }
   throw Error('Door inaccessible in room '+snap.node+' direction '+dir);
  }
  function explore(id){
   const here=d.snapshot();
   if(here.node!==id)throw Error('Wrong node while exploring '+JSON.stringify({id,here}));
   traversed.add(id);
   if(here.roomType==='boss')return;
   if(!here.cleared)d.debugClearRoom();
   for(const [dir,next] of Object.entries(plan.nodes[id].edges)){
    if(next===plan.boss||traversed.has(next))continue;
    walkTo(dir);
    if(d.snapshot().node!==next)throw Error('Door transition failed '+dir);
    explore(next);
    walkTo(opposite[dir]);
    if(d.snapshot().node!==id)throw Error('Reverse door failed '+dir);
   }
  }
  explore(0);
  // Graph's physical door layout (not a teleport) must allow reaching boss.
  let path=null,todo=[[d.snapshot().node,[]]],seen=new Set();
  for(let i=0;i<todo.length;i++){
   const [id,route]=todo[i];if(seen.has(id))continue;seen.add(id);
   if(id===plan.boss){path=route;break}
   for(const [dir,next] of Object.entries(plan.nodes[id].edges))
    todo.push([next,[...route,dir]]);
  }
  if(!path)throw Error('No route to generated guardian');
  for(const dir of path){
   if(!d.snapshot().cleared)d.debugClearRoom();
   walkTo(dir);
  }
  if(d.snapshot().node!==plan.boss)throw Error('Boss room cannot be reached');
  d.debugClearRoom();
  // Walk back out of the altar and then into the center seal.
  let guard=0;
  while(!d.snapshot().completed&&guard++<20){
   const p=d.snapshot().player;
   d.move(p.x<8?'right':p.x>8?'left':p.y<6?'down':'up');
  }
  const won=d.snapshot();
  if(!won.completed)throw Error('Boss seal cannot complete traversal');
  return {rooms:plan.count,explored:traversed.size,boss:plan.boss,
   moves:allMoves.length,transitions:allMoves.slice(0,8),won:won.completed,score:won.gold};
 });
 if(!progress.won||progress.explored<9||progress.moves<10)
  throw Error('Generated room navigation failed: '+JSON.stringify(progress));
 console.log('PROCEDURAL DUNGEON PHYSICAL DOOR TRAVERSAL:',JSON.stringify(progress));
 await page.screenshot({path:'/tmp/libation-dungeon-generated-victory.png',fullPage:false});
 await page.locator('#lwDReturn').click();
 if((await page.evaluate(()=>window.LibationDungeon.snapshot())).active)
  throw Error('Return did not restore GPS overworld');
 await page.locator('.dev-select-portal[data-kind="rupture"]').click();
 await page.locator('#enterVenue').click();
 await page.locator('#readyButton').click();
 const rupture=await page.evaluate(()=>window.LibationDungeon.snapshot());
 if(rupture.kind!=='rupture'||rupture.rooms!==10||rupture.maxHP!==18)
  throw Error('Ten-room rupture failed: '+JSON.stringify(rupture));
 await page.locator('#lwDExit').click();
 await page.locator('.dev-select-portal[data-kind="challenge"]').click();
 await page.locator('#enterVenue').click();
 await page.locator('#readyButton').click();
 if(!await page.evaluate(()=>window.LibationDungeon.debugBossEncounter()))
  throw Error('Cannot initialize boss defeat test');
 await page.waitForFunction(()=>window.LibationDungeon.snapshot().defeated===true,null,{timeout:22000});
 const defeated=await page.evaluate(()=>window.LibationDungeon.snapshot());
 if(defeated.hp!==0||defeated.completed||!defeated.active)
  throw Error('Boss does not cause legitimate defeat: '+JSON.stringify(defeated));
 await page.screenshot({path:'/tmp/libation-dungeon-defeat.png',fullPage:false});
 await page.locator('#lwDRetry').click();
 const afterDungeonRestart=await page.evaluate(()=>window.LibationDungeon.snapshot());
 if(!afterDungeonRestart.active||afterDungeonRestart.defeated||
    afterDungeonRestart.hp!==afterDungeonRestart.maxHP||afterDungeonRestart.node!==0)
  throw Error('Restart does not reset health/layout: '+JSON.stringify(afterDungeonRestart));
 await page.locator('#lwDReturn').click();
 await page.locator('#devPortalClear').click();
 if((await page.locator('.pixel-marker.demo.maplibregl-marker').count())!==0)
  throw Error('Developer portals not cleared');
 console.log('PLAYABLE PROCEDURAL DUNGEON TEST:',JSON.stringify({layouts,first,positionBefore,positionAfter,progress,rupture,defeated,afterDungeonRestart}));
 console.log('V15 STABLE GPS WORLD AUDIT:',JSON.stringify(inspect),
  'BROWSER ERRORS:',JSON.stringify(errors.slice(0,8)));
 if(inspect.mapOpacity<.99||inspect.baseOpacity<.99||
    inspect.baseDisplay==='none'||inspect.mapSize[0]<200||
    !inspect.avatarVisible||!inspect.avatarGeoAnchored||
    inspect.atlasVisible||inspect.oldWorldVisible||inspect.fakeBackgroundVisible||
    inspect.spriteDimensions[0]!==192||inspect.spriteDimensions[1]!==66){
   throw Error('Live geographic basemap or GPS avatar is obscured by broken raster world');
 }
 if(errors.some(e=>/Uncaught|ReferenceError|TypeError|SyntaxError/.test(e))){
   throw Error('Runtime JS exceptions: '+errors.join('; '));
 }
 }finally{await browser.close()}
})().catch(e=>{console.error(e.stack||String(e));process.exit(1)});
