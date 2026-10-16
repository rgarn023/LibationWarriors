// Deterministic browser test for the V13 geographic RPG renderer.
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
   const c=document.querySelector('#gameOverworldArt');
   return !!(window.LibationGameWorld?.diagnostics().ready && c?.width>100
    && document.querySelector('#gpsMarker')
    && document.querySelector('#online')?.textContent?.includes('LIVE')
    && document.querySelector('#locationReadout')?.textContent?.includes('GPS POSITION FOUND'));
  },null,{timeout:14500});
 }catch(waitError){
  const diag=await page.evaluate(()=>({
    ready:!!window.LibationGameWorld?.diagnostics().ready,
    features:window.LibationGameWorld?.diagnostics().features,
    canvas:!!document.querySelector('#gameOverworldArt'),
    mapLoaded:typeof mapLoaded!=='undefined'?mapLoaded:'undefined',
    gps:typeof currentGeolocation!=='undefined'?currentGeolocation:'undefined',
    provider:typeof provider!=='undefined'?provider:'undefined',
    banner:document.querySelector('#liveLocationBanner')?.textContent?.slice(0,150),
    status:document.querySelector('#online')?.textContent?.slice(0,100),
    maplibre:typeof window.maplibregl,
    scripts:[...document.scripts].map(x=>x.src).filter(Boolean).slice(-5)
  }));
  console.log('V13 TIMEOUT DIAGNOSTIC',JSON.stringify(diag),'BROWSER ERRORS',JSON.stringify(errors));
  await page.screenshot({path:'/tmp/libation-world-screenshot.png',fullPage:false});
  throw waitError;
 }
 await page.waitForTimeout(500);
 const inspect=await page.evaluate(()=>{
  const c=document.querySelector('#gameOverworldArt');
  const ctx=c.getContext('2d',{willReadFrequently:true});
  const sample=ctx.getImageData(0,0,c.width,c.height).data;
  const colors=new Set();
  for(let i=0;i<sample.length;i+=40)colors.add(
   sample[i]+','+sample[i+1]+','+sample[i+2]);
  const marker=document.querySelector('#gpsMarker');
  const mapLoaded=!!document.querySelector('#online')?.textContent?.includes('LIVE');
  const geolocation=!!document.querySelector('#locationReadout')?.textContent?.includes('GPS POSITION FOUND');
  return {mapLoaded,geolocation,
   features:window.LibationGameWorld.diagnostics().features,
   canvasSize:[c.width,c.height],canvasDisplay:getComputedStyle(c).display,
   colors:colors.size,hasGPSMarker:!!marker,
   oldOverlayHidden:getComputedStyle(document.querySelector('#gameWorld')).display==='none',
   fakeIllustrationHidden:getComputedStyle(document.querySelector('#illustratedBackdrop')).display==='none',
   gpsOnMap:!!marker?.closest('.maplibregl-marker'),
   liveGeographyReady:document.body.classList.contains('game-geography-ready')};
 });
 const spriteDimensions=await page.evaluate(async()=>{
   const img=new Image();img.src='./avatar_snes.png';await img.decode();
   return [img.naturalWidth,img.naturalHeight];
 });
 inspect.spriteDimensions=spriteDimensions;
 await page.screenshot({path:'/tmp/libation-world-screenshot.png',fullPage:false});
 console.log('V14 WORLD AUDIT:',JSON.stringify(inspect),
   'JS ERRORS:',JSON.stringify(errors.slice(0,12)));
 if(!inspect.mapLoaded||!inspect.geolocation||inspect.features<3||
    inspect.colors<6||!inspect.hasGPSMarker||!inspect.oldOverlayHidden||
    !inspect.fakeIllustrationHidden||!inspect.liveGeographyReady||
    inspect.spriteDimensions[0]!==192||inspect.spriteDimensions[1]!==66){
   throw Error('Georeferenced RPG world browser smoke test failed');
 }
 if(errors.some(e=>/Uncaught|ReferenceError|TypeError|SyntaxError/.test(e))){
   throw Error('Runtime JS exceptions: '+errors.join('; '));
 }
 }finally{await browser.close()}
})().catch(e=>{console.error(e.stack||String(e));process.exit(1)});
