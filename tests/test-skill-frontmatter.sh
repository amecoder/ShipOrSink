#!/usr/bin/env bash
# Every sos skill has a name matching its folder, a description <= 1024 chars,
# is model-invocable (sos:cycle calls stages via the Skill tool), and its
# relative reference links resolve.
# shellcheck source=SCRIPTDIR/_lib.sh
. "$(dirname "$0")/_lib.sh"
EXPECTED="build ci cycle done regress setup ship spec tc"
got="$(find "$PLUGIN/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort | tr '\n' ' ' | sed 's/ $//')"
[ "$got" = "$EXPECTED" ] && ok "9 stage skills present" || bad "skills: '$got'"

for d in "$PLUGIN"/skills/*/; do
  s="$(basename "$d")"
  out="$(python3 - "$d/SKILL.md" "$s" <<'PY'
import re, sys, pathlib
path, folder = pathlib.Path(sys.argv[1]), sys.argv[2]
t = path.read_text()
m = re.match(r"^---\n(.*?)\n---\n", t, re.S)
if not m:
    print("no-frontmatter"); sys.exit()
fm = m.group(1)
name = re.search(r"^name:\s*(\S+)", fm, re.M)
desc = re.search(r"^description:\s*>-\n((?:  .*\n?)+)", fm + "\n", re.M)
problems = []
if not name or name.group(1) != folder:
    problems.append("name")
dlen = len(" ".join(desc.group(1).split())) if desc else -1
if not 0 < dlen <= 1024:
    problems.append(f"desc={dlen}")
if re.search(r"disable-model-invocation:\s*true", fm):
    problems.append("model-invocation-disabled")
for link in re.findall(r"\]\(([^)#]+)(?:#[^)]*)?\)", re.sub(r"```.*?```|`[^`\n]*`", "", t, flags=re.S)):
    if link.startswith(("http", "mailto")):
        continue
    if not (path.parent / link).resolve().exists():
        problems.append(f"broken-link:{link}")
print(",".join(problems) or "ok")
PY
)"
  [ "$out" = "ok" ] && ok "$s frontmatter and links" || bad "$s: $out"
done

echo "references link back"
for f in "$PLUGIN"/references/*.md; do
  out="$(python3 - "$f" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1]); t = re.sub(r"```.*?```|`[^`\n]*`", "", p.read_text(), flags=re.S)
bad = [l for l in re.findall(r"\]\(([^)#]+)(?:#[^)]*)?\)", t)
       if not l.startswith(("http", "mailto")) and not (p.parent / l).resolve().exists()]
print(",".join(bad) or "ok")
PY
)"
  [ "$out" = "ok" ] && ok "$(basename "$f") links" || bad "$(basename "$f"): $out"
done
summary
