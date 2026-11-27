"""Generate a traditional Xcode project with explicit file references; stdlib only."""
from pathlib import Path
import hashlib, json
root=Path(__file__).resolve().parent
project=root/'NOVA'/'NOVA.xcodeproj'
project.mkdir(parents=True,exist_ok=True)
app=root/'NOVA'/'NOVA'
sources=sorted(app.rglob('*.swift'))
assets=app/'Assets.xcassets'
def uid(s): return hashlib.md5(s.encode()).hexdigest().upper()[:24]
def ref(s): return uid('NOVA-'+s)
obj={}
def add(ident, isa, **props): obj[ident]={'isa':isa,**props};return ident
project_id=ref('PBXProject'); target_id=ref('Target'); proj_cfg_list=ref('ConfigProject'); target_cfg_list=ref('ConfigTarget')
main_group=ref('RootGroup'); app_group=ref('AppGroup'); product_group=ref('ProductsGroup')
src_build_phase=ref('SourcesPhase');res_phase=ref('ResourcesPhase'); framework_phase=ref('FrameworksPhase'); product_ref=ref('AppProduct')
file_refs={};build_refs={}
for file in sources+[assets]:
    rel=str(file.relative_to(app))
    file_refs[rel]=ref('File '+rel)
    build_refs[rel]=ref('Build '+rel)
    add(file_refs[rel],'PBXFileReference',lastKnownFileType=('folder.assetcatalog' if file==assets else 'sourcecode.swift'),path=rel,sourceTree='<group>')
    add(build_refs[rel],'PBXBuildFile',fileRef=file_refs[rel])
add(product_ref,'PBXFileReference',explicitFileType='wrapper.application',includeInIndex=0,path='NOVA.app',sourceTree='BUILT_PRODUCTS_DIR')
add(app_group,'PBXGroup',children=[file_refs[rel] for rel in file_refs],path='NOVA',sourceTree='<group>')
add(product_group,'PBXGroup',children=[product_ref],name='Products',sourceTree='<group>')
add(main_group,'PBXGroup',children=[app_group,product_group],sourceTree='<group>')
add(src_build_phase,'PBXSourcesBuildPhase',buildActionMask=2147483647,files=[build_refs[k] for k in build_refs if k.endswith('.swift')],runOnlyForDeploymentPostprocessing=0)
add(res_phase,'PBXResourcesBuildPhase',buildActionMask=2147483647,files=[build_refs[k] for k in build_refs if k.endswith('.xcassets')],runOnlyForDeploymentPostprocessing=0)
add(framework_phase,'PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
add(target_cfg_list,'XCConfigurationList',buildConfigurations=[ref('Target Debug'),ref('Target Release')],defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
add(proj_cfg_list,'XCConfigurationList',buildConfigurations=[ref('Project Debug'),ref('Project Release')],defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
for kind in ('Debug','Release'):
    add(ref('Project '+kind),'XCBuildConfiguration',name=kind,buildSettings={'ALWAYS_SEARCH_USER_PATHS':'NO','CLANG_ENABLE_MODULES':'YES','SWIFT_VERSION':'5.0','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'16.0','TARGETED_DEVICE_FAMILY':'1,2'})
    common={'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'1','DEVELOPMENT_TEAM':'','GENERATE_INFOPLIST_FILE':'NO','INFOPLIST_FILE':'NOVA/Info.plist','INFOPLIST_KEY_CFBundleDisplayName':'NOVA','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.productivity','INFOPLIST_KEY_NSPhotoLibraryUsageDescription':'AI에 첨부할 사진을 선택하기 위해 사진 접근이 필요합니다.','INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription':'사진 저장 기능을 사용할 때 사진 접근이 필요합니다.','INFOPLIST_KEY_NSMicrophoneUsageDescription':'질문을 음성으로 입력하기 위해 마이크를 사용합니다.','INFOPLIST_KEY_NSSpeechRecognitionUsageDescription':'한국어 음성을 텍스트로 변환하기 위해 음성 인식을 사용합니다.','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','IPHONEOS_DEPLOYMENT_TARGET':'16.0','MARKETING_VERSION':'10.0','PRODUCT_BUNDLE_IDENTIFIER':'com.novaproject.multiagent','PRODUCT_NAME':'$(TARGET_NAME)','SDKROOT':'iphoneos','SWIFT_VERSION':'5.0','SWIFT_EMIT_LOC_STRINGS':'YES','TARGETED_DEVICE_FAMILY':'1,2','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','ENABLE_PREVIEWS':'YES','SWIFT_STRICT_CONCURRENCY':'minimal'}
    if kind=='Debug': common.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone','DEBUG_INFORMATION_FORMAT':'dwarf'})
    else: common.update({'SWIFT_OPTIMIZATION_LEVEL':'-O','DEBUG_INFORMATION_FORMAT':'dwarf-with-dsym'})
    add(ref('Target '+kind),'XCBuildConfiguration',name=kind,buildSettings=common)
add(target_id,'PBXNativeTarget',buildConfigurationList=target_cfg_list,buildPhases=[src_build_phase,framework_phase,res_phase],buildRules=[],dependencies=[],name='NOVA',productName='NOVA',productReference=product_ref,productType='com.apple.product-type.application')
add(project_id,'PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1430','TargetAttributes':{target_id:{'CreatedOnToolsVersion':'14.3'}}},buildConfigurationList=proj_cfg_list,compatibilityVersion='Xcode 14.0',developmentRegion='ko',hasScannedForEncodings=0,knownRegions=['ko','en','Base'],mainGroup=main_group,productRefGroup=product_group,projectDirPath='',projectRoot='',targets=[target_id])

def fmt(value, indent=0):
    sp='\t'*indent
    if isinstance(value,dict):
        return '{\n'+''.join(sp+'\t'+f'{escape(k)} = {fmt(v,indent+1)};\n' for k,v in value.items())+sp+'}'
    if isinstance(value,list):
        return '(\n'+''.join(sp+'\t'+fmt(v,indent+1)+',\n' for v in value)+sp+')'
    if isinstance(value,(int,float)):return str(value)
    return escape(value)
def escape(s):
    s=str(s)
    import re
    if re.fullmatch(r'[A-Za-z0-9_./$+*-]+',s):return s
    return json.dumps(s,ensure_ascii=False)
file_content='// !$*UTF8*$!\n'+fmt({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':obj,'rootObject':project_id})+'\n'
(project/'project.pbxproj').write_text(file_content,encoding='utf8')
print('Created Xcode project with',len(sources),'Swift source files')
