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
pub fn Report::markdown(self : Report) -> String {
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
    "## Findings",
    "",
  ]
  for f in self.findings {
    lines.push("- [" + f.status + "] " + f.rule_id + " at " + f.symbol)
    lines.push("  " + f.reason + " Action: " + f.action)
  }
  if self.findings.is_empty() {
    lines.push(
      "All obligations in the supported scalar/synchronous scope are satisfied.",
    )
  }
  lines.push("")
  lines.push("## Changes")
  lines.push("")
  for c in self.changes {
    lines.push("- " + c.kind + " at " + c.symbol)
  }
  if self.changes.is_empty() {
    lines.push("No selected-world contract changes.")
  }
  lines.join("\n") + "\n"
}

///|
pub fn Report::json(self : Report) -> Json {
  match @json.ToJson::to_json(self) {
    Object(fields) => {
      fields.set("old_semantic_contract", self.old_contract.semantic_json())
      fields.set("new_semantic_contract", self.new_contract.semantic_json())
      fields.set("markdown", @json.ToJson::to_json(self.markdown()))
      Json::object(fields)
    }
    _ => abort("report serialization must produce an object")
  }
}
