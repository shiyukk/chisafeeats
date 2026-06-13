#!/usr/bin/env python3
"""Rebuild the bundled seed from the pre-merge (license-keyed) seed, fixing:
  #1 latest-inspection snapshot picked by (date, then numeric inspection_id)
  #6 venue facility_type/risk = the dominant license (most inspections), stable
  + venue merge (name+address+zip, 16-hex id) and latest_inspection_id column.

Score is recomputed to mirror Swift HygieneScore. PHASE 0 validates that mirror
against the existing Swift-computed scores before any mutation.

Usage: rebuild_seed.py <premerge.sqlite>   (mutates it in place)
"""
import sqlite3, hashlib, sys, collections

def norm(s): return (s or "").strip().lower()
def sha1_16(s): return hashlib.sha1(s.encode("utf-8")).hexdigest()[:16]
def venue_id(name, addr, zip_, lic):
    n, a, z = norm(name), norm(addr), norm(zip_)
    ident = f"{n}|{a}|{z}"
    if n and a: return "A:" + sha1_16(ident)
    lic = (lic or "").strip()
    if lic and lic != "0": return "L:" + lic
    return "A:" + sha1_16(ident)

# --- Swift HygieneScore mirror (seed violations are all >=2023 => post-2018) ---
def severity_penalty(num):
    if num is None: return 1
    if 1 <= num <= 29: return 12
    if 30 <= num <= 44: return 6
    if 45 <= num <= 63: return 2
    return 1
def vnums(raw):
    out = []
    if not raw: return out
    for e in raw.split(" | "):
        e = e.strip()
        if not e: continue
        d = e.find(".")
        out.append(int(e[:d]) if d > 0 and e[:d].isdigit() else None)
    return out
def hygiene_score(result_code, violations_raw):
    if result_code in (3, 4): return None
    nums = vnums(violations_raw)
    if not nums:
        return {0: 100, 1: 78, 2: 50}.get(result_code)
    score = max(0, 100 - sum(severity_penalty(n) for n in nums))
    return min(score, 59) if result_code == 2 else score

db = sys.argv[1]
con = sqlite3.connect(db)
con.execute("PRAGMA foreign_keys=off")
cur = con.cursor()

# Latest inspection per establishment: max(date, then numeric id).
print("indexing inspections per establishment…")
latest = {}   # estab_id -> (date, idnum, id, result_code, violations_raw)
insp_count = collections.Counter()
for eid, iid, idate, rcode, vraw in cur.execute(
        "SELECT establishment_id, inspection_id, inspection_date, results_code, violations_raw FROM inspection"):
    insp_count[eid] += 1
    idnum = int(iid) if (iid or "").isdigit() else -1
    key = (idate or "", idnum)
    cur_best = latest.get(eid)
    if cur_best is None or key > (cur_best[0], cur_best[1]):
        latest[eid] = (idate or "", idnum, iid, rcode, vraw)

# ---- PHASE 0: validate the Python score mirror against stored Swift scores ----
estabs = cur.execute("""SELECT id, dba_name, address, zip, license, facility_type, risk, score,
                               latest_result, latest_result_code FROM establishment""").fetchall()
mism = 0; checked = 0; samples = []
for (eid, name, addr, zip_, lic, ftype, risk, score, lres, lcode) in estabs:
    lt = latest.get(eid)
    if not lt: continue
    py = hygiene_score(lt[3], lt[4])
    # only compare where OUR latest == the row's snapshot date (unambiguous vs the
    # old same-day bug): if our latest result_code matches the stored snapshot.
    if lt[3] == lcode:
        checked += 1
        if py != score:
            mism += 1
            if len(samples) < 6: samples.append((eid, name, lcode, score, py, lt[4][:40] if lt[4] else None))
print(f"PHASE0 score mirror: checked {checked}, mismatches {mism}")
for s in samples: print("   MISMATCH", s)
if checked and mism / checked > 0.02:
    print("!! mirror disagreement too high — aborting"); sys.exit(1)

# ---- PHASE 1: merge into venues ----
groups = collections.defaultdict(list)   # vid -> [estab rows]
for row in estabs:
    groups[venue_id(row[1], row[2], row[3], row[4])].append(row)

old2new = {}; to_delete = []; canon_updates = []
for vid, members in groups.items():
    # dominant member = most inspections (tie: most recent latest inspection)
    def member_key(m):
        lt = latest.get(m[0])
        return (insp_count[m[0]], lt[0] if lt else "", lt[1] if lt else -1)
    dom = max(members, key=member_key)
    # venue's latest inspection across ALL members
    cand = [latest[m[0]] for m in members if m[0] in latest]
    snap = max(cand, key=lambda t: (t[0], t[1])) if cand else None
    for m in members:
        old2new[m[0]] = vid
        if m[0] != dom[0]: to_delete.append(m[0])
    # snapshot from the venue's truly-latest inspection; facility/risk from dom
    if snap:
        ldate, _, lid, lcode, lvraw = snap
        lresult = {0:"Pass",1:"Pass w/ Conditions",2:"Fail",3:"Out of Business"}.get(lcode, dom[8])
        canon_updates.append((vid, dom[5], dom[6], lresult, lcode, ldate, lid,
                              1 if lcode == 3 else 0, hygiene_score(lcode, lvraw), dom[0]))
    else:
        canon_updates.append((vid, dom[5], dom[6], dom[8], dom[9], None, None, 0, None, dom[0]))

print(f"venues: {len(estabs)} -> {len(groups)} (merged {len(estabs)-len(groups)})")

# add the column first so we can write latest_inspection_id
cur.execute("ALTER TABLE establishment ADD COLUMN latest_inspection_id TEXT")
# repoint inspections
for oid, nid in old2new.items():
    if oid != nid:
        cur.execute("UPDATE inspection SET establishment_id=? WHERE establishment_id=?", (nid, oid))
cur.executemany("DELETE FROM establishment WHERE id=?", [(o,) for o in to_delete])
# rewrite canonical rows (rename id + snapshot + dominant facility/risk)
for (vid, ftype, risk, lres, lcode, ldate, lid, oob, score, oldid) in canon_updates:
    cur.execute("""UPDATE establishment SET id=?, facility_type=?, risk=?, latest_result=?,
                   latest_result_code=?, latest_inspection_date=?, latest_inspection_id=?,
                   is_out_of_business=?, score=? WHERE id=?""",
                (vid, ftype, risk, lres, lcode, ldate, lid, oob, score, oldid))
# record migration v7 so the app's migrator matches the shipped schema
cur.execute("INSERT OR IGNORE INTO grdb_migrations(identifier) VALUES ('v7_latest_inspection_id')")
con.commit()
con.execute("VACUUM")

# ---- verification ----
est = cur.execute("SELECT COUNT(*) FROM establishment").fetchone()[0]
ins = cur.execute("SELECT COUNT(*) FROM inspection").fetchone()[0]
orph = cur.execute("SELECT COUNT(*) FROM inspection i LEFT JOIN establishment e ON e.id=i.establishment_id WHERE e.id IS NULL").fetchone()[0]
dups = cur.execute("SELECT COUNT(*) FROM (SELECT 1 FROM establishment GROUP BY lower(trim(dba_name)),lower(trim(address)),COALESCE(zip,'') HAVING COUNT(*)>1)").fetchone()[0]
noid = cur.execute("SELECT COUNT(*) FROM establishment WHERE latest_inspection_id IS NULL AND latest_inspection_date IS NOT NULL").fetchone()[0]
nosample = cur.execute("SELECT COUNT(*) FROM establishment WHERE sample_key IS NULL").fetchone()[0]
migs = ",".join(r[0] for r in cur.execute("SELECT identifier FROM grdb_migrations ORDER BY 1"))
print(f"establishments={est} inspections={ins} orphans={orph} name+addr+zip dups={dups}")
print(f"snapshot-without-id={noid} sample_key NULL={nosample}")
print(f"migrations: {migs}")
con.close()
