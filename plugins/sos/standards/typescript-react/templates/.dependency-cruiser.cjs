// ──────────────────────────────────────────────────────────────────────────────
// .dependency-cruiser.cjs — 의존 방향 · 순환 검사 (dependency-cruiser 18)
// 실행: npx --no depcruise . --config .dependency-cruiser.cjs   (CI: ci-typescript.yml lint 잡 "Dependency rules")
//
// 폴더 구조 (Onion = Hexagonal/Clean 을 프런트엔드에 맞춘 것 — src/ 아래 또는 프로젝트 루트):
//   domain/       도메인 — 프로젝트의 다른 폴더도, react·react-dom·next 도 import 하지 않는다 (순수 TS)
//   application/  유스케이스 — 프로젝트 안에서는 domain 만 쓴다 (npm 패키지는 막지 않는다)
//   그 밖의 폴더  app/ · components/ · hooks/ · lib/ · types/ … 는 바깥 계층이라 안쪽을 자유롭게 쓴다
// 의존은 바깥에서 안쪽(domain)으로만 향한다. domain·application 폴더가 없는 프로젝트는 순환 검사만 적용된다.
// domain 이 쓰는 공용 타입·유틸은 domain 안에 둔다(src/types 등 바깥 폴더를 import 하면 실패한다).
// 예외가 꼭 필요하면 규칙의 from/to 에 pathNot 을 더하고, 바로 위 주석에 이유·날짜·담당자를 적는다.
// ──────────────────────────────────────────────────────────────────────────────

/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: "no-circular",
      comment: "Circular imports make modules impossible to load, test or extract on their own.",
      severity: "error",
      from: {},
      to: { circular: true },
    },
    {
      name: "domain-no-outer-layers",
      comment: "domain/ is the innermost layer: it must not import any other project folder.",
      severity: "error",
      from: { path: "^(src/)?domain/" },
      to: { couldNotResolve: false, dependencyTypesNot: ["core"], pathNot: "^(src/)?domain/|(^|/)node_modules/" },
    },
    {
      name: "domain-no-framework",
      comment: "domain/ stays framework-free (type-only imports included) so it runs and tests without React/Next.",
      severity: "error",
      from: { path: "^(src/)?domain/" },
      // resolved (node_modules/…, @types/…) or unresolved bare specifiers
      to: { path: "(^|/)node_modules/(@types/)?(react|react-dom|next)/|^(react|react-dom|next)(/|$)" },
    },
    {
      name: "application-no-outer-layers",
      comment: "application/ may use domain/ only — UI, routes and adapters depend on it, not the other way round.",
      severity: "error",
      from: { path: "^(src/)?application/" },
      to: {
        couldNotResolve: false,
        dependencyTypesNot: ["core"],
        pathNot: "^(src/)?(domain|application)/|(^|/)node_modules/",
      },
    },
    {
      name: "layers-no-unresolvable",
      comment:
        "An import from domain/ or application/ that cannot be resolved (alias missing from tsconfig.json, typo) " +
        "would slip past the layer rules above — fail instead.",
      severity: "error",
      from: { path: "^(src/)?(domain|application)/" },
      to: { couldNotResolve: true, pathNot: "^(react|react-dom|next)(/|$)" },
    },
  ],
  options: {
    doNotFollow: { path: "node_modules" },
    exclude: { path: "^(\\.next|out|build|dist|coverage)/" }, // build output; node_modules is doNotFollow above
    tsPreCompilationDeps: true, // type-only imports count
    tsConfig: { fileName: "tsconfig.json" }, // path aliases (@/…) — an alias missing here fails layers-no-unresolvable
  },
};
