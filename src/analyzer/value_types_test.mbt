///|
fn value_source(
  definitions : String,
  parameter : String,
  result : String,
) -> String {
  "package demo:values; interface api { " +
  definitions +
  " f: func(x: " +
  parameter +
  ") -> " +
  result +
  "; } world app { export api; }"
}

///|
fn value_report(
  old : String,
  new : String,
  direction : String,
) -> @contract.Report {
  let old_contract = match @analyzer.from_source(old, "app") {
    Ok(value) => value
    Err(message) => abort(message)
  }
  let new_contract = match @analyzer.from_source(new, "app") {
    Ok(value) => value
    Err(message) => abort(message)
  }
  @contract.compare(old_contract, new_contract, direction)
}

///|
test "nested common values are compatible in both directions" {
  let definitions = "enum color { red, blue } flags access { read, write } record item { id: u32, name: string } variant event { empty, item(item) } type wrapped = list<option<result<tuple<event, color, access>, string>>>;"
  let a = value_source(definitions, "wrapped", "result<list<item>>")
  for direction in ["provider-upgrade", "consumer-upgrade"] {
    let r = value_report(a, a, direction)
    assert_eq(r.status, "COMPATIBLE")
    assert_eq(r.findings.length(), 0)
  }
}

///|
test "common scalar containers preserve aliases and structure" {
  let a = value_source(
    "type num = u32; type xs = list<option<num>>;", "xs", "tuple<num, string>",
  )
  let b = value_source(
    "type xs = list<option<u32>>; type num = u32;", "list<option<u32>>", "tuple<u32, string>",
  )
  assert_eq(value_report(a, b, "provider-upgrade").status, "COMPATIBLE")
  assert_eq(
    @analyzer.from_source(a, "app").unwrap().semantic_json(),
    @analyzer.from_source(b, "app").unwrap().semantic_json(),
  )
}

///|
test "list option tuple and result element changes are breaking" {
  for
    (old_type, new_type) in [
      ("list<u32>", "list<u64>"),
      ("option<u32>", "option<string>"),
      ("tuple<u32, string>", "tuple<string, u32>"),
      ("tuple<u32>", "tuple<u32, u32>"),
      ("result<u32, string>", "result<u64, string>"),
      ("result<u32, string>", "result<u32, u64>"),
      ("result", "result<u32>"),
      ("result<_, string>", "result<string>"),
      (
        "list<option<tuple<u32, result<string>>>>", "list<option<tuple<u64, result<string>>>>",
      ),
    ] {
    let a = value_source("", old_type, "u32")
    let b = value_source("", new_type, "u32")
    for direction in ["provider-upgrade", "consumer-upgrade"] {
      let r = value_report(a, b, direction)
      assert_eq(r.status, "BREAKING")
      assert_true(r.findings.any(fn(f) { f.rule_id == "TYPE_CHANGED" }))
    }
  }
}

///|
test "records variants flags and enums preserve ordered names" {
  for
    (old_def, new_def) in [
      ("record t { a: u32, b: string }", "record t { b: string, a: u32 }"),
      ("record t { a: u32 }", "record t { renamed: u32 }"),
      ("record t { a: u32 }", "record t { a: u64 }"),
      ("variant t { a, b(u32) }", "variant t { a, b(u64) }"),
      ("variant t { a, b(u32) }", "variant t { a, b }"),
      ("variant t { a, b }", "variant t { b, a }"),
      ("enum t { a, b }", "enum t { b, a }"),
      ("flags t { a, b }", "flags t { b, a }"),
    ] {
    for direction in ["provider-upgrade", "consumer-upgrade"] {
      assert_eq(
        value_report(
          value_source(old_def, "t", "t"),
          value_source(new_def, "t", "t"),
          direction,
        ).status,
        "BREAKING",
      )
    }
  }
}

///|
test "public unused value type change cannot escape analysis" {
  let a = "package demo:values; interface api { type value = list<option<u32>>; } world app { export api; }"
  let b = "package demo:values; interface api { type value = list<option<u64>>; } world app { export api; }"
  let r = value_report(a, b, "provider-upgrade")
  assert_eq(r.status, "BREAKING")
  assert_true(r.findings.any(fn(f) { f.symbol.contains("/type/value") }))
}

///|
test "unsupported nested resource and future remain unknown" {
  for
    ty in [
      "list<own<handle>>", "option<borrow<handle>>", "tuple<u32, own<handle>>", "result<u32, own<handle>>",
      "result<own<handle>, u32>", "list<future<u32>>", "option<stream<u32>>",
    ] {
    let a = value_source("resource handle;", ty, "u32")
    let r = value_report(a, a, "provider-upgrade")
    assert_eq(r.status, "UNKNOWN")
    assert_true(r.findings.any(fn(f) { f.symbol.contains("/param/x") }))
  }
  for
    definition in [
      "resource handle; record t { value: own<handle> }", "resource handle; variant t { value(own<handle>), empty }",
    ] {
    let a = value_source(definition, "t", "u32")
    let r = value_report(a, a, "provider-upgrade")
    assert_eq(r.status, "UNKNOWN")
    assert_true(
      r.findings.any(fn(f) {
        f.rule_id == "UNSUPPORTED_RESOURCE" && f.symbol.contains("/param/x")
      }),
    )
  }
}

///|
test "known break wins over nested unsupported type" {
  let a = value_source("resource handle;", "list<own<handle>>", "list<u32>")
  let b = value_source("resource handle;", "list<own<handle>>", "list<u64>")
  let r = value_report(a, b, "provider-upgrade")
  assert_eq(r.status, "BREAKING")
  assert_true(r.findings.any(fn(f) { f.status == "UNKNOWN" }))
  assert_true(r.findings[0].status == "BREAKING")
}

///|
test "summary totals are exact and samples are bounded" {
  let functions : Array[String] = []
  for i = 0; i < 40; i = i + 1 {
    functions.push("call" + i.to_string() + ": func(x: own<handle>);")
  }
  let a = "package demo:values; interface api { resource handle; " +
    functions.join(" ") +
    " } world app { export api; }"
  let r = value_report(a, a, "provider-upgrade")
  let summary = r.summary()
  assert_eq(summary.finding_count, r.findings.length())
  assert_eq(summary.unknown_count, r.findings.length())
  let mut count = 0
  for group in summary.groups {
    count = count + group.count
    assert_true(group.sample_symbols.length() <= 3)
  }
  assert_eq(count, r.findings.length())
  assert_true(r.summary_markdown().contains("Showing 20 of"))
  assert_true(r.summary_markdown().length() < r.markdown().length())
  assert_true(r.markdown().contains("call39"))
}
