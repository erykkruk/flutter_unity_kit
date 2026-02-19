# Unity Content Loading & Generation Guide

> This document describes **all** the ways to generate, load, and manage 3D content with Unity — both in the context of Flutter-Unity embedding (unity_kit) and native iOS/Android platforms.

---

## Table of Contents

1. [Overview of Options](#1-overview-of-options)
2. [Scene Loading](#2-scene-loading)
3. [Loading Individual Models/Prefabs](#3-loading-individual-modelsprefabs)
4. [AssetBundles](#4-assetbundles)
5. [Addressables](#5-addressables)
6. [glTF/GLB — Runtime Import](#6-gltfglb--runtime-import)
7. [Runtime Mesh Generation](#7-runtime-mesh-generation)
8. [Asset Streaming & LOD](#8-asset-streaming--lod)
9. [Remote Configuration](#9-remote-configuration)
10. [Hot Content Updates (Without Store Submission)](#10-hot-content-updates-without-store-submission)
11. [AR Foundation](#11-ar-foundation)
12. [Platform Differences (iOS vs Android)](#12-platform-differences-ios-vs-android)
13. [Integration with unity_kit](#13-integration-with-unity_kit)

---

## 1. Overview of Options

| Approach | Asset Loading | Code Loading | iOS Safe | Android Safe | Complexity | Best For |
|----------|:-:|:-:|:-:|:-:|:-:|---------|
| **Scene Loading** | Built-in | No | Yes | Yes | Low | Switching game contexts |
| **Prefab Instantiation** | Yes | No | Yes | Yes | Low | Loading individual models on-demand |
| **AssetBundles** | Yes | No | Yes | Yes | High | Legacy projects, full control |
| **Addressables + CCD** | Yes | No | Yes | Yes | Medium | Primary content delivery system |
| **glTF/GLB Runtime** | Yes | No | Yes | Yes | Medium | User-generated content, NFTs, external 3D |
| **Runtime Mesh Gen** | N/A | No | Yes | Yes | Medium-High | Procedural content |
| **Remote Config** | Config only | No | Yes | Yes | Low | Feature flags, tuning, A/B testing |
| **HybridCLR** | Yes | **Yes** | Gray area | Yes | High | Code hot-fixes (use cautiously on iOS) |
| **AR Foundation** | N/A | No | Yes | Yes | Medium | AR camera experiences |

---

## 2. Scene Loading

### What Is It?

Unity SceneManager allows loading entire scenes at runtime — either **replacing** the current scene or **additively** (layer upon layer). A scene in Unity is a container holding GameObjects, their components, lighting, lightmaps, navmesh, skybox, and other environment settings. A scene = a `.unity` file in the editor.

### Loading Modes

```
┌──────────────────────────────────────────────────────────────────────┐
│  LoadSceneMode.Single                                                │
│  ─────────────────────                                               │
│  Replaces the ENTIRE current scene with a new one. All GameObjects   │
│  from the previous scene are destroyed (unless they have             │
│  DontDestroyOnLoad). Lightmaps, navmesh, skybox — everything        │
│  comes from the new scene.                                           │
│                                                                       │
│  Use: transitioning from main menu to gameplay, between levels.      │
├──────────────────────────────────────────────────────────────────────┤
│  LoadSceneMode.Additive                                               │
│  ─────────────────────                                               │
│  Adds a new scene TO the existing one. Both sets of GameObjects      │
│  coexist. Each loaded scene has its own root in the hierarchy.       │
│  Only ONE scene is "active" (active scene) — newly created           │
│  objects go into the active scene.                                    │
│                                                                       │
│  Use: modular design, UI overlays, streaming open world.             │
└──────────────────────────────────────────────────────────────────────┘
```

### How Does It Work?

**C# (Unity) — full examples:**

```csharp
// ═══════════════════════════════════════════════════════
// 1. SYNCHRONOUS (blocks the main thread — NOT for mobile)
// ═══════════════════════════════════════════════════════
SceneManager.LoadScene("GameShowroom", LoadSceneMode.Single);
// The entire frame is blocked until loading completes.
// On mobile = UI freeze, possible ANR (Application Not Responding).

// ═══════════════════════════════════════════════════════
// 2. ASYNCHRONOUS — basic (recommended on mobile)
// ═══════════════════════════════════════════════════════
AsyncOperation op = SceneManager.LoadSceneAsync("GameShowroom", LoadSceneMode.Additive);

// Scene loads in the background — Unity allocates time per frame.
// progress: 0.0 → 0.9 = loading, 0.9 = ready for activation.
op.completed += (asyncOp) => {
    Debug.Log("Scene GameShowroom loaded!");
};

// ═══════════════════════════════════════════════════════
// 3. ASYNCHRONOUS with loading screen (production)
// ═══════════════════════════════════════════════════════
IEnumerator LoadSceneWithProgress(string sceneName)
{
    // Show loading screen
    loadingScreen.SetActive(true);
    progressBar.value = 0f;

    AsyncOperation op = SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
    op.allowSceneActivation = false; // Wait — do not activate immediately

    while (!op.isDone)
    {
        // progress goes from 0.0 to 0.9 (90% = loaded in memory)
        float progress = Mathf.Clamp01(op.progress / 0.9f);
        progressBar.value = progress;

        // Send progress to Flutter
        NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
            type = "scene_loading_progress",
            sceneName = sceneName,
            progress = progress
        }));

        if (op.progress >= 0.9f)
        {
            // Scene ready — activate (this triggers Awake/Start on objects)
            op.allowSceneActivation = true;
        }

        yield return null; // Wait one frame
    }

    // Set as active scene (new objects go here)
    SceneManager.SetActiveScene(SceneManager.GetSceneByName(sceneName));

    loadingScreen.SetActive(false);
}

// ═══════════════════════════════════════════════════════
// 4. UNLOADING a scene (CRITICAL on mobile — memory!)
// ═══════════════════════════════════════════════════════
IEnumerator UnloadScene(string sceneName)
{
    AsyncOperation op = SceneManager.UnloadSceneAsync(sceneName);
    yield return op;

    // After unloading the scene, assets may still remain in memory!
    // Resources.UnloadUnusedAssets() cleans up orphaned assets.
    yield return Resources.UnloadUnusedAssets();

    // Force GC (optional, but recommended after a large unload)
    System.GC.Collect();
}

// ═══════════════════════════════════════════════════════
// 5. MANAGING multiple additive scenes
// ═══════════════════════════════════════════════════════
public class SceneController : MonoBehaviour
{
    private readonly Dictionary<string, bool> _loadedScenes = new();

    public async void LoadSceneIfNeeded(string sceneName)
    {
        if (_loadedScenes.ContainsKey(sceneName)) return;

        _loadedScenes[sceneName] = true;
        var op = SceneManager.LoadSceneAsync(sceneName, LoadSceneMode.Additive);
        await op; // Unity 2023+ async/await support
    }

    public async void UnloadIfLoaded(string sceneName)
    {
        if (!_loadedScenes.ContainsKey(sceneName)) return;

        _loadedScenes.Remove(sceneName);
        await SceneManager.UnloadSceneAsync(sceneName);
        await Resources.UnloadUnusedAssets();
    }

    // Swap one scene for another
    public async void SwapScene(string oldScene, string newScene)
    {
        // Load the new one BEFORE unloading the old one — avoids "empty frame"
        await SceneManager.LoadSceneAsync(newScene, LoadSceneMode.Additive);
        SceneManager.SetActiveScene(SceneManager.GetSceneByName(newScene));

        if (_loadedScenes.ContainsKey(oldScene))
        {
            await SceneManager.UnloadSceneAsync(oldScene);
            _loadedScenes.Remove(oldScene);
        }
        _loadedScenes[newScene] = true;

        await Resources.UnloadUnusedAssets();
    }
}
```

**Dart (Flutter -> Unity via unity_kit bridge):**

```dart
// ═══════════════════════════════════════════════════════
// Flutter: sending scene commands to Unity
// ═══════════════════════════════════════════════════════

// Load scene (additive)
bridge.send(UnityMessage.command('LoadScene', {
  'sceneName': 'GameShowroom',
  'mode': 'additive',  // or 'single'
}));

// Unload scene
bridge.send(UnityMessage.command('UnloadScene', {
  'sceneName': 'ItemCollection',
}));

// Swap scene
bridge.send(UnityMessage.command('SwapScene', {
  'oldScene': 'ItemCollection',
  'newScene': 'GameShowroom',
}));

// ═══════════════════════════════════════════════════════
// Flutter: listening for scene events
// ═══════════════════════════════════════════════════════

// Track scene loading (progress bar in Flutter)
bridge.messageStream
  .where((msg) => msg.type == 'scene_loading_progress')
  .listen((msg) {
    final progress = msg.data?['progress'] as double? ?? 0;
    final sceneName = msg.data?['sceneName'] as String? ?? '';
    setState(() {
      _loadingProgress = progress;
      _loadingScene = sceneName;
    });
  });

// Scene loaded
bridge.sceneStream.listen((SceneInfo info) {
  debugPrint('Scene ${info.name} loaded');
  debugPrint('  buildIndex: ${info.buildIndex}');
  debugPrint('  isLoaded: ${info.isLoaded}');
  debugPrint('  isValid: ${info.isValid}');

  // Update Flutter application state
  context.read<SceneCubit>().onSceneLoaded(info);
});

// Scene unloaded
bridge.messageStream
  .where((msg) => msg.type == 'scene_unloaded')
  .listen((msg) {
    context.read<SceneCubit>().onSceneUnloaded(msg.data?['sceneName']);
  });
```

### Additive Loading — The Key to Modularity

Additive scenes allow creating a modular architecture. The key principle: **one persistent scene + swappable modules**.

```
Base scene "Core" (persistent — NEVER unloaded):
├── Main Camera (with CinemachineBrain)
├── Global Light (Directional)
├── EventSystem
├── AudioManager (DontDestroyOnLoad)
├── FlutterBridge (singleton)
├── SceneController
└── GameManager
     └── RemoteConfigManager

+ Additive scene "ModelViewer":            ← loaded when user opens a model
  ├── ModelPedestal (prefab)
  ├── ModelSpotlight (Point Light)
  ├── ModelAnimationController
  ├── CinemachineVirtualCamera (orbit)
  ├── PostProcessVolume (model-specific)
  └── ModelInteractionHandler

+ Additive scene "ItemCollection":         ← another additive scene
  ├── GridLayout (3D grid)
  ├── ScrollSystem
  ├── CollectionCamera (virtual cam)
  ├── ThumbnailRenderer
  └── CollectionManager

+ Additive scene "ItemCustomizer":         ← customize flow
  ├── CustomizePedestal
  ├── MaterialPicker
  ├── ColorWheel
  ├── CustomizeCamera
  └── UndoRedoManager

+ Additive scene "ARExperience":           ← AR mode
  ├── ARSession
  ├── ARSessionOrigin
  ├── ARPlaneManager
  ├── ARRaycastManager
  └── ARModelPlacer
```

**Why this architecture?**

| Benefit | Description |
|---------|-------------|
| **Isolation** | Each module has its own lighting, camera, post-processing |
| **Memory** | Unloading a module frees its assets |
| **Collaboration** | Different artists work on different scenes without merge conflicts |
| **Testing** | Each module can be opened separately in the editor |
| **Build size** | Modules can be in Addressables (not in the base build) |

**Note about Active Scene:**

```csharp
// IMPORTANT: only one scene is "active" at a time.
// Newly created objects (Instantiate without parent) go into the active scene.
// Lighting and skybox of the CURRENT active scene are used.

SceneManager.SetActiveScene(SceneManager.GetSceneByName("ModelViewer"));
// Now lighting from ModelViewer is dominant
// Instantiate() without parent creates objects in ModelViewer
```

### Scene Sources — Where Can They Be Loaded From?

| Source | How to Load | When to Use |
|--------|-------------|-------------|
| **Build Settings** | `SceneManager.LoadSceneAsync("name")` | Scenes built into the app (core, menu) |
| **AssetBundle** | First `AssetBundle.LoadFromFile()`, then `SceneManager.LoadSceneAsync()` | Legacy, full control |
| **Addressables** | `Addressables.LoadSceneAsync("address")` | Recommended — manages bundles automatically |
| **Addressables Remote** | Same as above, but group has remote build path | New scenes without app update |

```csharp
// ═══ From Build Settings ═══
SceneManager.LoadSceneAsync("GameShowroom", LoadSceneMode.Additive);
// Scene MUST be in File > Build Settings > Scenes In Build

// ═══ From AssetBundle ═══
// Step 1: load the bundle containing the scene
AssetBundle sceneBundle = AssetBundle.LoadFromFile(
    Path.Combine(Application.persistentDataPath, "scenes/gameshowroom")
);
// Step 2: load the scene from the bundle (by name, not path)
SceneManager.LoadSceneAsync("GameShowroom", LoadSceneMode.Additive);
// Step 3: unload the bundle after loading the scene
sceneBundle.Unload(false);

// ═══ From Addressables ═══
var sceneHandle = Addressables.LoadSceneAsync(
    "Scenes/GameShowroom",
    LoadSceneMode.Additive,
    activateOnLoad: true
);
// sceneHandle.Result = SceneInstance (for later unload)
SceneInstance sceneInstance = await sceneHandle.Task;

// Unloading:
Addressables.UnloadSceneAsync(sceneHandle);
```

### Lightmaps and Static Data in Additive Scenes

**Problem:** Lightmaps, reflection probes, and navmesh are per-scene. With additive loading they can conflict.

**Solutions:**

| Problem | Solution |
|---------|----------|
| Lightmaps from two scenes mix together | Bake lightmaps separately per scene. Each scene has its own LightmapData. Unity automatically manages offsets |
| Two scenes have different skyboxes | Set skybox on the active scene. `SceneManager.SetActiveScene()` switches the skybox |
| Navmesh does not connect between scenes | Use `NavMeshSurface` component (from AI Navigation package) — builds navmesh at runtime, can merge multiple scenes |
| Reflection probes duplicate | Disable probes in inactive scenes, or use different masks |

### Pros and Cons

| Pros | Cons |
|------|------|
| Full context switching — change the entire world at once | Scenes in Build Settings increase APK/IPA size |
| Async loading = zero lag with correct implementation | Large scenes = memory spikes (peak RAM during loading) |
| Additive = modularity, isolation, team collaboration | Lightmaps/navmesh/reflection probes require management |
| Works identically in Flutter embed | Only one scene "active" at a time (skybox, lighting) |
| Scenes from Addressables = remote loading | Synchronous LoadScene blocks UI (use Async!) |
| Progress tracking (`AsyncOperation.progress`) | Awake/Start on scene objects can cause spikes if there are many |
| Swap pattern (load new -> unload old) | `Resources.UnloadUnusedAssets()` after unload is slow (50-200ms) |

### Platform Notes

**iOS:**
- SceneManager works identically in Flutter embed. Unity player has its own game loop.
- **Peak memory**: While loading a new scene (before unloading the old one), both scenes are in RAM. On an iPhone with 3GB RAM this is critical — plan swaps carefully.
- **allowSceneActivation = false**: The scene is 90% loaded in memory, but objects do not yet have Awake/Start. This is a good moment to show a loading screen.

**Android:**
- Identical behavior to iOS. Watch out for low-end devices with 2GB RAM.
- **ANR (Application Not Responding)**: Synchronous `LoadScene` on a large scene = ANR dialog after 5 seconds. ALWAYS use `LoadSceneAsync`.

**Flutter-specific:**
- Unity scene state is **invisible** to Flutter — Unity must send a return message.
- unity_kit handles this automatically: `SceneTracker.cs` hooks `SceneManager.sceneLoaded` / `sceneUnloaded` and sends events to Flutter via `NativeAPI.NotifySceneLoaded()`.
- Flutter listens on `bridge.sceneStream` -> `SceneInfo` with name, buildIndex, isLoaded, isValid.
- **Loading UI**: Show a loading screen in Flutter (Dart widget) while Unity loads the scene. Listen for progress messages from Unity.

---

## 3. Loading Individual Models/Prefabs

### What Is It?

Loading and instantiating individual 3D models (prefabs) into an **already running scene** — without loading an entire new scene. A prefab in Unity is a "template" of a GameObject with components (mesh, materials, animations, scripts, colliders, etc.). A single prefab can be instantiated multiple times.

**Key difference vs scenes:** Scene = the entire context (lighting, camera, everything). Prefab = a single object placed into an existing context.

### How Does It Work? — All Methods

```csharp
// ═══════════════════════════════════════════════════════
// METHOD 1: Addressables — RECOMMENDED
// ═══════════════════════════════════════════════════════

// A. Load + Instantiate separately (when you need a reference to the prefab)
var loadHandle = Addressables.LoadAssetAsync<GameObject>("Models/Model_001");
GameObject prefab = await loadHandle.Task;

// Instantiate multiple times from the same prefab
GameObject instance1 = Instantiate(prefab, pos1, Quaternion.identity, parent);
GameObject instance2 = Instantiate(prefab, pos2, Quaternion.identity, parent);

// Cleanup: Release prefab when you no longer need more instances
// (existing instances are NOT destroyed)
Addressables.Release(loadHandle);

// B. InstantiateAsync — load + instantiate in one step
var instHandle = Addressables.InstantiateAsync(
    "Models/Model_001",
    position: Vector3.zero,
    rotation: Quaternion.identity,
    parent: modelContainer.transform
);
GameObject model = await instHandle.Task;

// Cleanup: ReleaseInstance destroys the object AND releases the asset
Addressables.ReleaseInstance(model);

// ═══════════════════════════════════════════════════════
// METHOD 2: AssetBundle — lower level, full control
// ═══════════════════════════════════════════════════════

// From local file (previously downloaded)
string bundlePath = Path.Combine(Application.persistentDataPath, "bundles/models");
AssetBundle bundle = await AssetBundle.LoadFromFileAsync(bundlePath);
GameObject prefab = bundle.LoadAsset<GameObject>("Model_001");
GameObject instance = Instantiate(prefab, Vector3.zero, Quaternion.identity);

// From URL (CDN)
var request = UnityWebRequestAssetBundle.GetAssetBundle(
    "https://cdn.example.com/bundles/models_android",
    version: 1,                     // cache version
    crc: 0                          // CRC check (0 = skip)
);
await request.SendWebRequest();
AssetBundle remoteBundle = DownloadHandlerAssetBundle.GetContent(request);
GameObject remotePrefab = remoteBundle.LoadAsset<GameObject>("Model_001");
Instantiate(remotePrefab);

// Cleanup
bundle.Unload(false); // false = do not destroy loaded assets in memory

// ═══════════════════════════════════════════════════════
// METHOD 3: Resources — NOT RECOMMENDED (but worth knowing)
// ═══════════════════════════════════════════════════════

// Files MUST be in the Assets/Resources/ folder
// All Resources are packed into the build — they increase APK size
GameObject prefab = Resources.Load<GameObject>("Models/Model_001");
Instantiate(prefab);

// Why not: everything from Resources goes into the build,
// no lazy loading, no remote, no cache.

// ═══════════════════════════════════════════════════════
// METHOD 4: glTF/GLB runtime — models from external sources
// ═══════════════════════════════════════════════════════

// Details in section 6 (glTF/GLB)
var gltf = new GltfImport();
await gltf.Load("https://api.example.com/models/model.glb");
gltf.InstantiateMainScene(modelContainer.transform);
```

### Full ModelManager Implementation (C#)

```csharp
/// <summary>
/// Manages loading, displaying, and removing models in the scene.
/// Inherits from FlutterMonoBehaviour — automatically listens for messages from Flutter.
/// </summary>
public class ModelManager : FlutterMonoBehaviour
{
    [SerializeField] private Transform modelContainer;
    [SerializeField] private Transform pedestalPosition;

    private GameObject _currentModel;
    private AsyncOperationHandle<GameObject> _currentHandle;
    private readonly Dictionary<string, AsyncOperationHandle<GameObject>> _preloadedModels = new();

    // ─── Flutter Message Handling ───
    protected override void OnFlutterMessage(string method, string data)
    {
        switch (method)
        {
            case "LoadModel":
                var loadPayload = JsonUtility.FromJson<ModelPayload>(data);
                _ = LoadModel(loadPayload.modelId, loadPayload.source, loadPayload.url);
                break;

            case "UnloadModel":
                UnloadCurrentModel();
                break;

            case "SwapModel":
                var swapPayload = JsonUtility.FromJson<ModelPayload>(data);
                _ = SwapModel(swapPayload.modelId, swapPayload.source, swapPayload.url);
                break;

            case "PreloadModel":
                var preloadPayload = JsonUtility.FromJson<ModelPayload>(data);
                _ = PreloadModel(preloadPayload.modelId);
                break;

            case "SetModelTransform":
                var transformData = JsonUtility.FromJson<ModelTransform>(data);
                ApplyTransform(transformData);
                break;

            case "SetModelAnimation":
                var animData = JsonUtility.FromJson<AnimPayload>(data);
                SetAnimation(animData.animationName, animData.speed);
                break;

            case "SetModelMaterial":
                var matData = JsonUtility.FromJson<MaterialPayload>(data);
                _ = SwapMaterial(matData.materialAddress);
                break;
        }
    }

    // ─── Core Loading ───
    private async Task LoadModel(string modelId, string source, string url = null)
    {
        UnloadCurrentModel();

        try
        {
            SendToFlutter("model_loading", JsonUtility.ToJson(new { modelId }));

            switch (source)
            {
                case "addressables":
                    // Check if preloaded
                    if (_preloadedModels.TryGetValue(modelId, out var preloaded))
                    {
                        _currentModel = Instantiate(
                            preloaded.Result,
                            pedestalPosition.position,
                            Quaternion.identity,
                            modelContainer
                        );
                        _preloadedModels.Remove(modelId);
                        _currentHandle = preloaded;
                    }
                    else
                    {
                        _currentHandle = Addressables.InstantiateAsync(
                            $"Models/{modelId}",
                            pedestalPosition.position,
                            Quaternion.identity,
                            modelContainer
                        );
                        _currentModel = await _currentHandle.Task;
                    }
                    break;

                case "gltf":
                    var gltf = new GltfImport();
                    bool success = await gltf.Load(url);
                    if (success)
                    {
                        gltf.InstantiateMainScene(modelContainer);
                        _currentModel = modelContainer.GetChild(modelContainer.childCount - 1).gameObject;
                        _currentModel.transform.position = pedestalPosition.position;
                    }
                    break;
            }

            SendToFlutter("model_loaded", JsonUtility.ToJson(new {
                modelId,
                success = _currentModel != null,
                bounds = GetBoundsJson(_currentModel)
            }));
        }
        catch (Exception e)
        {
            SendToFlutter("model_error", JsonUtility.ToJson(new {
                modelId,
                error = e.Message
            }));
        }
    }

    // ─── Swap (load new before removing old — no empty frame) ───
    private async Task SwapModel(string newModelId, string source, string url = null)
    {
        GameObject oldModel = _currentModel;

        // Load new (old is still visible)
        await LoadModel(newModelId, source, url);

        // Destroy old
        if (oldModel != null) Destroy(oldModel);
    }

    // ─── Preload (download to memory without instantiating) ───
    private async Task PreloadModel(string modelId)
    {
        if (_preloadedModels.ContainsKey(modelId)) return;

        var handle = Addressables.LoadAssetAsync<GameObject>($"Models/{modelId}");
        await handle.Task;
        _preloadedModels[modelId] = handle;

        SendToFlutter("model_preloaded", JsonUtility.ToJson(new { modelId }));
    }

    // ─── Unload ───
    private void UnloadCurrentModel()
    {
        if (_currentModel != null)
        {
            if (_currentHandle.IsValid())
                Addressables.ReleaseInstance(_currentModel);
            else
                Destroy(_currentModel);

            _currentModel = null;
        }
    }

    // ─── Transform / Animation / Material ───
    private void ApplyTransform(ModelTransform t)
    {
        if (_currentModel == null) return;
        _currentModel.transform.localPosition = new Vector3(t.x, t.y, t.z);
        _currentModel.transform.localEulerAngles = new Vector3(t.rx, t.ry, t.rz);
        _currentModel.transform.localScale = new Vector3(t.sx, t.sy, t.sz);
    }

    private void SetAnimation(string animName, float speed)
    {
        if (_currentModel == null) return;
        var animator = _currentModel.GetComponentInChildren<Animator>();
        if (animator == null) return;
        animator.speed = speed;
        animator.Play(animName);
    }

    private async Task SwapMaterial(string materialAddress)
    {
        if (_currentModel == null) return;
        var matHandle = Addressables.LoadAssetAsync<Material>(materialAddress);
        Material mat = await matHandle.Task;
        var renderers = _currentModel.GetComponentsInChildren<Renderer>();
        foreach (var r in renderers) r.material = mat;
    }

    // ─── Cleanup ───
    private void OnDestroy()
    {
        UnloadCurrentModel();
        foreach (var handle in _preloadedModels.Values)
            Addressables.Release(handle);
        _preloadedModels.Clear();
    }

    // ─── Helpers ───
    private string GetBoundsJson(GameObject obj)
    {
        if (obj == null) return "{}";
        var renderers = obj.GetComponentsInChildren<Renderer>();
        if (renderers.Length == 0) return "{}";
        Bounds bounds = renderers[0].bounds;
        for (int i = 1; i < renderers.Length; i++)
            bounds.Encapsulate(renderers[i].bounds);
        return JsonUtility.ToJson(new {
            centerX = bounds.center.x, centerY = bounds.center.y, centerZ = bounds.center.z,
            sizeX = bounds.size.x, sizeY = bounds.size.y, sizeZ = bounds.size.z
        });
    }
}

// ─── Payload structs ───
[Serializable] public struct ModelPayload { public string modelId; public string source; public string url; }
[Serializable] public struct ModelTransform { public float x, y, z, rx, ry, rz, sx, sy, sz; }
[Serializable] public struct AnimPayload { public string animationName; public float speed; }
[Serializable] public struct MaterialPayload { public string materialAddress; }
```

**Dart (Flutter -> Unity) — full API:**

```dart
// ═══════════════════════════════════════════════════════
// Flutter: full API for managing models
// ═══════════════════════════════════════════════════════

class ModelController {
  final UnityBridge _bridge;

  ModelController(this._bridge);

  // Load model from Addressables
  void loadModel(String modelId) {
    _bridge.send(UnityMessage.to('ModelManager', 'LoadModel', {
      'modelId': modelId,
      'source': 'addressables',
    }));
  }

  // Load model from URL (glTF)
  void loadModelFromUrl(String modelId, String glbUrl) {
    _bridge.send(UnityMessage.to('ModelManager', 'LoadModel', {
      'modelId': modelId,
      'source': 'gltf',
      'url': glbUrl,
    }));
  }

  // Preload (download to cache without displaying)
  void preloadModel(String modelId) {
    _bridge.send(UnityMessage.to('ModelManager', 'PreloadModel', {
      'modelId': modelId,
    }));
  }

  // Swap model for another (smooth swap)
  void swapModel(String newModelId) {
    _bridge.send(UnityMessage.to('ModelManager', 'SwapModel', {
      'modelId': newModelId,
      'source': 'addressables',
    }));
  }

  // Remove current model
  void unloadModel() {
    _bridge.send(UnityMessage.command('UnloadModel', {}));
  }

  // Set position/rotation/scale
  void setTransform({
    double x = 0, double y = 0, double z = 0,
    double rx = 0, double ry = 0, double rz = 0,
    double sx = 1, double sy = 1, double sz = 1,
  }) {
    _bridge.send(UnityMessage.to('ModelManager', 'SetModelTransform', {
      'x': x, 'y': y, 'z': z,
      'rx': rx, 'ry': ry, 'rz': rz,
      'sx': sx, 'sy': sy, 'sz': sz,
    }));
  }

  // Set animation
  void setAnimation(String name, {double speed = 1.0}) {
    _bridge.send(UnityMessage.to('ModelManager', 'SetModelAnimation', {
      'animationName': name,
      'speed': speed,
    }));
  }

  // Change material
  void setMaterial(String materialAddress) {
    _bridge.send(UnityMessage.to('ModelManager', 'SetModelMaterial', {
      'materialAddress': materialAddress,
    }));
  }

  // Event streams
  Stream<Map<String, dynamic>> get onModelLoaded =>
      _bridge.messageStream
          .where((msg) => msg.type == 'model_loaded')
          .map((msg) => msg.data ?? {});

  Stream<Map<String, dynamic>> get onModelLoading =>
      _bridge.messageStream
          .where((msg) => msg.type == 'model_loading')
          .map((msg) => msg.data ?? {});

  Stream<Map<String, dynamic>> get onModelError =>
      _bridge.messageStream
          .where((msg) => msg.type == 'model_error')
          .map((msg) => msg.data ?? {});
}
```

### Usage Scenarios — In Detail

| Scenario | Method | Source | Details |
|----------|--------|--------|---------|
| Single model preview | `LoadModel` | Addressables | Load into scene with pedestal, orbit camera, lighting |
| Collection (grid) | Loop `InstantiateAsync` | Addressables | Load thumbnails (LOD 2) on grid. Full model only after tap |
| Swipe carousel | `SwapModel` | Addressables | Preload next/previous. Swap without empty frame |
| NFT from marketplace | `LoadModel(gltf)` | glTF from URL | Model comes as .glb from API. No prefab in Unity |
| Customization | `SetMaterial` | Addressables | Load material variant. Swap on renderer |
| Seasonal skin | `SetMaterial` | Remote Config + Addressables | RC specifies material address -> load from Addressables |
| Gallery collection | Loop load + `RenderTexture` | Addressables | Render model to texture -> show as thumbnail in UI |

### Object Pooling — Optimization for Collections

```csharp
/// <summary>
/// Object pool — recycle instead of Destroy/Instantiate.
/// Critical for collections with scrolling (carousel, grid).
/// </summary>
public class ModelPool
{
    private readonly Dictionary<string, Queue<GameObject>> _pools = new();
    private readonly Transform _poolRoot;

    public ModelPool(Transform poolRoot)
    {
        _poolRoot = poolRoot;
        _poolRoot.gameObject.SetActive(false); // Hide pooled objects
    }

    public async Task<GameObject> Get(string modelId, Transform parent)
    {
        if (_pools.TryGetValue(modelId, out var queue) && queue.Count > 0)
        {
            // Recycle from pool
            var obj = queue.Dequeue();
            obj.transform.SetParent(parent);
            obj.SetActive(true);
            return obj;
        }

        // Not in pool — load new
        var handle = Addressables.InstantiateAsync($"Models/{modelId}", parent);
        return await handle.Task;
    }

    public void Return(string modelId, GameObject obj)
    {
        obj.SetActive(false);
        obj.transform.SetParent(_poolRoot);

        if (!_pools.ContainsKey(modelId))
            _pools[modelId] = new Queue<GameObject>();

        _pools[modelId].Enqueue(obj);
    }

    public void Clear()
    {
        foreach (var queue in _pools.Values)
            while (queue.Count > 0)
                Addressables.ReleaseInstance(queue.Dequeue());
        _pools.Clear();
    }
}
```

### Shader Warmup — Eliminating Stutter

```csharp
/// <summary>
/// Shader warmup — precompile shader variants at startup.
/// Without this: the first render of a new shader = 50-200ms stutter.
/// </summary>
public class ShaderWarmup : MonoBehaviour
{
    [SerializeField] private ShaderVariantCollection shaderVariants;

    private void Start()
    {
        // Precompile ALL variants declared in the collection
        if (shaderVariants != null)
        {
            shaderVariants.WarmUp();
            Debug.Log($"Warmed up {shaderVariants.shaderCount} shaders, " +
                      $"{shaderVariants.variantCount} variants");
        }
    }
}

// How to create a ShaderVariantCollection:
// 1. Window > Analysis > Shader Variant Tracker (Unity 6000+)
// 2. Or manually: Create > Shader > Shader Variant Collection
// 3. Add shaders + variants used by model prefabs
// 4. Assign to ShaderWarmup component in the Core scene
```

### Texture Compression — Impact on Memory

| Format | iOS | Android | Quality | Size | GPU Decompression |
|--------|:---:|:-------:|---------|------|:-:|
| **ASTC 4x4** | Yes | Yes | Best | Medium | Yes |
| **ASTC 6x6** | Yes | Yes | Good | Small | Yes |
| **ASTC 8x8** | Yes | Yes | Acceptable | Very small | Yes |
| **ETC2** | No | Yes | Good | Small | Yes |
| **PVRTC** | Yes (legacy) | No | Acceptable | Small | Yes |
| **RGB24 (uncompressed)** | Yes | Yes | Perfect | HUGE | No |

**Recommendation:** ASTC 6x6 as default. ASTC 4x4 for face details/close-ups. ASTC 8x8 for terrains/backgrounds.

```
Example: 2048x2048 texture
├── RGB24:   12 MB in VRAM
├── ASTC 4x4: 1 MB in VRAM  (12x smaller!)
├── ASTC 6x6: 0.5 MB in VRAM
└── ASTC 8x8: 0.25 MB in VRAM

For a collection of 50 models with 3 textures each (diffuse, normal, mask):
├── RGB24:   50 x 3 x 12 MB = 1800 MB  ← will not fit in RAM
├── ASTC 4x4: 50 x 3 x 1 MB = 150 MB   ← OK on mid-range
└── ASTC 6x6: 50 x 3 x 0.5 MB = 75 MB  ← OK even on low-end
```

---

## 4. AssetBundles

### What Is It?

Archives of platform-specific assets (models, textures, materials, prefabs, scenes) loaded at runtime. This is a **low-level** system — the foundation on which Addressables is built. Each bundle is a binary file containing serialized Unity assets in the native format for a given platform.

**When to use raw AssetBundles instead of Addressables?**
- When you need full control over packing, versioning, and caching
- When you have an existing pipeline/CDN and do not want Unity abstraction dependencies
- When the project is migrating from a legacy system
- In most cases: **use Addressables** (section 5), which manage AssetBundles automatically

### How Does It Work? — Complete Pipeline

```
┌──────────────────────────────────────────────────────────────┐
│                        BUILD TIME                             │
│                                                               │
│  1. Mark assets in Inspector → AssetBundle name               │
│     e.g. "models/common", "models/rare", "scenes/showroom"   │
│                                                               │
│  2. Build script generates bundles:                           │
│     BuildPipeline.BuildAssetBundles(                          │
│         outputPath,                                           │
│         BuildAssetBundleOptions.ChunkBasedCompression,        │
│         BuildTarget.Android  // OR BuildTarget.iOS            │
│     );                                                        │
│                                                               │
│  3. Output:                                                   │
│     outputPath/                                               │
│     ├── models_common              (bundle file)              │
│     ├── models_common.manifest     (dependencies, hash)       │
│     ├── models_rare                                           │
│     ├── models_rare.manifest                                  │
│     ├── scenes_showroom                                       │
│     ├── scenes_showroom.manifest                              │
│     └── Android                    (master manifest)          │
│                                                               │
│  IMPORTANT: A bundle built for Android does NOT work on iOS!  │
│  You must build separately per platform.                      │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│                    HOSTING / DISTRIBUTION                      │
│                                                               │
│  Option A: CDN (S3, CloudFront, Cloudflare R2, GCS)          │
│  ├── https://cdn.example.com/bundles/android/v42/models_common│
│  └── https://cdn.example.com/bundles/ios/v42/models_common   │
│                                                               │
│  Option B: Unity CCD (Cloud Content Delivery)                │
│  ├── Dashboard → Bucket "android-prod" → Upload              │
│  └── Dashboard → Bucket "ios-prod" → Upload                  │
│                                                               │
│  Option C: StreamingAssets (built into APK/IPA)              │
│  └── Assets/StreamingAssets/bundles/models_common             │
│                                                               │
│  Option D: Google Play Asset Delivery (Android only)         │
│  ├── install-time: downloaded with APK (at installation)      │
│  ├── fast-follow: downloaded right after installation         │
│  └── on-demand: downloaded on user request                    │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│                         RUNTIME                               │
│                                                               │
│  1. Download/load bundle                                     │
│  2. Load asset from bundle (prefab, texture, scene...)       │
│  3. Instantiate in scene                                     │
│  4. When no longer needed → Unload bundle                    │
│  5. When asset not needed → Destroy + UnloadUnusedAssets     │
└──────────────────────────────────────────────────────────────┘
```

### Complete Code Examples

```csharp
// ═══════════════════════════════════════════════════════
// 1. LOADING FROM LOCAL FILE (StreamingAssets or downloaded)
// ═══════════════════════════════════════════════════════

// A. From StreamingAssets (built into APK/IPA)
IEnumerator LoadFromStreamingAssets()
{
    // On Android: StreamingAssets is in JAR (compressed) → requires UnityWebRequest
    // On iOS: StreamingAssets is a normal folder → can use LoadFromFile
    string path;

    #if UNITY_ANDROID && !UNITY_EDITOR
        path = Application.streamingAssetsPath + "/bundles/models_common";
        var request = UnityWebRequestAssetBundle.GetAssetBundle(path);
        yield return request.SendWebRequest();
        AssetBundle bundle = DownloadHandlerAssetBundle.GetContent(request);
    #else
        path = Path.Combine(Application.streamingAssetsPath, "bundles/models_common");
        var bundleRequest = AssetBundle.LoadFromFileAsync(path);
        yield return bundleRequest;
        AssetBundle bundle = bundleRequest.assetBundle;
    #endif

    if (bundle == null) { Debug.LogError("Failed to load bundle"); yield break; }

    // Load prefab from bundle
    var assetRequest = bundle.LoadAssetAsync<GameObject>("Model_001");
    yield return assetRequest;
    Instantiate((GameObject)assetRequest.asset);
}

// B. From Application.persistentDataPath (previously downloaded)
IEnumerator LoadFromDownloaded()
{
    string path = Path.Combine(Application.persistentDataPath, "bundles/models_common");

    if (!File.Exists(path))
    {
        Debug.LogError($"Bundle not found: {path}");
        yield break;
    }

    var bundleRequest = AssetBundle.LoadFromFileAsync(path);
    yield return bundleRequest;
    AssetBundle bundle = bundleRequest.assetBundle;

    // Load ALL prefabs from the bundle
    var allAssets = bundle.LoadAllAssetsAsync<GameObject>();
    yield return allAssets;

    foreach (var asset in allAssets.allAssets)
    {
        Debug.Log($"Found prefab in bundle: {asset.name}");
    }
}

// ═══════════════════════════════════════════════════════
// 2. DOWNLOADING FROM SERVER (CDN)
// ═══════════════════════════════════════════════════════

IEnumerator DownloadAndLoadBundle(string url, uint version)
{
    // UnityWebRequestAssetBundle automatically caches!
    // version = version number. Same version → cache hit.
    // Version change → new download.
    var request = UnityWebRequestAssetBundle.GetAssetBundle(url, version, crc: 0);

    // Progress tracking
    request.SendWebRequest();
    while (!request.isDone)
    {
        float progress = request.downloadProgress;
        NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
            type = "bundle_download_progress",
            url = url,
            progress = progress
        }));
        yield return null;
    }

    if (request.result != UnityWebRequest.Result.Success)
    {
        Debug.LogError($"Download failed: {request.error}");
        yield break;
    }

    AssetBundle bundle = DownloadHandlerAssetBundle.GetContent(request);
    // ... use the bundle
}

// ═══════════════════════════════════════════════════════
// 3. DEPENDENCY MANAGEMENT (manual!)
// ═══════════════════════════════════════════════════════

// Problem: models_rare prefab uses a material from shared_materials bundle.
// If shared_materials is not loaded → missing material (magenta).

IEnumerator LoadWithDependencies(string bundleName)
{
    // 1. Load master manifest (contains dependency info)
    var masterRequest = AssetBundle.LoadFromFileAsync(
        Path.Combine(Application.persistentDataPath, "bundles/Android")
    );
    yield return masterRequest;
    AssetBundleManifest manifest = masterRequest.assetBundle
        .LoadAsset<AssetBundleManifest>("AssetBundleManifest");

    // 2. Get list of dependencies
    string[] dependencies = manifest.GetAllDependencies(bundleName);
    // e.g. ["shared_materials", "shared_textures"]

    // 3. Load ALL dependencies BEFORE the main bundle
    List<AssetBundle> depBundles = new();
    foreach (string dep in dependencies)
    {
        var depRequest = AssetBundle.LoadFromFileAsync(
            Path.Combine(Application.persistentDataPath, $"bundles/{dep}")
        );
        yield return depRequest;
        depBundles.Add(depRequest.assetBundle);
    }

    // 4. Only now load the main bundle
    var mainRequest = AssetBundle.LoadFromFileAsync(
        Path.Combine(Application.persistentDataPath, $"bundles/{bundleName}")
    );
    yield return mainRequest;

    // 5. Now assets from the main bundle have access to dependencies
    var prefab = mainRequest.assetBundle.LoadAsset<GameObject>("Model_001");
    Instantiate(prefab); // Materials loaded correctly!
}

// ═══════════════════════════════════════════════════════
// 4. UNLOAD — critical on mobile
// ═══════════════════════════════════════════════════════

// Unload(false): release ONLY the bundle from memory.
// Loaded assets (prefabs, textures) REMAIN in memory.
// You can no longer load new assets from this bundle.
bundle.Unload(false);

// Unload(true): release bundle + ALL loaded assets.
// Instances in the scene lose materials/textures (magenta).
// Use ONLY when you know nothing from this bundle is in the scene.
bundle.Unload(true);

// Cleanup orphaned assets (after Unload(false) + Destroy instances)
yield return Resources.UnloadUnusedAssets();
System.GC.Collect();
```

### Bundle Compression

| Option | Size on Disk | Load Time | RAM During Loading | Usage |
|--------|:-:|:-:|:-:|---------|
| **Uncompressed** | Large | Fastest | Low | Dev/debug |
| **LZMA** | Smallest | Slow (full decompression) | High peak | Download (then re-compress to LZ4) |
| **LZ4 (ChunkBased)** | Medium | Fast (chunk-by-chunk) | Low | **RECOMMENDED on mobile** |

```csharp
// Recommended build:
BuildPipeline.BuildAssetBundles(
    outputPath,
    BuildAssetBundleOptions.ChunkBasedCompression, // LZ4
    BuildTarget.Android
);
```

### Packing Strategies — What to Pack Together?

| Strategy | Description | When to Use |
|----------|-------------|-------------|
| **Per-asset** | One prefab = one bundle | When models are loaded individually, independently |
| **Per-group** | Group of models = one bundle (e.g. "common", "rare") | When models of a given group are loaded together |
| **Shared dependencies** | Shared materials/textures in a separate bundle | When many models share materials |
| **Per-scene** | Entire scene + its assets = one bundle | For additive scene loading from server |

```
Recommended bundle structure:
├── shared_materials    (materials used by many models)
├── shared_textures     (shared textures, e.g. particle atlas)
├── shared_shaders      (custom shaders)
├── models_common_01    (common tier models, batch 1: 10 models)
├── models_common_02    (common tier models, batch 2: 10 models)
├── models_rare_01      (rare tier models)
├── models_legendary_01 (legendary tier models)
├── scenes_showroom     (model preview scene)
├── scenes_collection   (collection scene)
└── scenes_ar           (AR scene)
```

### Pros and Cons

| Pros | Cons |
|------|------|
| Full control over packing and strategy | Manual dependency management — EVERY one must be tracked |
| Any CDN/server — no vendor lock-in | Manual versioning, hash checking, cache invalidation |
| Mature system (10+ years in production) | Bundle per platform (iOS != Android) — double build |
| Supports delta patching (changed bundles) | No built-in reference counting — memory leaks are easy |
| Can host scenes, prefabs, audio, everything | Complicated variants/naming at large scale |
| LZ4 compression = fast loading on mobile | Manifest must be manually parsed for dependencies |
| Full control over cache (version, CRC) | Debugging issues (missing dependencies) is difficult |

### Platform Notes

**Android:**
- `StreamingAssets` is packed inside the APK (in the `/assets/` folder of JAR) — it is compressed and you **cannot** use `AssetBundle.LoadFromFile()`. Requires `UnityWebRequest` or `BetterStreamingAssets` (asset store).
- **Google Play Asset Delivery (PAD)**: For apps >150MB. Bundles can be delivered as:
  - `install-time`: packed with APK, available immediately
  - `fast-follow`: downloaded automatically after installation
  - `on-demand`: downloaded when the user needs them (ideal for models)
- Scoped Storage (Android 11+): save downloaded bundles to `Application.persistentDataPath` — the only place without permissions.

**iOS:**
- StreamingAssets is a normal folder in the app bundle — `LoadFromFile()` works.
- Save downloaded bundles to `Application.persistentDataPath`.
- **Cellular download limit**: ~200MB. Apple blocks downloads >200MB on LTE. Make sure bundles per model are <10MB, or inform the user about the need for Wi-Fi.
- **Background download**: iOS does not allow Unity to download in the background. Use native `NSURLSession` with background configuration (requires native plugin).
- **App Thinning**: Bundles in StreamingAssets are NOT subject to App Thinning (iOS does not know what is in them). Size is 1:1.

---

## 5. Addressables

### What Is It?

A modern, higher-level asset management system built **on top of** AssetBundles. Uses addresses (strings) for references — automatically manages dependencies, memory, and remote/local loading. **This is the recommended system for new Unity projects.**

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Address** | String identifying an asset (e.g. `"Models/Model_001"`). Independent of file path |
| **Group** | Collection of addresses built into one AssetBundle. Controls strategy (local/remote) |
| **Label** | Tag on assets. Allows loading groups of assets by tag (e.g. `"rare"`, `"seasonal"`) |
| **Catalog** | JSON mapping addresses to bundle locations. Can be remote (updatable!) |
| **Profile** | Build/load path configuration per environment (dev, staging, prod) |
| **Content State** | A `.bin` file saving build state. Critical for content-only updates |

### How Does It Work? — Complete Pipeline

```
┌──────────────────────────────────────────────────────────────┐
│                     UNITY EDITOR SETUP                        │
│                                                               │
│  1. Window > Asset Management > Addressables > Groups         │
│                                                               │
│  2. Create groups:                                            │
│     ┌─────────────────────────────────────────────┐           │
│     │ Group: "LocalCore"                           │           │
│     │   Build Path: LocalBuildPath                 │           │
│     │   Load Path: LocalLoadPath                   │           │
│     │   Assets: core shaders, UI, base scene       │           │
│     │                                              │           │
│     │ Group: "RemoteModels_Common"                 │           │
│     │   Build Path: RemoteBuildPath                │           │
│     │   Load Path: RemoteLoadPath                  │           │
│     │   Assets: common model prefabs               │           │
│     │   Labels: [common]                           │           │
│     │                                              │           │
│     │ Group: "RemoteModels_Rare"                   │           │
│     │   Build Path: RemoteBuildPath                │           │
│     │   Load Path: RemoteLoadPath                  │           │
│     │   Assets: rare model prefabs                 │           │
│     │   Labels: [rare]                             │           │
│     │                                              │           │
│     │ Group: "RemoteScenes"                        │           │
│     │   Build Path: RemoteBuildPath                │           │
│     │   Load Path: RemoteLoadPath                  │           │
│     │   Assets: GameShowroom.unity, AR.unity       │           │
│     └─────────────────────────────────────────────┘           │
│                                                               │
│  3. Profiles (per environment):                              │
│     ┌─────────────────────────────────────────────┐           │
│     │ Profile: "Production"                        │           │
│     │   RemoteBuildPath: ServerData/[BuildTarget]  │           │
│     │   RemoteLoadPath: https://cdn.example.com/   │           │
│     │                   [BuildTarget]              │           │
│     │                                              │           │
│     │ Profile: "Development"                       │           │
│     │   RemoteBuildPath: ServerData/[BuildTarget]  │           │
│     │   RemoteLoadPath: http://localhost:8080/     │           │
│     │                   [BuildTarget]              │           │
│     └─────────────────────────────────────────────┘           │
│                                                               │
│  4. Settings:                                                │
│     ☑ Build Remote Catalog  ← KEY for remote updates         │
│     ☑ Only update catalogs manually  ← control in code       │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│                         BUILD                                 │
│                                                               │
│  Addressables > Build > New Build > Default Build Script      │
│                                                               │
│  Output:                                                      │
│  ServerData/Android/                                          │
│  ├── catalog_2024.12.01.12.30.45.json   (content catalog)    │
│  ├── catalog_2024.12.01.12.30.45.hash   (hash for caching)   │
│  ├── remotemodels_common_abc123.bundle  (model assets)        │
│  ├── remotemodels_rare_def456.bundle                          │
│  ├── remotescenes_ghi789.bundle                               │
│  └── settings.json                       (runtime settings)   │
│                                                               │
│  Library/com.unity.addressables/                              │
│  └── addressables_content_state.bin   ← KEEP THIS FILE!      │
│      (needed for content-only updates)                        │
│                                                               │
│  Upload ServerData/ folder to CDN/CCD                         │
└──────────────────────────────────────────────────────────────┘
                            ↓
┌──────────────────────────────────────────────────────────────┐
│                        RUNTIME                                │
│                                                               │
│  1. Initialization (auto or manual):                         │
│     Addressables.InitializeAsync()                           │
│     → loads local settings                                    │
│     → checks remote catalog hash                              │
│     → if new → downloads new catalog                          │
│                                                               │
│  2. Load asset:                                               │
│     Addressables.LoadAssetAsync<T>("address")                │
│     → resolves address → bundle location                      │
│     → checks cache (is bundle already downloaded)             │
│     → downloads bundle if remote and not in cache             │
│     → loads dependencies (other bundles)                      │
│     → deserializes asset                                      │
│     → increments reference count                              │
│     → returns asset                                           │
│                                                               │
│  3. Release:                                                  │
│     Addressables.Release(handle)                             │
│     → decrements reference count                              │
│     → if count = 0 → frees asset from memory                 │
│     → if no asset from bundle is used                        │
│       → frees bundle from memory                              │
└──────────────────────────────────────────────────────────────┘
```

### Complete Code Examples

```csharp
// ═══════════════════════════════════════════════════════
// 1. BASIC LOADING
// ═══════════════════════════════════════════════════════

// A. Load prefab by address
var handle = Addressables.LoadAssetAsync<GameObject>("Models/Model_001");
GameObject prefab = await handle.Task;
GameObject instance = Instantiate(prefab);
// IMPORTANT: handle must be Release()'d when you no longer need more instances

// B. Load + Instantiate in one step
var instance = await Addressables.InstantiateAsync("Models/Model_001").Task;
// Cleanup: Addressables.ReleaseInstance(instance) → destroys AND releases

// C. Load a scene
var sceneHandle = Addressables.LoadSceneAsync(
    "Scenes/GameShowroom",
    LoadSceneMode.Additive,
    activateOnLoad: true
);
SceneInstance scene = await sceneHandle.Task;
// Cleanup: Addressables.UnloadSceneAsync(sceneHandle)

// D. Load texture/material/any type
var texHandle = Addressables.LoadAssetAsync<Texture2D>("Textures/ModelDiffuse_001");
Texture2D texture = await texHandle.Task;

// E. Load by label (all models with label "rare")
var listHandle = Addressables.LoadAssetsAsync<GameObject>(
    "rare",                         // label
    (GameObject prefab) => {        // callback per asset
        Debug.Log($"Loaded rare model: {prefab.name}");
    }
);
IList<GameObject> rareModels = await listHandle.Task;

// F. Load by multiple labels (AND/OR)
var mergeHandle = Addressables.LoadAssetsAsync<GameObject>(
    new List<string> { "rare", "seasonal" },    // multiple labels
    null,                                        // callback
    Addressables.MergeMode.Intersection          // AND (both labels)
    // MergeMode.Union = OR (one or both)
);

// ═══════════════════════════════════════════════════════
// 2. REFERENCE COUNTING — why it matters
// ═══════════════════════════════════════════════════════

// WRONG — memory leak:
var handle = Addressables.LoadAssetAsync<GameObject>("Models/Model_001");
await handle.Task;
// ... use ...
// ← forgot Release() → asset will NEVER be freed from RAM!

// CORRECT:
var handle = Addressables.LoadAssetAsync<GameObject>("Models/Model_001");
GameObject prefab = await handle.Task;
GameObject instance = Instantiate(prefab);
// ... use instance ...
Destroy(instance);
Addressables.Release(handle); // ← release reference

// EVEN BETTER — InstantiateAsync (auto reference counting):
var instance = await Addressables.InstantiateAsync("Models/Model_001").Task;
// ... use instance ...
Addressables.ReleaseInstance(instance); // destroys AND releases reference

// ═══════════════════════════════════════════════════════
// 3. PRELOADING — download to cache without loading to RAM
// ═══════════════════════════════════════════════════════

// Scenario: user browses a model list in Flutter.
// Preload the next 3 models in the background (download bundle, but do not load to RAM).

public class ModelPreloader
{
    private readonly List<AsyncOperationHandle> _downloadHandles = new();

    // Download bundle to cache (disk) — do not load to RAM
    public async Task PredownloadModels(List<string> modelIds)
    {
        foreach (string modelId in modelIds)
        {
            // GetDownloadSizeAsync returns the size to download (0 = in cache)
            var sizeHandle = Addressables.GetDownloadSizeAsync($"Models/{modelId}");
            long size = await sizeHandle.Task;
            Addressables.Release(sizeHandle);

            if (size > 0)
            {
                // Download to cache (do not load to RAM)
                var downloadHandle = Addressables.DownloadDependenciesAsync($"Models/{modelId}");

                downloadHandle.Completed += (op) => {
                    NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
                        type = "model_predownloaded",
                        modelId = modelId,
                        success = op.Status == AsyncOperationStatus.Succeeded
                    }));
                };

                _downloadHandles.Add(downloadHandle);
            }
        }
    }

    // Check total download size for a group
    public async Task<long> GetTotalDownloadSize(string label)
    {
        var handle = Addressables.GetDownloadSizeAsync(label);
        long size = await handle.Task;
        Addressables.Release(handle);
        return size; // bytes
    }

    public void Cleanup()
    {
        foreach (var handle in _downloadHandles)
            if (handle.IsValid()) Addressables.Release(handle);
        _downloadHandles.Clear();
    }
}

// ═══════════════════════════════════════════════════════
// 4. PROGRESS TRACKING — feedback to Flutter
// ═══════════════════════════════════════════════════════

IEnumerator LoadModelWithProgress(string modelId)
{
    var handle = Addressables.InstantiateAsync($"Models/{modelId}");

    while (!handle.IsDone)
    {
        // PercentComplete: 0.0 → 1.0
        float progress = handle.PercentComplete;

        NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
            type = "model_load_progress",
            modelId = modelId,
            progress = progress
        }));

        yield return null;
    }

    if (handle.Status == AsyncOperationStatus.Succeeded)
    {
        NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
            type = "model_loaded",
            modelId = modelId,
            success = true
        }));
    }
}

// ═══════════════════════════════════════════════════════
// 5. ERROR HANDLING
// ═══════════════════════════════════════════════════════

public async Task<GameObject> SafeLoadModel(string modelId)
{
    try
    {
        var handle = Addressables.InstantiateAsync($"Models/{modelId}");
        var result = await handle.Task;

        if (handle.Status == AsyncOperationStatus.Failed)
        {
            Debug.LogError($"Failed to load {modelId}: {handle.OperationException}");
            NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
                type = "model_error",
                modelId = modelId,
                error = handle.OperationException?.Message ?? "Unknown error"
            }));
            return null;
        }

        return result;
    }
    catch (InvalidKeyException e)
    {
        // Address does not exist in the catalog
        Debug.LogError($"Address not found: Models/{modelId}");
        return null;
    }
    catch (Exception e)
    {
        // Network error, corruption, etc.
        Debug.LogError($"Unexpected error loading {modelId}: {e}");
        return null;
    }
}
```

### Remote Catalog Update — New Content Without App Update

This is the **most important** Addressables feature. It allows adding new models, scenes, materials — without submission to App Store / Google Play.

```csharp
/// <summary>
/// Manages Addressables catalog updates.
/// Call on application start (loading screen).
/// </summary>
public class CatalogUpdater : MonoBehaviour
{
    public event Action<float> OnProgress;
    public event Action<bool> OnComplete;
    public event Action<long> OnUpdateAvailable;

    // ═══ FULL UPDATE FLOW ═══
    public async Task CheckAndUpdate()
    {
        // Step 1: Initialize Addressables (if not initialized)
        await Addressables.InitializeAsync().Task;

        // Step 2: Check if there is a new remote catalog
        var checkHandle = Addressables.CheckForCatalogUpdates(autoReleaseHandle: false);
        await checkHandle.Task;
        List<string> catalogsToUpdate = checkHandle.Result;
        Addressables.Release(checkHandle);

        if (catalogsToUpdate == null || catalogsToUpdate.Count == 0)
        {
            Debug.Log("Catalog up to date — no updates");
            OnComplete?.Invoke(false);
            return;
        }

        Debug.Log($"Update available for {catalogsToUpdate.Count} catalogs");

        // Step 3: Optionally check download size
        long totalSize = 0;
        foreach (var catalog in catalogsToUpdate)
        {
            var sizeHandle = Addressables.GetDownloadSizeAsync(catalog);
            totalSize += await sizeHandle.Task;
            Addressables.Release(sizeHandle);
        }
        OnUpdateAvailable?.Invoke(totalSize);

        // Step 4: Download updated catalog
        var updateHandle = Addressables.UpdateCatalogs(catalogsToUpdate, autoReleaseHandle: false);
        await updateHandle.Task;
        Addressables.Release(updateHandle);

        Debug.Log("Catalog updated! New addresses available.");
        OnComplete?.Invoke(true);

        // Step 5: (Optional) Preload new assets
        // E.g. download thumbnails of new models
    }

    // ═══ FLOW WITH LOADING SCREEN ═══
    public IEnumerator CheckAndUpdateWithProgress()
    {
        yield return Addressables.InitializeAsync();

        var checkHandle = Addressables.CheckForCatalogUpdates(autoReleaseHandle: false);
        yield return checkHandle;

        if (checkHandle.Result?.Count > 0)
        {
            var updateHandle = Addressables.UpdateCatalogs(
                checkHandle.Result,
                autoReleaseHandle: false
            );

            while (!updateHandle.IsDone)
            {
                OnProgress?.Invoke(updateHandle.PercentComplete);

                NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
                    type = "catalog_update_progress",
                    progress = updateHandle.PercentComplete
                }));

                yield return null;
            }

            Addressables.Release(updateHandle);

            NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
                type = "catalog_updated",
                newAddressesAvailable = true
            }));
        }

        Addressables.Release(checkHandle);
    }
}
```

**Workflow for publishing new content:**

```
1. Artist creates a new model in Unity Editor
2. Mark prefab as Addressable: "Models/NewModel_042"
3. Add to group "RemoteModels_Common", label "common"

4. Build content update (NOT a new app build!):
   Addressables > Build > Update Previous Build
   → Point to addressables_content_state.bin from the last build
   → Generates ONLY changed bundles + new catalog

5. Upload to CDN/CCD:
   ├── New catalog JSON + hash
   └── Only changed bundles (new model)

6. Users:
   ├── Open app → CatalogUpdater checks hash
   ├── New hash → download new catalog (a few KB)
   ├── "Models/NewModel_042" is now available
   └── When user wants to see it → download bundle (on demand)

No submission to App Store / Google Play!
```

**CRITICAL file: `addressables_content_state.bin`**

```
This file MUST be preserved after every app build.
Without it you cannot do a content-only update!

Workflow:
1. Build app → save addressables_content_state.bin → commit/archive
2. Content update → use this file → generates delta
3. New app build → generates NEW .bin → archive the new one
4. Content update for the new version → use the new .bin
```

### Unity Cloud Content Delivery (CCD)

Unity offers a managed CDN dedicated to hosting AssetBundles. Full integration with Addressables — zero CDN configuration.

**Setup:**

```
1. Unity Dashboard → Cloud Content Delivery
2. Create buckets:
   ├── "myapp-android-prod"
   ├── "myapp-ios-prod"
   ├── "myapp-android-staging"
   └── "myapp-ios-staging"

3. In Unity Editor:
   Addressables > Profiles > "Production":
     RemoteLoadPath = https://[ProjectID].client-api.unity3dusercontent.com/
                      client_api/v1/environments/production/buckets/[BucketID]/
                      release_by_badge/latest/entry_by_path/content/?path=

4. Build Addressables → Upload ServerData/ to CCD bucket
5. Create Release → Assign Badge "latest"
```

| Feature | Details |
|---------|---------|
| Free tier | 50GB bandwidth/month |
| Above 50GB | $0.08/GB |
| Above 50TB | $0.06/GB |
| Above 500TB | $0.03/GB |
| Formats | .bundle, .gzip, .txt, .json and others |
| Integration | Native with Addressables (zero custom code) |
| Per-platform | Separate buckets for iOS and Android |
| Environments | Separate dev/staging/prod |
| Badges | "latest", "v1.2", "seasonal_winter" — pointer to release |
| Releases | Immutable content snapshots. Rollback = change badge |
| Dashboard | Web UI for management, upload, monitoring |

**Alternatives to CCD (self-hosted):**

| CDN | Cost | Setup | Notes |
|-----|------|-------|-------|
| **AWS S3 + CloudFront** | ~$0.085/GB | Medium | Most popular. Terraform/CDK for automation |
| **Cloudflare R2** | $0.015/GB (egress free!) | Low | Cheapest. Zero egress fees |
| **Google Cloud Storage** | ~$0.08/GB | Medium | Good Firebase integration |
| **Azure Blob + CDN** | ~$0.087/GB | Medium | Enterprise |
| **Firebase Hosting** | Free 10GB/day | Low | Simple setup, limitations |

### Addressables — Advanced Techniques

```csharp
// ═══ Dynamic addresses (from server/Remote Config) ═══
string modelAddress = RemoteConfigService.Instance
    .appConfig.GetString("featured_model_address"); // "Models/LimitedEdition_001"
var model = await Addressables.InstantiateAsync(modelAddress).Task;

// ═══ Conditional loading per platform ═══
string platform = Application.platform == RuntimePlatform.IPhonePlayer ? "ios" : "android";
var model = await Addressables.InstantiateAsync($"Models/{platform}/HighRes_001").Task;

// ═══ Memory profiling — check what is loaded ═══
// Window > Asset Management > Addressables > Event Viewer
// Shows: what is loaded, reference count, bundles in memory

// ═══ Cache clearing ═══
// Clear ENTIRE Addressables cache (e.g. after a major update):
Caching.ClearCache();
// Or per bundle:
Caching.ClearOtherCachedVersions(bundleName, Hash128.Parse(currentHash));
```

### Pros and Cons

| Pros | Cons |
|------|------|
| Automatic dependencies — no need to track manually | Abstraction adds debugging complexity |
| Reference counting → no memory leaks (if you Release()) | Learning curve for the pipeline (groups, profiles, labels) |
| Memory management (Release() frees automatically) | Automation does not fit ultra-granular control |
| Content update without app rebuild! (remote catalog) | `addressables_content_state.bin` must be archived |
| Labels → load groups of assets with a single call | Profiler/Event Viewer requires learning |
| Integration with CCD (zero custom CDN) | GetDownloadSizeAsync not always accurate |
| Progress tracking (PercentComplete) | First build is slower than raw AssetBundles |
| Predownload (DownloadDependenciesAsync) | Cache invalidation can be tricky |
| Profiling (Event Viewer, Build Layout Report) | Error messages can be cryptic |
| Per-label, per-address, per-group control | |

---

## 6. glTF/GLB — Runtime Import

### What Is It?

Loading standard 3D files (glTF 2.0 / GLB) at runtime — **without** prior conversion to native Unity assets. glTF ("Graphics Language Transmission Format") is the industry standard for 3D exchange, supported by the Khronos Group. Blender, Maya, 3ds Max, Substance Painter — all export glTF.

**Two format variants:**

| Format | Description | Size | Loading |
|--------|-------------|------|---------|
| **.gltf** | JSON + separate files (.bin, .png) | Larger (multiple files) | Slower (multiple HTTP requests) |
| **.glb** | Binary — everything in one file | Smaller | Faster (single file) |

**Recommendation: GLB** — single file, faster loading, less overhead.

### Why Is This Important?

| Scenario | Description |
|----------|-------------|
| **NFT from marketplace** | Models as NFTs with metadata containing a URL to .glb |
| **External art pipeline** | Artists export from Blender/Maya -> .glb -> CDN -> app loads at runtime |
| **User-generated content** | User uploads .glb -> rendering in Unity |
| **Cross-platform content** | Same .glb for web viewer, mobile app, and desktop |
| **Dynamic content API** | Backend returns URL to model. App does not need to know in advance what it will load |
| **A/B testing visuals** | Different model variants without app rebuild |

### Three Libraries — Detailed Comparison

#### A. glTFast (Unity official) — RECOMMENDED

```csharp
// ═══ Installation ═══
// Package Manager → Add by name: com.unity.cloud.gltfast

// ═══ Basic loading ═══
using GLTFast;

var gltf = new GltfImport();
bool success = await gltf.Load("https://cdn.example.com/models/model_001.glb");

if (success) {
    // Instantiate MAIN scene from the glTF file
    var instantiator = new GameObjectInstantiator(gltf, parentTransform);
    await gltf.InstantiateMainSceneAsync(instantiator);

    // OR simpler version:
    gltf.InstantiateMainScene(parentTransform);
}

// ═══ Loading with progress ═══
var gltf = new GltfImport();

// Custom downloader with progress tracking
var downloadProvider = new DefaultDownloadProvider();
var settings = new ImportSettings {
    AnimationMethod = AnimationMethod.Legacy, // or Mecanim
    GenerateMipMaps = true,
    AnisotropicFilterLevel = 4,
    NodeNameMethod = NameImportMethod.OriginalUnique,
};

bool success = await gltf.Load(
    "https://cdn.example.com/models/model_001.glb",
    settings,
    downloadProvider
);

// ═══ Loading from local file ═══
string localPath = Path.Combine(Application.persistentDataPath, "models/model.glb");
var gltf = new GltfImport();
bool success = await gltf.Load($"file://{localPath}");

// ═══ Loading from byte array (when you have data in memory) ═══
byte[] glbData = await DownloadGlbBytes(url);
var gltf = new GltfImport();
bool success = await gltf.LoadGltfBinary(glbData);
if (success) gltf.InstantiateMainScene(parentTransform);

// ═══ Accessing loaded data ═══
if (gltf.MaterialCount > 0)
{
    Material mat = gltf.GetMaterial(0);
    Debug.Log($"Material: {mat.name}, shader: {mat.shader.name}");
}

if (gltf.TextureCount > 0)
{
    Texture2D tex = gltf.GetTexture(0);
    Debug.Log($"Texture: {tex.width}x{tex.height}");
}

// Mesh info
for (int i = 0; i < gltf.MeshCount; i++)
{
    // Mesh data available through gltf.GetMeshes()
}

// Animations
if (gltf.AnimationCount > 0)
{
    // Animations are automatically added to the GameObject
    var animations = gltf.GetAnimationClips();
}

// ═══ Cleanup ═══
gltf.Dispose(); // Free native resources (textures, meshes)
```

| Feature | Details |
|---------|---------|
| Author | Unity Technologies (official package since Unity 2023+) |
| Performance | **Burst + Jobs** = multithreaded parsing, ~3-5x faster than UnityGLTF |
| Render pipelines | URP, HDRP, Built-in — automatic detection |
| Import + Export | Yes, both at runtime |
| Build size | Small (optimized, no Json.NET) |
| Animations | Legacy + Mecanim |
| Draco compression | Yes (mesh compression, ~70% smaller files) |
| KTX/Basis textures | Yes (GPU-ready texture compression) |
| glTF extensions | KHR_materials_unlit, KHR_texture_transform, KHR_draco_mesh_compression, many others |

#### B. UnityGLTF (Khronos Group) — community

```csharp
// ═══ Installation ═══
// Package Manager → Add by git URL:
// https://github.com/KhronosGroup/UnityGLTF.git

using GLTF;
using UnityGLTF;

// Basic loading
var loader = new WebRequestLoader(new Uri("https://cdn.example.com/models/"));
var importer = new GLTFSceneImporter("model_001.glb", loader);
importer.MaximumLod = 300; // max LOD level
importer.IsMultithreaded = true;

await importer.LoadSceneAsync();
// Scene loaded under root transform

// With custom material
importer.SetShaderForMaterialType(GLTFSceneImporter.MaterialType.PbrMetallicRoughness,
    Shader.Find("Custom/ModelShader"));
```

| Feature | Details |
|---------|---------|
| Author | Khronos Group + Prefrontal Cortex (fork) |
| Performance | Pure C# — slower, but more flexible |
| Flexibility | Extensive plugin system, custom material mappers |
| Build size | Larger (~1-2MB additional with Json.NET) |
| Export | Yes, with extensions (KHR_animation_pointer, MSFT_lod) |
| Custom shaders | Easier than in glTFast — shader mapping API |

#### C. GLTFUtility (Siccity) — lightweight

```csharp
// Installation: via UPM git URL
// https://github.com/Siccity/GLTFUtility.git

using Siccity.GLTFUtility;

// Sync (blocking — not for mobile!)
GameObject model = Importer.LoadFromFile(filePath);

// Async
Importer.ImportGLBAsync(filePath, new ImportSettings(), (result, clips) => {
    // result = loaded GameObject
    // clips = AnimationClip[]
});
```

Simpler API, but less actively maintained. No Draco, no KTX.

### Detailed Comparison

| Feature | glTFast | UnityGLTF | GLTFUtility |
|---|---|---|---|
| **Mobile performance** | Best (Burst+Jobs) | Good | Good |
| **Support** | Unity official | Community (active) | Limited |
| **Build size** | ~200KB | ~1-2MB (Json.NET) | ~500KB |
| **Animations** | Legacy + Mecanim | Legacy + Mecanim | Legacy |
| **PBR materials** | Full (auto pipeline detect) | Full (custom mapping) | Basic |
| **Draco compression** | Yes | No | No |
| **KTX/Basis textures** | Yes | No | No |
| **Custom shader mapping** | Limited | Extensive | Minimal |
| **Export** | Yes (runtime) | Yes (runtime + editor) | No |
| **Async loading** | Yes (native) | Yes | Yes |
| **Cross-platform** | All Unity platforms | All | Most |
| **glTF extensions** | 20+ extensions | 15+ extensions | ~5 extensions |
| **Parse time 10MB GLB** | ~200ms (mobile) | ~600ms (mobile) | ~500ms (mobile) |

### Full GltfLoader Implementation (C#)

```csharp
using GLTFast;
using UnityEngine;

/// <summary>
/// Loader for glTF/GLB models from CDN.
/// Handles: loading, caching, cleanup, error handling.
/// </summary>
public class GltfModelLoader : MonoBehaviour
{
    [SerializeField] private Transform modelContainer;
    [SerializeField] private Material fallbackMaterial;

    private GltfImport _currentGltf;
    private GameObject _currentModel;

    // ─── Load model from URL ───
    public async Task<bool> LoadFromUrl(string url, string modelId)
    {
        // Cleanup previous
        UnloadCurrent();

        try
        {
            NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
                type = "gltf_loading",
                modelId = modelId
            }));

            _currentGltf = new GltfImport();

            var settings = new ImportSettings {
                AnimationMethod = AnimationMethod.Mecanim,
                GenerateMipMaps = true,
                AnisotropicFilterLevel = 4,
            };

            bool success = await _currentGltf.Load(url, settings);

            if (!success)
            {
                Debug.LogError($"Failed to load glTF: {url}");
                NotifyError(modelId, "Failed to parse glTF file");
                return false;
            }

            // Instantiate
            var instantiator = new GameObjectInstantiator(_currentGltf, modelContainer);
            bool instantiated = await _currentGltf.InstantiateMainSceneAsync(instantiator);

            if (!instantiated)
            {
                NotifyError(modelId, "Failed to instantiate glTF scene");
                return false;
            }

            _currentModel = modelContainer.GetChild(modelContainer.childCount - 1).gameObject;

            // Auto-scale to unified size (model on pedestal)
            NormalizeScale(_currentModel, targetHeight: 1.5f);

            // Center on pedestal
            CenterModel(_currentModel);

            NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
                type = "gltf_loaded",
                modelId = modelId,
                meshCount = _currentGltf.MeshCount,
                materialCount = _currentGltf.MaterialCount,
                animationCount = _currentGltf.AnimationCount,
                success = true
            }));

            return true;
        }
        catch (Exception e)
        {
            NotifyError(modelId, e.Message);
            return false;
        }
    }

    // ─── Load from local file ───
    public async Task<bool> LoadFromFile(string filePath, string modelId)
    {
        string uri = filePath.StartsWith("file://") ? filePath : $"file://{filePath}";
        return await LoadFromUrl(uri, modelId);
    }

    // ─── Load from byte array ───
    public async Task<bool> LoadFromBytes(byte[] data, string modelId)
    {
        UnloadCurrent();

        _currentGltf = new GltfImport();
        bool success = await _currentGltf.LoadGltfBinary(data);
        if (!success) return false;

        _currentGltf.InstantiateMainScene(modelContainer);
        _currentModel = modelContainer.GetChild(modelContainer.childCount - 1).gameObject;
        NormalizeScale(_currentModel, 1.5f);
        CenterModel(_currentModel);

        return true;
    }

    // ─── Download + Cache + Load ───
    public async Task<bool> DownloadCacheAndLoad(string url, string modelId)
    {
        string cacheDir = Path.Combine(Application.persistentDataPath, "gltf_cache");
        Directory.CreateDirectory(cacheDir);
        string cachedPath = Path.Combine(cacheDir, $"{modelId}.glb");

        // Check cache
        if (File.Exists(cachedPath))
        {
            return await LoadFromFile(cachedPath, modelId);
        }

        // Download
        using var request = UnityWebRequest.Get(url);
        var op = request.SendWebRequest();

        while (!op.isDone)
        {
            NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
                type = "gltf_download_progress",
                modelId = modelId,
                progress = request.downloadProgress
            }));
            await Task.Yield();
        }

        if (request.result != UnityWebRequest.Result.Success)
        {
            NotifyError(modelId, $"Download failed: {request.error}");
            return false;
        }

        // Cache to disk
        File.WriteAllBytes(cachedPath, request.downloadHandler.data);

        // Load from cache
        return await LoadFromFile(cachedPath, modelId);
    }

    // ─── Helpers ───
    private void NormalizeScale(GameObject obj, float targetHeight)
    {
        var renderers = obj.GetComponentsInChildren<Renderer>();
        if (renderers.Length == 0) return;

        Bounds bounds = renderers[0].bounds;
        foreach (var r in renderers) bounds.Encapsulate(r.bounds);

        float currentHeight = bounds.size.y;
        if (currentHeight <= 0) return;

        float scale = targetHeight / currentHeight;
        obj.transform.localScale *= scale;
    }

    private void CenterModel(GameObject obj)
    {
        var renderers = obj.GetComponentsInChildren<Renderer>();
        if (renderers.Length == 0) return;

        Bounds bounds = renderers[0].bounds;
        foreach (var r in renderers) bounds.Encapsulate(r.bounds);

        Vector3 offset = bounds.center - obj.transform.position;
        obj.transform.position -= offset;
        obj.transform.position = new Vector3(
            obj.transform.position.x,
            obj.transform.position.y + bounds.extents.y, // Feet on ground
            obj.transform.position.z
        );
    }

    private void UnloadCurrent()
    {
        if (_currentModel != null) Destroy(_currentModel);
        _currentGltf?.Dispose();
        _currentGltf = null;
        _currentModel = null;
    }

    private void NotifyError(string modelId, string error)
    {
        NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
            type = "gltf_error",
            modelId = modelId,
            error = error
        }));
    }

    private void OnDestroy() => UnloadCurrent();
}
```

### Draco Compression — 70% Smaller Files

Draco is a mesh compression library from Google. glTFast supports it natively.

```
Model without Draco:  5.2 MB (.glb)
Model with Draco:     1.5 MB (.glb)  ← 71% smaller!

Decompression on mobile: ~50ms (Burst compiled)
```

**How to enable:**
1. Export from Blender: check "Draco mesh compression" in glTF export settings
2. glTFast detects automatically and decompresses with Burst

### KTX/Basis Universal Textures — GPU-Ready Compression

```
Standard textures in glTF: PNG/JPEG
→ Decompressed to RGBA32 in RAM → converted to GPU format
→ Slow, high RAM usage during loading

KTX/Basis Universal:
→ GPU-ready format (ASTC/ETC2/BC7 per platform)
→ Directly to GPU without decompression step
→ 4-6x faster loading, less peak RAM
```

**Requires:** `com.unity.cloud.ktx` package (glTFast auto-detect)

### Platform Notes

- **Android**: File paths must use `Application.persistentDataPath` for downloaded models. `StreamingAssets` requires `UnityWebRequest` (not `file://`). Draco + Burst works on ARM64.
- **iOS**: File URIs **must** have the `file://` prefix. AOT compilation means: avoid reflection-heavy code in custom importers. Draco + Burst works on ARM64. **Privacy Manifest** — if downloading from a server, declare network usage.
- **Both**: glTFast with Burst gives **3-5x** better parsing performance on mobile ARM than pure C# (UnityGLTF). Large GLB files (50MB+) should be loaded asynchronously with a progress indicator.
- **Peak memory**: During GLB parsing, the file + decompressed data are in RAM simultaneously. For a 20MB GLB, peak RAM can be ~60MB. On low-end mobile this matters.
- **Textures**: glTF uses PNG/JPEG — decompressed to RGBA32 -> converted to platform format (ASTC). This step is expensive. Use KTX/Basis for better performance.

---

## 7. Runtime Mesh Generation

### What Is It?

Creating 3D geometry programmatically at runtime — without pre-made assets. You define vertices, triangles, normals, UVs, and colors in C# code. Unity converts this into GPU buffers.

**When does it make sense vs loading pre-made models?**

| Use Runtime Mesh | Use Pre-Made Models |
|------------------|---------------------|
| Shape depends on data (user input, API) | Fixed, designed model |
| Infinite variation (procedural terrain) | Finite set of variants |
| Simple geometry (planes, primitives) | Complex organic geometry |
| Data visualization (charts, diagrams) | Characters, world objects |
| Customizable shapes (sliders, parameters) | Ready-made assets from artists |

### How Does It Work? — From Simple to Advanced

```csharp
// ═══════════════════════════════════════════════════════
// 1. BASIC — quad (two triangles)
// ═══════════════════════════════════════════════════════

public class SimpleQuadGenerator : MonoBehaviour
{
    void Start()
    {
        Mesh mesh = new Mesh();

        // 4 vertices (bottom-left, bottom-right, top-left, top-right)
        mesh.vertices = new Vector3[] {
            new Vector3(-0.5f, 0, -0.5f),  // 0: bottom-left
            new Vector3( 0.5f, 0, -0.5f),  // 1: bottom-right
            new Vector3(-0.5f, 0,  0.5f),  // 2: top-left
            new Vector3( 0.5f, 0,  0.5f),  // 3: top-right
        };

        // 2 triangles (6 indices). Order = clockwise = front face.
        mesh.triangles = new int[] {
            0, 2, 1,  // bottom-left triangle
            2, 3, 1,  // top-right triangle
        };

        // UV mapping (0,0 = bottom-left → 1,1 = top-right)
        mesh.uv = new Vector2[] {
            new Vector2(0, 0),
            new Vector2(1, 0),
            new Vector2(0, 1),
            new Vector2(1, 1),
        };

        // Normals (all point up for a flat surface)
        mesh.normals = new Vector3[] {
            Vector3.up, Vector3.up, Vector3.up, Vector3.up,
        };
        // OR: mesh.RecalculateNormals(); — automatically

        // Assign to components
        GetComponent<MeshFilter>().mesh = mesh;
        // MeshRenderer + Material must be on the same GameObject
    }
}

// ═══════════════════════════════════════════════════════
// 2. PROCEDURAL GRID — terrain with heightmap
// ═══════════════════════════════════════════════════════

public class ProceduralTerrain : MonoBehaviour
{
    [SerializeField] private int gridSizeX = 50;
    [SerializeField] private int gridSizeZ = 50;
    [SerializeField] private float cellSize = 0.5f;
    [SerializeField] private float heightScale = 3f;
    [SerializeField] private float noiseScale = 0.1f;

    void Start()
    {
        Mesh mesh = new Mesh();
        // For large meshes (>65K vertices) — use 32-bit index buffer
        mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;

        int vertexCount = (gridSizeX + 1) * (gridSizeZ + 1);
        var vertices = new Vector3[vertexCount];
        var uvs = new Vector2[vertexCount];
        var colors = new Color[vertexCount]; // vertex colors

        // Generate vertices with Perlin noise heightmap
        int i = 0;
        for (int z = 0; z <= gridSizeZ; z++)
        {
            for (int x = 0; x <= gridSizeX; x++)
            {
                float height = Mathf.PerlinNoise(x * noiseScale, z * noiseScale) * heightScale;
                vertices[i] = new Vector3(x * cellSize, height, z * cellSize);
                uvs[i] = new Vector2((float)x / gridSizeX, (float)z / gridSizeZ);

                // Vertex color based on height (green → brown → white)
                float normalizedHeight = height / heightScale;
                colors[i] = Color.Lerp(Color.green, Color.white, normalizedHeight);
                i++;
            }
        }

        // Generate triangles
        int triangleCount = gridSizeX * gridSizeZ * 6;
        var triangles = new int[triangleCount];
        int t = 0;
        for (int z = 0; z < gridSizeZ; z++)
        {
            for (int x = 0; x < gridSizeX; x++)
            {
                int bottomLeft = z * (gridSizeX + 1) + x;
                int bottomRight = bottomLeft + 1;
                int topLeft = bottomLeft + (gridSizeX + 1);
                int topRight = topLeft + 1;

                triangles[t++] = bottomLeft;
                triangles[t++] = topLeft;
                triangles[t++] = bottomRight;

                triangles[t++] = topLeft;
                triangles[t++] = topRight;
                triangles[t++] = bottomRight;
            }
        }

        mesh.vertices = vertices;
        mesh.triangles = triangles;
        mesh.uv = uvs;
        mesh.colors = colors;
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        GetComponent<MeshFilter>().mesh = mesh;
    }
}

// ═══════════════════════════════════════════════════════
// 3. PARAMETRIC OBJECT — cylinder controlled from Flutter
// ═══════════════════════════════════════════════════════

public class ParametricCylinder : FlutterMonoBehaviour
{
    private Mesh _mesh;

    protected override void OnFlutterMessage(string method, string data)
    {
        if (method == "UpdateCylinder")
        {
            var p = JsonUtility.FromJson<CylinderParams>(data);
            GenerateCylinder(p.radius, p.height, p.segments);
        }
    }

    private void GenerateCylinder(float radius, float height, int segments)
    {
        if (_mesh == null)
        {
            _mesh = new Mesh();
            _mesh.MarkDynamic(); // Optimization for frequently modified meshes
            GetComponent<MeshFilter>().mesh = _mesh;
        }

        var vertices = new List<Vector3>();
        var triangles = new List<int>();
        var uvs = new List<Vector2>();

        // Bottom cap center
        vertices.Add(Vector3.zero);
        uvs.Add(new Vector2(0.5f, 0.5f));

        // Bottom ring + Top ring + Side vertices
        for (int i = 0; i <= segments; i++)
        {
            float angle = (float)i / segments * Mathf.PI * 2;
            float x = Mathf.Cos(angle) * radius;
            float z = Mathf.Sin(angle) * radius;

            // Bottom ring
            vertices.Add(new Vector3(x, 0, z));
            uvs.Add(new Vector2((float)i / segments, 0));

            // Top ring
            vertices.Add(new Vector3(x, height, z));
            uvs.Add(new Vector2((float)i / segments, 1));
        }

        // Top cap center
        int topCenterIdx = vertices.Count;
        vertices.Add(new Vector3(0, height, 0));
        uvs.Add(new Vector2(0.5f, 0.5f));

        // Bottom cap triangles
        for (int i = 0; i < segments; i++)
        {
            triangles.Add(0);
            triangles.Add(1 + (i + 1) * 2);
            triangles.Add(1 + i * 2);
        }

        // Side triangles
        for (int i = 0; i < segments; i++)
        {
            int bl = 1 + i * 2;
            int br = 1 + (i + 1) * 2;
            int tl = bl + 1;
            int tr = br + 1;

            triangles.Add(bl); triangles.Add(tl); triangles.Add(br);
            triangles.Add(tl); triangles.Add(tr); triangles.Add(br);
        }

        // Top cap triangles
        for (int i = 0; i < segments; i++)
        {
            triangles.Add(topCenterIdx);
            triangles.Add(1 + i * 2 + 1);
            triangles.Add(1 + (i + 1) * 2 + 1);
        }

        _mesh.Clear();
        _mesh.SetVertices(vertices);
        _mesh.SetTriangles(triangles, 0);
        _mesh.SetUVs(0, uvs);
        _mesh.RecalculateNormals();
        _mesh.RecalculateBounds();
    }

    [Serializable]
    struct CylinderParams { public float radius; public float height; public int segments; }
}

// ═══════════════════════════════════════════════════════
// 4. ADVANCED — Jobs + Burst (multithreaded)
// ═══════════════════════════════════════════════════════

using Unity.Burst;
using Unity.Collections;
using Unity.Jobs;
using Unity.Mathematics;

[BurstCompile]
struct GenerateTerrainJob : IJobParallelFor
{
    public int gridSizeX;
    public float cellSize;
    public float heightScale;
    public float noiseScale;

    [WriteOnly] public NativeArray<float3> vertices;
    [WriteOnly] public NativeArray<float2> uvs;

    public void Execute(int index)
    {
        int x = index % (gridSizeX + 1);
        int z = index / (gridSizeX + 1);

        float height = noise.cnoise(new float2(x * noiseScale, z * noiseScale)) * heightScale;
        vertices[index] = new float3(x * cellSize, height, z * cellSize);
        uvs[index] = new float2((float)x / gridSizeX, (float)z / gridSizeX);
    }
}

public class BurstTerrain : MonoBehaviour
{
    [SerializeField] private int gridSize = 100;

    void Start()
    {
        int vertexCount = (gridSize + 1) * (gridSize + 1);

        var vertices = new NativeArray<float3>(vertexCount, Allocator.TempJob);
        var uvs = new NativeArray<float2>(vertexCount, Allocator.TempJob);

        var job = new GenerateTerrainJob {
            gridSizeX = gridSize,
            cellSize = 0.5f,
            heightScale = 3f,
            noiseScale = 0.05f,
            vertices = vertices,
            uvs = uvs,
        };

        // Multithreaded! Each vertex generated in parallel.
        JobHandle handle = job.Schedule(vertexCount, 64); // 64 = batch size
        handle.Complete();

        // Apply to mesh
        Mesh mesh = new Mesh();
        mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;

        using var meshDataArray = Mesh.AllocateWritableMeshData(1);
        var meshData = meshDataArray[0];
        meshData.SetVertexBufferParams(vertexCount,
            new VertexAttributeDescriptor(VertexAttribute.Position),
            new VertexAttributeDescriptor(VertexAttribute.TexCoord0, dimension: 2));
        // ... copy data ...

        Mesh.ApplyAndDisposeWritableMeshData(meshDataArray, mesh);
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        GetComponent<MeshFilter>().mesh = mesh;

        vertices.Dispose();
        uvs.Dispose();
    }
}
```

### Use Cases

| Scenario | Description | Complexity |
|----------|-------------|------------|
| **Pedestal/podium** | Procedural pedestal under a model (shape depends on rarity) | Low |
| **Particle trails** | Custom mesh for trail renderer (e.g. sparkle trail behind model) | Medium |
| **Data visualization** | 3D stat chart for a model (bar chart, radar chart) | Medium |
| **Dynamic backgrounds** | Procedural terrain/skybox behind model | Medium |
| **Customizable accessories** | Parametric hats, glasses on model (slider-driven) | High |
| **Morphing effects** | Vertex displacement animation (transform model) | High |

### Key APIs

| API | Description | When to Use |
|-----|-------------|-------------|
| `mesh.MarkDynamic()` | Informs GPU that mesh will be frequently modified | Animated/parametric meshes |
| `mesh.indexFormat = UInt32` | 32-bit index buffer (>65K vertices) | Terrains, large meshes |
| `mesh.RecalculateNormals()` | Automatic normals | When not calculating manually |
| `mesh.RecalculateTangents()` | Tangents for normal maps | When mesh uses normal maps |
| `mesh.RecalculateBounds()` | Bounding box (culling/physics) | ALWAYS after changing vertices |
| `Mesh.MeshDataArray` | Native mesh data (Jobs/Burst) | Large meshes, performance |
| `mesh.SetVertices(List<>)` | Set from list (fewer allocations) | Better than `mesh.vertices = ` |

### Platform Notes

- **Mobile general**: Max ~100K vertices per mesh on mid-range. Above that -> split into sub-meshes.
- **`MarkDynamic()`**: For meshes changed every few frames. NOT for static meshes (wastes GPU memory).
- **iOS (Metal)**: Handles runtime meshes well. Burst compiled generation works on ARM64. Avoid rebuilding mesh every frame if not necessary.
- **Android (Vulkan/OpenGL ES)**: Test on low-end GPUs (Mali-G31, Adreno 505). Burst-compiled generation = **2-5x** faster than managed C#. `UInt32` index format requires OpenGL ES 3.0+ (99% of devices from 2015+).
- **Colliders**: `MeshCollider` with runtime mesh is expensive. On mobile prefer primitive colliders (Box, Sphere, Capsule) or convex colliders. If necessary — `MeshCollider.sharedMesh = mesh` (not every frame!).

---

## 8. Asset Streaming & LOD

### Texture Streaming

Unity has a built-in texture streaming system (Mipmap Streaming) — it loads only the needed mipmaps to the GPU based on camera distance from the object. Drastically reduces VRAM usage.

```
┌────────────────────────────────────────────────────────────┐
│  Mipmap levels (for a 2048x2048 texture):                   │
│                                                             │
│  Mip 0: 2048x2048 = 16 MB (ASTC 4x4)    ← close to camera │
│  Mip 1: 1024x1024 = 4 MB                                   │
│  Mip 2: 512x512   = 1 MB                                   │
│  Mip 3: 256x256   = 256 KB                                 │
│  Mip 4: 128x128   = 64 KB                                  │
│  Mip 5: 64x64     = 16 KB               ← far away         │
│  ...                                                        │
│                                                             │
│  Streaming budget = max VRAM for textures.                  │
│  Unity loads/unloads mipmaps dynamically                    │
│  to fit within the budget.                                  │
└────────────────────────────────────────────────────────────┘
```

**Configuration:**

```csharp
// Quality Settings (Inspector or runtime):
QualitySettings.streamingMipmapsActive = true;           // ENABLE
QualitySettings.streamingMipmapsMemoryBudget = 256;      // MB (VRAM budget for textures)
QualitySettings.streamingMipmapsMaxLevelReduction = 2;   // Max drop mipmap levels
QualitySettings.streamingMipmapsAddAllCameras = true;    // Track all cameras

// Per-texture (in Import Settings):
// ☑ Streaming Mipmaps
// Mip Map Priority: 0 (normal), +2 (more important — load faster)
```

**Notes for mobile:**

| Setting | Low-end | Mid-range | High-end |
|---------|---------|-----------|----------|
| Memory Budget | 128 MB | 256 MB | 512 MB |
| Max Level Reduction | 3 | 2 | 1 |
| Mip Priority (background) | -1 | 0 | 0 |
| Mip Priority (model) | +2 | +1 | 0 |

**Pop-in problem:** When the camera zooms in quickly, the texture may appear blurry for a moment (loading a higher mip). Solutions:
- `StreamingController` component on the camera — preloads mips in advance
- Higher mip priority on key objects (models)
- Larger budget (at the cost of RAM)

### LOD (Level of Detail)

`LODGroup` component automatically switches between mesh variants of different detail levels depending on the object's size on screen.

```
┌────────────────────────────────────────────────────────────┐
│  LODGroup setup:                                            │
│                                                             │
│  Screen %  100%                    50%      25%    10%  0% │
│  ├──────────LOD 0──────────┤──LOD 1──┤─LOD 2─┤─Culled──┤  │
│  │  10,000 tris            │  3,000  │  500  │    0    │  │
│  │  Full materials         │  Simple │  Flat  │  Hidden │  │
│  │  Normal maps            │  No NM  │  No NM│         │  │
│  │  All animations         │  Basic  │  None │         │  │
│  └─────────────────────────┘─────────┘───────┘─────────┘  │
└────────────────────────────────────────────────────────────┘
```

```csharp
// ═══ Manually set LOD on a runtime-loaded prefab ═══
public void SetupLOD(GameObject model, GameObject[] lodMeshes)
{
    var lodGroup = model.AddComponent<LODGroup>();

    LOD[] lods = new LOD[lodMeshes.Length + 1]; // +1 for culled

    for (int i = 0; i < lodMeshes.Length; i++)
    {
        Renderer[] renderers = lodMeshes[i].GetComponentsInChildren<Renderer>();
        float screenPercentage = 1f / (i + 1); // LOD0=1.0, LOD1=0.5, LOD2=0.33
        lods[i] = new LOD(screenPercentage, renderers);
    }

    // Last LOD — culled (0% screen = hide)
    lods[lodMeshes.Length] = new LOD(0.01f, new Renderer[0]);

    lodGroup.SetLODs(lods);
    lodGroup.RecalculateBounds();
}

// ═══ LOD with Addressables — load progressively ═══
public async Task LoadModelProgressive(string modelId, Transform parent)
{
    // Step 1: Load LOD 2 immediately (500 tris, tiny bundle)
    var lodLow = await Addressables.InstantiateAsync($"Models/{modelId}_LOD2", parent).Task;

    // Step 2: Load LOD 0 in the background (full detail, bigger bundle)
    var lodHigh = await Addressables.InstantiateAsync($"Models/{modelId}_LOD0", parent).Task;

    // Step 3: Setup LODGroup
    var lodGroup = lodHigh.AddComponent<LODGroup>();
    lodGroup.SetLODs(new LOD[] {
        new LOD(0.5f, lodHigh.GetComponentsInChildren<Renderer>()),
        new LOD(0.1f, lodLow.GetComponentsInChildren<Renderer>()),
        new LOD(0f, new Renderer[0]),
    });

    // User sees low-poly immediately, high-poly appears when ready
}
```

### Streaming with Addressables — Full Strategy

```
┌────────────────────────────────────────────────────────────┐
│              CONTENT STREAMING STRATEGY                      │
│                                                             │
│  Layer 1: INSTALL (base APK/IPA)                    ~50MB  │
│  ├── Core scene (camera, lighting, UI)                      │
│  ├── Shared shaders (shader variant collection)             │
│  ├── UI atlas textures                                      │
│  ├── Loading screen assets                                  │
│  └── Local Addressables group                               │
│                                                             │
│  Layer 2: FIRST LAUNCH (automatic download)         ~20MB  │
│  ├── Featured model (LOD 0 + LOD 2)                        │
│  ├── Showroom scene                                         │
│  ├── Basic particle effects                                 │
│  └── Audio clips (ambient, UI sounds)                       │
│                                                             │
│  Layer 3: ON DEMAND (per user action)               ~5MB   │
│  ├── Individual model prefabs (per model in collection)     │
│  ├── Material variants (holographic, matte, etc.)           │
│  └── Animation clips per model                              │
│                                                             │
│  Layer 4: LAZY (background, low priority)           varies  │
│  ├── High-res textures (LOD 0 only)                        │
│  ├── AR scene + AR assets                                   │
│  ├── Seasonal/event content                                 │
│  └── Bonus animations                                       │
└────────────────────────────────────────────────────────────┘
```

**Implementation:**

```csharp
public class ContentStreamingManager : MonoBehaviour
{
    // ═══ Layer 2: First Launch ═══
    public async Task DownloadEssentials()
    {
        // Get download size
        var sizeHandle = Addressables.GetDownloadSizeAsync("essential");
        long size = await sizeHandle.Task;
        Addressables.Release(sizeHandle);

        if (size > 0)
        {
            NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
                type = "download_required",
                sizeBytes = size,
                formattedSize = FormatBytes(size)
            }));

            // Download with progress
            var downloadHandle = Addressables.DownloadDependenciesAsync("essential");
            while (!downloadHandle.IsDone)
            {
                var status = downloadHandle.GetDownloadStatus();
                NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
                    type = "download_progress",
                    downloadedBytes = status.DownloadedBytes,
                    totalBytes = status.TotalBytes,
                    percent = status.Percent
                }));
                await Task.Yield();
            }
            Addressables.Release(downloadHandle);
        }
    }

    // ═══ Layer 3: On Demand ═══
    public async Task<bool> EnsureModelDownloaded(string modelId)
    {
        var sizeHandle = Addressables.GetDownloadSizeAsync($"Models/{modelId}");
        long size = await sizeHandle.Task;
        Addressables.Release(sizeHandle);

        if (size == 0) return true; // Already in cache

        // Inform Flutter about download need
        NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
            type = "model_download_required",
            modelId = modelId,
            sizeBytes = size
        }));

        // Download
        var downloadHandle = Addressables.DownloadDependenciesAsync($"Models/{modelId}");
        await downloadHandle.Task;
        bool success = downloadHandle.Status == AsyncOperationStatus.Succeeded;
        Addressables.Release(downloadHandle);
        return success;
    }

    // ═══ Layer 4: Background preload ═══
    public async Task PreloadInBackground(List<string> modelIds)
    {
        foreach (string modelId in modelIds)
        {
            // Check if download is needed
            var sizeHandle = Addressables.GetDownloadSizeAsync($"Models/{modelId}");
            long size = await sizeHandle.Task;
            Addressables.Release(sizeHandle);

            if (size > 0)
            {
                var handle = Addressables.DownloadDependenciesAsync($"Models/{modelId}");
                await handle.Task;
                Addressables.Release(handle);

                // Give breathing room — do not block main thread
                await Task.Delay(100);
            }
        }
    }

    private string FormatBytes(long bytes)
    {
        if (bytes < 1024) return $"{bytes} B";
        if (bytes < 1024 * 1024) return $"{bytes / 1024f:F1} KB";
        return $"{bytes / (1024f * 1024f):F1} MB";
    }
}
```

### Memory Budgets on Mobile — Details

| Tier | Total RAM | Unity Budget | Textures | Meshes | Audio | Other |
|------|:-:|:-:|:-:|:-:|:-:|:-:|
| **Low-end** | 2-3 GB | 300 MB | 100 MB | 30 MB | 20 MB | 150 MB |
| **Mid-range** | 4-6 GB | 500 MB | 250 MB | 60 MB | 30 MB | 160 MB |
| **High-end** | 8+ GB | 800 MB | 400 MB | 100 MB | 50 MB | 250 MB |

**How to measure usage:**

```csharp
// Runtime memory check
long totalMemory = UnityEngine.Profiling.Profiler.GetTotalAllocatedMemoryLong();
long textureMemory = UnityEngine.Profiling.Profiler.GetAllocatedMemoryForGraphicsDriver();

// Log to Flutter
NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
    type = "memory_stats",
    totalMB = totalMemory / (1024f * 1024f),
    textureMB = textureMemory / (1024f * 1024f),
    systemMemoryMB = SystemInfo.systemMemorySize
}));

// Auto-unload on low memory
Application.lowMemory += () => {
    Resources.UnloadUnusedAssets();
    System.GC.Collect();
    // Optionally: unload LOD 0, keep LOD 2
};
```

### Device Tier Detection

```csharp
/// <summary>
/// Automatic device tier detection.
/// Use to set budgets, LOD, quality settings.
/// </summary>
public enum DeviceTier { Low, Mid, High }

public static DeviceTier DetectTier()
{
    int ram = SystemInfo.systemMemorySize;       // MB
    int vram = SystemInfo.graphicsMemorySize;     // MB
    int cores = SystemInfo.processorCount;

    if (ram >= 6000 && vram >= 4000 && cores >= 6)
        return DeviceTier.High;
    if (ram >= 3000 && vram >= 2000 && cores >= 4)
        return DeviceTier.Mid;
    return DeviceTier.Low;
}

// Usage:
void Start()
{
    DeviceTier tier = DetectTier();

    switch (tier)
    {
        case DeviceTier.Low:
            QualitySettings.streamingMipmapsMemoryBudget = 128;
            QualitySettings.SetQualityLevel(0); // Lowest
            Application.targetFrameRate = 30;
            break;
        case DeviceTier.Mid:
            QualitySettings.streamingMipmapsMemoryBudget = 256;
            QualitySettings.SetQualityLevel(2); // Medium
            Application.targetFrameRate = 60;
            break;
        case DeviceTier.High:
            QualitySettings.streamingMipmapsMemoryBudget = 512;
            QualitySettings.SetQualityLevel(4); // Ultra
            Application.targetFrameRate = 60;
            break;
    }

    // Inform Flutter about the tier
    NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
        type = "device_tier",
        tier = tier.ToString(),
        ram = SystemInfo.systemMemorySize,
        gpu = SystemInfo.graphicsDeviceName
    }));
}
```

---

## 9. Remote Configuration

### What Is It?

Changing game behavior, visuals, and parameters from a server — **without updating the application**. Unity offers the official **Unity Remote Config** service (part of Unity Gaming Services). Works on a key-value store with a rules engine.

**What Remote Config is NOT:**
- It does NOT deliver assets (use Addressables for that)
- It does NOT change code (use HybridCLR for that)
- It is NOT a database (use Cloud Save / your own backend for that)

**What it IS:** A lightweight, fast configuration system that tells the application **how to behave** — what values to use, what to show, what to hide.

### How Does It Work? — Complete Setup

```csharp
// ═══════════════════════════════════════════════════════
// 1. INSTALLATION
// ═══════════════════════════════════════════════════════

// Package Manager → Add by name:
// com.unity.services.remoteconfig
// com.unity.services.authentication (dependency)

// ═══════════════════════════════════════════════════════
// 2. DASHBOARD SETUP
// ═══════════════════════════════════════════════════════

// Unity Dashboard → Project Settings → Remote Config:
//
// Keys:
// ├── featured_model_id        (string)  = "model_042"
// ├── model_rotation_speed     (float)   = 2.5
// ├── show_particle_effects    (bool)    = true
// ├── seasonal_theme           (string)  = "default"
// ├── lighting_preset          (string)  = "warm"
// ├── max_models_in_view       (int)     = 12
// ├── showcase_layout          (json)    = {"rows":3,"cols":4}
// └── featured_models_list     (json)    = ["model_001","model_042","model_099"]
//
// Rules (conditions):
// ├── Rule: "Christmas Event"
// │   Condition: date >= 2025-12-20 AND date <= 2026-01-05
// │   Override: seasonal_theme = "christmas"
// │
// ├── Rule: "iOS High-End"
// │   Condition: platform == "iOS" AND deviceModel contains "iPhone15"
// │   Override: max_models_in_view = 20, show_particle_effects = true
// │
// ├── Rule: "Android Low-End"
// │   Condition: platform == "Android" AND systemMemory < 3000
// │   Override: max_models_in_view = 6, show_particle_effects = false
// │
// └── Rule: "A/B Test Lighting"
//     Condition: randomPercent < 50
//     Override: lighting_preset = "cool"

// ═══════════════════════════════════════════════════════
// 3. INITIALIZATION IN CODE
// ═══════════════════════════════════════════════════════

using Unity.Services.Core;
using Unity.Services.Authentication;
using Unity.Services.RemoteConfig;

public class RemoteConfigManager : MonoBehaviour
{
    // Cached values
    public string FeaturedModelId { get; private set; }
    public float ModelRotationSpeed { get; private set; }
    public bool ShowParticles { get; private set; }
    public string SeasonalTheme { get; private set; }
    public string LightingPreset { get; private set; }
    public int MaxModelsInView { get; private set; }

    public event Action OnConfigUpdated;

    public async Task Initialize()
    {
        // Step 1: Initialize Unity Services
        await UnityServices.InitializeAsync();

        // Step 2: Anonymous authentication (required)
        if (!AuthenticationService.Instance.IsSignedIn)
        {
            await AuthenticationService.Instance.SignInAnonymouslyAsync();
        }

        // Step 3: Listen for fetched config
        RemoteConfigService.Instance.FetchCompleted += OnFetchCompleted;

        // Step 4: Fetch with attributes (used for rule evaluation)
        await FetchConfig();
    }

    public async Task FetchConfig()
    {
        RemoteConfigService.Instance.FetchConfigs(
            new UserAttributes {
                // Custom attributes sent to the rules engine
                deviceTier = DetectDeviceTier(),
                appVersion = Application.version,
                userId = AuthenticationService.Instance.PlayerId,
            },
            new AppAttributes {
                // App-level attributes
            }
        );
    }

    private void OnFetchCompleted(ConfigResponse response)
    {
        switch (response.requestOrigin)
        {
            case ConfigOrigin.Default:
                Debug.Log("Remote Config: using default values");
                break;
            case ConfigOrigin.Cached:
                Debug.Log("Remote Config: using cached values (offline)");
                break;
            case ConfigOrigin.Remote:
                Debug.Log("Remote Config: fresh values from server");
                break;
        }

        // Read values
        var config = RemoteConfigService.Instance.appConfig;

        FeaturedModelId = config.GetString("featured_model_id", "model_001");
        ModelRotationSpeed = config.GetFloat("model_rotation_speed", 1.5f);
        ShowParticles = config.GetBool("show_particle_effects", true);
        SeasonalTheme = config.GetString("seasonal_theme", "default");
        LightingPreset = config.GetString("lighting_preset", "warm");
        MaxModelsInView = config.GetInt("max_models_in_view", 12);

        // Send to Flutter
        NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
            type = "remote_config_updated",
            featuredModelId = FeaturedModelId,
            rotationSpeed = ModelRotationSpeed,
            showParticles = ShowParticles,
            seasonalTheme = SeasonalTheme,
            lightingPreset = LightingPreset,
            maxModelsInView = MaxModelsInView,
        }));

        // Apply settings
        ApplyConfig();
        OnConfigUpdated?.Invoke();
    }

    private void ApplyConfig()
    {
        // Lighting preset
        var lightManager = FindFirstObjectByType<LightingManager>();
        lightManager?.ApplyPreset(LightingPreset);

        // Particle effects
        var particles = FindObjectsByType<ParticleSystem>(FindObjectsSortMode.None);
        foreach (var ps in particles)
        {
            var emission = ps.emission;
            emission.enabled = ShowParticles;
        }
    }

    private string DetectDeviceTier()
    {
        int ram = SystemInfo.systemMemorySize;
        if (ram >= 6000) return "high";
        if (ram >= 3000) return "mid";
        return "low";
    }

    private void OnDestroy()
    {
        RemoteConfigService.Instance.FetchCompleted -= OnFetchCompleted;
    }
}

// Custom attribute structs (must implement these interfaces)
[Serializable]
public struct UserAttributes
{
    public string deviceTier;
    public string appVersion;
    public string userId;
}

[Serializable]
public struct AppAttributes { }

// ═══════════════════════════════════════════════════════
// 4. ADVANCED — JSON CONFIG
// ═══════════════════════════════════════════════════════

// In Dashboard: key "showcase_config" = JSON:
// {
//   "layout": "grid",
//   "rows": 3,
//   "cols": 4,
//   "showRarity": true,
//   "sortBy": "rarity",
//   "featuredModels": ["model_001", "model_042", "model_099"]
// }

string jsonConfig = config.GetJson("showcase_config");
var showcaseConfig = JsonUtility.FromJson<ShowcaseConfig>(jsonConfig);

[Serializable]
public struct ShowcaseConfig
{
    public string layout;
    public int rows;
    public int cols;
    public bool showRarity;
    public string sortBy;
    public string[] featuredModels;
}
```

### Remote Config Use Cases — Complete List

| Category | Key | Type | Default | Description |
|----------|-----|------|---------|-------------|
| **Featured** | `featured_model_id` | string | `"model_001"` | Model on the main screen |
| **Featured** | `featured_models_list` | json | `[]` | List of models in showcase |
| **Visual** | `model_rotation_speed` | float | `1.5` | Auto-rotation speed |
| **Visual** | `show_particle_effects` | bool | `true` | Particle effects |
| **Visual** | `lighting_preset` | string | `"warm"` | Lighting preset (warm/cool/dramatic) |
| **Visual** | `post_processing_intensity` | float | `0.7` | Post-processing intensity |
| **Visual** | `background_color` | string | `"#1A1A2E"` | Scene background color |
| **Layout** | `max_models_in_view` | int | `12` | Max models in collection |
| **Layout** | `showcase_config` | json | `{...}` | Showcase layout configuration |
| **Event** | `seasonal_theme` | string | `"default"` | Seasonal theme |
| **Event** | `event_banner_url` | string | `""` | Event banner URL |
| **Event** | `event_start_date` | string | `""` | ISO8601 start date |
| **Event** | `event_end_date` | string | `""` | ISO8601 end date |
| **Content** | `new_model_addressable` | string | `""` | Addressable for new model |
| **Content** | `material_variant` | string | `"default"` | Material variant |
| **Feature flags** | `enable_ar_mode` | bool | `false` | Enable AR mode |
| **Feature flags** | `enable_customizer` | bool | `false` | Enable customizer |
| **Feature flags** | `enable_trading` | bool | `false` | Enable trading |
| **Performance** | `target_frame_rate` | int | `60` | Target FPS |
| **Performance** | `shadow_quality` | string | `"medium"` | Shadow quality |
| **A/B Test** | `onboarding_variant` | string | `"A"` | Onboarding variant |

### Dart (Flutter) — Listening for Config Changes

```dart
class RemoteConfigController {
  final UnityBridge _bridge;

  RemoteConfigController(this._bridge);

  // Listen for configuration changes from Unity
  Stream<RemoteConfig> get onConfigUpdated =>
      _bridge.messageStream
          .where((msg) => msg.type == 'remote_config_updated')
          .map((msg) => RemoteConfig.fromJson(msg.data ?? {}));

  // Force refresh configuration
  void refreshConfig() {
    _bridge.send(UnityMessage.command('RefreshRemoteConfig', {}));
  }
}

class RemoteConfig {
  final String featuredModelId;
  final double rotationSpeed;
  final bool showParticles;
  final String seasonalTheme;
  final String lightingPreset;
  final int maxModelsInView;

  RemoteConfig({
    required this.featuredModelId,
    required this.rotationSpeed,
    required this.showParticles,
    required this.seasonalTheme,
    required this.lightingPreset,
    required this.maxModelsInView,
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      featuredModelId: json['featuredModelId'] as String? ?? 'model_001',
      rotationSpeed: (json['rotationSpeed'] as num?)?.toDouble() ?? 1.5,
      showParticles: json['showParticles'] as bool? ?? true,
      seasonalTheme: json['seasonalTheme'] as String? ?? 'default',
      lightingPreset: json['lightingPreset'] as String? ?? 'warm',
      maxModelsInView: json['maxModelsInView'] as int? ?? 12,
    );
  }
}
```

### Alternatives to Unity Remote Config

| Service | Cost | Pros | Cons |
|---------|------|------|------|
| **Unity Remote Config** | Free (UGS) | Native integration, rules engine | Vendor lock-in |
| **Firebase Remote Config** | Free | A/B testing, analytics integration | Requires Firebase SDK |
| **LaunchDarkly** | Paid | Enterprise feature flags, targeting | Cost, overkill for small projects |
| **Custom backend** | Server cost | Full control | Must build and maintain |

### Offline Fallback

```csharp
// Remote Config automatically caches the last fetch.
// When offline → returns cached values.
// When never fetched → returns default values provided in GetString/GetFloat/etc.

// Additionally: save critical values to disk
public void CacheConfigToDisk()
{
    var config = new Dictionary<string, object> {
        ["featured_model_id"] = FeaturedModelId,
        ["seasonal_theme"] = SeasonalTheme,
        // ...
    };
    string json = JsonUtility.ToJson(new SerializableDict(config));
    string path = Path.Combine(Application.persistentDataPath, "cached_config.json");
    File.WriteAllText(path, json);
}
```

---

## 10. Hot Content Updates (Without Store Submission)

### Overview

"Hot update" = changing content or app behavior without submission to App Store / Google Play. The key question: **what** do you want to update?

| What to Update | Method | iOS Safe? | Android Safe? |
|----------------|--------|:-:|:-:|
| **3D models, textures, scenes** | Addressables remote catalog | YES | YES |
| **Parameters, feature flags** | Remote Config | YES | YES |
| **External 3D models** | glTF from CDN | YES | YES |
| **Animations, audio** | Addressables | YES | YES |
| **C# code (game logic)** | HybridCLR | GRAY AREA | YES |
| **Scripts (Lua, Python)** | xLua, IronPython | RISK | YES |
| **Entire APK patch** | UnityAndroidHotUpdate | N/A | YES |

### A. Addressables + Remote Catalog (RECOMMENDED)

**The safest and most powerful method. Accepted by Apple and Google.**

```
┌──────────────────────────────────────────────────────────────┐
│                    CONTENT UPDATE WORKFLOW                     │
│                                                               │
│  Step 1: INITIAL APP RELEASE                                 │
│  ├── Build app with Addressables (remote catalog enabled)    │
│  ├── Upload bundles + catalog to CDN                         │
│  ├── Preserve addressables_content_state.bin ← CRITICAL!     │
│  └── Submit to App Store / Google Play                        │
│                                                               │
│  Step 2: CREATING NEW CONTENT (days/weeks later)             │
│  ├── Artist creates a new model in Unity Editor              │
│  ├── Mark as Addressable: "Models/NewModel_042"              │
│  ├── Add to group "RemoteModels", label "common"             │
│  └── Optionally: new materials, animations, scenes           │
│                                                               │
│  Step 3: CONTENT-ONLY BUILD (no app rebuild!)                │
│  ├── Addressables > Build > Update Previous Build            │
│  ├── Point to addressables_content_state.bin from step 1     │
│  ├── System generates ONLY changed/new bundles               │
│  ├── Generates new catalog JSON + hash                       │
│  └── Output: ServerData/ folder with changes                 │
│                                                               │
│  Step 4: DEPLOY                                               │
│  ├── Upload ServerData/ to CDN (overwrite old catalog)       │
│  ├── New catalog hash = signal for app                       │
│  └── Done — users will get the new content                   │
│                                                               │
│  Step 5: USER EXPERIENCE                                      │
│  ├── User opens app                                          │
│  ├── CatalogUpdater checks hash (a few KB)                   │
│  ├── New hash → download new catalog (~10-50 KB)             │
│  ├── Now "Models/NewModel_042" is available in the catalog   │
│  ├── When user wants to see it → download bundle (~2-5 MB)   │
│  └── Model loaded! No visit to the Store!                    │
│                                                               │
│  ZERO submissions to App Store / Google Play!                │
│  ZERO waiting for review (Apple: 24-48h)!                    │
│  ZERO forcing updates on users!                              │
└──────────────────────────────────────────────────────────────┘
```

**What CAN be updated through Addressables:**

| Asset | Example | Typical Size |
|-------|---------|:-:|
| Prefabs (3D models) | New model with meshes, materials, animations | 2-10 MB |
| Textures | New skins, color variants | 0.5-4 MB |
| Materials | Holographic, matte, glow variants | <100 KB |
| Scenes | New showroom, seasonal arena | 5-20 MB |
| AnimationClips | New idle, dance, emote animations | 0.1-1 MB |
| Audio | New sounds, music | 0.5-5 MB |
| ScriptableObjects | Configuration data (stats, descriptions) | <50 KB |
| Shader Variants | New visual effects | 0.1-0.5 MB |

**What CANNOT be updated:** Compiled C# code (MonoBehaviours, game logic). The old app build must be able to handle the new content.

### B. HybridCLR (C# Code Hot Update)

Extends IL2CPP with an interpreter, enabling hot-loading of C# DLLs at runtime.

```
┌──────────────────────────────────────────────────────────────┐
│  HOW IT WORKS:                                                │
│                                                               │
│  Standard Unity build:                                        │
│  C# → IL (intermediate language) → IL2CPP → Native (AOT)    │
│  All code is compiled. Cannot be changed without rebuild.     │
│                                                               │
│  With HybridCLR:                                              │
│  ├── "AOT assembly" — core code, compiled normally            │
│  └── "Hot update assembly" — interpreted code                 │
│      ↓                                                        │
│      Download new DLL from server → load → interpret          │
│      → New logic works WITHOUT app rebuild!                   │
│                                                               │
│  IMPORTANT: hot update assemblies must be declared            │
│  in advance in the HybridCLR configuration. You cannot        │
│  arbitrarily add new assemblies after the fact.               │
└──────────────────────────────────────────────────────────────┘
```

| Platform | Status | Notes |
|----------|--------|-------|
| Android | Fully works | No restrictions on dynamic code |
| iOS | Technically works | **Gray area** with Apple Guideline 3.3.2 |
| WebGL | Works | |
| Consoles | Works | |

**Apple Guideline 3.3.2 — full text:**

> "An Application may not download or install executable code. Interpreted code may only be used in an Application if all scripts, code and interpreters are packaged in the Application and not downloaded."

**Interpretation for HybridCLR:**
- The interpreter (HybridCLR runtime) is **built into the app** -> OK
- DLLs with new code are **downloaded from the server** -> violates the rule
- However: DLLs are "interpreted" (not native executable) -> arguments in favor
- **Risk**: Apple may reject the app if it detects significant behavior changes after DLL download
- **Practice**: Small hot-fixes (bug fix) pass review. Large gameplay changes -> risk of rejection
- **Recommendation**: On iOS use HybridCLR ONLY for bug-fixes, not for new features

### C. Lua / Scripts (xLua, Tolua)

```
Embed a Lua interpreter in Unity → download scripts from server → control behavior.

xLua: https://github.com/Tencent/xLua (most popular, Tencent)
Tolua: https://github.com/topameng/tolua (alternative)

Scenario:
├── Fixed C# code: rendering, physics, Unity API calls
└── Dynamic Lua: game logic, AI, quest system, UI flow
    ↓
    Download new .lua files from server
    → Interpreter executes → new behavior
```

**iOS vs Android:**

| Aspect | iOS | Android |
|--------|-----|---------|
| Built-in interpreter | OK — Lua interpreter in app bundle | OK |
| Built-in scripts | OK — .lua files in app bundle | OK |
| Scripts from server | **RISK** — violates 3.3.2 depending on Apple's interpretation | OK — no restrictions |
| JavaScriptCore | OK — Apple allows JavaScript in WebKit/JSCore | N/A |

### D. Data-Driven Design — Safe Alternative

Instead of hot-updating code, design a **data-driven** system:

```
┌──────────────────────────────────────────────────────────────┐
│  INSTEAD OF:                                                  │
│  Download new C# script → new model behavior                 │
│                                                               │
│  DO:                                                          │
│  ScriptableObject "ModelBehaviorConfig" in Addressables:      │
│  {                                                            │
│    "idleAnimation": "bounce",                                 │
│    "idleSpeed": 1.2,                                          │
│    "particleEffect": "sparkle_gold",                          │
│    "interactionType": "spin",                                 │
│    "specialAbility": "glow_pulse",                            │
│    "soundEffect": "chime_01"                                  │
│  }                                                            │
│                                                               │
│  Fixed C# code in app handles ALL possible values.            │
│  New "behavior" = new ScriptableObject in Addressables.       │
│  100% safe on iOS!                                            │
└──────────────────────────────────────────────────────────────┘
```

### E. Recommended Update Strategy

```
┌────────────────────────────────────────────────────────────┐
│                    UPDATE STRATEGY                           │
│                                                             │
│  TIER 1: SAFE (iOS + Android) — ALWAYS USE                 │
│  ├── Addressables + remote catalog                          │
│  │   → New models, textures, scenes, animations             │
│  ├── Remote Config                                          │
│  │   → Feature flags, parameters, A/B testing               │
│  ├── glTF from CDN                                          │
│  │   → External 3D models (NFT, marketplace)                │
│  ├── ScriptableObjects in Addressables                      │
│  │   → Data-driven behavior configs                         │
│  └── Unity CCD or custom CDN                                │
│      → Bundle + catalog hosting                             │
│                                                             │
│  TIER 2: ANDROID ONLY — use when needed                    │
│  ├── HybridCLR                                              │
│  │   → Hot-fix critical code bugs                           │
│  ├── xLua                                                   │
│  │   → Dynamic game logic                                   │
│  └── APK patching                                           │
│      → Full hot update (Android only)                       │
│                                                             │
│  TIER 3: RISKY ON iOS — avoid                              │
│  ├── HybridCLR on iOS                                       │
│  │   → Only bug-fixes, not new features                     │
│  └── Downloading Lua scripts on iOS                         │
│      → Apple may reject                                     │
│                                                             │
│  NEVER:                                                      │
│  └── Downloading native code (dylib/so) on iOS              │
│      → Immediate rejection                                  │
└────────────────────────────────────────────────────────────┘
```

---

## 11. AR Foundation

### What Is It?

Unity AR Foundation is a cross-platform AR framework — a common API for ARKit (iOS) and ARCore (Android). It allows overlaying Unity 3D content on the device's camera feed. Instead of writing separate ARKit/ARCore code, you write once in AR Foundation.

### AR Foundation Architecture

```
┌──────────────────────────────────────────────────────────┐
│  AR Foundation (common API)                               │
│  ├── ARSession — AR session management                   │
│  ├── ARSessionOrigin / XROrigin — AR world coordinates   │
│  ├── ARCameraManager — camera feed as background         │
│  ├── ARPlaneManager — surface detection                  │
│  ├── ARRaycastManager — raycasts into AR world           │
│  ├── ARAnchorManager — anchors (persistent positions)    │
│  ├── ARTrackedImageManager — image tracking              │
│  ├── ARFaceManager — face tracking                       │
│  ├── ARPointCloudManager — point cloud                   │
│  └── AROcclusionManager — occlusion (real objects front) │
│                                                           │
│           ↓ implementation per platform ↓                │
│                                                           │
│  ┌─────────────────┐    ┌──────────────────┐              │
│  │  ARKit XR Plugin │    │  ARCore XR Plugin│              │
│  │  (com.unity.xr.  │    │  (com.unity.xr.  │              │
│  │   arkit)          │    │   arcore)         │              │
│  │                   │    │                   │              │
│  │  iOS 11+          │    │  Android 7.0+     │              │
│  │  A9+ chip         │    │  ARCore supported │              │
│  │  ARKit 6.0        │    │  devices          │              │
│  └─────────────────┘    └──────────────────┘              │
└──────────────────────────────────────────────────────────┘
```

### How Does It Work with Flutter (unity_kit)?

```
┌──────────────────────────────────────────────────────────┐
│  Flutter App                                              │
│  ├── Navigation (GoRouter)                               │
│  ├── State Management (Cubit)                            │
│  ├── AR Controls (Dart widgets over Unity)               │
│  │   ├── "Place model" button                            │
│  │   ├── Scale/rotate sliders                            │
│  │   ├── Take photo button                               │
│  │   ├── Model picker (horizontal scroll)                │
│  │   └── "Back" button                                   │
│  │                                                        │
│  └── UnityView widget (full screen)                      │
│       └── Unity AR Session                                │
│            ├── Camera feed (background)                   │
│            ├── Detected planes (visualization)            │
│            ├── 3D Model (loaded from Addressables)        │
│            │   ├── Shadows on AR plane                    │
│            │   ├── Light estimation applied               │
│            │   └── Animations playing                     │
│            └── Particle effects                           │
│                                                           │
│  Communication:                                           │
│  Flutter → Unity: "PlaceModel", "ScaleModel", "RotateModel"│
│  Unity → Flutter: "ar_plane_detected", "model_placed",   │
│                   "ar_tracking_state_changed"             │
└──────────────────────────────────────────────────────────┘
```

### AR Foundation Features — Detailed Matrix

| Feature | iOS (ARKit) | Android (ARCore) | Usage |
|---------|:-:|:-:|---------|
| **Plane detection** | Yes (horizontal + vertical) | Yes (horizontal + vertical) | Place model on floor/table |
| **Image tracking** | Yes (up to 100 ref images) | Yes (up to 20 ref images) | Scan a card -> show 3D model |
| **Face tracking** | Yes (TrueDepth, 52 blendshapes) | Yes (limited, no depth) | Face filter with model (AR selfie) |
| **Body tracking** | Yes (2D + 3D skeleton) | No | Model mimics user poses |
| **Light estimation** | Yes (directional, ambient, probes) | Yes (ambient, directional) | Realistic model lighting in AR |
| **LiDAR meshing** | Yes (Pro models only) | No | Accurate scene mesh (occlusion, physics) |
| **Raycasting** | Yes | Yes | Tap on screen -> position in AR space |
| **Anchors** | Yes (persistent!) | Yes (Cloud Anchors) | Save model position -> return later |
| **Occlusion** | Yes (people + LiDAR) | Yes (Depth API, limited devices) | Model behind a real object |
| **Environment probes** | Yes | Yes | Environment reflections on model |
| **Object tracking** | Yes (scan 3D object) | No | Replace a real object with a model |
| **Geo anchors** | Yes (ARKit 6+) | Yes (Geospatial API) | Place model at a specific GPS location |

### Full AR Manager Implementation (C#)

```csharp
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;
using System.Collections.Generic;

/// <summary>
/// Manages the AR session and communication with Flutter.
/// Mount on a GameObject with ARSession, XROrigin.
/// </summary>
public class ARModelManager : FlutterMonoBehaviour
{
    [SerializeField] private ARSession arSession;
    [SerializeField] private ARRaycastManager raycastManager;
    [SerializeField] private ARPlaneManager planeManager;
    [SerializeField] private AROcclusionManager occlusionManager;

    private GameObject _currentModel;
    private readonly List<ARRaycastHit> _raycastHits = new();
    private bool _isPlacementMode = true;

    // ─── Flutter Messages ───
    protected override void OnFlutterMessage(string method, string data)
    {
        switch (method)
        {
            case "EnableAR":
                var payload = JsonUtility.FromJson<ARPayload>(data);
                _ = EnableAR(payload.modelId);
                break;

            case "DisableAR":
                DisableAR();
                break;

            case "PlaceModelAtScreenPoint":
                var pos = JsonUtility.FromJson<ScreenPoint>(data);
                PlaceModelAtScreenPoint(new Vector2(pos.x, pos.y));
                break;

            case "ScaleModel":
                var scaleData = JsonUtility.FromJson<ScalePayload>(data);
                ScaleModel(scaleData.scale);
                break;

            case "RotateModel":
                var rotData = JsonUtility.FromJson<RotatePayload>(data);
                RotateModel(rotData.angle);
                break;

            case "TakeScreenshot":
                _ = TakeScreenshot();
                break;
        }
    }

    // ─── Enable AR Session ───
    private async Task EnableAR(string modelId)
    {
        arSession.enabled = true;
        planeManager.enabled = true;

        // Listen for detected planes
        planeManager.planesChanged += OnPlanesChanged;

        // Load model
        _currentModel = await Addressables.InstantiateAsync($"Models/{modelId}").Task;
        _currentModel.SetActive(false); // Hide until user taps

        SendToFlutter("ar_enabled", JsonUtility.ToJson(new {
            modelId = modelId,
            message = "Point camera at a surface"
        }));
    }

    // ─── Plane Detection Callback ───
    private void OnPlanesChanged(ARPlanesChangedEventArgs args)
    {
        if (args.added.Count > 0 && _isPlacementMode)
        {
            SendToFlutter("ar_plane_detected", JsonUtility.ToJson(new {
                planeCount = planeManager.trackables.count,
                message = "Surface detected! Tap to place the model."
            }));
        }
    }

    // ─── Place Model at Screen Point (tap) ───
    private void PlaceModelAtScreenPoint(Vector2 screenPoint)
    {
        if (raycastManager.Raycast(screenPoint, _raycastHits, TrackableType.PlaneWithinPolygon))
        {
            Pose hitPose = _raycastHits[0].pose;

            if (_currentModel != null)
            {
                _currentModel.transform.position = hitPose.position;
                _currentModel.transform.rotation = hitPose.rotation;
                _currentModel.SetActive(true);
                _isPlacementMode = false;

                // Optionally: hide plane visualization
                foreach (var plane in planeManager.trackables)
                    plane.gameObject.SetActive(false);
                planeManager.planePrefab = null; // Stop visualizing new planes

                SendToFlutter("ar_model_placed", JsonUtility.ToJson(new {
                    positionX = hitPose.position.x,
                    positionY = hitPose.position.y,
                    positionZ = hitPose.position.z,
                    message = "Model placed! Use gestures to move/rotate."
                }));
            }
        }
    }

    // ─── Scale & Rotate ───
    private void ScaleModel(float scale)
    {
        if (_currentModel != null)
            _currentModel.transform.localScale = Vector3.one * Mathf.Clamp(scale, 0.1f, 3f);
    }

    private void RotateModel(float angle)
    {
        if (_currentModel != null)
            _currentModel.transform.Rotate(Vector3.up, angle);
    }

    // ─── Screenshot ───
    private async Task TakeScreenshot()
    {
        yield return new WaitForEndOfFrame();

        Texture2D screenshot = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, false);
        screenshot.ReadPixels(new Rect(0, 0, Screen.width, Screen.height), 0, 0);
        screenshot.Apply();

        byte[] bytes = screenshot.EncodeToPNG();
        string path = Path.Combine(Application.persistentDataPath,
            $"ar_screenshot_{DateTime.Now:yyyyMMdd_HHmmss}.png");
        File.WriteAllBytes(path, bytes);

        Destroy(screenshot);

        SendToFlutter("ar_screenshot_taken", JsonUtility.ToJson(new {
            path = path,
            message = "Photo saved!"
        }));
    }

    // ─── Disable AR ───
    private void DisableAR()
    {
        planeManager.planesChanged -= OnPlanesChanged;
        planeManager.enabled = false;
        arSession.enabled = false;

        if (_currentModel != null)
        {
            Addressables.ReleaseInstance(_currentModel);
            _currentModel = null;
        }

        _isPlacementMode = true;
    }

    private void OnDestroy() => DisableAR();

    // ─── Payloads ───
    [Serializable] struct ARPayload { public string modelId; }
    [Serializable] struct ScreenPoint { public float x; public float y; }
    [Serializable] struct ScalePayload { public float scale; }
    [Serializable] struct RotatePayload { public float angle; }
}
```

### Dart (Flutter) — AR UI Overlay

```dart
class ARScreen extends StatefulWidget {
  final UnityBridge bridge;
  final String modelId;

  const ARScreen({required this.bridge, required this.modelId});

  @override
  State<ARScreen> createState() => _ARScreenState();
}

class _ARScreenState extends State<ARScreen> {
  bool _planeDetected = false;
  bool _modelPlaced = false;
  double _modelScale = 1.0;

  @override
  void initState() {
    super.initState();
    widget.bridge.send(UnityMessage.command('EnableAR', {'modelId': widget.modelId}));
    widget.bridge.messageStream.listen(_onARMessage);
  }

  void _onARMessage(UnityMessage msg) {
    switch (msg.type) {
      case 'ar_plane_detected':
        setState(() => _planeDetected = true);
        break;
      case 'ar_model_placed':
        setState(() => _modelPlaced = true);
        break;
      case 'ar_screenshot_taken':
        final path = msg.data?['path'] as String? ?? '';
        _showScreenshotPreview(path);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        UnityView(bridge: widget.bridge),
        SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      widget.bridge.send(UnityMessage.command('DisableAR', {}));
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  if (_modelPlaced)
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      onPressed: () {
                        widget.bridge.send(UnityMessage.command('TakeScreenshot', {}));
                      },
                    ),
                ],
              ),
              const Spacer(),
              if (!_planeDetected)
                _buildInstruction('Point camera at a flat surface'),
              if (_planeDetected && !_modelPlaced)
                _buildInstruction('Tap the surface to place the model'),
              if (_modelPlaced)
                Slider(
                  value: _modelScale,
                  min: 0.2,
                  max: 3.0,
                  onChanged: (value) {
                    setState(() => _modelScale = value);
                    widget.bridge.send(
                      UnityMessage.to('ARModelManager', 'ScaleModel', {'scale': value}),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstruction(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      margin: const EdgeInsets.only(bottom: 40),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  void _showScreenshotPreview(String path) {
    // Show dialog with photo preview + share option
  }

  @override
  void dispose() {
    widget.bridge.send(UnityMessage.command('DisableAR', {}));
    super.dispose();
  }
}
```

### Image Tracking — Scan a Card

```csharp
// Scenario: physical card with QR/image -> scan -> show 3D model

public class ImageTracker : FlutterMonoBehaviour
{
    [SerializeField] private ARTrackedImageManager imageManager;
    [SerializeField] private XRReferenceImageLibrary imageLibrary;

    private readonly Dictionary<string, GameObject> _trackedModels = new();

    void OnEnable() => imageManager.trackedImagesChanged += OnTrackedImagesChanged;
    void OnDisable() => imageManager.trackedImagesChanged -= OnTrackedImagesChanged;

    private void OnTrackedImagesChanged(ARTrackedImagesChangedEventArgs args)
    {
        foreach (var trackedImage in args.added)
        {
            string imageName = trackedImage.referenceImage.name; // e.g. "card_001"
            _ = SpawnModelOnCard(imageName, trackedImage.transform);

            SendToFlutter("ar_card_detected", JsonUtility.ToJson(new {
                cardId = imageName,
                message = $"Card {imageName} detected!"
            }));
        }

        foreach (var trackedImage in args.updated)
        {
            if (_trackedModels.TryGetValue(trackedImage.referenceImage.name, out var model))
            {
                model.transform.position = trackedImage.transform.position;
                model.transform.rotation = trackedImage.transform.rotation;
                model.SetActive(trackedImage.trackingState == TrackingState.Tracking);
            }
        }
    }

    private async Task SpawnModelOnCard(string cardId, Transform anchor)
    {
        string modelId = cardId.Replace("card_", "model_"); // card_001 -> model_001
        var model = await Addressables.InstantiateAsync($"Models/{modelId}", anchor).Task;
        model.transform.localPosition = Vector3.up * 0.1f; // Raise above card
        _trackedModels[cardId] = model;
    }
}
```

### Platform Notes and Requirements

**iOS (ARKit):**
- **Minimum requirements**: A9+ chip (iPhone 6s, iPad 2017+), iOS 11+
- **LiDAR**: iPhone 12 Pro+, iPad Pro 2020+. Enables: mesh scanning, accurate occlusion, faster plane detection
- **Face tracking**: TrueDepth camera (iPhone X+). 52 blendshapes (ARKit)
- **Privacy Manifest**: **MUST** declare `NSCameraUsageDescription` + reason in Privacy Manifest
- **Permissions**: Camera permission request in Flutter BEFORE starting AR session in Unity
- **World tracking**: 6DoF (position + rotation), persistent anchors (survive app restart)

**Android (ARCore):**
- **Minimum requirements**: Android 7.0+, Google Play Services for AR installed
- **Supported device list**: [developers.google.com/ar/devices](https://developers.google.com/ar/devices)
- **Huawei**: Devices without Google Play Services need HMS AR Engine (separate plugin)
- **Depth API**: Samsung Galaxy S20+, Pixel 4+. Enables occlusion without LiDAR
- **Cloud Anchors**: Shared AR experiences between devices
- **Geospatial API**: Place content at a specific GPS location

**Flutter-specific:**
- Camera permission: handle in Flutter (`permission_handler`) BEFORE sending `EnableAR` to Unity
- AR view must be full-screen (Unity renders camera feed)
- Flutter widgets overlay on top (Stack widget) — buttons, sliders, info panels
- **Battery**: AR session consumes a lot of battery. Inform the user or limit session time

---

## 12. Platform Differences (iOS vs Android)

### iOS — Key Restrictions

| Restriction | Details | Impact |
|-------------|---------|--------|
| **No JIT** | AOT mandatory (IL2CPP). No `System.Reflection.Emit`, no dynamic code generation | Test reflection-heavy code on device (Editor uses JIT -> masks problems) |
| **Guideline 3.3.2** | Cannot download executable/interpreted code from server. Assets OK | Addressables = OK. HybridCLR/Lua from server = risk |
| **Generic limitations** | AOT must see all generic instantiations at compile time | Add `[Preserve]` attribute or link.xml for reflection-used generics |
| **Privacy Manifest** | Since May 2024 — mandatory manifest declaring API usage | Camera (AR), UserDefaults (cache), File access — declare in manifest |
| **App Sandbox** | Only `Application.persistentDataPath` for writing | Downloaded bundles, cache, screenshots -> persistentDataPath |
| **Cellular download limit** | ~200MB limit for LTE/5G downloads | Bundles per model <10MB. Inform about Wi-Fi for large downloads |
| **Metal only** | OpenGL ES deprecated since iOS 12 | Test shaders with Metal backend |
| **Background restrictions** | App in background -> Unity pauses | Bundle downloads must be in foreground |
| **App size limit** | App Store: 4GB max. Cellular limit ~200MB | Use Addressables remote -> small base app |

**Critical C# patterns that DO NOT work on iOS (IL2CPP):**

```csharp
// DOES NOT WORK — System.Reflection.Emit
var dynamicMethod = new DynamicMethod("test", typeof(int), Type.EmptyTypes);

// DOES NOT WORK — dynamic keyword
dynamic obj = GetSomething(); obj.Method(); // runtime fail

// RISK — generic with reflection
typeof(List<>).MakeGenericType(someType); // crash if AOT did not see this type

// WORKS — explicit generics
var list = new List<GameModel>(); // AOT sees type at compile time

// WORKAROUND — Preserve attribute
[Preserve]
public class GenericHelper {
    // Forces AOT compilation for this generic
    static void PreserveGenerics() {
        new Dictionary<string, List<GameModel>>();
    }
}
```

### Android — Key Restrictions

| Restriction | Details | Impact |
|-------------|---------|--------|
| **Scoped Storage (11+)** | Only app-specific directories without permissions | Always `Application.persistentDataPath` |
| **16KB page size (15+)** | Google Play requires 16KB page size support. Requires Unity 6000.0.38+ | Use Unity 6000+ LTS |
| **StreamingAssets** | Packed in APK (compressed in JAR). `File.ReadAllBytes()` does not work | Always `UnityWebRequest` to read StreamingAssets |
| **Play Asset Delivery** | Base APK limit: 150MB (AAB). Above -> use asset packs | Large bundles as on-demand PAD |
| **Fragmentation** | GPU: Adreno, Mali, PowerVR. RAM: 2-16GB. Android 7.0-15+ | Test on minimum: 2GB RAM + Mali GPU + Android 9 |
| **Vulkan vs OpenGL ES** | Vulkan = newer, faster, but not on all devices | Auto Graphics API -> Vulkan with OpenGL ES 3.0 fallback |
| **64-bit requirement** | Google Play requires 64-bit (arm64) since 2019 | Unity IL2CPP ARM64 = default |

**Android-specific: Google Play Asset Delivery (PAD):**

```
┌──────────────────────────────────────────────────────┐
│  Play Asset Delivery — three modes:                   │
│                                                       │
│  install-time:                                        │
│  ├── Downloaded TOGETHER with APK at installation    │
│  ├── Available immediately after install             │
│  └── Use: core assets, shared materials              │
│                                                       │
│  fast-follow:                                         │
│  ├── Downloaded AUTOMATICALLY after install          │
│  ├── Does not block installation                     │
│  └── Use: initial model collection, base scenes      │
│                                                       │
│  on-demand:                                           │
│  ├── Downloaded ON USER REQUEST                       │
│  ├── Ideal for on-demand content                     │
│  └── Use: individual models, AR assets, seasonal     │
│                                                       │
│  Max per pack: 512MB (install-time: 1GB)             │
│  Max total: 2GB download size                         │
└──────────────────────────────────────────────────────┘
```

### Common Mobile Restrictions

| Restriction | Details | Mitigation |
|-------------|---------|------------|
| **Memory** | Low-end: 2GB total (~300MB for app). High-end: 8GB+ (~800MB) | Device tier detection -> adaptive quality |
| **Thermal throttling** | Sustained 100% CPU/GPU -> throttle after 3-5 min | Target 60fps with headroom |
| **Background pause** | Unity pauses in background | Save state. Resume gracefully |
| **Shader compilation** | First render of new shader variant = 50-200ms stutter | `ShaderVariantCollection.WarmUp()` at startup |
| **Garbage Collection** | Unity GC = stop-the-world | Object pooling. Avoid allocations in Update(). Incremental GC |
| **Draw calls** | Mobile GPU sweet spot = 50-100 draw calls/frame | Static/dynamic batching. SRP Batcher. GPU instancing |
| **Texture memory** | RGBA32 2048x2048 = 16MB | ASTC compression. Texture streaming. LOD |
| **Battery drain** | GPU + CPU + Network = fast discharge | Adaptive FPS (30fps idle, 60fps interaction) |

### Platform Comparison — Decision Matrix

| Aspect | iOS | Android |
|--------|-----|---------|
| **Dynamic code loading** | FORBIDDEN (Guideline 3.3.2) | ALLOWED |
| **Asset downloads** | ALLOWED (assets != code) | ALLOWED |
| **Background downloads** | Limited (NSURLSession background) | Limited (Doze mode) |
| **File system** | Sandbox only | Scoped Storage (11+) |
| **Min target** | iOS 13+ (practically) | Android 7.0+ (API 24) |
| **GPU API** | Metal only | Vulkan + OpenGL ES 3.0 fallback |
| **AR** | ARKit (A9+) | ARCore (limited device list) |
| **App distribution** | App Store only | Play Store + sideloading + alternative stores |
| **Review time** | 24-48h | A few hours (auto-review) |
| **Hot updates** | Assets only (Addressables) | Assets + code (HybridCLR, Lua) |
| **Privacy** | Privacy Manifest required | Permissions dialog |
| **Test devices** | iPhone SE -> iPhone 15 Pro (~10 models) | 100+ devices to test |

---

## 13. Integration with unity_kit

### What unity_kit Already Provides

unity_kit has full communication and lifecycle infrastructure — the foundation for all scenarios described in this document.

**Dart (Flutter) — ready components:**

| Component | File | Purpose |
|-----------|------|---------|
| `UnityBridge` (abstract) | `src/bridge/unity_bridge.dart` | Flutter-Unity communication interface |
| `UnityBridgeImpl` | `src/bridge/unity_bridge.dart` | Production bridge implementation |
| `MessageHandler` | `src/bridge/message_handler.dart` | Message routing by `type` |
| `ReadinessGuard` | `src/bridge/readiness_guard.dart` | Message queuing before Unity readiness (max 100) |
| `MessageBatcher` | `src/bridge/message_batcher.dart` | Message coalescence (16ms window, coalesce by key) |
| `MessageThrottler` | `src/bridge/message_throttler.dart` | Rate limiting (100ms window, drop/keepLatest/keepFirst) |
| `LifecycleManager` | `src/bridge/lifecycle_manager.dart` | State machine: uninitialized->initializing->ready->paused->disposed |
| `UnityView` | `src/widgets/unity_view.dart` | Widget embedding Unity (AndroidView/UiKitView) |
| `UnityConfig` | `src/models/unity_config.dart` | Configuration: sceneName, fullscreen, targetFrameRate, platformViewMode |
| `UnityMessage` | `src/models/unity_message.dart` | Message model with factories: `.command()`, `.to()` |
| `UnityEvent` | `src/models/unity_event.dart` | Event with timestamp: `.created()`, `.error()`, `.sceneLoaded()` |
| `SceneInfo` | `src/models/scene_info.dart` | Scene info: name, buildIndex, isLoaded, isValid |
| `UnityAssetLoader` (abstract) | `src/streaming/` | Loading strategy abstraction (Addressables / raw bundles) |
| `StreamingController` | `src/streaming/` | Content download orchestration |
| `ContentBundle` | `src/streaming/` | Downloadable content model with integrity checks (sha256, dependencies) |
| Exception hierarchy | `src/exceptions/` | EngineNotReady, Communication, Bridge, Lifecycle exceptions |

**C# (Unity) — ready components:**

| Component | File | Purpose |
|-----------|------|---------|
| `FlutterBridge.cs` | `Scripts/UnityKit/` | Singleton endpoint — `ReceiveMessage(json)`. Typed + routed messages |
| `MessageRouter.cs` | `Scripts/UnityKit/` | Static registry: `Register(target, handler)`, `Route(target, method, data)` |
| `FlutterMonoBehaviour.cs` | `Scripts/UnityKit/` | Base class — auto-registration in Router, abstract `OnFlutterMessage()` |
| `FlutterMessage.cs` | `Scripts/UnityKit/` | Serializable model: target, method, data |
| `NativeAPI.cs` | `Scripts/UnityKit/` | Platform bridge: `SendToFlutter()`, `NotifySceneLoaded()` |
| `SceneTracker.cs` | `Scripts/UnityKit/` | Auto-hooks `SceneManager.sceneLoaded/Unloaded`, notifies Flutter |
| `MessageBatcher.cs` | `Scripts/UnityKit/` | Batching outgoing messages (C# side) |
| `FlutterAddressablesManager.cs` | `Scripts/UnityKit/` | Addressables integration with bridge |

### How Scenarios Map to unity_kit

```text
┌─────────────────────────────────────────────────────────────┐
│  SCENARIO                        UNITY_KIT COMPONENTS        │
│                                                              │
│  Load model (Addressables)       bridge.send() → ModelManager│
│  ├── Dart: UnityMessage.to()     → FlutterMonoBehaviour      │
│  ├── C#: OnFlutterMessage()      → Addressables              │
│  └── Dart: messageStream         ← NativeAPI.SendToFlutter   │
│                                                              │
│  Change scene                    bridge.send() → SceneController│
│  ├── Dart: UnityMessage.command()→ SceneManager.LoadSceneAsync│
│  └── Dart: sceneStream          ← SceneTracker.cs            │
│                                                              │
│  Load glTF from URL              bridge.send() → GltfLoader  │
│  ├── Dart: UnityMessage.to()    → glTFast.Load(url)          │
│  └── Dart: messageStream        ← SendToFlutter              │
│                                                              │
│  Check catalog update            automatically on start       │
│  ├── C#: CatalogUpdater         → Addressables.CheckFor...   │
│  └── Dart: messageStream        ← "catalog_updated"          │
│                                                              │
│  Remote Config                   automatically on start       │
│  ├── C#: RemoteConfigManager    → UGS FetchConfigs           │
│  └── Dart: messageStream        ← "remote_config_updated"    │
│                                                              │
│  AR mode                         bridge.send() → ARManager   │
│  ├── Dart: UnityMessage.command()→ AR Foundation APIs         │
│  └── Dart: messageStream        ← "ar_model_placed"          │
│                                                              │
│  Preload model                   bridge.send() → ModelManager│
│  ├── Dart: UnityMessage.to()    → Addressables.LoadAssetAsync│
│  └── Dart: messageStream        ← "model_preloaded"          │
│                                                              │
│  Download progress               automatically per operation  │
│  ├── C#: per component          → GetDownloadStatus()         │
│  └── Dart: messageStream        ← "*_progress"               │
└─────────────────────────────────────────────────────────────┘
```

### Full Example Flow — From Start to Interaction

```dart
// ═══════════════════════════════════════════════════════
// Dart (Flutter) — complete production flow
// ═══════════════════════════════════════════════════════

class ModelViewerScreen extends StatefulWidget {
  final String modelId;
  final String? modelSource; // 'addressables' or 'gltf'
  final String? glbUrl;      // if source == 'gltf'

  const ModelViewerScreen({
    required this.modelId,
    this.modelSource = 'addressables',
    this.glbUrl,
  });

  @override
  State<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends State<ModelViewerScreen> {
  late final UnityBridge _bridge;
  late final ModelController _modelController;

  bool _isReady = false;
  bool _isModelLoaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bridge = UnityBridgeImpl();
    _modelController = ModelController(_bridge);
    _initializeUnity();
  }

  Future<void> _initializeUnity() async {
    // 1. Initialize bridge
    await _bridge.initialize();

    // 2. Wait for Unity readiness (catalog update + remote config done)
    _bridge.eventStream
      .where((e) => e.type == UnityEventType.loaded)
      .first
      .then((_) {
        setState(() => _isReady = true);
        _loadModel();
      });

    // 3. Listen for events
    _bridge.messageStream.listen(_onMessage);
  }

  void _onMessage(UnityMessage msg) {
    switch (msg.type) {
      case 'model_loading':
        setState(() {
          _isModelLoaded = false;
          _errorMessage = null;
        });
        break;

      case 'model_download_required':
        setState(() {
          _isDownloading = true;
          _downloadProgress = 0;
        });
        break;

      case 'bundle_download_progress':
      case 'gltf_download_progress':
        setState(() {
          _downloadProgress = (msg.data?['progress'] as num?)?.toDouble() ?? 0;
        });
        break;

      case 'model_loaded':
      case 'gltf_loaded':
        setState(() {
          _isModelLoaded = true;
          _isDownloading = false;
        });
        break;

      case 'model_error':
      case 'gltf_error':
        setState(() {
          _errorMessage = msg.data?['error'] as String? ?? 'Unknown error';
          _isDownloading = false;
        });
        break;

      case 'remote_config_updated':
        // Config updated — Unity applied settings itself
        break;

      case 'catalog_updated':
        // New content available — optionally show "NEW" badge
        break;
    }
  }

  void _loadModel() {
    if (widget.modelSource == 'gltf' && widget.glbUrl != null) {
      _modelController.loadModelFromUrl(widget.modelId, widget.glbUrl!);
    } else {
      _modelController.loadModel(widget.modelId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Unity view (full screen)
          if (_isReady)
            UnityView(
              bridge: _bridge,
              config: UnityConfig(
                sceneName: 'GameShowroom',
                targetFrameRate: 60,
              ),
            ),

          // Loading overlay
          if (!_isReady || _isDownloading)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _isDownloading
                      ? 'Downloading model... ${(_downloadProgress * 100).toInt()}%'
                      : 'Initializing...',
                  ),
                  if (_isDownloading)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: LinearProgressIndicator(value: _downloadProgress),
                    ),
                ],
              ),
            ),

          // Error
          if (_errorMessage != null)
            Center(child: Text('Error: $_errorMessage')),

          // Controls (visible when model loaded)
          if (_isModelLoaded)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.rotate_left,
                    onPressed: () => _modelController.setTransform(ry: -45),
                  ),
                  _ActionButton(
                    icon: Icons.rotate_right,
                    onPressed: () => _modelController.setTransform(ry: 45),
                  ),
                  _ActionButton(
                    icon: Icons.animation,
                    onPressed: () => _modelController.setAnimation('dance'),
                  ),
                  _ActionButton(
                    icon: Icons.color_lens,
                    onPressed: () => _modelController.setMaterial('Materials/Holographic'),
                  ),
                  _ActionButton(
                    icon: Icons.view_in_ar,
                    onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ARScreen(
                        bridge: _bridge,
                        modelId: widget.modelId,
                      )),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _modelController.unloadModel();
    _bridge.dispose();
    super.dispose();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      mini: true,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}
```

```csharp
// ═══════════════════════════════════════════════════════
// C# (Unity) — complete GameManager bootstrap
// ═══════════════════════════════════════════════════════

/// <summary>
/// Main game manager. Mount on a GameObject in the Core scene (persistent).
/// Coordinates: catalog update, remote config, shader warmup, readiness.
/// </summary>
public class GameManager : MonoBehaviour
{
    [SerializeField] private ShaderVariantCollection shaderVariants;

    private CatalogUpdater _catalogUpdater;
    private RemoteConfigManager _remoteConfigManager;
    private DeviceTierDetector _tierDetector;

    private async void Start()
    {
        // 1. Detect device tier → set quality
        _tierDetector = new DeviceTierDetector();
        _tierDetector.ApplyQualitySettings();

        // 2. Shader warmup (eliminates stutter on first render)
        if (shaderVariants != null)
            shaderVariants.WarmUp();

        // 3. Catalog update (check for new content)
        _catalogUpdater = gameObject.AddComponent<CatalogUpdater>();
        await _catalogUpdater.CheckAndUpdate();

        // 4. Remote Config (fetch settings)
        _remoteConfigManager = gameObject.AddComponent<RemoteConfigManager>();
        await _remoteConfigManager.Initialize();

        // 5. Ready! Notify Flutter
        NativeAPI.SendToFlutter(JsonUtility.ToJson(new {
            type = "ready",
            deviceTier = _tierDetector.Tier.ToString(),
            catalogUpdated = _catalogUpdater.WasUpdated,
        }));
    }
}
```

### Content Loading Architecture — Full Flow

```text
Flutter (Dart)                        Unity (C#)
──────────────                        ──────────

┌─ APP START ─┐
│             │
│ bridge      │
│ .initialize │──────────────────────→ FlutterBridge.Start()
│             │                        │
│             │                        ├─ CatalogUpdater.CheckAndUpdate()
│             │                        │   ├─ CheckForCatalogUpdates()
│             │                        │   ├─ (new hash? → download catalog)
│             │                        │   └─ SendToFlutter("catalog_updated")
│             │                        │
│             │                        ├─ RemoteConfigManager.Initialize()
│             │                        │   ├─ FetchConfigs(userAttrs, appAttrs)
│             │                        │   ├─ Apply quality settings per tier
│             │                        │   └─ SendToFlutter("remote_config_updated")
│             │                        │
│             │                        ├─ ShaderWarmup.WarmUp()
│             │                        │
│             │  ←────────────────────── SendToFlutter("ready")
│             │
└─────────────┘

┌─ LOAD MODEL ┐
│             │
│ controller  │
│ .loadModel()│──────────────────────→ ModelManager.OnFlutterMessage("LoadModel")
│             │                        │
│             │  ←─────(progress)───── │ SendToFlutter("model_loading", {progress})
│             │                        │
│             │                        ├─ Check source:
│             │                        │   ├─ "addressables":
│             │                        │   │   ├─ EnsureModelDownloaded(modelId)
│             │                        │   │   │   ├─ GetDownloadSizeAsync()
│             │                        │   │   │   ├─ (>0? → download bundle)
│             │                        │   │   │   └─ (0 = in cache, skip)
│             │                        │   │   ├─ InstantiateAsync("Models/{modelId}")
│             │                        │   │   └─ Apply LOD, materials, animations
│             │                        │   │
│             │                        │   └─ "gltf":
│             │                        │       ├─ DownloadCacheAndLoad(url)
│             │                        │       │   ├─ Check local cache
│             │                        │       │   ├─ Download .glb if needed
│             │                        │       │   └─ glTFast.Load() → Instantiate
│             │                        │       ├─ NormalizeScale(targetHeight)
│             │                        │       └─ CenterModel()
│             │                        │
│             │                        ├─ Apply Remote Config:
│             │                        │   ├─ Material variant (from config)
│             │                        │   ├─ Animation speed
│             │                        │   ├─ Particle effects on/off
│             │                        │   └─ Lighting preset
│             │                        │
│             │  ←────────────────────── SendToFlutter("model_loaded", {
│             │                            modelId, bounds, meshCount, success
│             │                         })
│             │
│ setState(   │
│   loaded    │
│ )           │
└─────────────┘

┌─ INTERACTIONS ┐
│               │
│ .setAnimation │───→ ModelManager.SetAnimation("idle", 1.5)
│ .setMaterial  │───→ ModelManager.SwapMaterial("Materials/Holographic")
│ .setTransform │───→ ModelManager.ApplyTransform({rx:45})
│ .swapModel    │───→ ModelManager.SwapModel(newId) [load new → destroy old]
│               │
└───────────────┘

┌─ AR MODE ─────┐
│               │
│ .enableAR()   │───→ ARModelManager.EnableAR(modelId)
│               │      ├─ Start ARSession
│               │      ├─ Enable PlaneManager
│               │      └─ Load model (hidden)
│               │
│               │  ←──── "ar_plane_detected"
│ show "tap     │
│  to place"    │
│               │
│ .placeModel() │───→ ARModelManager.PlaceModelAtScreenPoint(x,y)
│               │      ├─ ARRaycast → hit pose
│               │      ├─ Position model on plane
│               │      └─ Apply light estimation
│               │
│               │  ←──── "ar_model_placed"
│ show controls │
│ (scale/rotate)│
│               │
│ .disableAR()  │───→ ARModelManager.DisableAR()
└───────────────┘
```

---

## Sources

- [Unity Docs: AssetBundles](https://docs.unity3d.com/Manual/AssetBundlesIntro.html)
- [Unity Docs: Addressables](https://docs.unity3d.com/Packages/com.unity.addressables@1.21/manual/index.html)
- [Unity Docs: SceneManager](https://docs.unity3d.com/ScriptReference/SceneManagement.SceneManager.html)
- [Unity Docs: Mesh API](https://docs.unity3d.com/Manual/GeneratingMeshGeometryProcedurally.html)
- [Unity glTFast](https://docs.unity3d.com/Packages/com.unity.cloud.gltfast@5.2/manual/index.html)
- [UnityGLTF (Khronos)](https://github.com/KhronosGroup/UnityGLTF)
- [Unity Remote Config](https://unity.com/products/remote-config)
- [Unity CCD](https://unity.com/products/cloud-content-delivery)
- [Unity AR Foundation](https://docs.unity3d.com/Packages/com.unity.xr.arfoundation@5.1/manual/index.html)
- [HybridCLR](https://www.hybridclr.cn/en/docs/intro)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Unity: Comparing Runtime Asset Loading](https://unity.com/blog/comparing-runtime-asset-loading-technology)
- [Addressables Content Catalog Refresh](https://www.kittehface.com/2024/01/unity-addressables-content-catalog.html)
