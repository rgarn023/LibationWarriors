/* Original Mana-inspired 16-bit fantasy character sprite sheets.
 * Artwork is authored frame-by-frame at native 64x96 and 68x84 pixel resolution.
 * This module owns no gameplay state; hit detection lives in dungeon.js.
 */
(()=>{
'use strict';
const TAU=Math.PI*2,actions=['idle','walk','attack','hurt','defeat'];
const dirs=['down','left','right','up'];
const ink='#252b3c',gold='#f5d38c',ivory='#f7e7bd';
const cache=new Map();
const pirateSheet=new Image();
let pirateSheetReady=false;
pirateSheet.decoding='async';
pirateSheet.onload=()=>{pirateSheetReady=pirateSheet.naturalWidth===1344&&pirateSheet.naturalHeight===984};
pirateSheet.onerror=()=>{pirateSheetReady=false};
pirateSheet.src='./assets/pirate-action-atlas.webp';
const portraitFrames={idle:[2,6],walk:[1,12],attack:[0,8],
 dodge:[3,8],hurt:[4,4],defeat:[5,6]};
function sheetPose(who,dir,action,frame){
 return pirateSheetReady&&who?.gender!=='female'&&
  String(who?.faction||'Pirate').toLowerCase().includes('pirate')&&
  (dir==='right'||dir==='left')&&Object.hasOwn(portraitFrames,action);
}
function drawSheetFrame(ctx,who,dir,action,frame,x,y,scale=1){
 const [row,count]=portraitFrames[action];
 ctx.save();ctx.imageSmoothingEnabled=false;
 if(dir==='left'){ctx.translate(x,0);ctx.scale(-1,1);x=0}
 const width=Math.round(104*scale),height=Math.round(148*scale);
 ctx.drawImage(pirateSheet,(frame%count)*112,row*164,112,164,
   Math.round(x-width/2),Math.round(y-height+11*scale),width,height);
 ctx.restore();
}

function rect(c,x,y,w,h,col){c.fillStyle=col;c.fillRect(Math.round(x),Math.round(y),Math.ceil(w),Math.ceil(h))}
function poly(c,pts,col,line=ink,width=2){c.beginPath();pts.forEach(([x,y],i)=>i?c.lineTo(x,y):c.moveTo(x,y));c.closePath();c.fillStyle=col;c.fill();if(line){c.strokeStyle=line;c.lineWidth=width;c.lineJoin='round';c.stroke()}}
function oval(c,x,y,rx,ry,col){c.beginPath();c.ellipse(x,y,rx,ry,0,0,TAU);c.fillStyle=col;c.fill()}
function ln(c,x,y,x2,y2,col=ink,w=2){c.beginPath();c.moveTo(x,y);c.lineTo(x2,y2);c.strokeStyle=col;c.lineWidth=w;c.lineCap='round';c.stroke()}
function colorConfig(w){
 const fem=w?.gender==='female',f=String(w?.faction||'Pirate').toLowerCase();
 let hash=2166136261;for(const a of String(w?.id||'')){hash=Math.imul(hash^a.charCodeAt(0),16777619)}
 const variant=(hash>>>0)%3;
 return {
  hair:fem?'#f4cf79':variant===2?'#c5a26c':'#a9774c',
  shadowHair:fem?'#9c6a51':'#513846',
  tunic:fem?(variant===1?'#446c81':'#437ba9'):
    f.includes('witch')?'#7854a0':variant===1?'#4a886c':variant===2?'#99609a':'#ca6653',
  trim:fem?'#a8e7e8':'#f8b977',
  cape:fem?'#2f568c':'#784966',capeLight:fem?'#718fc3':'#b86e78',
  skin:fem?'#f1bd98':'#e7aa88',
  skinShade:fem?'#ca896e':'#b87565',
  boot:'#624b43',bootHi:'#a78765',fem
 };
}
function heroFrame(w,dir,act,n){
 const phase=act==='walk'?n%12:n%8,who=colorConfig(w),
  key=['hero',String(w?.id||'basic'),dir,act,phase,
  w?.gender||'male',w?.faction||'Pirate'].join(':');
 if(cache.has(key))return cache.get(key);
 const cvs=document.createElement('canvas');cvs.width=64;cvs.height=96;
 const c=cvs.getContext('2d');c.imageSmoothingEnabled=false;
 const isMove=act==='walk',isAtk=act==='attack',back=dir==='up',side=dir==='left'||dir==='right';
 const cyc=Math.sin(phase*Math.PI/(isMove?6:4)),
  foot1=isMove?Math.round(cyc*6):0,foot2=-foot1;
 const bob=isMove?Math.round(Math.abs(cyc)*3):act==='idle'?(phase%4===0?1:0):0;
 const flow=isMove?Math.round(Math.cos(phase*Math.PI/6)*4):n%2?1:0;
 c.save();if(dir==='left'){c.translate(64,0);c.scale(-1,1)}
 if(act==='defeat'){c.translate(11,77);c.rotate(-.99);c.translate(-11,-77)}
 oval(c,32,89,23,6,'#10223789');
 // Boots and legs: distinct silhouettes at every stride.
 for(const [x,k] of [[20,foot1],[38,foot2]]){
  poly(c,[[x-5,65+k],[x+5,64+k],[x+7,83+k],[x+11,86+k],
   [x+10,90+k],[x-8,90+k],[x-8,86+k]],ink,ink,1);
  poly(c,[[x-3,65+k],[x+4,66+k],[x+5,82+k],[x-4,83+k]],who.boot);
  rect(c,x-2,67+k,3,12,who.bootHi);
  rect(c,x-7,85+k,16,3,'#87684e');
  rect(c,x-5,86+k,10,2,'#c6a16a');
  rect(c,x-6,89+k,15,2,'#393946');
 }
 c.translate(0,-bob);
 // Floating mantle, cape trim, shoulder flaps.
 poly(c,[[18,35],[44,35],[54,59],[52+flow,81],[43+flow,88],
  [19+flow,85],[12+flow,78],[10,51]],who.cape,ink,3);
 poly(c,[[23,44],[45,44],[49+flow,77],[44+flow,83],
  [39+flow,81],[38,57]],who.capeLight,null);
 ln(c,16,51,17+flow,80,'#deb17d',3);
 ln(c,47,49,49+flow,80,who.trim,3);
 poly(c,[[20,36],[43,35],[50,44],[46,68],[19,70],[14,46]],
  ink,ink,2);
 poly(c,[[20,39],[42,38],[47,47],[44,67],[21,67],[18,45]],who.tunic,null);
 rect(c,20,39,22,4,who.trim);rect(c,24,44,14,12,'#ecd6aa');
 rect(c,29,46,5,8,'#8f785d');rect(c,25,56,16,3,'#4c4555');
 // Cross-body strap and satchel are readable even on phone.
 poly(c,[[20,41],[23,41],[41,59],[39,62]],'#6a483f',null);
 ln(c,23,41,40,58,'#deb77f',1.4);
 rect(c,14,56,13,17,'#463a40');rect(c,16,58,10,11,'#9e714c');
 rect(c,19,60,4,4,gold);rect(c,19,67,6,2,ink);
 rect(c,17,66,31,6,ink);rect(c,18,67,29,4,'#99704a');
 rect(c,31,66,8,7,gold);rect(c,34,67,3,4,ink);
 // Oversized soft leather shoulder pads with metal studs.
 poly(c,[[17,39],[9,43],[11,53],[19,55],[23,44]],'#4e4e57',ink,2);
 poly(c,[[46,38],[54,42],[53,53],[44,54],[41,44]],'#5d5364',ink,2);
 rect(c,12,44,7,3,gold);rect(c,46,43,6,3,gold);
 rect(c,15,48,2,2,ivory);rect(c,50,48,2,2,ivory);
 // Arm movement and weapon hand, independently following attack phases.
 const lift=isAtk?[3,14,25,30,17,6,0,0][phase]:0;
 rect(c,9,52,10,16,ink);rect(c,11,53,7,11,who.tunic);
 rect(c,11,62,8,7,'#564249');rect(c,12,65,7,7,who.skinShade);
 rect(c,47,52-lift,10,17,ink);rect(c,49,54-lift,6,11,who.tunic);
 rect(c,48,63-lift,8,7,'#4e3f47');
 oval(c,52,69-lift,5,5,who.skin);
 if(isAtk){
  const angles=[0,-.3,-.8,-1.45,-2.15,-2.5,-.8,0];
  c.save();c.translate(51,66-lift);c.rotate(angles[phase]);
  // Thick alloy edge, guard and pommel with four-tone metal finish.
  poly(c,[[-4,-48],[0,-56],[5,-49],[6,-9],[-4,-9]],'#a9cbd7',ink,2);
  rect(c,0,-48,2,37,'#f8ffff');rect(c,-6,-11,15,4,gold);
  rect(c,-2,-7,6,11,'#554a53');rect(c,-1,1,5,4,gold);
  c.restore();
 }else{
  // Sheathed silver blade at the side gives a readable warrior silhouette.
  ln(c,51,59,56,87,'#708491',5);ln(c,52,60,54,85,'#d8e6e7',2);
  ln(c,46,70,58,68,gold,4);
 }
 // Large expressive head, lighted face, distinct front/side/back hair.
 poly(c,[[22,14],[43,14],[48,21],[47,36],[38,41],[23,38],[17,29],[18,20]],
  who.skin,ink,3);
 rect(c,20,27,5,7,who.skinShade);
 rect(c,44,27,3,6,who.skinShade);
 if(back){
  poly(c,[[17,18],[22,10],[36,5],[46,15],[49,32],[41,39],
   [38,32],[33,39],[25,34],[19,37]],who.hair,ink,2);
  poly(c,[[23,11],[32,8],[42,15],[39,19],[28,17]],'#f8d791',null);
  rect(c,24,32,3,6,who.shadowHair);
 }else{
  poly(c,[[17,24],[17,12],[25,7],[33,8],[39,4],[47,11],
   [50,19],[44,25],[38,21],[32,27],[27,21],[21,30]],
   who.hair,ink,2);
  poly(c,[[19,14],[26,10],[35,11],[32,15],[24,16]],'#f6d495',null);
  rect(c,20,23,4,8,who.shadowHair);
  if(side){
   rect(c,40,28,4,4,ink);rect(c,41,28,2,2,'#fff7e1');
   rect(c,47,34,2,2,who.skinShade);
  }else{
   rect(c,26,28,4,4,ink);rect(c,39,28,4,4,ink);
   rect(c,27,28,2,2,'#fff8dc');rect(c,40,28,2,2,'#fff8dc');
   rect(c,34,34,4,2,'#b96d67');
   rect(c,35,31,2,2,who.skinShade);
  }
 }
 // Adventurer's embroidered headband, NOT a pirate hat.
 rect(c,20,19,26,4,'#8b4855');rect(c,23,19,19,2,gold);
 rect(c,34,17,6,6,who.trim);
 if(side)poly(c,[[17,21],[12,23],[10+flow,37],[15+flow,36]],'#dbbc83',null);
 if(act==='hurt'){
  c.globalAlpha=.35;rect(c,18+phase%3,17,30,24,phase%2?'#f7a1a0':'#fff9dd');c.globalAlpha=1;
 }
 c.restore();
 cache.set(key,cvs);if(cache.size>440)cache.delete(cache.keys().next().value);
 return cvs;
}
function beastFrame(e,frame,action='idle'){
 const kind=e.kind||'slime',v=e.variant||0,phase=frame%8;
 const key=['enemy',kind,v,action,phase,e.boss?'boss':'minion',
  e.awake===false?'sleep':'awake'].join(':');
 if(cache.has(key))return cache.get(key);
 const cv=document.createElement('canvas');cv.width=68;cv.height=88;
 const c=cv.getContext('2d');c.imageSmoothingEnabled=false;
 const pulse=Math.sin(phase*Math.PI/4);
 const bob=action==='walk'?Math.round(Math.abs(pulse)*5):
  action==='hurt'?(phase%2?3:0):
  action==='attack'?Math.round(Math.sin(phase*Math.PI/4)*4):
  Math.round(Math.abs(pulse)*2);
 const p=(x,y,w,h,col)=>rect(c,x,y,w,h,col);
 const beastPal=[
  {main:'#8d6db0',light:'#c5a6e2',shade:'#4c3d70',eye:'#fceba9'},
  {main:'#5c9a9b',light:'#b4e0be',shade:'#345b78',eye:'#fff4c6'},
  {main:'#ad755e',light:'#e9b884',shade:'#65485f',eye:'#e9f9f6'}
 ][v%3];
 c.save();oval(c,34,78,23,6,'#0b1a2a75');
 if(action==='defeat'){c.translate(7,67);c.rotate(-.35);c.translate(-7,-67)}
 if(action==='attack')c.translate(Math.round(Math.sin(phase*Math.PI/4)*2),0);
 c.translate(0,-bob);
 const eye=(x,y)=>{p(x-2,y-2,6,6,ink);p(x,y-1,3,3,beastPal.eye);p(x+1,y,1,1,'#ffffff')};
 const horn=(x,y,dx=1)=>poly(c,[[x,y+10],[x+dx*3,y-4],[x+dx*10,y+14]],beastPal.light,ink,1.8);
 const sword=(x,y)=>{p(x,y-22,7,30,ink);p(x+1,y-22,5,26,'#b9d6dd');p(x+2,y-19,2,22,'#fffcee');p(x-5,y+5,17,5,gold)};
 if(kind==='slime'){
  poly(c,[[13,65],[12,56],[18,42],[26,34],[41,34],[53,47],[57,65],
   [51,75],[20,75]],beastPal.shade,ink,3);
  poly(c,[[17,59],[22,44],[29,38],[43,41],[52,58],[49,69],[22,69]],
   beastPal.main,null);
  p(22,43,16,5,beastPal.light);p(19,52,5,10,'#d5f7dd');
  eye(26,58);eye(42,58);p(32,65,6,3,ink);
  p(17,72,9,4,beastPal.light);p(45,72,8,3,beastPal.light);
 }else if(kind==='bat'||kind==='wisp'){
  if(kind==='bat'){
   const wing=phase%2?12:-2;
   poly(c,[[29,37],[17,18-wing],[4,28-wing],[9,50],[22,46]],
    beastPal.main,ink,3);
   poly(c,[[39,37],[52,18-wing],[64,28-wing],[59,50],[46,46]],
    beastPal.main,ink,3);
   oval(c,34,48,14,18,beastPal.shade);
   horn(25,25,-1);horn(43,25,1);eye(29,46);eye(41,46);
   p(32,57,5,4,'#fff3df');
  }else{
   poly(c,[[34,16],[46,27],[53,46],[48,61],[36,73],[20,59],
    [17,43],[23,29]],beastPal.main,ink,3);
   poly(c,[[32,23],[42,33],[45,50],[36,66],[24,53],[26,35]],
    beastPal.light,null);
   p(32,30,7,11,'#fff3ce');eye(27,45);eye(41,45);
   for(let i=0;i<4;i++){let a=i*TAU/4+phase*.14;p(34+Math.cos(a)*23,44+Math.sin(a)*18,4,5,gold)}
  }
 }else if(kind==='spider'){
  for(let j=0;j<4;j++)for(const side of [-1,1]){
   const yy=32+j*9+Math.round(pulse*(j%2?3:-3));
   ln(c,34+side*10,43,34+side*22,yy,beastPal.shade,5);
   ln(c,34+side*22,yy,34+side*29,yy+10,beastPal.light,4);
  }
  oval(c,34,49,17,21,beastPal.shade);oval(c,34,34,12,13,beastPal.main);
  poly(c,[[34,28],[26,47],[35,65],[43,47]],beastPal.light,ink,2);
  for(let i=0;i<4;i++)eye(26+i*5,35+i%2*4);
 }else if(kind==='mimic'){
  p(12,44,45,34,ink);p(14,47,42,27,'#75513e');
  p(18,53,34,18,'#b17c4d');p(23,55,4,14,beastPal.light);
  for(let i=0;i<5;i++)poly(c,[[19+i*7,49],[22+i*7,60],[25+i*7,49]],ivory,ink,1);
  poly(c,[[13,45],[10,32],[18,20],[56,21],[62,37],[57,47]],
   '#8e5365',ink,3);
  p(18,28,34,5,'#d2a465');p(25,34,7,5,beastPal.eye);
  eye(21,29);eye(47,29);p(31,47,6,5,gold);
 }else if(kind==='thornbound'||kind==='shaman'){
  poly(c,[[22,65],[15,39],[20,22],[32,14],[47,23],[55,49],
   [47,71],[36,75]],'#577052',ink,3);
  poly(c,[[21,45],[24,29],[34,20],[43,30],[48,49]],
   '#94ad69',null);
  if(kind==='thornbound'){
   horn(21,20,-1);horn(45,19,1);
   p(24,57,7,18,'#775940');p(39,58,8,17,'#775940');
   eye(28,40);eye(42,40);p(30,51,12,4,'#3a554c');
   ln(c,19,50,9,69,'#9a724f',5);ln(c,51,51,61,71,'#9a724f',5);
  }else{
   p(17,23,36,11,beastPal.main);p(21,16,28,9,'#ae8b6d');
   for(let i=0;i<5;i++)p(20+i*7,21+(i%2)*2,3,3,'#f7e3b9');
   eye(29,44);eye(42,44);ln(c,52,35,57,73,'#9f8253',4);
   oval(c,55,29,11,9,beastPal.light);
  }
 }else if(kind==='brute'||kind==='guardian'||kind==='sentinel'||kind==='acolyte'){
  const boss=kind==='guardian',brute=kind==='brute';
  const base=brute?'#92654f':boss?'#675d8f':'#64778b';
  const hi=brute?'#d7a16b':boss?'#c7a4e4':'#c1d2d8';
  const shade=brute?'#543e39':'#343b55';
  poly(c,[[14,34],[18,20],[34,15],[49,20],[58,40],[53,70],
   [45,77],[19,77]],shade,ink,3);
  poly(c,[[17,33],[25,25],[44,25],[53,38],[49,59],[19,59]],base,ink,2);
  p(22,36,25,9,hi);p(28,44,13,12,shade);p(30,46,9,9,boss?'#d88cda':'#9adeca');
  poly(c,[[15,19],[23,7],[45,7],[54,19],[49,33],[18,33]],
   shade,ink,3);
  p(24,13,22,10,hi);p(25,24,19,6,base);
  eye(27,24);eye(42,24);
  if(boss){horn(19,8,-1);horn(49,8,1)}
  poly(c,[[13,37],[6,46],[10,67],[21,63]],base,ink,2);
  poly(c,[[55,37],[61,45],[58,68],[47,64]],base,ink,2);
  p(22,66,9,13,shade);p(40,66,9,13,shade);
  if(brute){p(2,57,14,13,'#ac7b5a');p(51,57,15,13,'#ac7b5a')}
  else sword(60,57);
 }else{
  // Skeletal warriors, archers, robed mages, specters and leeches have
  // individually keyed face, weapon, limb, cowl and shoulder silhouettes.
  const caster=['mage','specter','leech'].includes(kind);
  const bone=['skeleton','archer'].includes(kind);
  const main=caster?beastPal.shade:bone?'#b9b2a1':beastPal.main;
  poly(c,[[20,34],[27,25],[43,25],[52,43],[52,70],[17,72],[15,47]],
   caster?beastPal.shade:main,ink,3);
  if(caster){
   poly(c,[[20,33],[25,15],[42,10],[49,32],[50,64],[34,78],
    [16,68]],beastPal.main,ink,3);
   p(26,30,20,19,'#282f48');eye(28,36);eye(43,36);
   if(kind==='leech'){
    for(let i=0;i<3;i++)ln(c,20+i*12,67,11+i*21,82,beastPal.light,3);
   }else if(kind==='mage'){
    ln(c,54,26,60,75,'#95734f',4);oval(c,54,21,9,10,beastPal.light);
   }else{p(31,57,10,5,ink);p(22,70,7,9,beastPal.light)}
  }else{
   oval(c,34,23,15,15,'#d7cab5');p(19,19,29,14,'#e9d8bf');
   eye(28,22);eye(41,22);
   p(29,33,4,6,'#69564f');p(40,33,4,6,'#69564f');
   p(19,41,31,7,beastPal.light);
   p(21,60,9,18,'#5a4d4b');p(40,60,9,18,'#5a4d4b');
   if(kind==='archer'){
    c.strokeStyle=gold;c.lineWidth=4;c.beginPath();c.arc(58,45,25,-1.3,1.3);c.stroke();
    ln(c,63,20,63,69,ivory,2);ln(c,16,44,50,41,gold,3);
   }else sword(59,49);
  }
 }
 // Frame-dependent impact recoil and a readable small health pip.
 if(e.hitUntil&&e.hitUntil>performance.now()){
  rect(c,19+phase%2,24,30,34,'#fff5ce59');
 }
 c.restore();
 cache.set(key,cv);if(cache.size>440)cache.delete(cache.keys().next().value);
 return cv;
}
function drawHero(c,s,now){
 const action=s.animation||'idle';
 if(sheetPose(s.warrior,s.face,action,0)){
  const t=now<s.hitStopUntil?s.lastImpactAt:now;
  let frame=0;
  if(action==='walk')frame=Math.floor(t/68)%12;
  else if(action==='attack')frame=Math.min(7,Math.max(0,Math.floor((t-s.attackStart)/52)));
  else if(action==='idle')frame=Math.floor(t/260)%6;
  else if(action==='hurt')frame=Math.floor(t/95)%4;
  else if(action==='dodge')frame=Math.min(7,Math.max(0,Math.floor((t-(s.dodgeUntil-440))/55)));
  else frame=5;
  drawSheetFrame(c,s.warrior,s.face,action,frame,s.player.x*32+16,s.player.y*32+16);
  return;
 }
 // Pause the contact pose for just 64ms to make every landed strike punchy.
 const t=now<s.hitStopUntil?s.lastImpactAt:now;
 let frame=0;
 if(action==='attack')frame=Math.min(7,Math.max(0,Math.floor((t-s.attackStart)/52)));
 else if(action==='walk')frame=Math.floor(t/65)%12;
 else if(action==='hurt')frame=Math.floor(t/82)%8;
 else if(action==='idle')frame=Math.floor(t/450)%4;
 else frame=7;
 const image=heroFrame(s.warrior,s.face,action,frame);
 const x=s.player.x*32+16,y=s.player.y*32+16;
 c.save();c.imageSmoothingEnabled=false;
 c.drawImage(image,Math.round(x-44),Math.round(y-119),88,132);
 c.restore();
}
function previewHero(who,dir='down',act='idle',frame=0){
 if(sheetPose(who,dir,act,frame)){
  const cv=document.createElement('canvas');cv.width=128;cv.height=192;
  drawSheetFrame(cv.getContext('2d'),who,dir,act,frame,64,170,1.16);
  return cv.toDataURL('image/png');
 }
 const img=heroFrame(who,dir,act,frame);
 const cv=document.createElement('canvas');cv.width=128;cv.height=192;
 const c=cv.getContext('2d');c.imageSmoothingEnabled=false;
 c.drawImage(img,0,0,128,192);return cv.toDataURL('image/png');
}
function drawEnemy(c,e,now){
 const action=e.hitUntil>now?'hurt':
  e.windup>0?'attack':
  e.visualFrom&&now-e.visualFrom.t<180?'walk':'idle';
 const frame=Math.floor(now/(action==='walk'?84:action==='attack'?70:150))%8;
 const img=beastFrame(e,frame,action);
 const f=e.visualFrom,t=f?Math.max(0,Math.min(1,(now-f.t)/145)):1;
 const x=(f?f.x+(e.x-f.x)*t:e.x)*32+16;
 const y=(f?f.y+(e.y-f.y)*t:e.y)*32+16,large=e.boss?1.45:1;
 const w=94*large,h=120*large;
 c.save();c.imageSmoothingEnabled=false;
 if(e.windup) {c.fillStyle='#ffbf7699';c.fillRect(x-25,y-12,50,5)}
 c.drawImage(img,Math.round(x-w/2),Math.round(y-h+12),w,h);
 // Clearly visible hit/armor health state.
 if(e.hp<e.maxHP){
  rect(c,x-19,y-h+6,38,4,'#273445');rect(c,x-18,y-h+7,
   Math.round(36*Math.max(0,e.hp/e.maxHP)),2,'#d2bb79');
 }
 c.restore();
}
function drawSlash(c,s,now){
 // The authored pirate frame already includes its own blade and energy arc.
 if(sheetPose(s.warrior,s.face,'attack',0))return;
 if(!s.attackStart||now>=s.attackUntil)return;
 const t=now<s.hitStopUntil?s.lastImpactAt:now;
 const p=Math.min(1,(t-s.attackStart)/416);
 if(p<.17||p>.76)return;
 const x=s.player.x*32+16,y=s.player.y*32+16;
 // Melee contact is at 0.32 of the full eight-frame animation.
 const phase=(p-.17)/.59, angle=phase*Math.PI*.92,dir=s.face;
 c.save();c.translate(x,y-37);
 const rot={right:0,down:Math.PI*.5,left:Math.PI,up:-Math.PI*.5}[dir]||0;
 c.rotate(rot);
 if(s.attackCombo===0)c.scale(1,-1);
 c.globalAlpha=Math.min(1,phase*7,(1-phase)*7);
 const rx=36;
 c.strokeStyle='#5bbbd3';c.lineWidth=13;c.beginPath();
 c.ellipse(24,0,rx,34,0,-1.15+angle*.85,-.25+angle*.85);c.stroke();
 c.strokeStyle='#d7ffff';c.lineWidth=7;c.beginPath();
 c.ellipse(24,0,rx,34,0,-1.15+angle*.85,-.25+angle*.85);c.stroke();
 c.strokeStyle='#ffffff';c.lineWidth=2;c.beginPath();
 c.ellipse(24,0,rx,34,0,-1.15+angle*.85,-.25+angle*.85);c.stroke();
 const a=-.25+angle*.85;
 oval(c,24+rx*Math.cos(a),34*Math.sin(a),4,4,'#ffffff');
 c.restore();
}
window.LibationSpriteStudio=Object.freeze({
 drawHero,drawEnemy,drawSlash,previewHero,
 frameCount:8,walkingFrames:12,attackFrames:8,enemyPoseFrames:8,
 authoredAnimationRows:6,
 sheetAvailable:()=>pirateSheetReady,
 artVersion:'authored-pirate-atlas-plus-mana-fallback-v2',
 archetypes:['slime','skeleton','bat','sentinel','specter','thornbound','mimic',
  'archer','brute','wisp','spider','mage','acolyte','leech','shaman','guardian']
});
})();
