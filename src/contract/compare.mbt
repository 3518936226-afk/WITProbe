///|
fn finding(
  status : String,
  rule : String,
  symbol : String,
  reason : String,
) -> Finding {
  {
    status,
    rule_id: rule,
    symbol,
    reason,
    action: if status == "UNKNOWN" {
      match rule {
        "UNSUPPORTED_RESOURCE" | "UNSUPPORTED_RESOURCE_OR_ACCESSOR" =>
          "Review nominal resource identity, ownership and lifecycle; these are not covered by the scalar rules."
        "UNSUPPORTED_ASYNC" =>
          "Review async ABI and payload semantics with the intended runtime before extending the rule set."
        "UNMAPPED_DEPENDENCY_VERSION" =>
          "Review the dependency identity mapping explicitly; package versions are not erased automatically."
        "PARAMETER_NAME_CHANGED" =>
          "Review the parameter name change; its compatibility has not been proven by this rule set."
        "UNSUPPORTED_COMPOSITE" =>
          "Review ordered members and nested types, or add a tested composite-type rule; UNKNOWN blocks the gate."
        _ =>
          "Review this symbol manually or add a proven rule; do not treat UNKNOWN as compatible."
      }
    } else {
      "Restore the required contract or migrate the dependent party explicitly."
    },
  }
}

///|
fn check_type(
  actual : TypeDesc,
  expected : TypeDesc,
  path : String,
  out : Array[Finding],
) -> Unit {
  if actual.unsupported is None &&
    expected.unsupported is None &&
    actual.shape != expected.shape {
    out.push(
      finding(
        "BREAKING",
        "TYPE_CHANGED",
        path,
        "Required type " +
        expected.shape +
        " is supplied as " +
        actual.shape +
        ".",
      ),
    )
  }
}

///|
fn check_function(
  actual : Function,
  expected : Function,
  path : String,
  out : Array[Finding],
) -> Unit {
  if actual.unsupported is Some(_) || expected.unsupported is Some(_) {
    return
  }
  if actual.params.length() != expected.params.length() {
    out.push(
      finding(
        "BREAKING", "PARAMETER_COUNT_CHANGED", path, "Parameter count differs.",
      ),
    )
    return
  }
  for i = 0; i < actual.params.length(); i = i + 1 {
    let a = actual.params[i]
    let e = expected.params[i]
    if a.name != e.name {
      out.push(
        finding(
          "UNKNOWN",
          "PARAMETER_NAME_CHANGED",
          path + "/param/" + i.to_string(),
          "Parameter name semantics are outside the proven rules.",
        ),
      )
    }
    check_type(a.ty, e.ty, path + "/param/" + i.to_string(), out)
  }
  match (actual.result, expected.result) {
    (Some(a), Some(e)) => check_type(a, e, path + "/result", out)
    (None, None) => ()
    _ =>
      out.push(
        finding(
          "BREAKING",
          "RESULT_PRESENCE_CHANGED",
          path + "/result",
          "Required result presence differs.",
        ),
      )
  }
}

///|
fn check_edge(
  actual : Edge,
  expected : Edge,
  path : String,
  out : Array[Finding],
) -> Unit {
  if actual.kind != expected.kind {
    out.push(
      finding(
        "BREAKING", "WORLD_ITEM_KIND_CHANGED", path, "A world item changed between interface, function or type.",
      ),
    )
    return
  }
  for e in expected.functions {
    match actual.functions.iter().find_first(fn(a) { a.name == e.name }) {
      Some(a) => check_function(a, e, path + "/function/" + e.name, out)
      None =>
        out.push(
          finding(
            "BREAKING",
            "MISSING_FUNCTION",
            path + "/function/" + e.name,
            "The supplying party does not provide a required function.",
          ),
        )
    }
  }
  for e in expected.types {
    match actual.types.iter().find_first(fn(a) { a.name == e.name }) {
      Some(a) => check_type(a.ty, e.ty, path + "/type/" + e.name, out)
      None =>
        out.push(
          finding(
            "BREAKING",
            "MISSING_PUBLIC_TYPE",
            path + "/type/" + e.name,
            "A public type is required even when no function references it.",
          ),
        )
    }
  }
}

///|
fn base_identity(key : String) -> String {
  key.split("@").to_array()[0].to_owned()
}

///|
fn check_edges(
  available : Array[Edge],
  required : Array[Edge],
  path : String,
  out : Array[Finding],
) -> Unit {
  for e in required {
    match available.iter().find_first(fn(a) { a.key == e.key }) {
      Some(a) => check_edge(a, e, path + "/" + e.key, out)
      None =>
        if available.any(fn(a) { base_identity(a.key) == base_identity(e.key) }) {
          out.push(
            finding(
              "UNKNOWN",
              "UNMAPPED_DEPENDENCY_VERSION",
              path + "/" + e.key,
              "Dependency identity differs only by a version suffix; no mapping was proven.",
            ),
          )
        } else {
          out.push(
            finding(
              "BREAKING",
              "MISSING_WORLD_ITEM",
              path + "/" + e.key,
              "A required world capability is missing.",
            ),
          )
        }
    }
  }
}

///|
fn scan_unknown(
  edges : Array[Edge],
  path : String,
  out : Array[Finding],
) -> Unit {
  for edge in edges {
    let p = path + "/" + edge.key
    if edge.unsupported is Some(code) {
      out.push(
        finding(
          "UNKNOWN", code, p, "This edge requires an unsupported identity or metadata rule.",
        ),
      )
    }
    for t in edge.types {
      if t.ty.unsupported is Some(code) {
        out.push(
          finding(
            "UNKNOWN",
            code,
            p + "/type/" + t.name,
            "Public type is outside the scalar/alias rules, regardless of function usage.",
          ),
        )
      }
    }
    for f in edge.functions {
      let fp = p + "/function/" + f.name
      if f.unsupported is Some(code) {
        out.push(
          finding(
            "UNKNOWN", code, fp, "Function kind or external identity is unsupported.",
          ),
        )
      }
      for param in f.params {
        if param.ty.unsupported is Some(code) {
          out.push(
            finding(
              "UNKNOWN",
              code,
              fp + "/param/" + param.name,
              "Parameter type is unsupported.",
            ),
          )
        }
      }
      if f.result is Some(t) {
        if t.unsupported is Some(code) {
          out.push(
            finding(
              "UNKNOWN",
              code,
              fp + "/result",
              "Result type is unsupported.",
            ),
          )
        }
      }
    }
  }
}

///|
fn diff_edges(
  old : Array[Edge],
  new : Array[Edge],
  path : String,
  out : Array[Change],
) -> Unit {
  for a in old {
    match new.iter().find_first(fn(b) { b.key == a.key }) {
      None =>
        out.push({
          kind: "REMOVED",
          symbol: path + "/" + a.key,
          old_definition: Some(@json.ToJson::to_json(a).stringify()),
          new_definition: None,
        })
      Some(b) => {
        if a != b {
          out.push({
            kind: "MODIFIED",
            symbol: path + "/" + a.key,
            old_definition: Some(@json.ToJson::to_json(a).stringify()),
            new_definition: Some(@json.ToJson::to_json(b).stringify()),
          })
        }
        diff_members(a, b, path + "/" + a.key, out)
      }
    }
  }
  for b in new {
    if !old.any(fn(a) { a.key == b.key }) {
      out.push({
        kind: "ADDED",
        symbol: path + "/" + b.key,
        old_definition: None,
        new_definition: Some(@json.ToJson::to_json(b).stringify()),
      })
    }
  }
}

///|
fn diff_members(
  old : Edge,
  new : Edge,
  path : String,
  out : Array[Change],
) -> Unit {
  for a in old.functions {
    match new.functions.iter().find_first(fn(b) { b.name == a.name }) {
      None =>
        out.push({
          kind: "FUNCTION_REMOVED",
          symbol: path + "/function/" + a.name,
          old_definition: Some(@json.ToJson::to_json(a).stringify()),
          new_definition: None,
        })
      Some(b) =>
        if a != b {
          out.push({
            kind: "FUNCTION_MODIFIED",
            symbol: path + "/function/" + a.name,
            old_definition: Some(@json.ToJson::to_json(a).stringify()),
            new_definition: Some(@json.ToJson::to_json(b).stringify()),
          })
        }
    }
  }
  for b in new.functions {
    if !old.functions.any(fn(a) { a.name == b.name }) {
      out.push({
        kind: "FUNCTION_ADDED",
        symbol: path + "/function/" + b.name,
        old_definition: None,
        new_definition: Some(@json.ToJson::to_json(b).stringify()),
      })
    }
  }
  for a in old.types {
    match new.types.iter().find_first(fn(b) { b.name == a.name }) {
      None =>
        out.push({
          kind: "PUBLIC_TYPE_REMOVED",
          symbol: path + "/type/" + a.name,
          old_definition: Some(@json.ToJson::to_json(a).stringify()),
          new_definition: None,
        })
      Some(b) =>
        if a != b {
          out.push({
            kind: "PUBLIC_TYPE_MODIFIED",
            symbol: path + "/type/" + a.name,
            old_definition: Some(@json.ToJson::to_json(a).stringify()),
            new_definition: Some(@json.ToJson::to_json(b).stringify()),
          })
        }
    }
  }
  for b in new.types {
    if !old.types.any(fn(a) { a.name == b.name }) {
      out.push({
        kind: "PUBLIC_TYPE_ADDED",
        symbol: path + "/type/" + b.name,
        old_definition: None,
        new_definition: Some(@json.ToJson::to_json(b).stringify()),
      })
    }
  }
}

///|
// The public entry uses one relation: actual must satisfy expected.
// consumer-upgrade inputs are provider-world expectations, not the consumer's own world.
pub fn compare(old : Contract, new : Contract, direction : String) -> Report {
  let findings : Array[Finding] = []
  let changes : Array[Change] = []
  let provider = direction == "provider-upgrade"
  let actual = if provider { new } else { old }
  let expected = if provider { old } else { new }
  if direction != "provider-upgrade" && direction != "consumer-upgrade" {
    findings.push(
      finding(
        "ERROR", "INVALID_DIRECTION", "configuration", "Choose provider-upgrade or consumer-upgrade.",
      ),
    )
  } else if old.root_identity != new.root_identity ||
    old.root_identity == "<anonymous>" {
    findings.push(
      finding(
        "ERROR", "ROOT_IDENTITY_MISMATCH", "configuration", "Root namespace/package names differ; no explicit mapping is available.",
      ),
    )
  } else {
    scan_unknown(old.imports, "old/import", findings)
    scan_unknown(old.exports, "old/export", findings)
    scan_unknown(new.imports, "new/import", findings)
    scan_unknown(new.exports, "new/export", findings)
    check_edges(actual.exports, expected.exports, "export", findings)
    // Environment capabilities satisfy the actual provider's requirements.
    check_edges(expected.imports, actual.imports, "import", findings)
    diff_edges(old.imports, new.imports, "import", changes)
    diff_edges(old.exports, new.exports, "export", changes)
  }
  findings.sort_by_key(fn(f) { f.symbol + ":" + f.rule_id })
  changes.sort_by_key(fn(c) { c.symbol + ":" + c.kind })
  let status = if findings.any(fn(f) { f.status == "ERROR" }) {
    "ERROR"
  } else if findings.any(fn(f) { f.status == "BREAKING" }) {
    "BREAKING"
  } else if findings.any(fn(f) { f.status == "UNKNOWN" }) {
    "UNKNOWN"
  } else {
    "COMPATIBLE"
  }
  {
    schema_version: 1,
    rule_set_version: "scalar-sync-v1",
    analysis_scope: "structural",
    direction,
    actual_side: if provider {
      "new"
    } else {
      "old"
    },
    expected_side: if provider {
      "old"
    } else {
      "new"
    },
    status,
    exit_code: match status {
      "COMPATIBLE" => 0
      "BREAKING" => 1
      "ERROR" => 2
      _ => 3
    },
    old_contract: old,
    new_contract: new,
    changes,
    findings,
  }
}
