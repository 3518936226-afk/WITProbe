///|
fn source(body : String) -> String {
  "package demo:test; world app { " + body + " }"
}

///|
fn analyze(old : String, new : String, direction : String) -> @contract.Report {
  let a = @analyzer.from_source(old, "app").unwrap()
  let b = @analyzer.from_source(new, "app").unwrap()
  @contract.compare(a, b, direction)
}

///|
test "adding export has opposite direction verdicts" {
  let a = source("export run: func();")
  let b = source("export run: func(); export extra: func();")
  assert_eq(analyze(a, b, "provider-upgrade").status, "COMPATIBLE")
  assert_eq(analyze(a, b, "consumer-upgrade").status, "BREAKING")
}

///|
test "removing export has opposite direction verdicts" {
  let a = source("export run: func(); export extra: func();")
  let b = source("export run: func();")
  assert_eq(analyze(a, b, "provider-upgrade").status, "BREAKING")
  assert_eq(analyze(a, b, "consumer-upgrade").status, "COMPATIBLE")
}

///|
test "adding import has opposite direction verdicts" {
  let a = source("export run: func();")
  let b = source("import host: func(); export run: func();")
  assert_eq(analyze(a, b, "provider-upgrade").status, "BREAKING")
  assert_eq(analyze(a, b, "consumer-upgrade").status, "COMPATIBLE")
}

///|
test "removing import has opposite direction verdicts" {
  let a = source("import host: func(); export run: func();")
  let b = source("export run: func();")
  assert_eq(analyze(a, b, "provider-upgrade").status, "COMPATIBLE")
  assert_eq(analyze(a, b, "consumer-upgrade").status, "BREAKING")
}

///|
test "scalar parameter change is breaking both ways" {
  let a = source("export f: func(x: u32);")
  let b = source("export f: func(x: string);")
  for d in ["provider-upgrade", "consumer-upgrade"] {
    let r = analyze(a, b, d)
    assert_eq(r.exit_code, 1)
    assert_true(r.findings.any(fn(f) { f.rule_id == "TYPE_CHANGED" }))
  }
}

///|
test "scalar result change and result removal are breaking" {
  let a = source("export f: func() -> u32;")
  assert_eq(
    analyze(a, source("export f: func() -> string;"), "provider-upgrade").status,
    "BREAKING",
  )
  assert_eq(
    analyze(a, source("export f: func();"), "provider-upgrade").status,
    "BREAKING",
  )
}

///|
test "parameter count changes are breaking" {
  assert_eq(
    analyze(
      source("export f: func();"),
      source("export f: func(x: u32);"),
      "provider-upgrade",
    ).status,
    "BREAKING",
  )
}

///|
test "parameter name only is unknown" {
  let r = analyze(
    source("export f: func(x: u32);"),
    source("export f: func(y: u32);"),
    "provider-upgrade",
  )
  assert_eq(r.status, "UNKNOWN")
  assert_eq(r.exit_code, 3)
}

///|
test "public unused scalar type removal is breaking" {
  let a = "package demo:test; interface api { type id = u32; } world app { export api; }"
  let b = "package demo:test; interface api {} world app { export api; }"
  let r = analyze(a, b, "provider-upgrade")
  assert_eq(r.status, "BREAKING")
  assert_true(r.findings.any(fn(f) { f.rule_id == "MISSING_PUBLIC_TYPE" }))
}

///|
test "public unused record containing resource stays unknown" {
  let a = "package demo:test; interface api { resource handle; record item { value: own<handle> } } world app { export api; }"
  let r = analyze(a, a, "provider-upgrade")
  assert_eq(r.status, "UNKNOWN")
  assert_true(r.findings.any(fn(f) { f.rule_id == "UNSUPPORTED_RESOURCE" }))
}

///|
test "public resource gives actionable code" {
  let a = "package demo:test; interface api { resource item; } world app { export api; }"
  let r = analyze(a, a, "provider-upgrade")
  assert_eq(r.status, "UNKNOWN")
  assert_true(
    r.findings.any(fn(f) {
      f.rule_id == "UNSUPPORTED_RESOURCE" && f.action.length() > 0
    }),
  )
}

///|
test "async function never receives compatible by omission" {
  let a = "package demo:test; interface api { f: async func() -> future<u32>; } world app { export api; }"
  assert_eq(analyze(a, a, "provider-upgrade").status, "UNKNOWN")
}

///|
test "unexported interface does not contaminate selected world" {
  let a = source("export run: func();")
  let b = "package demo:test; interface unused { resource item; } world app { export run: func(); }"
  let r = analyze(a, b, "provider-upgrade")
  assert_eq(r.status, "COMPATIBLE")
  assert_eq(r.changes.length(), 0)
}

///|
test "declaration reordering produces equal IR" {
  let a = "package demo:test; interface api { z: func(); a: func(); type count = u32; } world app { export api; import host: func(); }"
  let b = "package demo:test; interface api { type count = u32; a: func(); z: func(); } world app { import host: func(); export api; }"
  assert_eq(
    @analyzer.from_source(a, "app").unwrap(),
    @analyzer.from_source(b, "app").unwrap(),
  )
}

///|
test "parameter order is preserved and changes remain visible" {
  let a = source("export f: func(x: u32, y: string);")
  let b = source("export f: func(y: string, x: u32);")
  assert_eq(analyze(a, b, "provider-upgrade").status, "BREAKING")
}

///|
test "breaking wins but unknown findings are retained" {
  let a = "package demo:test; interface api { resource item; } world app { export api; export run: func(); }"
  let b = "package demo:test; interface api { resource item; } world app { export api; }"
  let r = analyze(a, b, "provider-upgrade")
  assert_eq(r.status, "BREAKING")
  assert_true(r.findings.any(fn(f) { f.status == "UNKNOWN" }))
}

///|
test "direction reversal invariant" {
  let a = source("export f: func();")
  let b = source("export f: func(); export extra: func();")
  assert_eq(
    analyze(a, b, "provider-upgrade").status,
    analyze(b, a, "consumer-upgrade").status,
  )
}

///|
test "invalid direction and root identity are errors" {
  let a = source("export f: func();")
  assert_eq(analyze(a, a, "invalid").exit_code, 2)
  assert_eq(
    analyze(
      a, "package other:test; world app { export f: func(); }", "provider-upgrade",
    ).exit_code,
    2,
  )
}

///|
test "invalid syntax is input failure outside compatibility states" {
  assert_true(@analyzer.from_source("package invalid;", "app") is Err(_))
}

///|
test "report human and machine conclusion share one source" {
  let r = analyze(source("export f: func();"), source(""), "provider-upgrade")
  assert_true(r.markdown().contains("Status: " + r.status))
  assert_true(r.json().stringify().contains("BREAKING"))
  assert_eq(r.actual_side, "new")
  assert_eq(r.expected_side, "old")
}

///|
test "root version is preserved separately from structural identity" {
  let a = "package demo:test@1.0.0; world app { export f: func(); }"
  let b = "package demo:test@2.0.0; world app { export f: func(); }"
  let r = analyze(a, b, "provider-upgrade")
  assert_eq(r.status, "COMPATIBLE")
  assert_true(r.old_contract.source_version != r.new_contract.source_version)
  assert_eq(r.old_contract.semantic_json(), r.new_contract.semantic_json())
}

///|
test "interface imported function additions reverse the export rule" {
  let a = "package demo:test; interface api { f: func(); } world app { import api; }"
  let b = "package demo:test; interface api { f: func(); g: func(); } world app { import api; }"
  let p = analyze(a, b, "provider-upgrade")
  assert_eq(p.status, "BREAKING")
  assert_eq(analyze(a, b, "consumer-upgrade").status, "COMPATIBLE")
  assert_true(
    p.changes.any(fn(c) {
      c.kind == "FUNCTION_ADDED" && c.symbol.contains("/function/g")
    }),
  )
}

///|
test "dependency version mismatch is unknown rather than missing export" {
  let a = "package demo:test; world app { export dep:service/api@1.0.0; } package dep:service@1.0.0 { interface api { f: func(); } }"
  let b = "package demo:test; world app { export dep:service/api@2.0.0; } package dep:service@2.0.0 { interface api { f: func(); } }"
  let r = analyze(a, b, "provider-upgrade")
  assert_eq(r.status, "UNKNOWN")
  assert_true(
    r.findings.any(fn(f) { f.rule_id == "UNMAPPED_DEPENDENCY_VERSION" }),
  )
}

///|
test "scalar alias normalization is stable" {
  let a = "package demo:test; interface api { type number = u32; f: func(x: number); } world app { export api; }"
  let b = "package demo:test; interface api { f: func(x: u32); type number = u32; } world app { export api; }"
  assert_eq(analyze(a, b, "provider-upgrade").status, "COMPATIBLE")
  assert_eq(
    @analyzer.from_source(a, "app").unwrap().semantic_json(),
    @analyzer.from_source(b, "app").unwrap().semantic_json(),
  )
}

///|
test "record member ordering change is breaking" {
  let a = "package demo:test; interface api { record item { a: u32, b: string } } world app { export api; }"
  let b = "package demo:test; interface api { record item { b: string, a: u32 } } world app { export api; }"
  let r = analyze(a, b, "provider-upgrade")
  assert_eq(r.status, "BREAKING")
  assert_true(r.old_contract.semantic_json() != r.new_contract.semantic_json())
}
