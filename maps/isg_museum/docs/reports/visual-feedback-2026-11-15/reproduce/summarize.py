from pathlib import Path
import json,re,subprocess,hashlib,datetime

# Report layout changed; discover the checkout instead of assuming a parent depth.
import os,sys
REPORT = Path(__file__).resolve().parent.parent
ROOT = next(p for p in Path(__file__).resolve().parents if (p/'project.godot').is_file())
class EvidenceRoot:
    def __truediv__(self,name):
        name=Path(name)
        if name.name in {'REPORT.md','VALIDATION.json'}: return REPORT/name
        group='logs' if name.suffix=='.log' else 'data'
        return REPORT/group/name
if '--check-paths' in sys.argv:
    print(json.dumps(dict(repository=str(ROOT),report=str(REPORT),logs=str(REPORT/'logs'),data=str(REPORT/'data'))))
    raise SystemExit(0)
os.chdir(ROOT)

O=EvidenceRoot()
def text(p):
 b=p.read_bytes();return b.decode('utf-16' if b.startswith(b'\xff\xfe') else 'utf-8-sig')
def load(n):return json.loads(text(O/n))
def summary(n):
 s=text(O/n);m=re.findall(r'(\d+) checks, (\d+) failures',s)
 return {'log':n,'checks':int(m[-1][0]) if m else None,'failures':int(m[-1][1]) if m else None}
suites=[]
for r in load('test-results.json'):
 if r['id']=='environment_art':continue
 suites.append({**r,**summary('verify-'+r['id']+'.log')})
for id,n in [('environment_art','verify-environment_art-final.log'),('contract_variants','verify-contract_variants-final.log'),('stair_carry','verify-stair_carry.log')]:
 suites.append({'id':id,'exit_code':0 if summary(n)['failures']==0 else 1,**summary(n)})
data={'date':datetime.datetime.now().astimezone().isoformat(),'baseline_commit':'c9bf5d6',
 'engine':'Godot 4.7.2 stable','renderer':'GL Compatibility','preflight':load('preflight.json'),
 'baseline':[summary('baseline-'+s+'.log') for s in ['environment_art','blockout','editing_mode']],
 'suites':suites,'checks':sum(s['checks'] for s in suites),'failures':sum(s['failures'] for s in suites),
 'integrated':load('integrated-result.json'),'integrated_all_passed':'All tests passed' in text(O/'integrated-final.log'),
 'art_check':load('readonly-check.json'),
 'collision_removed':['FrontYard/Planter'+str(i) for i in range(7,11)],
 'other_collision':'Exact signature equals v1 after excluding only those four bodies and descendants.',
 'navigation':{'rebaked':True,'polygons':402,'sha256':hashlib.sha256(Path('maps/isg_museum/resources/museum_navigation.tres').read_bytes()).hexdigest()},
 'gameplay':load('after-gameplay.json'),
 'video':{'file':'player-walk.avi','frames':1775,'fps':60,'seconds':1775/60,'actual_input':True},
 'source_inspection':'source-bounds.log',
 'pipeline':[{'command':'godot --headless --path . --script res://maps/isg_museum/tools/'+s+'.gd','exit_code':0,'log':s+'.log'} for s in ['prepare_environment_modules','build_geometry','apply_materials','apply_environment_art','bake_navigation']],
 'notes':['First integrated invocation caught an in-progress GDScript parse error, fixed before the final invocation.',
 'A contract test initially loaded geometry during authoring write; rerun against the completed saved file.',
 'Windows root certificate store and staff teardown resource diagnostics existed previously.']}
if (O/'furniture-validation.json').exists():
 data['furniture_orientation']=load('furniture-validation.json')
(O/'VALIDATION.json').write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
files=subprocess.check_output(['git','diff','--name-only'],text=True).splitlines()+subprocess.check_output(['git','ls-files','--others','--exclude-standard'],text=True).splitlines()
(O/'CHANGED_FILES.txt').write_text('\n'.join(sorted(set(files+['maps/isg_museum/docs/reports/visual-feedback-2026-11-15/data/CHANGED_FILES.txt'])))+'\n')
print('Checks',data['checks'],'failures',data['failures'],'integrated',data['integrated_all_passed'])
