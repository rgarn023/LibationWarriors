const {chromium}=require('/tmp/libation-test/node_modules/playwright-core');
const fs=require('fs');
(async()=>{
 const chrome=['/usr/bin/google-chrome','/usr/bin/google-chrome-stable','/usr/bin/chromium','/snap/bin/chromium'].find(fs.existsSync);
 if(!chrome)throw Error('Chrome/Chromium browser not present on Actions runner');
 const browser=await chromium.launch({executablePath:chrome,headless:true,
  args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-webgl']});
 const ctx=await browser.newContext({
  viewport:{width:390,height:844},deviceScaleFactor:2,isMobile:true,hasTouch:true,
  geolocation:{longitude:-76.284,latitude:36.771,accuracy:12},
  permissions:['geolocation']});
 const page=await ctx.newPage();
 let errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await page.goto('http://127.0.0.1:8123/',{waitUntil:'domcontentloaded',timeout:25000});
 try{await page.waitForFunction(()=>document.body.classList.contains('game-ready'),null,{timeout:35000})}
 catch(err){console.log('World loading timed out:',err.message)}
 await page.waitForTimeout(2600);
 const inspect=await page.evaluate(()=>{
  const c=document.getElementById('gameWorld'),state=typeof worldState==='undefined'?null:worldState;
  let colorCount=0;
  if(c?.width&&c?.height){
   const ctx=c.getContext('2d'),pix=ctx.getImageData(0,0,Math.min(160,c.width),Math.min(160,c.height)).data;
   const colors=new Set();
   for(let i=0;i<pix.length;i+=400)colors.add([pix[i],pix[i+1],pix[i+2]].join(','));
   colorCount=colors.size;
  }
  return {gameReady:document.body.classList.contains('game-ready'),
   mapLoaded:typeof mapLoaded!=='undefined'&&mapLoaded,
   geolocation:typeof currentGeolocation!=='undefined'&&!!currentGeolocation,
   canvasSize:c?[c.width,c.height]:null,
   colorCount,geographicFeatures:state?Object.fromEntries(Object.entries(state.features).map(([k,v])=>[k,v.length])):{},
   portals:typeof venues!=='undefined'?venues.length:0};
 });
 await page.screenshot({path:'/tmp/libation-world-screenshot.png',fullPage:false});
 console.log('SCENE AUDIT:',JSON.stringify(inspect),'BROWSER ERRORS:',JSON.stringify(errors.slice(0,15)));
 await browser.close();
 if(!inspect.gameReady||!inspect.canvasSize?.[0]||!inspect.geolocation||inspect.colorCount<3){
  throw Error('Game renderer/geolocation/canvas smoke test did not pass');
 }
 if(errors.some(e=>/Uncaught|ReferenceError|TypeError|SyntaxError/.test(e)))throw Error('JavaScript errors: '+errors.join('; '));
})().catch(e=>{console.error(e.stack||String(e));process.exit(1)});
