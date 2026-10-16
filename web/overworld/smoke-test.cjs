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
  {type:'Feature',properties:{kind:'water'},geometry:{type:'Polygon',coordinates:[[[-76.281,36.767],[-76.278,36.767],[-76.278,36.774],[-76.281,36.774],[-76.281,36.767]]]}},
  {type:'Feature',properties:{kind:'building'},geometry:{type:'Polygon',coordinates:[[[-76.28448,36.7713],[-76.28430,36.7713],[-76.28430,36.77148],[-76.28448,36.77148],[-76.28448,36.7713]]]}},
  {type:'Feature',properties:{kind:'road'},geometry:{type:'LineString',coordinates:[[-76.287,36.7706],[-76.285,36.7708],[-76.281,36.7713],[-76.277,36.772]]}},
  {type:'Feature',properties:{kind:'trail'},geometry:{type:'LineString',coordinates:[[-76.2847,36.769],[-76.2841,36.77],[-76.284,36.773]]}}
 ]};
 const mockStyle={version:8,sources:{nearby:{type:'geojson',data:featureCollection}},
  layers:[
   {id:'background',type:'background',paint:{'background-color':'#a1d2a0'}},
   {id:'park',type:'fill',source:'nearby',filter:['==',['get','kind'],'park'],paint:{'fill-color':'#6eaf83'}},
   {id:'water',type:'fill',source:'nearby',filter:['==',['get','kind'],'water'],paint:{'fill-color':'#55acc9'}},
   {id:'building',type:'fill',source:'nearby',filter:['==',['get','kind'],'building'],paint:{'fill-color':'#bdaa80'}},
   {id:'road-primary',type:'line',source:'nearby',filter:['==',['get','kind'],'road'],paint:{'line-color':'#e8d6b1','line-width':7}},
   {id:'path',type:'line',source:'nearby',filter:['==',['get','kind'],'trail'],paint:{'line-color':'#efe5c3','line-width':3}}
  ]};
 await page.route('**/styles/liberty**',route=>route.fulfill({
  status:200,contentType:'application/json',body:JSON.stringify(mockStyle)
 }));
 await page.route('**/api/interpreter**',route=>route.fulfill({
  status:200,contentType:'application/json',body:JSON.stringify({elements:[
    {type:'node',id:55101,lat:36.77128,lon:-76.28408,tags:{amenity:'pub',name:'Test Fixture Tavern'}},
    {type:'node',id:55102,lat:36.77143,lon:-76.28388,tags:{craft:'brewery',name:'Test Fixture Brewery'}},
    {type:'node',id:55103,lat:36.77090,lon:-76.28420,tags:{amenity:'restaurant',name:'Restaurant Without Alcohol Tag'}}
   ]})
 }));
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
 // A close, tilted local-world camera is part of the gameplay contract.
 const readCamera=()=>page.locator('#map').evaluate(el=>({
   zoom:Number(el.dataset.cameraZoom),pitch:Number(el.dataset.cameraPitch),
   bearing:Number(el.dataset.cameraBearing)
 }));
 const texture=await page.locator('#map').getAttribute('data-terrain-tiles');
 if(texture!=='geographic')throw Error('Native georeferenced terrain tile materials absent: '+texture);
 const depth=await page.locator('#map').getAttribute('data-geographic-depth');
 if(depth!=='on')throw Error('Grounded building footprint depth missing: '+depth);
 const initialCamera=await readCamera();
 console.log('LOCAL EXPLORER CAMERA:',JSON.stringify(initialCamera));
 if(!(initialCamera.zoom>=18.1&&initialCamera.zoom<=18.4&&
   initialCamera.pitch>=59&&initialCamera.pitch<=68))
  throw Error('Camera regressed to distant overhead map: '+JSON.stringify(initialCamera));
 // Local zoom is bounded; plus/minus buttons must change real map scale.
 await page.locator('#zoomOutBtn').click();
 await page.waitForTimeout(450);
 const zoomedOut=await readCamera();
 if(!(zoomedOut.zoom<initialCamera.zoom-.18&&zoomedOut.zoom>=17.54))
  throw Error('Zoom-out control is still locked: '+JSON.stringify({initialCamera,zoomedOut}));
 await page.locator('#zoomInBtn').click();
 await page.waitForTimeout(450);
 const restored=await readCamera();
 if(Math.abs(restored.zoom-initialCamera.zoom)>.06)
  throw Error('Zoom-in failed to restore close camera: '+JSON.stringify(restored));
 console.log('LOCAL ZOOM CONTROLS:',JSON.stringify({initialCamera,zoomedOut,restored}));
 const pixelAudit=await inspectMarkerAnchors();
 console.log('ON-SCREEN GEOGRAPHIC MARKER AUDIT:',JSON.stringify(pixelAudit));
 if(!anchored(pixelAudit.avatar)||!pixelAudit.sprite.loaded||
    pixelAudit.sprite.width<32||pixelAudit.sprite.height<32||
    pixelAudit.sprite.display==='none'||!pixelAudit.portals.every(anchored))
  throw Error('Player or portal sprite does not render at true GPS coordinates: '+JSON.stringify(pixelAudit));
 await page.waitForTimeout(3500); // Allow location toast to clear.
 await page.screenshot({path:'/tmp/libation-world-screenshot.png',fullPage:false});
 // Simulate actual location movement and then a horizontal camera swipe.
 await context.setGeolocation({longitude:-76.2838,latitude:36.77105,accuracy:6});
 await page.waitForFunction(()=>document.body.classList.contains('walking'),null,{timeout:4500});
 const walkingFirst=await page.locator('#gpsMarker img.sprite').getAttribute('src');
 await page.waitForTimeout(360);
 const walkingSecond=await page.locator('#gpsMarker img.sprite').getAttribute('src');
 if(walkingFirst===walkingSecond)
  throw Error('Walking still uses a single static avatar frame');
 console.log('WALK FRAME CHANGED:',walkingFirst!==walkingSecond);
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
 let bearingDelta=Math.abs(afterTurn.bearing-beforeSwipe.bearing);
 bearingDelta=Math.min(bearingDelta,360-bearingDelta);
 if(bearingDelta<45||Math.abs(afterTurn.pitch-beforeSwipe.pitch)>2)
  throw Error('Android finger drag did not reliably turn camera: '+JSON.stringify({beforeSwipe,afterTurn}));
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
 console.log('TWO-FINGER PINCH:',JSON.stringify(pinched));
 await page.locator('#zoomInBtn').click();
 await page.locator('#zoomInBtn').click();
 await page.locator('#zoomInBtn').click();
 await page.waitForTimeout(500);
 await swipeTouch([90,650],[90,490]);
 const afterTilt=await readCamera();
 if(afterTilt.pitch<67||Math.abs(afterTilt.zoom-18.25)>.15)
  throw Error('Android vertical swipe did not tilt camera toward the horizon: '+JSON.stringify(afterTilt));
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
