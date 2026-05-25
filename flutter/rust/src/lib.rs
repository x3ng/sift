//! C FFI layer for sift — exposes SiftCore via JSON-passing extern "C" functions.
//! Used by Flutter via dart:ffi.

mod api;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::{Mutex, OnceLock};

static STATE: OnceLock<Mutex<api::SiftCoreWrapper>> = OnceLock::new();

fn with_state<F, T>(f: F) -> Result<T, String>
where
    F: FnOnce(&mut api::SiftCoreWrapper) -> Result<T, String>,
{
    let mutex = STATE.get().ok_or("not initialized")?;
    let mut guard = mutex.lock().map_err(|e| e.to_string())?;
    f(&mut guard)
}

fn to_c_string(s: String) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

/// Free a string returned by any sift_* function.
#[unsafe(no_mangle)]
pub extern "C" fn sift_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(ptr));
    }
}

// ── init ──────────────────────────────────────────────────────────

#[unsafe(no_mangle)]
pub extern "C" fn sift_init(data_dir: *const c_char) -> *mut c_char {
    let dir = if data_dir.is_null() {
        None
    } else {
        unsafe { CStr::from_ptr(data_dir).to_str().ok().map(|s| s.to_string()) }
    };
    match api::SiftCoreWrapper::new(dir) {
        Ok(wrapper) => {
            STATE.set(Mutex::new(wrapper)).ok();
            to_c_string(r#"{"ok":true}"#.to_string())
        }
        Err(e) => to_c_string(format!(r#"{{"ok":false,"error":"{}"}}"#, e)),
    }
}

// ── read ──────────────────────────────────────────────────────────

#[unsafe(no_mangle)]
pub extern "C" fn sift_list_parsed(query: *const c_char, show_done: bool) -> *mut c_char {
    let q = unsafe { CStr::from_ptr(query).to_string_lossy().to_string() };
    let result = with_state(|w| w.list_parsed(q, show_done));
    match result {
        Ok(entries) => to_c_string(serde_json::to_string(&entries).unwrap_or_default()),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_get_entry(id_prefix: *const c_char) -> *mut c_char {
    let prefix = unsafe { CStr::from_ptr(id_prefix).to_string_lossy().to_string() };
    let result = with_state(|w| Ok(w.get_entry(prefix)));
    match result {
        Ok(opt) => to_c_string(serde_json::to_string(&opt).unwrap_or_default()),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_all_tags() -> *mut c_char {
    let result = with_state(|w| Ok(w.all_tags()));
    match result {
        Ok(tags) => to_c_string(serde_json::to_string(&tags).unwrap_or_default()),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_search(query: *const c_char) -> *mut c_char {
    let q = unsafe { CStr::from_ptr(query).to_string_lossy().to_string() };
    let result = with_state(|w| Ok(w.search(q)));
    match result {
        Ok(entries) => to_c_string(serde_json::to_string(&entries).unwrap_or_default()),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_stats() -> *mut c_char {
    let result = with_state(|w| Ok(w.stats()));
    match result {
        Ok(stats) => to_c_string(serde_json::to_string(&stats).unwrap_or_default()),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_parse_query(input: *const c_char) -> *mut c_char {
    let s = unsafe { CStr::from_ptr(input).to_string_lossy().to_string() };
    let pq = api::parse_query(s);
    to_c_string(serde_json::to_string(&pq).unwrap_or_default())
}

// ── mutating ──────────────────────────────────────────────────────

#[unsafe(no_mangle)]
pub extern "C" fn sift_add(name: *const c_char, body_json: *const c_char, tags_json: *const c_char) -> *mut c_char {
    let n = unsafe { CStr::from_ptr(name).to_string_lossy().to_string() };
    let body: crate::api::FrbBody = unsafe {
        let js = CStr::from_ptr(body_json).to_string_lossy();
        serde_json::from_str(&js).unwrap_or(crate::api::FrbBody::Empty)
    };
    let tags: Vec<String> = unsafe {
        let js = CStr::from_ptr(tags_json).to_string_lossy();
        serde_json::from_str(&js).unwrap_or_default()
    };
    match with_state(|w| w.add(n, body, tags)) {
        Ok(entry) => to_c_string(serde_json::to_string(&entry).unwrap_or_default()),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_delete(id: *const c_char) -> *mut c_char {
    let id_str = unsafe { CStr::from_ptr(id).to_string_lossy().to_string() };
    match with_state(|w| w.delete(id_str)) {
        Ok(v) => to_c_string(format!(r#"{{"ok":{}}}"#, v)),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_edit(id: *const c_char, name_json: *const c_char, body_json: *const c_char) -> *mut c_char {
    let id_str = unsafe { CStr::from_ptr(id).to_string_lossy().to_string() };
    let n: Option<String> = unsafe {
        let js = CStr::from_ptr(name_json).to_string_lossy();
        if js == "null" { None } else { serde_json::from_str(&js).unwrap_or(None) }
    };
    let b: Option<crate::api::FrbBody> = unsafe {
        let js = CStr::from_ptr(body_json).to_string_lossy();
        if js == "null" { None } else { serde_json::from_str(&js).ok() }
    };
    match with_state(|w| w.edit(id_str, n, b)) {
        Ok(v) => to_c_string(format!(r#"{{"ok":{}}}"#, v)),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_tag(id: *const c_char, add_json: *const c_char, rm_json: *const c_char) -> *mut c_char {
    let id_str = unsafe { CStr::from_ptr(id).to_string_lossy().to_string() };
    let add: Vec<String> = unsafe {
        let js = CStr::from_ptr(add_json).to_string_lossy();
        serde_json::from_str(&js).unwrap_or_default()
    };
    let rm: Vec<String> = unsafe {
        let js = CStr::from_ptr(rm_json).to_string_lossy();
        serde_json::from_str(&js).unwrap_or_default()
    };
    match with_state(|w| w.tag(id_str, add, rm)) {
        Ok(v) => to_c_string(format!(r#"{{"ok":{}}}"#, v)),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_done(id: *const c_char) -> *mut c_char {
    let id_str = unsafe { CStr::from_ptr(id).to_string_lossy().to_string() };
    match with_state(|w| w.done(id_str)) {
        Ok(v) => to_c_string(format!(r#"{{"ok":{}}}"#, v)),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_undo(id: *const c_char) -> *mut c_char {
    let id_str = unsafe { CStr::from_ptr(id).to_string_lossy().to_string() };
    match with_state(|w| w.undo(id_str)) {
        Ok(v) => to_c_string(format!(r#"{{"ok":{}}}"#, v)),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_rename_tag(old: *const c_char, new: *const c_char) -> *mut c_char {
    let old_str = unsafe { CStr::from_ptr(old).to_string_lossy().to_string() };
    let new_str = unsafe { CStr::from_ptr(new).to_string_lossy().to_string() };
    match with_state(|w| w.rename_tag(old_str, new_str)) {
        Ok(n) => to_c_string(format!(r#"{{"count":{}}}"#, n)),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

// ── batch / io ────────────────────────────────────────────────────

#[unsafe(no_mangle)]
pub extern "C" fn sift_batch_delete(ids_json: *const c_char) -> *mut c_char {
    let ids: Vec<String> = unsafe {
        let js = CStr::from_ptr(ids_json).to_string_lossy();
        serde_json::from_str(&js).unwrap_or_default()
    };
    match with_state(|w| w.batch_delete(ids)) {
        Ok(n) => to_c_string(format!(r#"{{"count":{}}}"#, n)),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_batch_tag(ids_json: *const c_char, add_json: *const c_char, rm_json: *const c_char) -> *mut c_char {
    let ids: Vec<String> = unsafe {
        let js = CStr::from_ptr(ids_json).to_string_lossy();
        serde_json::from_str(&js).unwrap_or_default()
    };
    let add: Vec<String> = unsafe {
        let js = CStr::from_ptr(add_json).to_string_lossy();
        serde_json::from_str(&js).unwrap_or_default()
    };
    let rm: Vec<String> = unsafe {
        let js = CStr::from_ptr(rm_json).to_string_lossy();
        serde_json::from_str(&js).unwrap_or_default()
    };
    match with_state(|w| w.batch_tag(ids, add, rm)) {
        Ok(n) => to_c_string(format!(r#"{{"count":{}}}"#, n)),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_export(path: *const c_char) -> *mut c_char {
    let p = unsafe { CStr::from_ptr(path).to_string_lossy().to_string() };
    match with_state(|w| w.export_to(p)) {
        Ok(()) => to_c_string(r#"{"ok":true}"#.to_string()),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn sift_import(path: *const c_char) -> *mut c_char {
    let p = unsafe { CStr::from_ptr(path).to_string_lossy().to_string() };
    match with_state(|w| w.import_from(p)) {
        Ok(n) => to_c_string(format!(r#"{{"count":{}}}"#, n)),
        Err(e) => to_c_string(format!(r#"{{"error":"{}"}}"#, e)),
    }
}
