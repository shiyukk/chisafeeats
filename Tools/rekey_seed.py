#!/usr/bin/env python3
"""Re-key the bundled seed so several licenses at the same name+address collapse
into one establishment (venue). Must match InspectionImporter.establishmentID:

  name = trim(lower(dba_name)); address = trim(lower(address)); zip = trim(lower(zip))
  identity = name|address|zip
  if name and address: id = "A:" + sha1(identity)
  elif valid license:  id = "L:" + license
  else:                id = "A:" + sha1(identity)

For each new id, the establishment with the most recent inspection becomes the
canonical row (its latest snapshot is the venue's); the rest are merged in
(their inspections repointed) and deleted.
"""
import sqlite3, hashlib, sys

def norm(s): return (s or "").strip().lower()

def sha1_16(s):
    # First 16 hex chars (64 bits) — matches InspectionImporter.sha1.
    return hashlib.sha1(s.encode("utf-8")).hexdigest()[:16]

def venue_id(dba, address, zip_, license_):
    name, addr, z = norm(dba), norm(address), norm(zip_)
    identity = f"{name}|{addr}|{z}"
    if name and addr:
        return "A:" + sha1_16(identity)
    lic = (license_ or "").strip()
    if lic and lic != "0":
        return "L:" + lic
    return "A:" + sha1_16(identity)

db = sys.argv[1]
con = sqlite3.connect(db)
con.execute("PRAGMA foreign_keys=off")
cur = con.cursor()

before = cur.execute("SELECT COUNT(*) FROM establishment").fetchone()[0]
rows = cur.execute("""
    SELECT id, dba_name, address, zip, license, COALESCE(latest_inspection_date,''),
           COALESCE(score,-1)
    FROM establishment
""").fetchall()

groups = {}
for (oid, dba, addr, zip_, lic, ldate, score) in rows:
    nid = venue_id(dba, addr, zip_, lic)
    groups.setdefault(nid, []).append((oid, ldate, score))

old2new = {}        # every old id -> new id
canon_old = {}      # new id -> chosen canonical old id
to_delete = []      # non-canonical old ids
for nid, members in groups.items():
    best = max(members, key=lambda m: (m[1], m[2]))   # newest inspection, then score
    canon_old[nid] = best[0]
    for (oid, _, _) in members:
        old2new[oid] = nid
        if oid != best[0]:
            to_delete.append(oid)

# Repoint inspections, drop the merged-away rows, then rename canonical ids.
for oid, nid in old2new.items():
    if oid != nid:
        cur.execute("UPDATE inspection SET establishment_id=? WHERE establishment_id=?", (nid, oid))
cur.executemany("DELETE FROM establishment WHERE id=?", [(o,) for o in to_delete])
for nid, oid in canon_old.items():
    if oid != nid:
        cur.execute("UPDATE establishment SET id=? WHERE id=?", (nid, oid))

con.commit()
after = cur.execute("SELECT COUNT(*) FROM establishment").fetchone()[0]
insp = cur.execute("SELECT COUNT(*) FROM inspection").fetchone()[0]
orphans = cur.execute("""
    SELECT COUNT(*) FROM inspection i
    LEFT JOIN establishment e ON e.id = i.establishment_id WHERE e.id IS NULL
""").fetchone()[0]
con.execute("VACUUM")
con.close()
print(f"establishments: {before} -> {after}  (merged {before-after})")
print(f"inspections: {insp}  orphans: {orphans}")
