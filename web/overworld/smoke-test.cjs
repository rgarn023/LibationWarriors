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
  {type:'Feature',properties:{kind:'building'},geometry:{type:'Polygon',coordinates:[[[-76.2842,36.7702],[-76.284,36.7702],[-76.284,36.7704],[-76.2842,36.7704],[-76.2842,36.7702]]]}},
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
  status:200,contentType:'application/json',body:'{"elements":[]}'
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
 await page.screenshot({path:'/tmp/libation-world-screenshot.png',fullPage:false});
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
