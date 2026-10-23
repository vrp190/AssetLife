#!/usr/bin/env python3
"""Generate AssetLife.xcodeproj/project.pbxproj from the source tree.

Deterministic: UUIDs are derived from md5 of stable seeds. Re-run after adding
or removing Swift files. Output format: objectVersion 90 (Xcode 27 native format).
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_DIR = os.path.join(ROOT, "AssetLife")
TEST_DIR = os.path.join(ROOT, "AssetLifeTests")
OUT = os.path.join(ROOT, "AssetLife.xcodeproj", "project.pbxproj")

APP_NAME = "AssetLife"
TEST_NAME = "AssetLifeTests"
BUNDLE_ID = "com.gewu.AssetLife"
DEPLOYMENT_TARGET = "17.0"
SWIFT_VERSION = "5.0"


SAFE_UNQUOTED = re.compile(r"^[A-Za-z0-9_@./$-]+$")


def plist_value(v):
    """Quote build-setting values unless they are safe unquoted tokens or already structured."""
    if SAFE_UNQUOTED.match(v):
        return v
    if v.startswith("(") or v.startswith('"'):
        return v
    return '"' + v.replace('"', '\\"') + '"'


def uid(seed):
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


def collect_sources(base):
    out = []
    for dirpath, _dirs, files in os.walk(base):
        for f in sorted(files):
            if f.endswith(".swift"):
                rel = os.path.relpath(os.path.join(dirpath, f), base)
                out.append(rel)
    return sorted(out)


app_sources = collect_sources(APP_DIR)
test_display_sources = collect_sources(TEST_DIR)
# 无宿主 App 的逻辑测试：将核心源码一并编译进测试目标
core_dirs = ["Models", "Services", "ViewModels"]
test_core_sources = []
for d in core_dirs:
    base = os.path.join(APP_DIR, d)
    for dirpath, _dirs, files in os.walk(base):
        for f in sorted(files):
            if f.endswith(".swift"):
                test_core_sources.append(os.path.relpath(os.path.join(dirpath, f), APP_DIR))
# 参与编译的列表；分组只展示真实测试文件
test_sources = sorted(test_display_sources + test_core_sources)
test_group_files = test_display_sources
print("app sources:", len(app_sources))
print("test sources:", len(test_sources))

# ---- IDs ----
app_target_id = uid("target-app")
test_target_id = uid("target-test")
project_id = uid("project")
main_group_id = uid("group-main")
app_group_id = uid("group-app")
test_group_id = uid("group-test")
products_group_id = uid("group-products")
frameworks_app_id = uid("frameworks-app")
frameworks_test_id = uid("frameworks-test")
app_product_id = uid("product-app")
test_product_id = uid("product-test")
app_sources_phase_id = uid("phase-app-sources")
app_res_phase_id = uid("phase-app-resources")
app_frameworks_phase_id = uid("phase-app-frameworks")
test_sources_phase_id = uid("phase-test-sources")
test_frameworks_phase_id = uid("phase-test-frameworks")
app_config_list_id = uid("configlist-app")
test_config_list_id = uid("configlist-test")
project_config_list_id = uid("configlist-project")
app_dbg_id, app_rel_id = uid("cfg-app-debug"), uid("cfg-app-release")
test_dbg_id, test_rel_id = uid("cfg-test-debug"), uid("cfg-test-release")
proj_dbg_id, proj_rel_id = uid("cfg-proj-debug"), uid("cfg-proj-release")
proxy_id = uid("proxy-test")
dep_id = uid("dep-test-app")

assets_ref_id = uid("ref-assets")

# per-file ids
app_file_refs, app_build_files, app_groups = {}, {}, {}
test_file_refs, test_build_files = {}, {}

for rel in app_sources:
    app_file_refs[rel] = uid("fileref-app-" + rel)
    app_build_files[rel] = uid("buildfile-app-" + rel)
for rel in test_sources:
    test_file_refs[rel] = uid("fileref-test-" + rel)
    test_build_files[rel] = uid("buildfile-test-" + rel)
core_source_set = set(test_core_sources)


def group_for(rel):
    d = os.path.dirname(rel)
    return d if d else "."


# Build nested groups for app sources
def build_groups(files, prefix):
    """Return dict: group path -> [child rels]. Root files normalize to '.'."""
    tree = {}
    for rel in files:
        d = os.path.dirname(rel) or "."
        tree.setdefault(d, []).append(rel)
    return tree


app_tree = build_groups(app_sources, "app")
test_tree = build_groups(test_group_files, "test")

# Assign group ids for each directory (including nested)
app_dir_ids = {}
for d in list(app_tree.keys()):
    app_dir_ids[d] = uid("group-app-dir-" + d)


def emit_group_lines(tree, dir_ids, parent_path=""):
    lines = []
    for d in sorted(tree.keys()):
        children = []
        # direct children dirs
        for sub in sorted(tree.keys()):
            if sub == d:
                continue
            parent = os.path.dirname(sub) or "."
            if parent == d:
                children.append(("group", sub, dir_ids[sub]))
        for rel in tree[d]:
            children.append(("file", rel, None))
        children.sort(key=lambda c: (c[0] != "group", os.path.basename(c[1]).lower()))
        lines.append((d, dir_ids[d], children))
    return lines


app_group_lines = emit_group_lines(app_tree, app_dir_ids)
test_dir_ids = {d: uid("group-test-dir-" + d) for d in test_tree}
test_group_lines = emit_group_lines(test_tree, test_dir_ids)

# collect resources (xcassets)
app_resources = []
for dirpath, _dirs, files in os.walk(APP_DIR):
    for f in sorted(files):
        if f.endswith(".xcassets"):
            rel = os.path.relpath(os.path.join(dirpath, f), APP_DIR)
            app_resources.append(rel)

L = []
w = L.append

w("// !$*UTF8*$!")
w("{")
w("\tarchiveVersion = 1;")
w("\tclasses = {")
w("\t};")
w("\tobjectVersion = 90;")
w("\tobjects = {")
w("")
w("/* Begin PBXBuildFile section */")
for rel in app_sources:
    w(f"\t\t{app_build_files[rel]} /* {os.path.basename(rel)} in Sources */ = {{isa = PBXBuildFile; fileRef = {app_file_refs[rel]} /* {os.path.basename(rel)} */; }};")
for rel in app_resources:
    w(f"\t\t{uid('buildfile-res-'+rel)} /* {os.path.basename(rel)} in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref_id} /* {os.path.basename(rel)} */; }};")
for rel in test_sources:
    w(f"\t\t{test_build_files[rel]} /* {os.path.basename(rel)} in Sources */ = {{isa = PBXBuildFile; fileRef = {test_file_refs[rel]} /* {os.path.basename(rel)} */; }};")
w("/* End PBXBuildFile section */")
w("")
w("/* Begin PBXFileReference section */")
w(f"\t\t{app_product_id} /* {APP_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
w(f"\t\t{test_product_id} /* {TEST_NAME}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {TEST_NAME}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
for rel in app_sources:
    w(f"\t\t{app_file_refs[rel]} /* {os.path.basename(rel)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {os.path.basename(rel)}; sourceTree = \"<group>\"; }};")
for rel in app_resources:
    w(f"\t\t{assets_ref_id} /* {os.path.basename(rel)} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {os.path.basename(rel)}; sourceTree = \"<group>\"; }};")
for rel in test_sources:
    if rel in core_source_set:
        ref_path = "../AssetLife/" + rel
    else:
        ref_path = os.path.basename(rel)
    w(f"\t\t{test_file_refs[rel]} /* {os.path.basename(rel)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {ref_path}; sourceTree = \"<group>\"; }};")
w("/* End PBXFileReference section */")
w("")
w("/* Begin PBXFrameworksBuildPhase section */")
w(f"\t\t{app_frameworks_phase_id} /* Frameworks */ = {{")
w("\t\t\tisa = PBXFrameworksBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w(f"\t\t{test_frameworks_phase_id} /* Frameworks */ = {{")
w("\t\t\tisa = PBXFrameworksBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXFrameworksBuildPhase section */")
w("")
w("/* Begin PBXGroup section */")
w(f"\t\t{main_group_id} = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{app_group_id} /* {APP_NAME} */,")
w(f"\t\t\t\t{test_group_id} /* {TEST_NAME} */,")
w(f"\t\t\t\t{products_group_id} /* Products */,")
w("\t\t\t);")
w('\t\t\tsourceTree = "<group>";')
w("\t\t};")

# app group tree: top-level dirs of APP_DIR
# Root-level files (d == ".") go directly into app group
for d, gid, children in app_group_lines:
    if d == ".":
        # merge into the app group itself: emit as app group
        pass
# Emit the app group with top-level children (only direct children of the app root)
app_group_children = []
for d, gid, children in app_group_lines:
    if d == ".":
        for kind, rel, _cid in children:
            if kind == "file":
                app_group_children.append(f"\t\t\t\t{app_file_refs[rel]} /* {os.path.basename(rel)} */,")
top_dirs = sorted({d for d in app_tree if d and os.path.dirname(d) == ""})
for d in top_dirs:
    app_group_children.append(f"\t\t\t\t{app_dir_ids[d]} /* {d} */,")
# 资源文件（Assets.xcassets 等）直接挂在 App 组下
for rel in app_resources:
    app_group_children.append(f"\t\t\t\t{assets_ref_id} /* {os.path.basename(rel)} */,")
w(f"\t\t{app_group_id} /* {APP_NAME} */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for c in app_group_children:
    w(c)
w("\t\t\t);")
w(f'\t\t\tpath = {APP_NAME};')
w('\t\t\tsourceTree = "<group>";')
w("\t\t};")

for d, gid, children in app_group_lines:
    if d == ".":
        continue
    w(f"\t\t{gid} /* {d} */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for kind, rel, cid in children:
        if kind == "file":
            w(f"\t\t\t\t{app_file_refs[rel]} /* {os.path.basename(rel)} */,")
        else:
            w(f"\t\t\t\t{app_dir_ids[rel]} /* {os.path.basename(rel)} */,")
    w("\t\t\t);")
    w(f"\t\t\tpath = {os.path.basename(d)};")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")

# test group
test_group_children = []
for d, gid, children in test_group_lines:
    if d == ".":
        for kind, rel, _cid in children:
            if kind == "file":
                test_group_children.append(f"\t\t\t\t{test_file_refs[rel]} /* {os.path.basename(rel)} */,")
for rel in test_core_sources:
    test_group_children.append(f"\t\t\t\t{test_file_refs[rel]} /* {rel} */,")
w(f"\t\t{test_group_id} /* {TEST_NAME} */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
for c in test_group_children:
    w(c)
w("\t\t\t);")
w(f'\t\t\tpath = {TEST_NAME};')
w('\t\t\tsourceTree = "<group>";')
w("\t\t};")
for d, gid, children in test_group_lines:
    if d == ".":
        continue
    w(f"\t\t{gid} /* {d} */ = {{")
    w("\t\t\tisa = PBXGroup;")
    w("\t\t\tchildren = (")
    for kind, rel, cid in children:
        if kind == "file":
            w(f"\t\t\t\t{test_file_refs[rel]} /* {os.path.basename(rel)} */,")
        else:
            w(f"\t\t\t\t{test_dir_ids[rel]} /* {os.path.basename(rel)} */,")
    w("\t\t\t);")
    w(f"\t\t\tpath = {os.path.basename(d)};")
    w('\t\t\tsourceTree = "<group>";')
    w("\t\t};")

w(f"\t\t{products_group_id} /* Products */ = {{")
w("\t\t\tisa = PBXGroup;")
w("\t\t\tchildren = (")
w(f"\t\t\t\t{app_product_id} /* {APP_NAME}.app */,")
w(f"\t\t\t\t{test_product_id} /* {TEST_NAME}.xctest */,")
w("\t\t\t);")
w('\t\t\tname = Products;')
w('\t\t\tsourceTree = "<group>";')
w("\t\t};")
w("/* End PBXGroup section */")
w("")
w("/* Begin PBXNativeTarget section */")
w(f"\t\t{app_target_id} /* {APP_NAME} */ = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {app_config_list_id} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */;")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{app_sources_phase_id} /* Sources */,")
w(f"\t\t\t\t{app_frameworks_phase_id} /* Frameworks */,")
w(f"\t\t\t\t{app_res_phase_id} /* Resources */,")
w("\t\t\t);")
w("\t\t\tbuildRules = (")
w("\t\t\t);")
w("\t\t\tdependencies = (")
w("\t\t\t);")
w(f"\t\t\tname = {APP_NAME};")
w(f"\t\t\tproductName = {APP_NAME};")
w(f"\t\t\tproductReference = {app_product_id} /* {APP_NAME}.app */;")
w(f'\t\t\tproductType = "com.apple.product-type.application";')
w("\t\t};")
w(f"\t\t{test_target_id} /* {TEST_NAME} */ = {{")
w("\t\t\tisa = PBXNativeTarget;")
w(f"\t\t\tbuildConfigurationList = {test_config_list_id} /* Build configuration list for PBXNativeTarget \"{TEST_NAME}\" */;")
w("\t\t\tbuildPhases = (")
w(f"\t\t\t\t{test_sources_phase_id} /* Sources */,")
w(f"\t\t\t\t{test_frameworks_phase_id} /* Frameworks */,")
w("\t\t\t);")
w("\t\t\tbuildRules = (")
w("\t\t\t);")
w("\t\t\tdependencies = (")
w(f"\t\t\t\t{dep_id} /* PBXTargetDependency */,")
w("\t\t\t);")
w(f"\t\t\tname = {TEST_NAME};")
w(f"\t\t\tproductName = {TEST_NAME};")
w(f"\t\t\tproductReference = {test_product_id} /* {TEST_NAME}.xctest */;")
w(f'\t\t\tproductType = "com.apple.product-type.bundle.unit-test";')
w("\t\t};")
w("/* End PBXNativeTarget section */")
w("")
w("/* Begin PBXProject section */")
w(f"\t\t{project_id} /* Project object */ = {{")
w("\t\t\tisa = PBXProject;")
w("\t\t\tattributes = {")
w("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
w("\t\t\t\tLastSwiftUpdateCheck = 2630;")
w("\t\t\t\tLastUpgradeCheck = 2700;")
w("\t\t\t\tTargetAttributes = {")
w(f"\t\t\t\t\t{app_target_id} = {{")
w("\t\t\t\t\t\tCreatedOnToolsVersion = 27.0;")
w("\t\t\t\t\t};")
w(f"\t\t\t\t\t{test_target_id} = {{")
w("\t\t\t\t\t\tCreatedOnToolsVersion = 27.0;")
w("\t\t\t\t\t\tTestTargetID = " + app_target_id + ";")
w("\t\t\t\t\t};")
w("\t\t\t\t};")
w("\t\t\t};")
w(f"\t\t\tbuildConfigurationList = {project_config_list_id} /* Build configuration list for PBXProject \"{APP_NAME}\" */;")
w("\t\t\tminimizedProjectReferenceProxies = 1;")
w("\t\t\tpreferredProjectObjectVersion = 90;")
w("\t\t\tdevelopmentRegion = en;")
w("\t\t\thasScannedForEncodings = 0;")
w("\t\t\tknownRegions = (")
w("\t\t\t\ten,")
w("\t\t\t\tBase,")
w("\t\t\t\tzh-Hans,")
w("\t\t\t);")
w(f"\t\t\tmainGroup = {main_group_id};")
w(f"\t\t\tproductRefGroup = {products_group_id} /* Products */;")
w('\t\t\tprojectDirPath = "";')
w('\t\t\tprojectRoot = "";')
w("\t\t\ttargets = (")
w(f"\t\t\t\t{app_target_id} /* {APP_NAME} */,")
w(f"\t\t\t\t{test_target_id} /* {TEST_NAME} */,")
w("\t\t\t);")
w("\t\t};")
w("/* End PBXProject section */")
w("")
w("/* Begin PBXProxyFileSystem... (container proxy) */")
w(f"\t\t{proxy_id} /* PBXContainerItemProxy */ = {{")
w("\t\t\tisa = PBXContainerItemProxy;")
w(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
w("\t\t\tproxyType = 1;")
w(f"\t\t\tremoteGlobalIDString = {app_target_id};")
w(f"\t\t\tremoteInfo = {APP_NAME};")
w("\t\t};")
w(f"\t\t{dep_id} /* PBXTargetDependency */ = {{")
w("\t\t\tisa = PBXTargetDependency;")
w(f"\t\t\ttarget = {app_target_id} /* {APP_NAME} */;")
w(f"\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;")
w("\t\t};")
w("")
w("/* Begin PBXResourcesBuildPhase section */")
w(f"\t\t{app_res_phase_id} /* Resources */ = {{")
w("\t\t\tisa = PBXResourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for rel in app_resources:
    w(f"\t\t\t\t{uid('buildfile-res-'+rel)} /* {os.path.basename(rel)} in Resources */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXResourcesBuildPhase section */")
w("")
w("/* Begin PBXSourcesBuildPhase section */")
w(f"\t\t{app_sources_phase_id} /* Sources */ = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for rel in app_sources:
    w(f"\t\t\t\t{app_build_files[rel]} /* {os.path.basename(rel)} in Sources */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w(f"\t\t{test_sources_phase_id} /* Sources */ = {{")
w("\t\t\tisa = PBXSourcesBuildPhase;")
w("\t\t\tbuildActionMask = 2147483647;")
w("\t\t\tfiles = (")
for rel in test_sources:
    w(f"\t\t\t\t{test_build_files[rel]} /* {os.path.basename(rel)} in Sources */,")
w("\t\t\t);")
w("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
w("\t\t};")
w("/* End PBXSourcesBuildPhase section */")
w("")
w("/* Begin XCBuildConfiguration section */")

COMMON_CLANG = [
    ("CLANG_ANALYZER_NONNULL", "YES"),
    ("CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION", "YES_AGGRESSIVE"),
    ("CLANG_CXX_LANGUAGE_STANDARD", "gnu++20"),
    ("CLANG_ENABLE_MODULES", "YES"),
    ("CLANG_ENABLE_OBJC_ARC", "YES"),
    ("CLANG_ENABLE_OBJC_WEAK", "YES"),
    ("CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING", "YES"),
    ("CLANG_WARN_BOOL_CONVERSION", "YES"),
    ("CLANG_WARN_COMMA", "YES"),
    ("CLANG_WARN_CONSTANT_CONVERSION", "YES"),
    ("CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS", "YES"),
    ("CLANG_WARN_DIRECT_OBJC_ISA_USAGE", "YES_ERROR"),
    ("CLANG_WARN_DOCUMENTATION_COMMENTS", "YES"),
    ("CLANG_WARN_EMPTY_BODY", "YES"),
    ("CLANG_WARN_ENUM_CONVERSION", "YES"),
    ("CLANG_WARN_INFINITE_RECURSION", "YES"),
    ("CLANG_WARN_INT_CONVERSION", "YES"),
    ("CLANG_WARN_NON_LITERAL_NULL_CONVERSION", "YES"),
    ("CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF", "YES"),
    ("CLANG_WARN_OBJC_LITERAL_CONVERSION", "YES"),
    ("CLANG_WARN_OBJC_ROOT_CLASS", "YES_ERROR"),
    ("CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER", "YES"),
    ("CLANG_WARN_RANGE_LOOP_ANALYSIS", "YES"),
    ("CLANG_WARN_STRICT_PROTOTYPES", "YES"),
    ("CLANG_WARN_SUSPICIOUS_MOVE", "YES"),
    ("CLANG_WARN_UNGUARDED_AVAILABILITY", "YES_AGGRESSIVE"),
    ("CLANG_WARN_UNREACHABLE_CODE", "YES"),
    ("CLANG_WARN__DUPLICATE_METHOD_MATCH", "YES"),
    ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
    ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
    ("GCC_NO_COMMON_BLOCKS", "YES"),
    ("GCC_WARN_64_TO_32_BIT_CONVERSION", "YES"),
    ("GCC_WARN_ABOUT_RETURN_TYPE", "YES_ERROR"),
    ("GCC_WARN_UNDECLARED_SELECTOR", "YES"),
    ("GCC_WARN_UNINITIALIZED_AUTOS", "YES_AGGRESSIVE"),
    ("GCC_WARN_UNUSED_FUNCTION", "YES"),
    ("GCC_WARN_UNUSED_VARIABLE", "YES"),
]


def emit_config(cfg_id, name, is_debug, is_project, is_test):
    w(f"\t\t{cfg_id} /* {name} */ = {{")
    w("\t\t\tisa = XCBuildConfiguration;")
    w("\t\t\tbuildSettings = {")
    settings = []
    if is_project:
        settings += [
            ("ALWAYS_SEARCH_USER_PATHS", "NO"),
            ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
            ("LOCALIZATION_PREFERS_STRING_CATALOGS", "YES"),
        ]
    else:
        settings += [
            ("ALWAYS_SEARCH_USER_PATHS", "NO"),
            ("ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS", "YES"),
            ("CLANG_ENABLE_MODULES", "YES"),
            ("CODE_SIGNING_ALLOWED", "NO"),
            ("CURRENT_PROJECT_VERSION", "1"),
            ("ENABLE_USER_SCRIPT_SANDBOXING", "YES"),
            ("GENERATE_INFOPLIST_FILE", "YES"),
            ("INFOPLIST_KEY_CFBundleDisplayName", "格物"),
            ("INFOPLIST_KEY_UIApplicationSceneManifest_Generation", "YES"),
            ("INFOPLIST_KEY_UILaunchScreen_Generation", "YES"),
            ("INFOPLIST_KEY_UISupportedInterfaceOrientations", "UIInterfaceOrientationPortrait"),
            ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
            ("LOCALIZATION_PREFERS_STRING_CATALOGS", "YES"),
            ("MARKETING_VERSION", "1.0"),
            ("MTL_FAST_MATH", "YES"),
            ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID if not is_test else BUNDLE_ID + ".Tests"),
            ("PRODUCT_NAME", APP_NAME if not is_test else "$(TARGET_NAME)"),
            ("SDKROOT", "iphoneos"),
            ("SWIFT_EMIT_LOC_STRINGS", "YES"),
            ("SWIFT_VERSION", SWIFT_VERSION),
            ("TARGETED_DEVICE_FAMILY", "1"),
        ]
        if not is_test:
            settings += [
                ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
                ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
            ]
        # 无宿主 App 的逻辑测试：不需要 TEST_HOST / BUNDLE_LOADER
    for k, v in COMMON_CLANG:
        if k not in dict(settings):
            settings.append((k, v))
    if is_debug:
        settings += [
            ("DEBUG_INFORMATION_FORMAT", "dwarf"),
            ("ENABLE_TESTABILITY", "YES"),
            ("GCC_DYNAMIC_NO_PIC", "NO"),
            ("GCC_OPTIMIZATION_LEVEL", "0"),
            ("GCC_PREPROCESSOR_DEFINITIONS", '("DEBUG=1", "$(inherited)")'),
            ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE"),
            ("ONLY_ACTIVE_ARCH", "YES"),
            ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"),
            ("SWIFT_OPTIMIZATION_LEVEL", "-Onone"),
        ]
    else:
        settings += [
            ("DEBUG_INFORMATION_FORMAT", "dwarf-with-dsym"),
            ("GCC_DYNAMIC_NO_PIC", "NO"),
            ("GCC_OPTIMIZATION_LEVEL", "s"),
            ("MTL_ENABLE_DEBUG_INFO", "NO"),
            ("SWIFT_COMPILATION_MODE", "wholemodule"),
            ("SWIFT_OPTIMIZATION_LEVEL", "-O"),
        ]
    # de-dup keys, keep first occurrence, sorted output
    seen = {}
    for k, v in settings:
        if k not in seen:
            seen[k] = v
    for k in sorted(seen):
        v = seen[k]
        w(f"\t\t\t\t{k} = {plist_value(v)};")
    w("\t\t\t};")
    w(f'\t\t\tname = "{name}";')
    w("\t\t};")


emit_config(proj_dbg_id, "Debug", True, True, False)
emit_config(proj_rel_id, "Release", False, True, False)
emit_config(app_dbg_id, "Debug", True, False, False)
emit_config(app_rel_id, "Release", False, False, False)
emit_config(test_dbg_id, "Debug", True, False, True)
emit_config(test_rel_id, "Release", False, False, True)
w("/* End XCBuildConfiguration section */")
w("")
w("/* Begin XCConfigurationList section */")
w(f"\t\t{project_config_list_id} /* Build configuration list for PBXProject \"{APP_NAME}\" */ = {{")
w("\t\t\tisa = XCConfigurationList;")
w("\t\t\tbuildConfigurations = (")
w(f"\t\t\t\t{proj_dbg_id} /* Debug */,")
w(f"\t\t\t\t{proj_rel_id} /* Release */,")
w("\t\t\t);")
w("\t\t\tdefaultConfigurationIsVisible = 0;")
w("\t\t\tdefaultConfigurationName = Release;")
w("\t\t};")
w(f"\t\t{app_config_list_id} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */ = {{")
w("\t\t\tisa = XCConfigurationList;")
w("\t\t\tbuildConfigurations = (")
w(f"\t\t\t\t{app_dbg_id} /* Debug */,")
w(f"\t\t\t\t{app_rel_id} /* Release */,")
w("\t\t\t);")
w("\t\t\tdefaultConfigurationIsVisible = 0;")
w("\t\t\tdefaultConfigurationName = Release;")
w("\t\t};")
w(f"\t\t{test_config_list_id} /* Build configuration list for PBXNativeTarget \"{TEST_NAME}\" */ = {{")
w("\t\t\tisa = XCConfigurationList;")
w("\t\t\tbuildConfigurations = (")
w(f"\t\t\t\t{test_dbg_id} /* Debug */,")
w(f"\t\t\t\t{test_rel_id} /* Release */,")
w("\t\t\t);")
w("\t\t\tdefaultConfigurationIsVisible = 0;")
w("\t\t\tdefaultConfigurationName = Release;")
w("\t\t};")
w("/* End XCConfigurationList section */")
w("\t};")
w(f"\trootObject = {project_id} /* Project object */;")
w("}")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    f.write("\n".join(L) + "\n")
print("wrote", OUT)

# Patch the shared scheme with the real target IDs
scheme_path = os.path.join(ROOT, "AssetLife.xcodeproj", "xcshareddata", "xcschemes", "AssetLife.xcscheme")
if os.path.exists(scheme_path):
    with open(scheme_path) as f:
        scheme = f.read()
    scheme = scheme.replace("TARGET_APP_ID", app_target_id).replace("TARGET_TEST_ID", test_target_id)
    with open(scheme_path, "w") as f:
        f.write(scheme)
    print("patched", scheme_path)
