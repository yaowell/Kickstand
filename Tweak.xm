// ============================================================================
//  Kickstand — 剪切板插件「全局自动粘贴」外挂补丁
//  环境: Theos + Logos / roothide(无根) / iOS 16+ / arm64 + arm64e
// ----------------------------------------------------------------------------
//  设计思路(为什么这么写):
//   1) 点击拦截 — 两条路:
//      (a) 【精准】配置 ClickSelectors = ["类名:选择器", ...]
//      (b) 【自发现】按 dylib 镜像名(PluginImageHints)枚举该镜像里定义的所有类,
//          再把选择器命中 SelectorPatterns 的方法全部 hook 一遍(同一 IMP 中转)。
//          这样即使不知道类名,只要知道 dylib 的文件名就能拦住点击。
//   2) 写入剪贴板 — 原插件逻辑一行不动(%orig 照常调用),本补丁只在旁边"监听"
//      UIPasteboard 的所有 public setter,用来确认"点击->写入"这个事件确实发生了。
//   3) 全局模拟粘贴 — 只在【原插件未注入】的普通 App 进程里执行,延迟 0.1~0.2s,
//      走第一响应者 paste:,兜底 UITextInput/UIKeyInput insertText:。
//   4) 防冲突 — 进程内一旦检测到原插件(dylib 镜像 / 特征类名 / 类名前缀)存在,
//      或本进程是 SpringBoard 这类原生环境 → 只广播信号,绝不自己粘贴。
//      已注入的 App / SpringBoard 完完全全交给原插件,一个字节都不掺和。
// ============================================================================

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <time.h>
#import <string.h>

#if __has_include(<notify.h>)
#import <notify.h>
#else
// iPhoneOS SDK 里不一定有这个头,直接声明(darwin notify 在 libSystem 里)
extern uint32_t notify_post(const char *name);
extern uint32_t notify_register_dispatch(const char *name, int *out_token,
                                         dispatch_queue_t queue, void (^handler)(int));
#endif

// ============================================================================
//  1. 编译期默认配置(运行时可被 plist 覆盖,不用重编译)
// ============================================================================

// 补丁总开关
#define KS_ENABLED_DEFAULT              YES
// 详细日志(调试期开着,稳定后关掉)
#define KS_VERBOSE_DEFAULT              YES
// 只观察不粘贴(首次装车建议先 YES,看日志确认拦到的类/方法对了,再改 NO)
#define KS_DRY_RUN_DEFAULT              NO
// 粘贴延迟(秒),需求要求 0.1 ~ 0.2
#define KS_PASTE_DELAY_DEFAULT          0.15
// 剪贴板轮询间隔(秒)
#define KS_POLL_INTERVAL_DEFAULT        0.08
// 面板广播开关(在面板/SpringBoard 进程里 post darwin 通知,给目标 App 收)
#define KS_PANEL_SIGNAL_DEFAULT         YES
// 没有找到输入框就不粘(避免把内容糊到奇怪的地方)
#define KS_REQUIRE_TEXT_INPUT_DEFAULT   YES
// 自动发现开关
#define KS_AUTODISCOVER_DEFAULT         YES
// 是否 hook 原插件所有类(不推荐,命中面太大)
#define KS_HOOK_ALL_CLASSES_DEFAULT     NO

// 【重要】把你那个插件的 dylib 文件名(不含 .dylib 后缀,大小写不敏感)填进来。
// 例:插件装完在 /var/jb/Library/MobileSubstrate/DynamicLibraries/XXX.dylib
//     → 这里写 @"XXX"
// 留空也能跑:补丁会在日志里把所有"第三方 dylib 候选"列出来给你挑。
#define KS_DEFAULT_PLUGIN_IMAGE_HINTS   @[ \
    /* @"XXX" */ \
]

// 原插件的特征类名(可选,最硬的一条判据)
#define KS_DEFAULT_PLUGIN_CLASS_HINTS   @[ \
    /* @"XXXClipboardManager" */ \
]

// 原插件的类名前缀(可选)
#define KS_DEFAULT_PLUGIN_CLASS_PREFIXES @[ \
    /* @"XXX" */ \
]

// 精准拦截的点击方法,格式 "类名:选择器"(选择器带不带冒号都行)
#define KS_DEFAULT_CLICK_SELECTORS      @[ \
    /* @"XXXHistoryCell:didTapRow", */ \
]

// 自发现模式下的选择器关键字(小写匹配)
#define KS_DEFAULT_SELECTOR_PATTERNS    @[ \
    @"didselect", @"selectrow", @"rowtap", @"didpick", @"didchoose", \
    @"handletap", @"tapped", @"tapgesture", @"tapon", \
    @"onclick", @"clicked", @"didclick", \
    @"applyitem", @"applytext", @"pasteitem", @"copyitem", @"insertitem", \
    @"chooseitem", @"menuaction", @"performaction", @"itemselected" \
]

// 默认不注入的进程
#define KS_DEFAULT_SKIP_BUNDLES         @[ \
    @"com.apple.springboard", \
    @"com.apple.backboardd" \
]

// 默认白名单(空 = 全部进程都注入;填了就只在列表里的 App 生效)
#define KS_DEFAULT_INJECT_BUNDLES       @[ \
]

// 跨进程广播名(面板进程 post,目标 App 收)
#define KS_DARWIN_NOTIFY_NAME           "com.kickstand.paste.request"

#define KS_PREFS_PATH_1  @"/var/mobile/Library/Preferences/com.kickstand.plist"
#define KS_PREFS_PATH_2  @"/var/jb/var/mobile/Library/Preferences/com.kickstand.plist"

// ============================================================================
//  2. 全局状态
// ============================================================================

static NSUInteger   gKSLastChangeCount = 0;      // 上次看到的剪贴板版本号
static NSTimeInterval gKSSelfWriteUntil = 0;     // 本进程自己写剪贴板的时间窗(窗内不算外部写入)
static BOOL         gKSPasteDone       = NO;     // 本轮粘贴是否已完成
static NSTimeInterval gKSLastTrigger   = 0;      // 上次触发时间(去抖)
static dispatch_source_t gKSPollTimer  = nil;
static int          gKSNotifyToken     = -1;
static NSMutableDictionary<NSString *, NSValue *> *gKSOrigIMPs = nil;  // 运行时 hook 的原始 IMP
static NSMutableSet<NSString *>       *gKSHookedKeys = nil;            // 已 hook 的 key,防重复

// ============================================================================
//  3. 日志
// ============================================================================

// 前置声明:KSLog 宏要用到它
static BOOL KSPrefBool(NSString *key, BOOL def);

static NSString *KSLogPath(void) {
    static NSString *path = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray<NSString *> *cands = @[
            @"/var/tmp/Kickstand.log",
            @"/var/mobile/Library/Logs/Kickstand.log",
            [NSTemporaryDirectory() stringByAppendingPathComponent:@"Kickstand.log"]
        ];
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *c in cands) {
            NSString *dir = [c stringByDeletingLastPathComponent];
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
            [fm createFileAtPath:c contents:nil attributes:nil];
            if ([fm isWritableFileAtPath:c]) { path = c; break; }
        }
        if (!path) path = cands.lastObject;
    });
    return path;
}

static void KSLogRaw(NSString *msg) {
    time_t t = time(NULL);
    struct tm tmv;
    localtime_r(&t, &tmv);
    char ts[16];
    strftime(ts, sizeof(ts), "%H:%M:%S", &tmv);
    NSString *line = [NSString stringWithFormat:@"[%s][pid %d] %@\n", ts, getpid(), msg];
    @try {
        NSString *p = KSLogPath();
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
        if (!fh) {
            [line writeToFile:p atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            return;
        }
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    } @catch (NSException *e) { /* 日志失败绝不能影响主流程 */ }
}

#define KSLog(fmt, ...) \
    do { if (KSPrefBool(@"Verbose", KS_VERBOSE_DEFAULT)) \
        KSLogRaw([NSString stringWithFormat:(fmt), ##__VA_ARGS__]); } while (0)

// ============================================================================
//  4. 偏好读取(从 plist 覆盖编译期默认值)
// ============================================================================

static id KSPref(NSString *key) {
    static NSDictionary *prefs = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (NSString *p in @[KS_PREFS_PATH_1, KS_PREFS_PATH_2]) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:p];
            if (d) { prefs = d; break; }
        }
        if (!prefs) prefs = @{};
    });
    return prefs[key];
}

static BOOL KSPrefBool(NSString *key, BOOL def) {
    id v = KSPref(key);
    return v ? [v boolValue] : def;
}

static double KSPrefDouble(NSString *key, double def) {
    id v = KSPref(key);
    return v ? [v doubleValue] : def;
}

static NSArray *KSPrefArray(NSString *key, NSArray *fallback) {
    id v = KSPref(key);
    return [v isKindOfClass:[NSArray class]] ? v : fallback;
}

static NSArray<NSString *> *KSMerge(NSArray *base, NSString *prefKey) {
    NSMutableArray *m = [NSMutableArray array];
    if ([base isKindOfClass:[NSArray class]]) [m addObjectsFromArray:base];
    NSArray *p = KSPrefArray(prefKey, nil);
    if (p) [m addObjectsFromArray:p];
    NSMutableArray *out = [NSMutableArray array];
    for (id x in m) {
        if ([x isKindOfClass:[NSString class]] && [x length]) [out addObject:x];
    }
    return [out copy];
}

static NSArray<NSString *> *KSPluginImageHints(void) {
    static NSArray *v; static dispatch_once_t once;
    dispatch_once(&once, ^{ v = KSMerge(KS_DEFAULT_PLUGIN_IMAGE_HINTS, @"PluginImageHints"); });
    return v;
}
static NSArray<NSString *> *KSPluginClassHints(void) {
    static NSArray *v; static dispatch_once_t once;
    dispatch_once(&once, ^{ v = KSMerge(KS_DEFAULT_PLUGIN_CLASS_HINTS, @"PluginClassHints"); });
    return v;
}
static NSArray<NSString *> *KSPluginClassPrefixes(void) {
    static NSArray *v; static dispatch_once_t once;
    dispatch_once(&once, ^{ v = KSMerge(KS_DEFAULT_PLUGIN_CLASS_PREFIXES, @"PluginClassPrefixes"); });
    return v;
}
static NSArray<NSString *> *KSSelectorPatterns(void) {
    static NSArray *v; static dispatch_once_t once;
    dispatch_once(&once, ^{ v = KSMerge(KS_DEFAULT_SELECTOR_PATTERNS, @"SelectorPatterns"); });
    return v;
}
static NSArray<NSString *> *KSClickSelectors(void) {
    static NSArray *v; static dispatch_once_t once;
    dispatch_once(&once, ^{ v = KSMerge(KS_DEFAULT_CLICK_SELECTORS, @"ClickSelectors"); });
    return v;
}

// ============================================================================
//  5. 进程 / 环境判定
// ============================================================================

static NSString *KSBundleID(void) {
    static NSString *b = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ b = [NSBundle mainBundle].bundleIdentifier ?: @""; });
    return b;
}

static NSString *KSProcessName(void) {
    static NSString *n = nil; static dispatch_once_t once;
    dispatch_once(&once, ^{ n = [NSProcessInfo processInfo].processName ?: @""; });
    return n;
}

// SpringBoard / backboardd 这类原生环境 = 只广播,绝不粘
static BOOL KSIsSystemProcess(void) {
    NSString *bid = KSBundleID();
    NSString *pn  = KSProcessName();
    if ([bid hasPrefix:@"com.apple.springboard"]) return YES;
    if ([bid isEqualToString:@"com.apple.backboardd"]) return YES;
    if ([pn isEqualToString:@"SpringBoard"] || [pn isEqualToString:@"backboardd"]) return YES;
    return NO;
}

static BOOL KSImagePathMatches(NSString *path, NSArray<NSString *> *hints) {
    if (!path.length) return NO;
    if ([path rangeOfString:@"Kickstand" options:NSCaseInsensitiveSearch].location != NSNotFound) return NO;
    for (NSString *h in hints) {
        if (h.length && [path rangeOfString:h options:NSCaseInsensitiveSearch].location != NSNotFound)
            return YES;
    }
    return NO;
}

// 本进程里到底有没有加载那个原插件
static BOOL KSPluginLoadedInThisProcess(void) {
    NSArray<NSString *> *hints = KSPluginImageHints();
    NSArray<NSString *> *clsH  = KSPluginClassHints();
    NSArray<NSString *> *pfx   = KSPluginClassPrefixes();

    // 判据一:加载的镜像里有没有那个 dylib(每次都实扫,防止后面 dlopen 进来的)
    if (hints.count) {
        uint32_t n = _dyld_image_count();
        for (uint32_t i = 0; i < n; i++) {
            const char *nm = _dyld_get_image_name(i);
            if (!nm) continue;
            NSString *p = [NSString stringWithUTF8String:nm];
            if (KSImagePathMatches(p, hints)) return YES;
        }
    }

    // 判据二:特征类名
    for (NSString *c in clsH) {
        if (c.length && NSClassFromString(c)) return YES;
    }

    // 判据三:类名前缀(扫一遍全类表,结果缓存)
    static BOOL prefixHit = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (!pfx.count) return;
        uint32_t n = 0;
        Class *list = objc_copyClassList(&n);
        if (!list) return;
        for (uint32_t i = 0; i < n; i++) {
            const char *cn = class_getName(list[i]);
            if (!cn) continue;
            NSString *s = [NSString stringWithUTF8String:cn];
            for (NSString *p in pfx) {
                if (p.length && [s hasPrefix:p]) { prefixHit = YES; break; }
            }
            if (prefixHit) break;
        }
        free(list);
    });
    return prefixHit;
}

// 能不能"执行粘贴" —— 只有普通 App 且原插件没注入
static BOOL KSCanExecutePaste(void) {
    if (KSPrefBool(@"DryRun", KS_DRY_RUN_DEFAULT)) return NO;
    if (KSIsSystemProcess()) return NO;          // SpringBoard 等原生环境,免疫
    if (KSPluginLoadedInThisProcess()) return NO; // 已注入原插件,完全交给它
    return YES;
}

// 能不能广播"有人点了历史记录"
static BOOL KSCanPostSignal(void) {
    if (!KSPrefBool(@"PanelSignal", KS_PANEL_SIGNAL_DEFAULT)) return NO;
    return KSPluginLoadedInThisProcess() || KSIsSystemProcess();
}

static BOOL KSBundleAllowed(void) {
    NSString *bid = KSBundleID();
    NSArray *skip = KSPrefArray(@"SkipBundleIDs", KS_DEFAULT_SKIP_BUNDLES);
    if ([skip containsObject:bid]) return NO;
    NSArray *only = KSPrefArray(@"InjectBundleIDs", KS_DEFAULT_INJECT_BUNDLES);
    if (only.count && ![only containsObject:bid]) return NO;
    return YES;
}

// ============================================================================
//  6. 插件镜像 / 类发现
// ============================================================================

// 把本进程里的"第三方 dylib 候选"打出来 —— 方便你第一次装车时确认插件文件名
static void KSDumpImageCandidates(void) {
    uint32_t n = _dyld_image_count();
    NSMutableArray *cands = [NSMutableArray array];
    for (uint32_t i = 0; i < n; i++) {
        const char *nm = _dyld_get_image_name(i);
        if (!nm) continue;
        NSString *p = [NSString stringWithUTF8String:nm];
        if ([p hasPrefix:@"/System/"] || [p hasPrefix:@"/usr/lib/"] || [p hasPrefix:@"/usr/standalone/"]) continue;
        if ([p hasPrefix:@"/private/preboot/"] && [p rangeOfString:@"DynamicLibraries"].location == NSNotFound) continue;
        if (p.length) [cands addObject:p];
    }
    KSLog(@"--- 本进程非系统镜像候选 (%lu) ---", (unsigned long)cands.count);
    for (NSString *c in cands) KSLog(@"    %@", c);
}

// 按镜像名把"定义在插件 dylib 里"的类全捞出来
static NSArray<NSString *> *KSDiscoverPluginClasses(void) {
    NSMutableArray *out = [NSMutableArray array];
    NSArray<NSString *> *hints = KSPluginImageHints();
    if (!hints.count) return out;

    uint32_t n = 0;
    Class *list = objc_copyClassList(&n);
    if (!list) return out;
    for (uint32_t i = 0; i < n; i++) {
        Class c = list[i];
        const char *img = class_getImageName(c);
        if (!img) continue;
        NSString *imgStr = [NSString stringWithUTF8String:img];
        if (!KSImagePathMatches(imgStr, hints)) continue;
        const char *cn = class_getName(c);
        if (cn) [out addObject:[NSString stringWithUTF8String:cn]];
    }
    free(list);
    return out;
}

// ============================================================================
//  7. 运行时点击 Hook(不依赖 Logos,纯 runtime)
// ============================================================================

static void KSPostSignal(NSString *why);
static void KSOnPasteboardWrite(NSString *method);

// 通用中转:所有被 hook 的点击方法都走这里
// 用 void* 返回,避免 ARC 插手;多余寄存器参数在 arm64 上被被调方忽略,安全。
static void *KSGenericClickHook(id self, SEL _cmd, void *a1, void *a2, void *a3, void *a4) {
    NSString *key = [NSString stringWithFormat:@"%s:%s",
                     class_getName(object_getClass(self)), sel_getName(_cmd)];

    IMP orig = NULL;
    NSValue *v = gKSOrigIMPs[key];
    if (v) orig = (IMP)v.pointerValue;
    if (!orig) {
        // 兜底:沿继承链找
        Class c = object_getClass(self);
        while (c && !orig) {
            NSString *k2 = [NSString stringWithFormat:@"%s:%s", class_getName(c), sel_getName(_cmd)];
            NSValue *v2 = gKSOrigIMPs[k2];
            if (v2) orig = (IMP)v2.pointerValue;
            c = class_getSuperclass(c);
        }
    }

    KSLog(@"[点击] %@", key);

    void *ret = NULL;
    if (orig) {
        ret = ((void *(*)(id, SEL, void *, void *, void *, void *))orig)(self, _cmd, a1, a2, a3, a4);
    }
    // 原方法已经跑完(它这时已经把内容写进剪贴板了),广播给目标 App
    KSPostSignal(key);
    return ret;
}

static void KSHookInstanceMethod(Class cls, SEL sel, NSString *why) {
    if (!cls || !sel) return;
    if (!gKSOrigIMPs) gKSOrigIMPs = [NSMutableDictionary dictionary];
    if (!gKSHookedKeys) gKSHookedKeys = [NSMutableSet set];

    NSString *key = [NSString stringWithFormat:@"%s:%s", class_getName(cls), sel_getName(sel)];
    if ([gKSHookedKeys containsObject:key]) return;

    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;
    const char *types = method_getTypeEncoding(m);
    IMP orig = method_getImplementation(m);

    // 本类自己有没有实现?没有就先 addMethod(避免改到父类去)
    if (class_addMethod(cls, sel, (IMP)KSGenericClickHook, types)) {
        // 加成功 => 原来用的是父类实现,orig 就是父类的,直接用
    } else {
        Method own = class_getInstanceMethod(cls, sel);
        if (!own) return;
        orig = method_getImplementation(own);
        method_setImplementation(own, (IMP)KSGenericClickHook);
    }

    gKSOrigIMPs[key] = [NSValue valueWithPointer:(const void *)orig];
    [gKSHookedKeys addObject:key];
    KSLog(@"[hook] %@  (%@)", key, why);
}

// 选择器是否命中关键字
static BOOL KSSelectorMatches(NSString *selName, NSArray<NSString *> *patterns) {
    NSString *low = [selName lowercaseString];
    for (NSString *p in patterns) {
        if (p.length && [low rangeOfString:[p lowercaseString]].location != NSNotFound) return YES;
    }
    return NO;
}

static void KSHookPluginClickMethods(void) {
    // ---- (a) 精准列表 "类名:选择器" ----
    for (NSString *entry in KSClickSelectors()) {
        NSRange r = [entry rangeOfString:@":"];
        if (r.location == NSNotFound) continue;
        NSString *clsName = [entry substringToIndex:r.location];
        NSString *selName = [entry substringFromIndex:r.location + 1];
        if (!selName.length) continue;
        Class c = NSClassFromString(clsName);
        if (!c) { KSLog(@"[hook] 跳过 %@ (类不存在于本进程)", entry); continue; }
        KSHookInstanceMethod(c, NSSelectorFromString(selName), @"精准列表");
    }

    // ---- (b) 自发现 ----
    if (!KSPrefBool(@"AutoDiscover", KS_AUTODISCOVER_DEFAULT)) return;
    NSArray<NSString *> *hints = KSPluginImageHints();
    if (!hints.count) {
        KSLog(@"[自发现] 未配置 PluginImageHints,跳过。请从上方的镜像候选里挑出插件 dylib 名填进去。");
        return;
    }

    NSArray<NSString *> *classes = KSDiscoverPluginClasses();
    KSLog(@"[自发现] 插件镜像里共发现 %lu 个类", (unsigned long)classes.count);

    NSArray<NSString *> *patterns = KSSelectorPatterns();
    BOOL hookAll = KSPrefBool(@"HookAllClasses", KS_HOOK_ALL_CLASSES_DEFAULT);
    NSUInteger hookedCount = 0;

    for (NSString *clsName in classes) {
        Class c = NSClassFromString(clsName);
        if (!c) continue;

        unsigned int mcount = 0;
        Method *methods = class_copyMethodList(c, &mcount);   // 只拿本类自己的方法
        if (!methods) continue;

        KSLog(@"[自发现] 类 %@ — 方法 %u 个", clsName, mcount);
        for (unsigned int i = 0; i < mcount; i++) {
            NSString *selName = NSStringFromSelector(method_getName(methods[i]));
            KSLog(@"           - %@", selName);
            if (hookAll || KSSelectorMatches(selName, patterns)) {
                KSHookInstanceMethod(c, method_getName(methods[i]), @"自发现");
                hookedCount++;
            }
        }
        free(methods);
    }
    KSLog(@"[自发现] 命中并 hook 了 %lu 个方法", (unsigned long)hookedCount);
}

// ============================================================================
//  8. 剪贴板写入侧监听
// ============================================================================

static void KSOnPasteboardWrite(NSString *method) {
    // 本进程自己写的,开一个时间窗把它划掉(窗内不触发自动粘贴)
    gKSSelfWriteUntil = CFAbsoluteTimeGetCurrent() + 0.8;
    @try { gKSLastChangeCount = [UIPasteboard generalPasteboard].changeCount; } @catch (NSException *e) {}
    KSLog(@"[剪贴板] 本进程写入 (%@)", method);
    KSPostSignal(method);
}

// ============================================================================
//  9. 自动粘贴执行
// ============================================================================

@protocol KSStandardEditActions <NSObject>
@optional
- (void)paste:(id)sender;
@end

static UIResponder *KSFirstResponderInView(UIView *v) {
    if (v.isFirstResponder) return v;
    for (UIView *sub in v.subviews) {
        UIResponder *r = KSFirstResponderInView(sub);
        if (r) return r;
    }
    return nil;
}

static NSArray<UIWindow *> *KSAllWindows(void) {
    NSMutableArray *res = [NSMutableArray array];
    UIApplication *app = [UIApplication sharedApplication];
    for (UIScene *scene in app.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            [res addObjectsFromArray:((UIWindowScene *)scene).windows];
        }
    }
    if (!res.count) {
        for (UIWindow *w in app.windows) [res addObject:w];
    }
    // key window 排最前
    NSMutableArray *ordered = [NSMutableArray array];
    for (UIWindow *w in res) if (w.isKeyWindow) [ordered addObject:w];
    for (UIWindow *w in res) if (!w.isKeyWindow) [ordered addObject:w];
    return ordered;
}

static UIResponder *KSFindTextFirstResponder(void) {
    for (UIWindow *w in KSAllWindows()) {
        if (w.hidden || w.alpha < 0.01) continue;
        UIResponder *r = KSFirstResponderInView(w);
        if (r) return r;
    }
    return nil;
}

// 沿响应链找一个能执行 paste: 的
static BOOL KSPasteViaResponder(UIResponder *start) {
    UIResponder *cur = start;
    NSInteger guard = 0;
    while (cur && guard++ < 64) {
        if ([cur respondsToSelector:@selector(canPerformAction:withSender:)] &&
            [cur canPerformAction:@selector(paste:) withSender:nil]) {
            [(id<KSStandardEditActions>)cur paste:nil];
            KSLog(@"[粘贴] 通过 %@ 的 paste: 完成", NSStringFromClass([cur class]));
            return YES;
        }
        UIResponder *next = cur.nextResponder;
        if (next == cur) break;
        cur = next;
    }
    return NO;
}

// 兜底:直接拿剪贴板文本 insertText:(自定义编辑器/WebView 常吃这条)
static NSString *KSPasteboardPlainString(void) {
    @try {
        UIPasteboard *pb = [UIPasteboard generalPasteboard];
        NSString *s = pb.string;
        if (s.length) return s;
        NSArray *items = pb.items;
        if ([items isKindOfClass:[NSArray class]]) {
            for (NSDictionary *it in items) {
                if (![it isKindOfClass:[NSDictionary class]]) continue;
                NSString *v = it[@"public.utf8-plain-text"] ?: it[@"public.text"];
                if ([v isKindOfClass:[NSString class]] && v.length) return v;
            }
        }
    } @catch (NSException *e) {}
    return nil;
}

static BOOL KSInsertTextFallback(UIResponder *fr) {
    if (!fr) return NO;
    if (![fr conformsToProtocol:@protocol(UIKeyInput)] &&
        ![fr conformsToProtocol:@protocol(UITextInput)]) return NO;
    if (![fr respondsToSelector:@selector(insertText:)]) return NO;
    NSString *s = KSPasteboardPlainString();
    if (!s.length) return NO;
    [(id<UIKeyInput>)fr insertText:s];
    KSLog(@"[粘贴] 兜底 insertText: 完成 (%@ 字符)", @(s.length));
    return YES;
}

static BOOL KSPerformPasteNow(void) {
    if (!KSCanExecutePaste()) return NO;

    UIApplication *app = [UIApplication sharedApplication];
    if (app.applicationState != UIApplicationStateActive) return NO;

    BOOL requireInput = KSPrefBool(@"RequireTextInput", KS_REQUIRE_TEXT_INPUT_DEFAULT);
    UIResponder *fr = KSFindTextFirstResponder();
    if (requireInput && !fr) return NO;

    // 1) 标准路径:第一响应者 paste:
    if (KSPasteViaResponder(fr)) return YES;

    // 2) 兜底:insertText:
    if (KSInsertTextFallback(fr)) return YES;

    // 3) 再兜底:全窗口找 UITextInput
    for (UIWindow *w in KSAllWindows()) {
        if (w.hidden || w.alpha < 0.01) continue;
        UIResponder *r = KSFirstResponderInView(w);
        if (!r || r == fr) continue;
        if ([r conformsToProtocol:@protocol(UITextInput)] && [r respondsToSelector:@selector(insertText:)]) {
            if (KSInsertTextFallback(r)) return YES;
        }
    }
    return NO;
}

static void KSSchedulePaste(NSString *why) {
    if (!KSCanExecutePaste()) return;

    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (now - gKSLastTrigger < 0.5) return;   // 去抖:一次点击只粘一次
    gKSLastTrigger = now;
    gKSPasteDone = NO;

    double delay = KSPrefDouble(@"PasteDelay", KS_PASTE_DELAY_DEFAULT);
    KSLog(@"[触发] %@ → 延迟 %.2fs 自动粘贴", why, delay);

    // 延迟 + 最多 3 次补刀(面板还没收起 / 输入框还没回来时很有用)
    for (int i = 0; i < 4; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)((delay + i * 0.12) * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (gKSPasteDone) return;
            if (KSPerformPasteNow()) {
                gKSPasteDone = YES;
                KSLog(@"[完成] 自动粘贴成功(第 %d 次尝试)", i + 1);
            } else if (i == 3) {
                KSLog(@"[放弃] 4 次尝试都没找到可粘贴的输入框");
            }
        });
    }
}

// ============================================================================
//  10. 跨进程广播 + 剪贴板轮询 + 生命周期
// ============================================================================

static void KSPostSignal(NSString *why) {
    if (!KSCanPostSignal()) return;
    @try {
        notify_post(KS_DARWIN_NOTIFY_NAME);
        KSLog(@"[广播] 已通知目标 App 可以粘贴了 (%@)", why);
    } @catch (NSException *e) {}
}

static void KSPoll(void) {
    if (!KSCanExecutePaste()) return;
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;

    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    NSUInteger cc = pb.changeCount;
    if (cc == gKSLastChangeCount) return;

    NSUInteger prev = gKSLastChangeCount;
    gKSLastChangeCount = cc;

    if (CFAbsoluteTimeGetCurrent() < gKSSelfWriteUntil) {   // 自己刚写的,不算
        KSLog(@"[剪贴板] 变化落在自身写入窗口内,忽略");
        return;
    }
    KSLog(@"[剪贴板] 检测到外部写入 (%lu → %lu)", (unsigned long)prev, (unsigned long)cc);
    KSSchedulePaste(@"clipboard-change");
}

static void KSStartPolling(void) {
    if (!KSCanExecutePaste()) return;
    if (gKSPollTimer) return;

    @try { gKSLastChangeCount = [UIPasteboard generalPasteboard].changeCount; } @catch (NSException *e) {}

    dispatch_queue_t q = dispatch_queue_create("com.kickstand.poll", DISPATCH_QUEUE_SERIAL);
    double iv = KSPrefDouble(@"PollInterval", KS_POLL_INTERVAL_DEFAULT);
    if (iv < 0.02) iv = 0.02;      // 防手滑填 0,把 CPU 打满
    if (iv > 1.0) iv = 1.0;
    uint64_t ns = (uint64_t)(iv * NSEC_PER_SEC);

    gKSPollTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q);
    dispatch_source_set_timer(gKSPollTimer,
                              dispatch_time(DISPATCH_TIME_NOW, ns),
                              ns, ns / 4);
    dispatch_source_set_event_handler(gKSPollTimer, ^{ KSPoll(); });
    dispatch_resume(gKSPollTimer);
    KSLog(@"[轮询] 启动,间隔 %.2fs", iv);
}

static void KSStopPolling(void) {
    if (!gKSPollTimer) return;
    dispatch_source_cancel(gKSPollTimer);
    gKSPollTimer = nil;
    KSLog(@"[轮询] 停止");
}

static void KSRegisterDarwinNotify(void) {
    if (gKSNotifyToken >= 0) return;
    if (!KSCanExecutePaste()) return;
    @try {
        notify_register_dispatch(KS_DARWIN_NOTIFY_NAME, &gKSNotifyToken,
                                 dispatch_get_main_queue(), ^(int token) {
            KSLog(@"[广播] 收到面板的粘贴请求");
            KSSchedulePaste(@"darwin-notify");
        });
    } @catch (NSException *e) {}
}

static void KSSetupLifecycle(void) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:UIApplicationDidBecomeActiveNotification
                    object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *n) { KSStartPolling(); }];

    [nc addObserverForName:UIApplicationWillResignActiveNotification
                    object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *n) { KSStopPolling(); }];

    [nc addObserverForName:UIApplicationDidEnterBackgroundNotification
                    object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *n) { KSStopPolling(); }];
}

// ============================================================================
//  11. Logos Hooks —— 剪贴板写入侧
// ============================================================================

%group KSPasteboardGroup

%hook UIPasteboard

- (void)setString:(NSString *)value {
    %orig;
    KSOnPasteboardWrite(@"setString:");
}

- (void)setStrings:(NSArray<NSString *> *)strings {
    %orig;
    KSOnPasteboardWrite(@"setStrings:");
}

- (void)setItems:(NSArray<NSDictionary *> *)items options:(NSDictionary<UIPasteboardOption, id> *)options {
    %orig;
    KSOnPasteboardWrite(@"setItems:options:");
}

- (void)setItems:(NSArray<NSDictionary *> *)items {
    %orig;
    KSOnPasteboardWrite(@"setItems:");
}

- (void)setValue:(id)value forPasteboardType:(NSString *)type {
    %orig;
    KSOnPasteboardWrite([NSString stringWithFormat:@"setValue:forPasteboardType:(%@)", type]);
}

- (void)setData:(NSData *)data forPasteboardType:(NSString *)type {
    %orig;
    KSOnPasteboardWrite(@"setData:forPasteboardType:");
}

- (void)addItems:(NSArray<NSDictionary *> *)items {
    %orig;
    KSOnPasteboardWrite(@"addItems:");
}

- (void)setImage:(UIImage *)image {
    %orig;
    KSOnPasteboardWrite(@"setImage:");
}

- (void)setURL:(NSURL *)url {
    %orig;
    KSOnPasteboardWrite(@"setURL:");
}

- (void)setColor:(UIColor *)color {
    %orig;
    KSOnPasteboardWrite(@"setColor:");
}

%end

%end

// ============================================================================
//  12. 入口
// ============================================================================

%ctor {
    @autoreleasepool {
        if (!KSPrefBool(@"Enabled", KS_ENABLED_DEFAULT)) return;
        if (!KSBundleAllowed()) return;

        KSLog(@"==================================================");
        KSLog(@"Kickstand 载入 → %@ (%@) pid=%d", KSBundleID(), KSProcessName(), getpid());
        KSLog(@"DryRun=%d  能否粘贴=%d  能否广播=%d",
              KSPrefBool(@"DryRun", KS_DRY_RUN_DEFAULT), KSCanExecutePaste(), KSCanPostSignal());
        KSLog(@"PluginImageHints=%@", KSPluginImageHints());
        KSLog(@"PluginClassHints=%@", KSPluginClassHints());

        if (!KSPluginImageHints().count) KSDumpImageCandidates();

        // 剪贴板写入侧监听(所有进程都装,轻量)
        %init(KSPasteboardGroup);

        // 原插件的点击方法(运行时按配置/自发现 hook)
        KSHookPluginClickMethods();

        // 只有"未被插件注入的普通 App"才需要这套兜底
        if (KSCanExecutePaste()) {
            KSSetupLifecycle();
            KSRegisterDarwinNotify();
            KSStartPolling();
            KSLog(@"本进程启用自动粘贴兜底");
        } else {
            KSLog(@"本进程免疫:交给原插件处理");
        }
    }
}
