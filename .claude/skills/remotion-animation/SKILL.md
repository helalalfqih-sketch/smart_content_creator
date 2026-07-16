---
name: remotion-animation
description: Generates highly professional, viral TikTok-style animations using Remotion and React. Use this skill when asked to create an animation, video, or scene in Remotion.
argument-hint: [description of the animation]
---

# Remotion Professional Animation Guidelines

When generating or modifying Remotion components, **DO NOT** create boring, static, or linear animations. You must follow these viral TikTok-style professional pacing and animation rules:

## 1. Core Physics & Timing
- **Springs over Linear**: Always use `spring()` instead of linear transitions.
  - Set bouncy configs: `config: { damping: 12, stiffness: 120 }` (or similar) to make elements pop-in naturally.
- **Interpolation**: Use `interpolate()` to tie the spring progress (or frame) to `scale`, `opacity`, or `translateY`.
- **Fast Pacing**: Scenes should last 1 to 2 seconds (30 to 60 frames at 30fps).
- **Staggering**: If multiple elements appear, stagger them by subtracting from the frame: `frame: frame - delay`.

## 2. Attention Grabbers (The Hook)
- **Shake Effect**: For the first 1-2 seconds, use `Math.sin(frame * 0.8) * 10` on the `translateX` or `translateY` to add an organic shake/vibration effect to text or logos.
- **Motion Blur**: Interpolate CSS `filter: blur(Xpx)` fading to `0px` as elements enter the screen.

## 3. Typography & Styling
- **Big & Bold**: Text must be huge, bold (`fontWeight: '900'`), and highly contrasting.
- **Cinematic Overlays**: Add a `CinematicOverlay` component using `AbsoluteFill` that includes:
  - A subtle Vignette using `radial-gradient(circle, transparent 30%, rgba(0,0,0,0.6) 100%)`.
  - Top and bottom cinematic black bars (if appropriate).
- **Glassmorphism / Glow**: Use text-shadows (`textShadow: '0px 10px 30px rgba(0,0,0,0.8)'`) or box-shadows to make elements stand out against the background.

## 4. Execution Example
Here is the mental model for your code generation:
```tsx
const progress = spring({ frame: frame - delay, fps, config: { damping: 10, stiffness: 150 } });
const scale = interpolate(progress, [0, 1], [0.5, 1]);
const opacity = interpolate(progress, [0, 1], [0, 1]);
const shake = Math.sin(frame) * 5 * (1 - progress); // Shake stops as it settles

return (
  <AbsoluteFill style={{ transform: `scale(${scale}) translateX(${shake}px)`, opacity }}>
    {/* Content */}
  </AbsoluteFill>
);
```

## Your Task
Using these guidelines, generate the Remotion component for: $ARGUMENTS
