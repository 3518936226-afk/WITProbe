///|
priv struct IdentityContext {
  root : Int32?
  world : Int32
  mapping : Map[String, String]
}

///|
fn package_identity(
  r : @wit.Resolve,
  pkg : Int32?,
  context : IdentityContext,
  with_version : Bool,
) -> String {
  match pkg {
    None => "<anonymous>"
    Some(i) => {
      let p = r.packages[i].name
      let base = p.ns + ":" + p.name
      if with_version && pkg != context.root {
        match p.version {
          Some(v) => {
            let original = base + "@" + v
            context.mapping.get(original).unwrap_or(original)
          }
          None => base
        }
      } else {
        base
      }
    }
  }
}

///|
fn iface_identity(
  r : @wit.Resolve,
  id : Int32,
  context : IdentityContext,
) -> String {
  let iface = r.interfaces[id]
  let name = match iface.name {
    Some(name) => name
    None => {
      let w = r.worlds[context.world]
      let mut label = "<anonymous-interface>"
      for key, item in w.imports {
        if item is Interface(ref_) && ref_.id == id {
          label = "<world>/import/" + key
        }
      }
      for key, item in w.exports {
        if item is Interface(ref_) &&
          ref_.id == id &&
          label == "<anonymous-interface>" {
          label = "<world>/export/" + key
        }
      }
      label
    }
  }
  let pkg = package_identity(r, iface.pkg, context, true).split("@").to_array()
  let base = pkg[0].to_owned() + "/" + name
  if pkg.length() == 2 {
    base + "@" + pkg[1].to_owned()
  } else {
    base
  }
}

///|
fn nominal_at(
  r : @wit.Resolve,
  id : Int32,
  context : IdentityContext,
  depth : Int32,
) -> String {
  if depth > 256 {
    return "<depth-limit>"
  }
  let t = r.types[id]
  if t.kind is Alias(Id(target)) {
    return nominal_at(r, target, context, depth + 1)
  }
  let owner = match t.owner {
    Interface(i) => iface_identity(r, i, context)
    World(i) =>
      package_identity(r, r.worlds[i].pkg, context, true) +
      "/world/" +
      (if i == context.world { "<selected>" } else { r.worlds[i].name })
    None => "<anonymous-owner>"
  }
  owner + "/type/" + t.name.unwrap_or("<anonymous-type>")
}

///|
fn nominal(r : @wit.Resolve, id : Int32, context : IdentityContext) -> String {
  nominal_at(r, id, context, 0)
}

///|
fn unsupported(shape : String, code : String) -> @contract.TypeDesc {
  { shape, unsupported: Some(code), }
}

///|
fn resource_desc(
  kind : String,
  r : @wit.Resolve,
  id : Int32,
  context : IdentityContext,
) -> @contract.TypeDesc {
  let identity = nominal(r, id, context)
  let shape = kind + ":" + identity
  if resource_metadata(r, id, 0) is Some(code) {
    return unsupported(shape, code)
  }
  if identity.contains("<anonymous") || identity.contains("<depth-limit>") {
    unsupported(shape, "UNRESOLVED_RESOURCE_IDENTITY")
  } else {
    { shape, unsupported: None, }
  }
}

///|
fn resource_metadata(r : @wit.Resolve, id : Int32, depth : Int32) -> String? {
  if depth > 256 {
    return Some("TYPE_DEPTH_LIMIT")
  }
  let t = r.types[id]
  if t.external_id is Some(_) {
    return Some("UNSUPPORTED_EXTERNAL_ID")
  }
  match t.kind {
    Alias(Id(target)) => resource_metadata(r, target, depth + 1)
    Resource => None
    _ => Some("UNRESOLVED_RESOURCE_IDENTITY")
  }
}

///|
// A container is proven only when every nested type is proven. In particular,
// an equal-looking resource/future must not become compatible inside a list.
fn composite(
  shape : String,
  children : Array[@contract.TypeDesc],
) -> @contract.TypeDesc {
  let mut unsupported = None
  for child in children {
    if unsupported is None {
      unsupported = child.unsupported
    }
  }
  { shape, unsupported, }
}

///|
fn describe(
  r : @wit.Resolve,
  ty : @wit.RType,
  context : IdentityContext,
  depth : Int32,
) -> @contract.TypeDesc {
  if depth > 256 {
    return unsupported("<depth-limit>", "TYPE_DEPTH_LIMIT")
  }
  match ty {
    Id(i) => describe_id(r, i, context, depth)
    ErrorContext => unsupported("error-context", "UNSUPPORTED_ASYNC")
    _ => {
      let shape = match ty.to_json() {
        String(s) => s
        other => other.stringify()
      }
      { shape, unsupported: None, }
    }
  }
}

///|
fn function_ir(
  r : @wit.Resolve,
  f : @wit.RFunction,
  context : IdentityContext,
) -> @contract.Function {
  let owner_problem = match f.kind {
    Constructor(id) | Method(id) | Static(id) => resource_metadata(r, id, 0)
    _ => None
  }
  let kind = match f.kind {
    Freestanding => "freestanding"
    AsyncFreestanding | AsyncMethod(_) | AsyncStatic(_) => "async"
    Getter | MethodGetter(_) | StaticGetter(_) => "getter"
    Setter | MethodSetter(_) | StaticSetter(_) => "setter"
    Constructor(id) => "constructor:" + nominal(r, id, context)
    Method(id) => "method:" + nominal(r, id, context)
    Static(id) => "static:" + nominal(r, id, context)
  }
  {
    name: f.name,
    kind,
    params: f.params.map(fn(p) {
      @contract.Parameter::{ name: p.0, ty: describe(r, p.1, context, 0), }
    }),
    result: f.result.map(fn(t) { describe(r, t, context, 0) }),
    external_id: f.external_id,
    unsupported: if f.external_id is Some(_) {
      Some("UNSUPPORTED_EXTERNAL_ID")
    } else if kind == "async" {
      Some("UNSUPPORTED_ASYNC")
    } else if owner_problem is Some(code) {
      Some(code)
    } else if kind == "getter" || kind == "setter" {
      Some("UNSUPPORTED_RESOURCE_OR_ACCESSOR")
    } else if kind.contains("<anonymous") || kind.contains("<depth-limit>") {
      Some("UNRESOLVED_RESOURCE_IDENTITY")
    } else {
      None
    },
  }
}

///|
fn edges(
  r : @wit.Resolve,
  items : Map[String, @wit.RWorldItem],
  context : IdentityContext,
) -> Array[@contract.Edge] {
  let out : Array[@contract.Edge] = []
  for key, item in items {
    match item {
      Interface(ref_) => {
        let iface = r.interfaces[ref_.id]
        let identity = iface_identity(r, ref_.id, context)
        let edge_key = if key == "interface-" + ref_.id.to_string() {
          "interface:" + identity
        } else {
          "label:" + key + "=" + identity
        }
        let funcs = iface.functions
          .values()
          .to_array()
          .map(fn(f) { function_ir(r, f, context) })
        funcs.sort_by_key(fn(f) { f.name })
        let types : Array[@contract.PublicType] = []
        // Every interface type is public, including types unused by functions.
        for name, id in iface.types {
          types.push({ name, ty: describe_id(r, id, context, 0), })
        }
        types.sort_by_key(fn(t) { t.name })
        out.push({
          key: edge_key,
          kind: "interface",
          functions: funcs,
          types,
          external_id: ref_.external_id,
          unsupported: if ref_.external_id is Some(_) {
            Some("UNSUPPORTED_EXTERNAL_ID")
          } else {
            None
          },
        })
      }
      Function(f) =>
        out.push({
          key: "function:" + key,
          kind: "function",
          functions: [function_ir(r, f, context)],
          types: [],
          external_id: f.external_id,
          unsupported: None,
        })
      Type(id) =>
        out.push({
          key: "type:" + key,
          kind: "type",
          functions: [],
          types: [{ name: key, ty: describe_id(r, id, context, 0), }],
          external_id: None,
          unsupported: None,
        })
    }
  }
  out.sort_by_key(fn(e) { e.key })
  out
}

///|
fn contract_ir(
  r : @wit.Resolve,
  world_id : Int32,
  mapping : Map[String, String],
) -> @contract.Contract {
  let w = r.worlds[world_id]
  let context = IdentityContext::{ root: w.pkg, world: world_id, mapping, }
  {
    schema_version: 1,
    root_identity: package_identity(r, w.pkg, context, false),
    source_version: match w.pkg {
      Some(i) => r.packages[i].name.version
      None => None
    },
    world: w.name,
    imports: edges(r, w.imports, context),
    exports: edges(r, w.exports, context),
  }
}

///|
#warnings("-78")
pub fn from_source(
  source : String,
  world : String,
) -> Result[@contract.Contract, String] {
  match @wit.resolve(source) {
    Err(e) => Err(e.to_string())
    Ok(r) => {
      let mut selected : Int32? = None
      for i = 0; i < r.worlds.length(); i = i + 1 {
        if r.worlds[i].name == world {
          if selected is Some(_) {
            return Err("Ambiguous world name: " + world)
          }
          selected = Some(i)
        }
      }
      match selected {
        Some(i) => Ok(contract_ir(r, i, Map([])))
        None => Err("World not found: " + world)
      }
    }
  }
}

///|
pub fn error_json(code : String, message : String, direction : String) -> Json {
  Json::object({
    "schema_version": @json.ToJson::to_json(2),
    "rule_set_version": @json.ToJson::to_json("resource-sync-v3"),
    "status": @json.ToJson::to_json("ERROR"),
    "exit_code": @json.ToJson::to_json(2),
    "direction": @json.ToJson::to_json(direction),
    "error": Json::object({
      "code": @json.ToJson::to_json(code),
      "message": @json.ToJson::to_json(message),
    }),
  })
}

///|
pub fn compare_paths(
  old : String,
  new : String,
  old_world : String,
  new_world : String,
  direction : String,
) -> Json {
  match @wit.resolve_path(old, world=old_world) {
    Err(e) => error_json("OLD_INPUT_ERROR", e.to_string(), direction)
    Ok(a) =>
      match @wit.resolve_path(new, world=new_world) {
        Err(e) => error_json("NEW_INPUT_ERROR", e.to_string(), direction)
        Ok(b) =>
          @contract.compare(from_resolve(a), from_resolve(b), direction).json()
      }
  }
}

///|
fn describe_id(
  r : @wit.Resolve,
  i : Int32,
  context : IdentityContext,
  depth : Int32,
) -> @contract.TypeDesc {
  if depth > 256 {
    return unsupported("<depth-limit>", "TYPE_DEPTH_LIMIT")
  }

  let t = r.types[i]
  let description = match t.kind {
    Alias(a) => describe(r, a, context, depth + 1)
    Resource => resource_desc("resource", r, i, context)
    Handle(kind) =>
      match kind {
        Own(id) => resource_desc("own", r, id, context)
        Borrow(id) => resource_desc("borrow", r, id, context)
      }
    Record(fields) => {
      let children = fields.map(fn(f) {
        describe(r, f.field_type, context, depth + 1)
      })
      let shapes : Array[(String, String)] = []
      for index = 0; index < fields.length(); index = index + 1 {
        shapes.push((fields[index].name, children[index].shape))
      }
      composite("record:" + @json.ToJson::to_json(shapes).stringify(), children)
    }
    Variant(cases) => {
      let children : Array[@contract.TypeDesc] = []
      let shapes = cases.map(fn(c) {
        (
          c.name,
          c.case_type.map(fn(t) {
            let child = describe(r, t, context, depth + 1)
            children.push(child)
            child.shape
          }),
        )
      })
      composite(
        "variant:" + @json.ToJson::to_json(shapes).stringify(),
        children,
      )
    }
    Flags(names) =>
      composite("flags:" + @json.ToJson::to_json(names).stringify(), [])
    Enum(names) =>
      composite("enum:" + @json.ToJson::to_json(names).stringify(), [])
    List(a) => {
      let child = describe(r, a, context, depth + 1)
      composite("list:" + child.shape, [child])
    }
    FixedLengthList(a, n) =>
      unsupported(
        "fixed-list:" +
        n.to_string() +
        ":" +
        describe(r, a, context, depth + 1).shape,
        "UNSUPPORTED_COMPOSITE",
      )
    Map(a, b) =>
      unsupported(
        "map:" +
        @json.ToJson::to_json(
          (
            describe(r, a, context, depth + 1).shape,
            describe(r, b, context, depth + 1).shape,
          ),
        ).stringify(),
        "UNSUPPORTED_COMPOSITE",
      )
    Option(a) => {
      let child = describe(r, a, context, depth + 1)
      composite("option:" + child.shape, [child])
    }
    Tuple(items) => {
      let children = items.map(fn(t) { describe(r, t, context, depth + 1) })
      composite(
        "tuple:" +
        @json.ToJson::to_json(children.map(fn(t) { t.shape })).stringify(),
        children,
      )
    }
    Result(ok~, err~) => {
      let children : Array[@contract.TypeDesc] = []
      let ok_shape = ok.map(fn(t) {
        let child = describe(r, t, context, depth + 1)
        children.push(child)
        child.shape
      })
      let err_shape = err.map(fn(t) {
        let child = describe(r, t, context, depth + 1)
        children.push(child)
        child.shape
      })
      composite(
        "result:" + @json.ToJson::to_json((ok_shape, err_shape)).stringify(),
        children,
      )
    }
    Future(a) =>
      unsupported(
        "future:" +
        @json.ToJson::to_json(
          a.map(fn(t) { describe(r, t, context, depth + 1).shape }),
        ).stringify(),
        "UNSUPPORTED_ASYNC",
      )
    Stream(a) =>
      unsupported(
        "stream:" +
        @json.ToJson::to_json(
          a.map(fn(t) { describe(r, t, context, depth + 1).shape }),
        ).stringify(),
        "UNSUPPORTED_ASYNC",
      )
  }
  match t.external_id {
    Some(id) =>
      unsupported(
        "external:" + id + ":" + description.shape,
        "UNSUPPORTED_EXTERNAL_ID",
      )
    None => description
  }
}

///|
pub fn from_resolve(input : @wit.ResolveInput) -> @contract.Contract {
  contract_ir(input.resolve, input.world_id, Map([]))
}
