"""JellyMon runtime-rule solver (chain, one_way, personalities shy/sleepy/playful/lonely).
solve(level, level_idx) -> list of (catcher_index, dir) steps or None (exhaustive over macro states)."""
import heapq, itertools, copy
from collections import deque
SHAPES = {"S1": [(0,0)], "H2": [(0,0),(1,0)], "V2": [(0,0),(0,1)], "H3": [(0,0),(1,0),(2,0)], "V3": [(0,0),(0,1),(0,2)],
          "H4": [(0,0),(1,0),(2,0),(3,0)], "V4": [(0,0),(0,1),(0,2),(0,3)], "SQ": [(0,0),(1,0),(0,1),(1,1)],
          "LA": [(0,0),(0,1),(1,1)], "LB": [(0,0),(1,0),(1,1)], "L4A": [(0,0),(0,1),(0,2),(1,2)], "L4B": [(0,0),(1,0),(0,1),(0,2)],
          "L4C": [(0,0),(0,1),(1,1),(2,1)], "L4D": [(0,0),(1,0),(2,0),(2,1)]}
DIRS = [(-1,0),(1,0),(0,-1),(0,1)]
DNAME = {(-1,0):"L",(1,0):"R",(0,-1):"U",(0,1):"D"}
TRAITS = ["shy","sleepy","playful","lonely"]

class Level:
    def __init__(self, L, idx):
        self.grid = L["grid"]; self.rows = len(self.grid); self.cols = len(self.grid[0])
        self.voids=set(); self.walls=set(); self.jelly0={}
        cnt=0; limit = max(1,min(3,1+(idx-50)//18)) if idx>=50 else 0
        for y,row in enumerate(self.grid):
            for x,ch in enumerate(row):
                if ch=="_": self.voids.add((x,y))
                elif ch=="#": self.walls.add((x,y))
                elif ch!=".":
                    p=""
                    if cnt<limit and (x*3+y*5+idx)%7==0:
                        p=TRAITS[(idx//10+cnt)%4]; cnt+=1
                    self.jelly0[(x,y)]=(ch,p,0)
        self.chain0={}
        for ci,ch in enumerate(L.get("chains",[])):
            for i,c in enumerate(ch["cells"]): self.chain0[(int(c[0]),int(c[1]))]=(ci,i)
        self.one_way={(int(o["cell"][0]),int(o["cell"][1])):(int(o["dir"][0]),int(o["dir"][1])) for o in L.get("one_ways",[])}
        self.cats=[(c["color"],SHAPES[c["shape"]],int(c["capacity"])) for c in L["catchers"]]
        self.cat0=tuple(((int(c["cell"][0]),int(c["cell"][1])),int(c["capacity"])) for c in L["catchers"])
        self.chp0=tuple(0 for _ in L.get("chains",[]))
        self.L=L

    def start(self): return (self.cat0, dict(self.jelly0), self.chp0, dict(self.chain0))
    @staticmethod
    def key(st): return (st[0], frozenset(st[1].items()), st[2], frozenset(st[3].items()))
    def occupancy(self, cats):
        occ={}
        for ci,(org,cap) in enumerate(cats):
            if org is None: continue
            for off in self.cats[ci][1]: occ[(org[0]+off[0],org[1]+off[1])]=ci
        return occ
    def can_place(self, ci, org, jel, occ):
        color,cells,_=self.cats[ci]
        for off in cells:
            cl=(org[0]+off[0],org[1]+off[1])
            if cl[0]<0 or cl[1]<0 or cl[0]>=self.cols or cl[1]>=self.rows: return False
            if cl in self.walls or cl in self.voids: return False
            o=occ.get(cl)
            if o is not None and o!=ci: return False
            j=jel.get(cl)
            if j is not None and j[0]!=color: return False
        return True
    def one_way_ok(self, ci, org, d):
        cells=self.cats[ci][1]
        prev={(org[0]-d[0]+o[0],org[1]-d[1]+o[1]) for o in cells}
        for off in cells:
            cl=(org[0]+off[0],org[1]+off[1])
            if cl in prev: continue
            if cl in self.one_way and self.one_way[cl]!=d: return False
        return True
    @staticmethod
    def move_rules(chain,a,b):
        va,vb=chain.get(a),chain.get(b); chain.pop(a,None); chain.pop(b,None)
        if va is not None: chain[b]=va
        if vb is not None: chain[a]=vb
    def step(self, state, ci, d):
        cats,jel,chp,chain=state
        org0,cap=cats[ci]
        if org0 is None: return None
        color,cells,_=self.cats[ci]
        org=(org0[0]+d[0],org0[1]+d[1])
        occ=self.occupancy(cats)
        if not self.can_place(ci,org,jel,occ): return None
        if not self.one_way_ok(ci,org,d): return None
        jel=dict(jel); chain=dict(chain)
        fp=[(org[0]+o[0],org[1]+o[1]) for o in cells]; fps=set(fp)
        for cl in fp:
            j=jel.get(cl)
            if j is None or j[0]!=color or j[2]>0: continue
            if j[1]=="shy":
                for dd in DIRS:
                    t=(cl[0]+dd[0],cl[1]+dd[1])
                    if t[0]<0 or t[1]<0 or t[0]>=self.cols or t[1]>=self.rows: continue
                    if t in fps or t in self.walls or t in self.voids or t in jel or t in occ: continue
                    self.move_rules(chain,cl,t); del jel[cl]; jel[t]=(j[0],j[1],1)
                    return (cats,jel,chp,chain),"shy"
            elif j[1]=="playful":
                for dd in DIRS:
                    oc=(cl[0]+dd[0],cl[1]+dd[1]); other=jel.get(oc)
                    if other is not None and oc not in fps:
                        self.move_rules(chain,cl,oc); jel[cl]=other; jel[oc]=(j[0],j[1],1)
                        return (cats,jel,chp,chain),"playful"
        cats=list(cats); chp=list(chp)
        for cl in fp:
            if cap==0: break
            j=jel.get(cl)
            if j is None or j[0]!=color: continue
            if cl in chain and chp[chain[cl][0]]!=chain[cl][1]: continue
            if j[1]=="sleepy" and j[2]==0: jel[cl]=(j[0],j[1],1); continue
            if j[1]=="lonely" and j[2]==0:
                jel[cl]=(j[0],j[1],1)
                if not any((cl[0]+dd[0],cl[1]+dd[1]) in jel for dd in DIRS): continue
            del jel[cl]; cap-=1
            if cl in chain: chp[chain[cl][0]]+=1; del chain[cl]
        cats[ci]=(None,0) if cap==0 else (org,cap)
        return (tuple(cats),jel,tuple(chp),chain),"move"
    @staticmethod
    def changed(a,b):
        if a[1]!=b[1] or a[3]!=b[3] or a[2]!=b[2]: return True
        return any((x[0] is None)!=(y[0] is None) or x[1]!=y[1] for x,y in zip(a[0],b[0]))
    def macro_children(self, state):
        out=[]
        for ci in range(len(self.cats)):
            if state[0][ci][0] is None: continue
            seen={state[0][ci][0]}; dq=deque([(state,[])])
            while dq:
                st,path=dq.popleft()
                for d in DIRS:
                    r=self.step(st,ci,d)
                    if r is None: continue
                    ns,_=r; p2=path+[(ci,d)]
                    if self.changed(st,ns): out.append((ns,p2))
                    else:
                        pos=ns[0][ci][0]
                        if pos in seen: continue
                        seen.add(pos); dq.append((ns,p2))
        return out
    @staticmethod
    def solved(st): return not st[1] and all(o is None for o,_ in st[0])
    def solve(self, max_nodes=300000):
        start=self.start(); seen={self.key(start):None}; cnt=itertools.count()
        pq=[(len(start[1]),0,next(cnt),start)]; n=0
        while pq:
            f,g,_,st=heapq.heappop(pq); n+=1
            if n>max_nodes: return None, n, "limit"
            if self.solved(st):
                steps=[]; k=self.key(st)
                while seen[k] is not None:
                    pk,path=seen[k]; steps=path+steps; k=pk
                return steps, n, "solved"
            for ns,path in self.macro_children(st):
                k=self.key(ns)
                if k in seen: continue
                seen[k]=(self.key(st),path)
                h=len(ns[1])+0.5*sum(1 for o,_ in ns[0] if o is not None)
                heapq.heappush(pq,(h*2+(g+1)*0.2,g+1,next(cnt),ns))
        return None, n, "exhausted"

def fmt(L, steps):
    lines=[]; cur=None; run=[]
    for ci,d in steps:
        if ci!=cur and run: lines.append((cur,run)); run=[]
        cur=ci; run.append(DNAME[d])
    lines.append((cur,run))
    return "\n".join(f"{i+1:3d}. #{ci} {L['catchers'][ci]['color']}{L['catchers'][ci]['shape']}@{tuple(int(v) for v in L['catchers'][ci]['cell'])}: {' '.join(r)}" for i,(ci,r) in enumerate(lines))


if __name__ == "__main__":
    # 사용법: python3 tools/solve_level_runtime.py 161 [assets/data/levels.json]
    # 지원 규칙: 이동/충돌, 같은 색 통과, 수용량, 순서 체인, 일방통행, 성격 젤리(shy/sleepy/playful/lonely).
    # 얼음·스위치·열쇠·유령·폭탄·포털·출구·보스·색 순서·호위·이동 제한이 있는 레벨은 지원하지 않는다.
    import sys, json, os
    number = int(sys.argv[1])
    path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "..", "assets", "data", "levels.json")
    L = json.load(open(path, encoding="utf-8"))[number - 1]
    unsupported = {"frozen", "sealed_jellies", "switches", "key_locks", "exits", "shape_seals", "ghosts", "portals", "bombs",
                   "fragile_walls", "boss", "move_limit", "currents", "fog", "time_rifts", "color_order", "escort"} & set(L.keys())
    if unsupported or any(ch == "#" for row in L["grid"] for ch in row):
        print(f"L{number}: unsupported rules {sorted(unsupported)} (walls={'#' in ''.join(L['grid'])})"); sys.exit(2)
    steps, n, status = Level(L, number - 1).solve()
    print(f"L{number} {L.get('name','')}: {status} (macro states explored={n})")
    if steps:
        print(f"steps={len(steps)}")
        print(fmt(L, steps))
    sys.exit(0 if status == "solved" else 1)
