///|
#derive(Eq, Debug, ToJson)
pub(all) struct TypeDesc {
  shape : String
  unsupported : String?
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct Parameter {
  name : String
  ty : TypeDesc
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct Function {
  name : String
  kind : String
  params : Array[Parameter]
  result : TypeDesc?
  unsupported : String?
  external_id : String?
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct PublicType {
  name : String
  ty : TypeDesc
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct Edge {
  key : String
  kind : String
  functions : Array[Function]
  types : Array[PublicType]
  unsupported : String?
  external_id : String?
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct Contract {
  schema_version : Int32
  root_identity : String
  source_version : String?
  world : String
  imports : Array[Edge]
  exports : Array[Edge]
}

///|
pub fn Contract::semantic_json(self : Contract) -> Json {
  Json::object({
    "schema_version": @json.ToJson::to_json(self.schema_version),
    "root_identity": @json.ToJson::to_json(self.root_identity),
    "world": @json.ToJson::to_json(self.world),
    "imports": @json.ToJson::to_json(self.imports),
    "exports": @json.ToJson::to_json(self.exports),
  })
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct Finding {
  status : String
  rule_id : String
  symbol : String
  reason : String
  action : String
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct Change {
  kind : String
  symbol : String
  old_definition : String?
  new_definition : String?
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct Report {
  schema_version : Int32
  rule_set_version : String
  analysis_scope : String
  direction : String
  actual_side : String
  expected_side : String
  status : String
  exit_code : Int32
  old_contract : Contract
  new_contract : Contract
  changes : Array[Change]
  findings : Array[Finding]
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct FindingGroup {
  status : String
  rule_id : String
  count : Int32
  sample_symbols : Array[String]
  action : String
}

///|
#derive(Eq, Debug, ToJson)
pub(all) struct ReportSummary {
  finding_count : Int32
  breaking_count : Int32
  unknown_count : Int32
  error_count : Int32
  change_count : Int32
  groups : Array[FindingGroup]
}

///|
pub fn Report::summary(self : Report) -> ReportSummary {
  let grouped : Map[String, Array[Finding]] = Map([])
  for f in self.findings {
    let key = f.status + ":" + f.rule_id
    match grouped.get(key) {
      Some(items) => items.push(f)
      None => grouped.set(key, [f])
    }
  }
  let groups : Array[FindingGroup] = []
  for _, items in grouped {
    let samples : Array[String] = []
    for i = 0; i < items.length() && i < 3; i = i + 1 {
      samples.push(items[i].symbol)
    }
    groups.push({
      status: items[0].status,
      rule_id: items[0].rule_id,
      count: items.length(),
      sample_symbols: samples,
      action: items[0].action,
    })
  }
  groups.sort_by_key(fn(g) { g.status + ":" + g.rule_id })
  {
    finding_count: self.findings.length(),
    breaking_count: self.findings
    .filter(fn(f) { f.status == "BREAKING" })
    .length(),
    unknown_count: self.findings
    .filter(fn(f) { f.status == "UNKNOWN" })
    .length(),
    error_count: self.findings.filter(fn(f) { f.status == "ERROR" }).length(),
    change_count: self.changes.length(),
    groups,
  }
}

///|
fn Report::render_markdown(self : Report, limit : Int32) -> String {
  let summary = self.summary()
  let lines : Array[String] = [
    "# WITProbe compatibility report",
    "",
    "Status: " + self.status,
    "Direction: " + self.direction,
    "Actual provider: " + self.actual_side,
    "Expected contract/environment: " + self.expected_side,
    "Scope: structural; root package versions are mapped explicitly; this is not a runtime linking proof.",
    "Rules: " + self.rule_set_version,
    "",
    "## Summary",
    "",
    "Findings: " +
    summary.finding_count.to_string() +
    "; breaking: " +
    summary.breaking_count.to_string() +
    "; unknown: " +
    summary.unknown_count.to_string() +
    "; errors: " +
    summary.error_count.to_string() +
    "; changes: " +
    summary.change_count.to_string() +
    ".",
  ]
  for group in summary.groups {
    lines.push(
      "- [" +
      group.status +
      "] " +
      group.rule_id +
      ": " +
      group.count.to_string(),
    )
    lines.push("  Action: " + group.action)
    for symbol in group.sample_symbols {
      lines.push("  - Example: " + symbol)
    }
  }
  lines.push("")
  lines.push("## Findings")
  lines.push("")
  for i = 0; i < self.findings.length() && (limit < 0 || i < limit); i = i + 1 {
    let f = self.findings[i]
    lines.push("- [" + f.status + "] " + f.rule_id + " at " + f.symbol)
    lines.push("  " + f.reason + " Action: " + f.action)
  }
  if self.findings.is_empty() {
    lines.push(
      "All obligations in the supported synchronous value-type scope are satisfied.",
    )
  }
  if limit >= 0 && self.findings.length() > limit {
    lines.push(
      "Showing " +
      limit.to_string() +
      " of " +
      self.findings.length().to_string() +
      " findings; use --detail full for every finding and symbol path.",
    )
  }
  lines.push("")
  lines.push("## Changes")
  lines.push("")
  for i = 0; i < self.changes.length() && (limit < 0 || i < limit); i = i + 1 {
    let c = self.changes[i]
    lines.push("- " + c.kind + " at " + c.symbol)
  }
  if self.changes.is_empty() {
    lines.push("No selected-world contract changes.")
  }
  if limit >= 0 && self.changes.length() > limit {
    lines.push(
      "Showing " +
      limit.to_string() +
      " of " +
      self.changes.length().to_string() +
      " changes; use --detail full for complete definitions.",
    )
  }
  lines.join("\n") + "\n"
}

///|
pub fn Report::markdown(self : Report) -> String {
  self.render_markdown(-1)
}

///|
pub fn Report::summary_markdown(self : Report) -> String {
  self.render_markdown(20)
}

///|
pub fn Report::json(self : Report) -> Json {
  match @json.ToJson::to_json(self) {
    Object(fields) => {
      fields.set("detail", @json.ToJson::to_json("full"))
      fields.set("old_semantic_contract", self.old_contract.semantic_json())
      fields.set("new_semantic_contract", self.new_contract.semantic_json())
      fields.set("summary", @json.ToJson::to_json(self.summary()))
      fields.set("markdown", @json.ToJson::to_json(self.markdown()))
      fields.set(
        "summary_markdown",
        @json.ToJson::to_json(self.summary_markdown()),
      )
      Json::object(fields)
    }
    _ => abort("report serialization must produce an object")
  }
}
