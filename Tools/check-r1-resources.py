#!/usr/bin/env python3
"""Validate the public R1 localization contract and every bundled sound variant."""
import hashlib,json,math,pathlib,re,struct,subprocess
R=pathlib.Path(__file__).resolve().parents[1]
required='''登录时启动|启动|启动时显示窗口|计时开始后隐藏窗口|菜单栏|显示今日完成数|只统计今天已完成的专注|提醒|允许通知|专注完成声音|休息完成声音|音量|关闭通知也会关闭完成声音。音量受系统设置影响。|专注时播放滴答声|计时设置|计时设置…|设置…|设置|开始休息|返回专注|次数|时长|统计|关于 NanaFlow|专注、休息、继续。|duration_decrease_format|duration_increase_format|duration_cycles_format|about_version_format|statistics_minutes_format|statistics_hours_format|statistics_hours_minutes_format|statistics_less_than_minute|statistics_count_format|statistics_previous_period|statistics_next_period|selected|无|闹钟|铃声|铃铛|唱钵|风铃|和弦|竖琴|重要事件|脉冲|波纹|吹口哨|返回|返回计时器|完成|短休息|长休息|长时间停顿|循环|自动开始|专注|休息|分钟|%lld 分钟|菜单|开始|停止|暂停|关闭|重新开始周期|跳过休息时间|显示统计|隐藏计时器|显示计时器|跳到休息|跳到专注|重新开始|退出 NanaFlow|统计图表|第 %1$lld 轮，共 %2$lld 轮|好|未知错误|无法保存|天|周|月|年'''.split('|')
report={'requiredKeys':required,'languages':{}}
for lang in ('en','zh-Hans','zh-Hant'):
 p=R/f'Sources/NanaFocus/{lang}.lproj/Localizable.strings'
 subprocess.run(['plutil','-lint',str(p)],check=True,stdout=subprocess.DEVNULL)
 data=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(p)]))
 missing=sorted(set(required)-data.keys());assert not missing,(lang,missing)
 report['languages'][lang]={'keyCount':len(data),'publicKeysCovered':len(required),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
 # New format signatures must agree across all three languages.
 if lang=='en': formats={k:re.findall(r'%(?:\d+\$)?(?:lld|@)',data[k]) for k in required if k.endswith('_format')}
 else:
  for k,sig in formats.items():assert re.findall(r'%(?:\d+\$)?(?:lld|@)',data[k])==sig,(lang,k)
def require(condition, message):
 if not condition:
  raise ValueError(message)

def read_sound(path):
 """Decode the bundled AIFF integer PCM contract without optional audio modules."""
 content=path.read_bytes()
 label=path.name
 require(len(content)>=12 and content[:4]==b'FORM' and content[8:12]==b'AIFF',f'{label}: expected AIFF FORM')
 require(struct.unpack_from('>I',content,4)[0]+8==len(content),f'{label}: invalid FORM length')
 chunks={};position=12
 while position<len(content):
  require(position+8<=len(content),f'{label}: truncated chunk header')
  tag,size=struct.unpack_from('>4sI',content,position)
  end=position+8+size
  require(end+(size%2)<=len(content),f'{label}: truncated chunk {tag!r}')
  if tag in (b'COMM',b'SSND'):
   require(tag not in chunks,f'{label}: duplicate {tag!r}')
   chunks[tag]=content[position+8:end]
  position=end+(size%2)
 require(b'COMM' in chunks and b'SSND' in chunks,f'{label}: missing COMM/SSND')
 comm=chunks[b'COMM'];ssnd=chunks[b'SSND']
 require(len(comm)>=18 and len(ssnd)>=8,f'{label}: invalid COMM/SSND length')
 channels,frames,bits=struct.unpack_from('>hIh',comm)
 exponent,mantissa=struct.unpack_from('>HQ',comm,8)
 # AIFF stores its sample rate as an IEEE 754 80-bit extended value.
 require(0<exponent<0x7fff and mantissa>=1<<63,f'{label}: invalid positive sample rate')
 rate=math.ldexp(mantissa/2**63,exponent-16383)
 require((channels,bits,rate,frames)==(1,16,44100,43659),f'{label}: expected mono16 BE PCM 44100Hz/43659 frames, got {(channels,bits,rate,frames)}')
 offset,_=struct.unpack_from('>II',ssnd)
 require(8+offset<=len(ssnd),f'{label}: invalid SSND offset')
 raw=ssnd[8+offset:]
 require(len(raw)==frames*channels*2,f'{label}: PCM length does not match frame count')
 samples=struct.unpack('>'+str(frames*channels)+'h',raw)
 peak_integer=max(map(abs,samples))
 require(peak_integer>0,f'{label}: silent PCM')
 require(min(samples)>-32768 and max(samples)<32767,f'{label}: full-scale/clipped PCM')
 peak=peak_integer/32768
 rms=math.sqrt(sum(value*value for value in samples)/len(samples))/32768
 return samples,{'sampleRate':rate,'channels':channels,'bits':bits,'frames':frames,'duration':frames/rate,'peak':peak,'rms':rms,'peakDBFS':20*math.log10(peak),'rmsDBFS':20*math.log10(rms),'sha256':hashlib.sha256(content).hexdigest()}

sounds=('alarmClock','bell','bells','bowl','chime','chord','harp','milestone','pulse','ripple','whistle')
suffixes=('', '-v1', '-v2', '-v3')
sound_dir=R/'Sources/NanaFocus/Sounds'
expected={f'NanaFlow-{sound}{suffix}.aiff' for sound in sounds for suffix in suffixes}
require({p.name for p in sound_dir.glob('NanaFlow-*.aiff')}==expected,'expected exactly the 44 named completion sound resources')
report['sounds']={};report['soundMetrics']={};report['soundVariantErrorsLSB']={}
loudness_failures=[]
for sound in sounds:
 variants={}
 for suffix in suffixes:
  p=sound_dir/f'NanaFlow-{sound}{suffix}.aiff'
  samples,metrics=read_sound(p)
  variants[suffix]=samples
  report['sounds'][p.name]=metrics['sha256']
  report['soundMetrics'][p.name]=metrics
  if suffix=='':
   # App engineering regression limits, not an Apple requirement or a listening
   # test: reject both the formerly very quiet masters and excessive energy.
   # Broad ranges deliberately do not mirror the chosen peak-normalization target.
   if not (0.05<=metrics['peak']<=0.30 and 0.015<=metrics['rms']<=0.10):
    loudness_failures.append(f"{p.name}: 100% loudness outside app range peak[0.05,0.30]/RMS[0.015,0.10]; peak={metrics['peak']:.9f}, RMS={metrics['rms']:.9f}")
 base=variants['']
 for level in (1,2,3):
  suffix=f'-v{level}'
  error=max(abs(value-reference*level/4) for value,reference in zip(variants[suffix],base))
  require(error<=1,f'{sound}{suffix}: scaled PCM differs by {error} LSB (limit 1)')
  report['soundVariantErrorsLSB'][f'NanaFlow-{sound}{suffix}.aiff']=error
if loudness_failures:
 raise SystemExit('Completion sound loudness regression:\n'+'\n'.join(loudness_failures))
print(json.dumps(report,ensure_ascii=False,indent=2))
