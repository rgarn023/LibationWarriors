/* Libation Warriors — painted JRPG overworld adventurer.
 * Original character poses approved for this prototype. The existing vector
 * adventurer remains available if AVIF is unsupported or fails to load.
 * Cosmetic only: never mutates GPS data, warriors, scans or account state.
 */
(()=>{
'use strict';
const art=new Image(),cache=new Map();
let ready=false;
art.onload=()=>{
 if(art.naturalWidth!==640||art.naturalHeight!==140)return;
 ready=true;cache.clear();
 window.dispatchEvent(new Event('libation-painted-avatar-ready'));
};
art.onerror=()=>console.warn('Painted JRPG avatar unavailable; keeping vector fallback.');
art.src='./avatar_jrpg_strip.webp';
function render(frame,facing='up',config={}){
 if(!ready)return null;
 const phase=frame>=16?16+(frame%2):((frame%16)+16)%16;
 const skin=Number(config.skin)||0,hair=Number(config.hair)||0,coat=Number(config.outfit)||0;
 const style=Number(config.hairStyle)||0,body=Number(config.body)||0;
 const key=[phase,facing,skin,hair,coat,style,body].join(':');
 if(cache.has(key))return cache.get(key);
 const canvas=document.createElement('canvas');canvas.width=80;canvas.height=140;
 const g=canvas.getContext('2d',{willReadFrequently:true});
 g.imageSmoothingEnabled=true;g.imageSmoothingQuality='high';
 const moving=phase<16,angle=phase*Math.PI*2/16;
 const col=facing==='up'?1:facing==='down'?0:
  2+Math.min(5,Math.floor(phase%16*6/16));
 const horizontalScale=body===0?1.035:body===2?.955:1;
 g.save();g.translate(40,0);g.scale((facing==='left'?-1:1)*horizontalScale,1);
 g.translate(-40,0);
 g.drawImage(art,col*80,0,80,140,0,moving?Math.round(Math.abs(Math.sin(angle))*1.4):phase===17?1:0,80,140);
 g.restore();
 // Soft localized material tints retain photographic lighting/highlights.
 const hairShades=[[50,46,58],[149,86,48],[195,109,69],[232,190,126],[157,102,196]];
 const coatShades=[[60,128,159],[177,86,111],[91,138,119],[137,103,177],[183,143,88]];
 const skinShades=[[245,198,159],[220,167,134],[187,128,94],[145,94,67],[108,68,50]];
 const h=hairShades[Math.max(0,Math.min(4,hair))],
  c=coatShades[Math.max(0,Math.min(4,coat))],
  sk=skinShades[Math.max(0,Math.min(4,skin))];
 if(hair!==1||coat!==2||skin!==1){
  const id=g.getImageData(0,0,80,140),data=id.data;
  for(let i=0;i<data.length;i+=4){
   if(data[i+3]<30)continue;
   const y=Math.floor(i/4/80),r=data[i],green=data[i+1],blue=data[i+2];
   let target=null,mix=0;
   if(hair!==1&&y<54&&r>green*1.16&&green>blue*1.04){
    target=h;mix=.32;
   }else if(coat!==2&&y>49&&y<120&&blue>r*1.06&&blue>green*.92){
    target=c;mix=.30;
   }else if(skin!==1&&y<84&&r>green*1.14&&green>blue*1.16){
    target=sk;mix=.24;
   }
   if(!target)continue;
   const l=Math.max(.52,Math.min(1.26,(r+green+blue)/380));
   for(let k=0;k<3;k++)data[i+k]=Math.round(data[i+k]*(1-mix)+target[k]*l*mix);
  }
  g.putImageData(id,0,0);
 }
 if(style===1||style===4){
  g.strokeStyle=hair===3?'#e1b674':'#ae7249';g.lineCap='round';g.lineWidth=2.4;
  g.beginPath();g.moveTo(24,30);g.quadraticCurveTo(19,44,25,59);
  g.moveTo(53,31);g.quadraticCurveTo(62,47,57,59);g.stroke();
 }else if(style===3){
  g.fillStyle=hair===3?'#dcb07b':'#9d6641';
  g.beginPath();g.moveTo(30,17);g.lineTo(33,5);g.lineTo(38,16);g.fill();
 }
 const image=canvas.toDataURL('image/png');
 if(cache.size>135)cache.clear();cache.set(key,image);
 return image;
}
window.LibationPaintedAvatar=Object.freeze({
 render,ready:()=>ready,frameSize:[80,140],atlasSize:[640,140],
 directions:4,sideWalkFrames:6,source:'approved-illustration',assetFormat:'webp',
 clearCache:()=>cache.clear()
});
})();