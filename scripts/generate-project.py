"""Deterministic Xcode project, no third-party generator required. Run from any cwd."""
from pathlib import Path
import hashlib
import json

root = Path(__file__).resolve().parents[1]
ios = root / 'ios'
project = ios / 'Bridge.xcodeproj'
project.mkdir(exist_ok=True)
objects = []

def uid(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def q(value):
    return json.dumps(str(value), ensure_ascii=False)

def obj(name, content):
    objects.append(f'\t\t{uid(name)} = {{ {content} }};')
    return uid(name)

sources = sorted((ios / 'Bridge').rglob('*.swift'))
refs, builds = [], []
for path in sources:
    name = path.relative_to(ios).as_posix()
    ref = obj('file:' + name, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(name)}; sourceTree = "<group>";')
    refs.append(ref)
    builds.append(obj('build:' + name, f'isa = PBXBuildFile; fileRef = {ref};'))
plist = obj('plist', 'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Bridge/Info.plist; sourceTree = "<group>";')
app = obj('app', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = Bridge.app; sourceTree = BUILT_PRODUCTS_DIR;')
products = obj('products', f'isa = PBXGroup; children = ({app},); name = Products; sourceTree = "<group>";')
group = obj('root', f'isa = PBXGroup; children = ({",".join(refs + [plist, products])},); sourceTree = "<group>";')
source_phase = obj('sources', f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(builds)},); runOnlyForDeploymentPostprocessing = 0;')
framework_phase = obj('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
resource_phase = obj('resources', 'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')

for scope in ['project', 'target']:
    configs = []
    for mode in ['Debug', 'Release']:
        settings = {
            'CLANG_ENABLE_MODULES': 'YES', 'SWIFT_VERSION': '5.0', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
            'SDKROOT': 'iphoneos', 'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O',
        }
        if mode == 'Debug':
            settings.update({'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG', 'ENABLE_TESTABILITY': 'YES', 'DEBUG_INFORMATION_FORMAT': 'dwarf'})
        else:
            settings.update({'SWIFT_COMPILATION_MODE': 'wholemodule', 'DEBUG_INFORMATION_FORMAT': 'dwarf-with-dsym'})
        if scope == 'target':
            settings.update({
                'PRODUCT_BUNDLE_IDENTIFIER': 'com.ixytyxi.bridge', 'PRODUCT_NAME': '$(TARGET_NAME)',
                'INFOPLIST_FILE': 'Bridge/Info.plist', 'CODE_SIGN_STYLE': 'Automatic',
                'CURRENT_PROJECT_VERSION': '1', 'MARKETING_VERSION': '0.1.0',
                'TARGETED_DEVICE_FAMILY': '1', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
                'SUPPORTS_MACCATALYST': 'NO', 'LD_RUNPATH_SEARCH_PATHS': '$(inherited) @executable_path/Frameworks',
            })
        configs.append(obj(scope + mode, 'isa = XCBuildConfiguration; buildSettings = {' + ''.join(f'{k} = {q(v)};' for k, v in settings.items()) + f'}}; name = {mode};'))
    obj(scope + 'configs', f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')

target = obj('target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({source_phase},{framework_phase},{resource_phase},); buildRules = (); dependencies = (); name = Bridge; productName = Bridge; productReference = {app}; productType = "com.apple.product-type.application";')
obj('project', f'isa = PBXProject; attributes = {{LastUpgradeCheck = 2600; TargetAttributes = {{{target} = {{CreatedOnToolsVersion = 26.0;}};}};}}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base, "zh-Hans"); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
(project / 'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n' + '\n'.join(objects) + f'\n\t}};\n\trootObject = {uid("project")};\n}}\n', encoding='utf-8')
schemes = project / 'xcshareddata' / 'xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
(schemes / 'Bridge.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
  <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
   <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Bridge.app" BlueprintName="Bridge" ReferencedContainer="container:Bridge.xcodeproj"/>
  </BuildActionEntry></BuildActionEntries>
 </BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
  <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Bridge.app" BlueprintName="Bridge" ReferencedContainer="container:Bridge.xcodeproj"/></BuildableProductRunnable>
 </LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''', encoding='utf-8')
print(f'Generated {project} ({len(sources)} Swift files)')
