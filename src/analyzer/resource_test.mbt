///|
fn resource_source(definition : String) -> String {
  "package demo:handles; interface api { " +
  definition +
  " } world app { export api; }"
}

///|
fn resource_check(
  a : String,
  b : String,
  direction : String,
) -> @contract.Report {
  @contract.compare(
    @analyzer.from_source(a, "app").unwrap(),
    @analyzer.from_source(b, "app").unwrap(),
    direction,
  )
}

///|
test "constructor method static and nested handles are supported" {
  let a = resource_source(
    "resource file { constructor(size: u32); read: func(n: u64) -> list<u8>; open: static func() -> file; } f: func(x: option<borrow<file>>) -> result<own<file>, string>;",
  )
  for d in ["provider-upgrade", "consumer-upgrade"] {
    let r = resource_check(a, a, d)
    assert_eq(r.status, "COMPATIBLE")
    assert_true(
      r.old_contract.exports[0].functions.any(fn(f) {
        f.kind.contains("method:")
      }),
    )
  }
}

///|
test "own borrow and nominal resources cannot be interchanged" {
  let a = resource_source(
    "resource file; resource socket; f: func(x: own<file>);",
  )
  for
    body in [
      "resource file; resource socket; f: func(x: borrow<file>);", "resource file; resource socket; f: func(x: own<socket>);",
    ] {
    for d in ["provider-upgrade", "consumer-upgrade"] {
      assert_eq(resource_check(a, resource_source(body), d).status, "BREAKING")
    }
  }
}

///|
test "resource aliases retain canonical origin" {
  let a = "package demo:handles; interface base { resource file; } interface api { use base.{file as handle}; f: func(x: own<handle>); } world app { export base; export api; }"
  let r = resource_check(a, a, "provider-upgrade")
  assert_eq(r.status, "COMPATIBLE")
  let api = r.old_contract.exports
    .iter()
    .find_first(fn(e) { e.key.contains("/api") })
    .unwrap()
  assert_true(api.functions[0].params[0].ty.shape.contains("/base/type/file"))
  assert_true(!api.functions[0].params[0].ty.shape.contains("/api/type/handle"))
}

///|
test "inline resources with equal names have distinct identities" {
  let a = "package demo:handles; world app { export left: interface { resource file; } export right: interface { resource file; } }"
  let r = resource_check(a, a, "provider-upgrade")
  assert_eq(r.status, "COMPATIBLE")
  assert_true(
    r.old_contract.exports[0].types[0].ty.shape !=
    r.old_contract.exports[1].types[0].ty.shape,
  )
}

///|
test "resource method evolution follows export direction" {
  let a = resource_source("resource file { read: func() -> u32; }")
  let b = resource_source(
    "resource file { read: func() -> u32; write: func(x: u32); }",
  )
  assert_eq(resource_check(a, b, "provider-upgrade").status, "COMPATIBLE")
  assert_eq(resource_check(a, b, "consumer-upgrade").status, "BREAKING")
  let c = resource_source("resource file { read: func() -> u64; }")
  assert_eq(resource_check(a, c, "provider-upgrade").status, "BREAKING")
}

///|
test "resource async methods remain unknown" {
  let a = resource_source("resource file { read: async func() -> u32; }")
  assert_eq(resource_check(a, a, "provider-upgrade").status, "UNKNOWN")
}

///|
test "resource declaration reorder does not depend on parser array ids" {
  let a = resource_source(
    "resource file; resource socket; f: func(x: own<file>, y: borrow<socket>);",
  )
  let b = resource_source(
    "resource socket; resource file; f: func(x: own<file>, y: borrow<socket>);",
  )
  assert_eq(resource_check(a, b, "provider-upgrade").status, "COMPATIBLE")
  assert_eq(resource_check(a, b, "consumer-upgrade").status, "COMPATIBLE")
}
