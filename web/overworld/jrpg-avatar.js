/* Libation Warriors — high resolution JRPG overworld explorer.
 * Original, scalable cel-shaded art. Four compass poses + 16 gait phases.
 * Pure visual rendering: does not use/modify GPS, scans, ownership or maps.
 */
(()=>{
'use strict';
const W=240,H=340;
const colors={
 hair:['#282538','#795032','#bf683d','#dbc18e','#8662b3'],
 hairHi:['#625663','#c48b53','#e6a66d','#ffebc0','#c7a5ed'],
 skin:['#edc1a1','#c99574','#ab7458','#81553d','#5c3b2d'],
 coat:['#c8b38a','#ab6977','#668d76','#8977a8','#d9b47a'],
 coatDark:['#76624f','#6d3946','#2d5746','#4d406c','#89633f'],
 cape:['#f2dfbc','#e8ccd0','#c5e5d4','#ded4f3','#fae5b0']
};
const cache=new Map();
function clamp(n,max){return Number.isInteger(+n)?Math.min(max,Math.max(0,+n)):0}
function brighten(hex,factor){
 const n=parseInt(hex.slice(1),16),a=[n>>16&255,n>>8&255,n&255];
 return 'rgb('+a.map(c=>Math.round(Math.min(255,c*factor))).join(',')+')';
}
function render(frame,dir,config={}){
 const k=['up','down','left','right'].includes(dir)?dir:'up';
 const phase=frame<16?((frame%16)+16)%16:16+(frame%2);
 const sk=clamp(config.skin,4),ha=clamp(config.hair,4),out=clamp(config.outfit,4),
   style=clamp(config.hairStyle,4),build=clamp(config.body,2);
 const cacheKey=[k,phase,sk,ha,out,style,build].join(':');
 if(cache.has(cacheKey))return cache.get(cacheKey);
 const canvas=document.createElement('canvas');canvas.width=W;canvas.height=H;
 const g=canvas.getContext('2d');g.scale(W/100,H/145);
 g.lineCap='round';g.lineJoin='round';
 const hair=colors.hair[ha],hairHi=colors.hairHi[ha],
  coat=colors.coat[out],coatDark=colors.coatDark[out],
  cape=colors.cape[out],skin=colors.skin[sk],ivory='#f9eacf',gold='#d7ad67';
 const front=k==='down',back=k==='up',side=k==='right'||k==='left';
 const walk=phase<16,angle=(phase/16)*Math.PI*2;
 const stride=walk?Math.sin(angle)*6:0;
 const heave=walk?Math.abs(Math.sin(angle))*1.6:phase===17?.42:0;
 const swing=walk?Math.cos(angle)*5:0;
 const flutter=walk?Math.sin(angle+1.1)*2.5:Math.sin(phase*1.4)*.5;
 const broad=build===0?2:build===2?-2:0;
 const grad=(stops,x0,y0,x1,y1)=>{
  const z=g.createLinearGradient(x0,y0,x1,y1);
  for(let i=0;i<stops.length;i++)z.addColorStop(i/(stops.length-1),stops[i]);
  return z;
 };
 const shape=(draw,fill,outline='#42362f',width=1.15)=>{
  g.beginPath();draw(g);g.fillStyle=fill;g.fill();
  if(outline){g.strokeStyle=outline;g.lineWidth=width;g.stroke()}
 };
 const poly=(pts,fill,outline,width)=>shape(ctx=>{
  ctx.moveTo(pts[0][0],pts[0][1]);for(let i=1;i<pts.length;i++)ctx.lineTo(pts[i][0],pts[i][1]);
  ctx.closePath();
 },fill,outline,width);
 const ellipse=(x,y,rx,ry,fill,outline,width=1)=>shape(ctx=>ctx.ellipse(x,y,rx,ry,0,0,Math.PI*2),fill,outline,width);
 const curve=(p,fill,stroke,width)=>{
  shape(ctx=>{
   ctx.moveTo(p[0],p[1]);for(let i=2;i<p.length;i+=6)ctx.bezierCurveTo(...p.slice(i,i+6));
   ctx.closePath();
  },fill,stroke,width);
 };
 const line=(pts,color,width=1.2)=>{
  g.beginPath();g.moveTo(...pts[0]);for(let i=1;i<pts.length;i++)g.lineTo(...pts[i]);
  g.lineWidth=width;g.strokeStyle=color;g.stroke();
 };
 const dot=(x,y,r,c)=>ellipse(x,y,r,r,c,null);
 g.save();if(k==='left'){g.translate(100,0);g.scale(-1,1)}
 // Grounding remains a separate GPS marker's oval; this is only light contact shade.
 ellipse(50,132,23,3.1,'rgba(19,30,31,.22)',null);
 g.translate(0,-heave);
 // Leg articulation: boots rise independently without separating hips.
 for(let i=0;i<2;i++){
  const x=i===0?38:57,step=(i?1:-1)*stride;
  const y=102+Math.max(0,-step*.26);
  g.save();g.translate(x,y);g.rotate((i?1:-1)*stride*.009);
  poly([[-8,-4],[7,-4],[8,19],[-6,20]],grad([coatDark,'#8d6244','#574033'],0,-6,9,23),'#49362e',1.35);
  poly([[-9,14],[8,13],[10,24],[4,28],[-10,28],[-11,24]],
    grad(['#bb8758','#6b4639','#322d31'],0,10,8,30),'#382d31',1.3);
  poly([[-8,15],[8,14],[9,19],[-8,21]],'#b98d57','#514037',.8);
  line([[-7,18],[4,17]],'#f5ce86',1.2);
  line([[-9,27],[8,27]],'#241f25',2.1);
  g.restore();
 }
 // Cape is beneath the tunic; off-axis hem gives lively secondary motion.
 const capeX=back?66:61;
 curve([capeX-10,56,capeX+12,47,capeX+22,78,capeX+30+flutter,108,
  capeX+24+flutter,115,capeX+5,105,capeX-9,87,
  capeX-16,73,capeX-14,61,capeX-10,56],
  grad([ivory,cape,brighten(cape,.73)],50,46,90,119),'#7d6347',1.6);
 curve([capeX+1,65,capeX+23,65,capeX+25,93,capeX+20+flutter,103,
  capeX+12+flutter,99,capeX+8,81,capeX+1,65],
  'rgba(254,242,210,.63)',null);
 line([[capeX+23,78],[capeX+28+flutter,106],[capeX+21+flutter,112]],gold,2.0);
 line([[capeX+10,70],[capeX+19,75],[capeX+23,84]],'#f6eccd',1.1);
 // The narrow pouch and hip straps are independently dimensional.
 poly([[29,85],[37,85],[39,112],[27,111]],grad(['#74513d','#392e30'],24,82,41,116),'#382c2b',1.4);
 ellipse(34,98,6.5,9,grad(['#bc8755','#60422f'],27,91,39,111),'#5b4234',1);
 line([[29,96],[39,96]],gold,1.3);
 for(const [cx,cy] of [[31,101],[37,101]])dot(cx,cy,.8,'#eed098');
 // Arms oppose the stride. Small torso inclination conveys walking weight.
 const elbowShift=swing*.33;
 const arm=(right)=>{
  const x=right?66:34,sign=right?1:-1;
  const sway=right?-elbowShift:elbowShift;
  g.save();g.translate(x,64);g.rotate(sign*sway*.019);
  curve([0,0,6*sign,-4,13*sign,8,12*sign,23,
   14*sign,29,7*sign,34,3*sign,31,
   -3*sign,19,-6*sign,7,0,0],
   grad([ivory,coat,'#806b58'],x-6,57,x+12*sign,100),'#63493a',1.35);
  ellipse(sign*10,28,5.5,6.2,grad([skin,brighten(skin,.78)],x-4,85,x+6,99),'#633b30',.9);
  poly([[sign*6,23],[sign*15,22],[sign*17,27],[sign*6,29]],'#78553e','#4f3b32',.8);
  line([[sign*8,24],[sign*15,24]],gold,1);
  g.restore();
 };
 // Shoulder base with copper trim and brushed-fabric cel highlights.
 ellipse(50,66,24+broad,21,grad(['#f3ddbb',coat,coatDark],31,47,68,93),'#5a4136',1.7);
 curve([32,53,41,45,62,47,68,54,71,67,66,81,
  58,91,39,94,30,82,28,67,32,53],
  grad(['#eee3d1',coat,coatDark],34,53,67,102),'#63473a',1.55);
 poly([[38,75],[48,74],[59,95],[52,99]],'rgba(245,230,205,.67)',null);
 poly([[37,77],[65,78],[64,87],[36,86]],'#6e4935','#463129',1.0);
 line([[36,78],[64,80]],'#d5a561',2);
 ellipse(51,83,3.8,4.2,gold,'#533d2d',1);
 dot(51,82,1.3,'#fff0ca');
 arm(false);arm(true);
 // Crossbody leather straps and shiny buckles.
 line([[32,59],[60,93]],'#473127',6);
 line([[32,58],[60,91]],'#b58a54',2.9);
 line([[65,57],[40,96]],'#49342d',5);
 line([[65,58],[40,94]],'#be955d',2.3);
 ellipse(45,78,3,3,gold,'#6b4833',.8);
 // Thick soft scarf worn over the shoulders.
 curve([31,54,37,45,59,45,72,55,69,65,
  58,72,40,69,29,62,27,57,31,54],
  grad(['#fff3d9',ivory,cape,'#bba47e'],30,45,73,75),'#957457',1.4);
 line([[34,57],[44,63],[59,63],[67,59]],'#fff5db',1.65);
 line([[33,62],[47,71],[62,68]],'#b59167',1.25);
 poly([[49,58],[56,60],[53,66],[49,64]],gold,'#a77a48',.6);
 // Neck and warm, round chibi head.
 ellipse(50,46,10.6,9.7,grad([skin,brighten(skin,.75)],39,39,60,57),'#5d413a',1.0);
 const faceX=side?54:50;
 ellipse(faceX,29,20,20.5,grad([brighten(skin,1.20),skin,brighten(skin,.74)],29,13,69,51),'#66483c',1.4);
 ellipse(faceX-10,35,4.8,8,'rgba(255,222,190,.29)',null);
 if(front){
  ellipse(43,32.4,2.3,3.15,'#394153',null);ellipse(57,32.4,2.3,3.15,'#394153',null);
  dot(42.8,31.5,.75,'#fffaf0');dot(56.8,31.5,.75,'#fffaf0');
  line([[47,42],[52,42]],'#976c58',1.1);
 }else if(side){
  ellipse(65,33,2.7,3.6,'#303d47',null);
  dot(65.4,32.1,.9,'#fffaf0');
  ellipse(70.3,39.2,2.7,2.8,grad([skin,brighten(skin,.85)],66,38,73,44),'#896450',.7);
 }
 // Painterly tufts are curved shapes, not enlarged square pixels.
 curve([29,31,27,20,31,12,38,8,43,3,49,4,
  55,2,61,7,65,12,72,15,74,25,67,27,
  62,22,51,21,42,25,36,34,29,31],
  grad([hairHi,hair,brighten(hair,.57)],33,5,72,35),'#44352f',1.6);
 for(const [x,y,ex,ey] of [[37,15,30,11],[45,10,43,2],[55,11,62,3],[65,15,73,8],
  [35,24,24,21],[56,22,64,15],[44,21,48,13]]){
  curve([x-3,y+6,x-9,y-4,ex,ey-3,ex+4,ey+2,
   ex+8,ey+3,x+6,y+7,x-3,y+6],
   grad([hairHi,hair,brighten(hair,.66)],x-5,y-9,x+12,y+11),'#564034',.75);
 }
 if(back){
  // Back-of-head hair has its own layered volumes and a crown swirl.
  curve([30,20,34,4,54,3,68,18,73,26,67,41,
   58,49,41,47,32,38,30,20],grad([hairHi,hair,brighten(hair,.58)],30,10,71,49),'#46362f',1.1);
  for(const [x,y] of [[35,17],[46,13],[58,18],[64,26],[41,29],[52,31]]){
   curve([x,y,x+3,y-6,x+8,y-5,x+11,y+3,x+7,y+10,x+2,y+10,x,y],
    grad([hairHi,hair,brighten(hair,.68)],x,y-3,x+10,y+11),'#6a4432',.6);
  }
 }
 // Slight shine on hair and metallic hardware. Avoid harsh black pixel outlines.
 line([[39,15],[43,11],[48,9]],'rgba(255,231,179,.63)',1.3);
 line([[56,15],[60,12],[64,14]],'rgba(255,227,170,.52)',1);
 dot(56,81,1,'#fff6d4');dot(33,95,.85,'#e8bc72');
 g.restore();
 const uri=canvas.toDataURL('image/png');
 if(cache.size>140)cache.clear();
 cache.set(cacheKey,uri);
 return uri;
}
window.LibationJRPGAvatar=Object.freeze({render,style:'smooth-jrpg',resolution:[W,H],directions:4,gaitFrames:16,clearCache:()=>cache.clear()});
})();