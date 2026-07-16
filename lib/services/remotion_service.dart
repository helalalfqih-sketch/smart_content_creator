import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http; // ignore: unused_import
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:smart_content_creator/services/ai/gemini_director_service.dart'; // ignore: unused_import
import '../core/services/log_service.dart';
import '../models/video_composition.dart';
import '../services/ai_provider.dart';
import '../core/models/api_provider.dart';
import '../controllers/settings_controller.dart';
import '../core/utils/json_utils.dart';

/// 🎬 Remotion Service - The Video Generation Engine
/// Orchestrates the communication between Flutter and the AI Video Server
class RemotionService extends GetxService {
  late String _projectPath;
  late String _enginePath;

  @override
  void onInit() {
    super.onInit();
    _projectPath = Directory.current.path;
    _enginePath = p.join(_projectPath, 'video_engine');
  }

  /// 🧠 STEP 1: Compose the Project (Prompt -> VideoProject JSON)
  /// Standalone: Uses Gemini directly via AIProviderFactory
  Future<VideoProject?> composeProject(String prompt) async {
    try {
      LogService.info("Composing Project Standalone for: $prompt", tag: 'REMOTION');
      
      final systemPrompt = """
        You are an Elite Viral Content Director for TikTok, Reels, and YouTube Shorts.
        Your goal is to create a high-retention, viral video structure based on the user's prompt.
        
        STRICT RULES:
        1. **The Hook (Scene 1)**: Must be an attention-grabbing statement or a shocking visual description.
        2. **Narrative Arc**: Keep it fast-paced, high energy, and emotional.
        3. **Visuals**: Use descriptive visual styles (e.g., 'Cyberpunk city at night', 'Ultra-realistic cinematic portrait').
        
        The JSON must follow this exact structure:
        {
          "id": "project_${DateTime.now().millisecondsSinceEpoch}",
          "title": "Viral Masterpiece Title",
          "prompt": "$prompt",
          "scenes": [
            {
              "id": "scene_1",
              "type": "cinematic",
              "visualUrl": "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1000",
              "subtitle": "SHORT PUNCHY TEXT (Max 10 words)",
              "duration": 3.0,
              "visualPrompt": "AI visual prompt description"
            }
          ],
          "backgroundMusicUrl": "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"
        }
        Return ONLY the JSON. No markdown. No explanation.
      """;

      // Call Gemini directly with the user's API key
      final settings = Get.find<SettingsController>();
      final apiKey = settings.getApiKey(ProviderType.gemini);
      
      if (apiKey.isEmpty) throw Exception("Gemini API Key is missing");

      final gemini = AIProviderFactory.getServiceByType(ProviderType.gemini);
      final result = await gemini.generateText(systemPrompt, apiKey: apiKey);
      
      final rawJson = JsonUtils.parseSafe(result.description);
      
      // Post-processing: Ensure visualUrl is VALID and working
      final stableImages = [
        "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=1080",
        "https://images.unsplash.com/photo-1460925895917-afdab827c52f?q=80&w=1080",
        "https://images.unsplash.com/photo-1508739773434-c26b3d09e071?q=80&w=1080",
        "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?q=80&w=1080",
        "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?q=80&w=1080",
      ];

      if (rawJson.containsKey('scenes') && rawJson['scenes'] is List) {
        final scenes = rawJson['scenes'] as List;
        for (int i = 0; i < scenes.length; i++) {
          var scene = scenes[i];
          if (scene is Map) {
            // If Gemini guessed an ID (often leads to 404), replace with our stable rotation
            scene['visualUrl'] = stableImages[i % stableImages.length];
          }
        }
      }
      
      LogService.info("Director response sanitized with stable assets.", tag: 'REMOTION');
      
      if (rawJson.isNotEmpty && rawJson.containsKey('scenes')) {
        return VideoProject.fromJson(rawJson);
      } else {
        LogService.error("Invalid Project Structure: Missing 'scenes'.", tag: 'REMOTION');
        return null;
      }
    } catch (e) {
      LogService.error("Composition Error (Standalone): $e", tag: 'REMOTION');
      return null;
    }
  }

  /// 🎬 STEP 2: Render the Project (VideoProject -> MP4 File)
  /// Standalone: Detects platform and uses FFmpeg for mobile or NPM for desktop
  Future<String?> renderProject(VideoProject project, {Function(String)? onStatusUpdate}) async {
    try {
      LogService.info("Rendering Project Standalone: ${project.title}", tag: 'REMOTION');
      
      if (Platform.isAndroid || Platform.isIOS) {
        return await _renderMobile(project, onStatusUpdate);
      }
      return await _renderDesktop(project, onStatusUpdate);
    } catch (e) {
      LogService.error("Render Error: $e", tag: 'REMOTION');
      return null;
    }
  }

  /// 📱 Mobile Rendering Engine (FFmpeg based)
  Future<String?> _renderMobile(VideoProject project, Function(String)? onStatusUpdate) async {
    onStatusUpdate?.call("📱 Initializing Multi-Scene Engine...");
    
    if (project.scenes.isEmpty) return null;
    
    final tempDir = await getTemporaryDirectory();
    final List<String> scenePaths = [];
    
    try {
      for (int i = 0; i < project.scenes.length; i++) {
        final scene = project.scenes[i];
        final scenePath = p.join(tempDir.path, "scene_$i.mp4");
        
        // Safer extension detection
        String ext = "jpg";
        try {
          ext = scene.visualUrl.split('?').first.split('.').last.toLowerCase();
          if (ext.length > 4) ext = "jpg"; // Fallback for weird URLs
        } catch (_) {}
        
        final localFile = File(p.join(tempDir.path, "input_scene_$i.$ext"));
        
        onStatusUpdate?.call("📥 Preparing Scene ${i + 1}/${project.scenes.length}...");
        
        if (scene.visualUrl.startsWith('http')) {
          final response = await http.get(Uri.parse(scene.visualUrl));
          if (response.statusCode == 200) {
            await localFile.writeAsBytes(response.bodyBytes);
          } else {
            continue;
          }
        } else {
          final pickedFile = File(scene.visualUrl);
          if (await pickedFile.exists()) {
            await pickedFile.copy(localFile.path);
          } else {
            continue;
          }
        }

        onStatusUpdate?.call("✨ Rendering Scene ${i + 1} (30fps + Transitions)...");
        final subtitleText = scene.subtitle?.replaceAll("'", "") ?? "";
        final bool isVideo = ext == 'mp4' || ext == 'mov' || ext == 'mkv' || ext == 'webm';
        final double dur = scene.duration;
        
        // TikTok Style Text Filter
        final String textFilter = "drawtext=text='$subtitleText':fontcolor=white:fontsize=75:x=(w-text_w)/2:y=(h-text_h)*0.82:box=1:boxcolor=black@0.6:boxborderw=30:borderw=2:bordercolor=black@0.2";
        // Fade Transitions Filter
        final String fadeFilter = "fade=t=in:st=0:d=0.5,fade=t=out:st=${dur - 0.5}:d=0.5";

        String command;
        if (isVideo) {
          command = '-i "${localFile.path}" -t $dur -r 30 -pix_fmt yuv420p '
                    '-vf "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2,$fadeFilter,$textFilter" '
                    '-y "$scenePath"';
        } else {
          command = '-loop 1 -i "${localFile.path}" -t $dur -r 30 -pix_fmt yuv420p '
                    '-vf "scale=8000:-1,zoompan=z=\'min(zoom+0.0015,1.5)\':x=\'iw/2-(iw/zoom/2)\':y=\'ih/2-(ih/zoom/2)\':d=${(dur * 30).toInt()}:s=1080x1920,$fadeFilter,$textFilter" '
                    '-y "$scenePath"';
        }
        
        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();
        
        if (ReturnCode.isSuccess(returnCode)) {
          scenePaths.add(scenePath);
        } else {
          final logs = await session.getLogs();
          LogService.error("FFmpeg Scene Error: ${logs.last.getMessage()}", tag: 'REMOTION');
          onStatusUpdate?.call("❌ Error in Scene ${i + 1}");
          return null;
        }
      }

      if (scenePaths.isEmpty) return null;

      // 🔗 Step 2: Concatenate Scenes
      onStatusUpdate?.call("🔗 Stitching Scenes Together...");
      final String listPath = p.join(tempDir.path, 'scenes.txt');
      final String silentVideoPath = p.join(tempDir.path, 'temp_silent_video.mp4');
      
      final listContent = scenePaths.map((path) => "file '$path'").join('\n');
      await File(listPath).writeAsString(listContent);

      final concatCommand = '-f concat -safe 0 -i "$listPath" -c copy -y "$silentVideoPath"';
      final concatSession = await FFmpegKit.execute(concatCommand);

      if (!ReturnCode.isSuccess(await concatSession.getReturnCode())) {
        LogService.error("FFmpeg Concat Error", tag: 'REMOTION');
        return scenePaths.first;
      }

      // 🎶 Step 3: Mix Background Music if available
      if (project.backgroundMusicUrl != null && project.backgroundMusicUrl!.startsWith('http')) {
        onStatusUpdate?.call("🎶 Adding Background Music...");
        final musicFile = File(p.join(tempDir.path, "bg_music.mp3"));
        final musicResponse = await http.get(Uri.parse(project.backgroundMusicUrl!));
        
        if (musicResponse.statusCode == 200) {
          await musicFile.writeAsBytes(musicResponse.bodyBytes);
          final finalVideoPath = p.join(tempDir.path, 'final_masterpiece_${DateTime.now().millisecondsSinceEpoch}.mp4');
          
          // Mix music: Reduce music volume to 0.3 to keep it as background
          final mixCommand = '-i "$silentVideoPath" -i "${musicFile.path}" '
                            '-filter_complex "[1:a]volume=0.3[music];[0:a][music]amix=inputs=2:duration=first[a]" '
                            '-map 0:v -map "[a]" -c:v copy -y "$finalVideoPath"';
          
          final mixSession = await FFmpegKit.execute(mixCommand);
          if (ReturnCode.isSuccess(await mixSession.getReturnCode())) {
            onStatusUpdate?.call("✅ Production Complete!");
            return finalVideoPath;
          }
        }
      }

      onStatusUpdate?.call("✅ Masterpiece Ready!");
      return silentVideoPath;
    } catch (e) {
      LogService.error("Multi-Scene Render Exception: $e", tag: 'REMOTION');
      return project.scenes.first.visualUrl;
    }
  }

  /// 💻 Desktop Rendering Engine (Remotion based)
  Future<String?> _renderDesktop(VideoProject project, Function(String)? onStatusUpdate) async {
    onStatusUpdate?.call("🎬 Preparing scenes for Remotion...");

    // 1. Prepare Props for Remotion
    final propsFile = File(p.join(_enginePath, 'props.json'));
    await propsFile.writeAsString(jsonEncode(project.toJson()));

    // 2. Execute Build
    final shell = Platform.isWindows ? 'npm.cmd' : 'npm';
    
    final result = await Process.run(
      shell,
      ['run', 'build', '--', 'SceneEngine', 'out.mp4', '--props', 'props.json'],
      workingDirectory: _enginePath,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      LogService.error("Render failed: ${result.stderr}", tag: 'REMOTION');
      return null;
    }

    final outputFile = File(p.join(_enginePath, 'out.mp4'));
    return await outputFile.exists() ? outputFile.path : null;
  }

  /// 🚀 Master Function (Backward Compatibility & Convenience)
  Future<String?> generateVideo(String prompt,
      {Function(String)? onStatusUpdate}) async {
    try {
      onStatusUpdate?.call("🧠 AI Director is composing your project...");
      final project = await composeProject(prompt);

      if (project == null) throw Exception("Composition Failed");

      onStatusUpdate?.call("🎬 Starting cinematic render...");
      return await renderProject(project, onStatusUpdate: onStatusUpdate);
    } catch (e) {
      LogService.error("GenerateVideo Error: $e", tag: 'REMOTION');
      return null;
    }
  }
}
