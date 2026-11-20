// Shared timeline helpers: every slide exposes render(t) and is drawn frame by frame.
// Defaults follow the accepted reel pacing (store-reel.md): calm entrances, no overshoot.
const clamp=(x,a=0,b=1)=>Math.min(b,Math.max(a,x));
const prog=(t,start,dur)=>clamp((t-start)/dur);
const outCubic=x=>1-Math.pow(1-x,3);
const inOutCubic=x=>x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2;
const lerp=(a,b,x)=>a+(b-a)*x;
const snap=(v,s)=>Math.round(v/s)*s;
const $=s=>document.querySelector(s);
const pending=[];
function frame(img,dir,t,{fps=30,count,speed=1,offset=0,hold=true}={}){
  if(!count) throw new Error('frame(): count (last clean frame) is required');
  let i=Math.floor((t*speed+offset)*fps)+1; i=hold?Math.min(Math.max(i,1),count):((i-1)%count)+1;
  const src=`${dir}/${String(i).padStart(4,'0')}.jpg`;
  if(img.dataset.src!==src){img.dataset.src=src;img.src=src;pending.push(img.decode().catch(()=>{}));}
}
async function settle(){await Promise.all(pending.splice(0));}
function words(el){const txt=el.textContent;el.textContent='';return txt.split(' ').map((w,i,a)=>{const s=document.createElement('span');s.textContent=w+(i<a.length-1?' ':'');s.style.display='inline-block';el.appendChild(s);return s;});}
function letters(el){const txt=el.textContent;el.textContent='';return [...txt].map(c=>{const s=document.createElement('span');s.textContent=c===' '?' ':c;el.appendChild(s);return s;});}
function riseIn(spans,t,start,stagger=.22,dur=1.0,dist=60){spans.forEach((s,i)=>{const p=outCubic(prog(t,start+i*stagger,dur));s.style.opacity=p;s.style.transform=`translateY(${(1-p)*dist}px)`;});}
function typeIn(spans,t,start,per=.07){spans.forEach((s,i)=>{s.style.visibility=t>=start+i*per?'visible':'hidden';});}
